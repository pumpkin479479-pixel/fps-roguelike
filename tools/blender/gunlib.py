"""銃モデルを Blender のスクリプトで組み立てるための共通部品。

座標の約束(Blender 側):
    +Y = 銃口の向き / +Z = 上 / +X = 銃の右側。単位はメートル。
    原点 = グリップを握る位置(グリップの上端)。
glTF に書き出すと Godot では 銃口 = -Z、上 = +Y になる。

パーツは枠ごとに別オブジェクト(receiver / barrel / magazine / stock …)にし、
取り付け位置は全銃共通の名前の空オブジェクト(attach_* / muzzle)で示す。
動く部品(ボルトハンドル、引き金など)も別オブジェクトにして、動きはゲーム側で付ける。

色は共通パレット(PALETTE)から選ぶ。テクスチャは使わない。
"""

import math
import os
import sys

import bpy  # bmesh より先に読み込む(bpy モジュール版では必須)
import bmesh
from mathutils import Matrix, Vector

# 共通パレット: 名前 → (色, 金属感, 粗さ)
PALETTE = {
    "steel": ((0.050, 0.056, 0.070), 0.55, 0.42),   # 黒染めの鉄(金属感を強くしすぎるとゲーム内で真っ黒になる)
    "steel_worn": ((0.09, 0.095, 0.11), 0.65, 0.36),  # 擦れた鉄(小部品)
    "wood": ((0.20, 0.050, 0.022), 0.0, 0.55),       # 赤みのある木(ラッカー仕上げ)
    "wood_dark": ((0.14, 0.05, 0.018), 0.0, 0.6),
    "bakelite": ((0.13, 0.035, 0.018), 0.0, 0.45),    # 樹脂(オレンジがかった茶)
    "brass": ((0.55, 0.38, 0.12), 0.95, 0.3),
    "copper": ((0.55, 0.25, 0.12), 0.9, 0.35),       # 弾頭
    "primer": ((0.6, 0.6, 0.6), 0.9, 0.3),           # 雷管
    "steel_bright": ((0.12, 0.12, 0.13), 0.65, 0.40),
    "recess": ((0.010, 0.010, 0.012), 0.5, 0.7),     # 穴の奥(暗く)
    "sight_orange": ((1.0, 0.32, 0.04), 0.0, 0.45),  # 照星の目印(背景に埋もれないように)
    "glow": ((0.2, 0.8, 1.0), 0.0, 0.3),
}


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name):
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    color, metal, rough = PALETTE[name]
    m = bpy.data.materials.new("pal_" + name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Roughness"].default_value = rough
    if name == "glow":
        bsdf.inputs["Emission Color"].default_value = (*color, 1.0)
        bsdf.inputs["Emission Strength"].default_value = 4.0
    m.name = name
    return m


def _new_object(name, bm, mat, parent=None):
    mesh = bpy.data.meshes.new(name)
    # 座標の入れ替えで裏返った面を外向きに直す(裏返ったままだと、削りが失敗し、ゲームでは面が消える)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material(mat))
    if parent is not None:
        obj.parent = parent
    return obj


def prism(name, profile, width, mat, x=0.0, bevel=0.0):
    """横から見た形(YZ 平面の多角形、時計回りでも反時計回りでも可)を X 方向に厚み width で押し出す。"""
    bm = bmesh.new()
    verts_l = [bm.verts.new((x - width / 2, y, z)) for (y, z) in profile]
    verts_r = [bm.verts.new((x + width / 2, y, z)) for (y, z) in profile]
    bm.faces.new(verts_l)
    bm.faces.new(list(reversed(verts_r)))
    n = len(profile)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((verts_l[i], verts_l[j], verts_r[j], verts_r[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=1, affect="EDGES")
    obj = _new_object(name, bm, mat)
    smooth(obj)
    return obj


def box(name, center, size, mat, bevel=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0] + center[0], v.co.y * size[1] + center[1], v.co.z * size[2] + center[2]))
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=1, affect="EDGES")
    return _new_object(name, bm, mat)


def tube_y(name, y0, y1, radius, mat, x=0.0, z=0.0, segments=10, radius1=None):
    """Y 方向の円柱(銃身・ガスチューブなど)。radius1 を渡すと先細り / ラッパ型。"""
    bm = bmesh.new()
    r1 = radius if radius1 is None else radius1
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=radius, radius2=r1, depth=abs(y1 - y0))
    # create_cone は Z 方向なので Y 方向へ寝かせる
    for v in bm.verts:
        cx, cy, cz = v.co
        v.co = Vector((cx + x, cz + (y0 + y1) / 2, cy + z))
    obj = _new_object(name, bm, mat)
    smooth(obj, 50.0)
    return obj


def tube_x(name, center, length, radius, mat, segments=8):
    """X 方向の円柱(ボルトハンドルの軸など)。"""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=radius, radius2=radius, depth=length)
    for v in bm.verts:
        cx, cy, cz = v.co
        v.co = Vector((cz + center[0], cy + center[1], cx + center[2]))
    return _new_object(name, bm, mat)


# ---------------- 断面をつないで作る形(ロフト) ----------------
# 真横から押し出しただけの形は、上や斜めから見ると薄い板に見える。
# 本体・ハンドガード・ストック・グリップ・マガジンは、角を丸めた断面を並べてつなぐ。

def rounded_rect(w, h, r, seg=2):
    """幅 w・高さ h・角の半径 r の角丸長方形(中心原点、反時計回り)。seg は角1つの分割数。"""
    r = max(0.0, min(r, w / 2 - 1e-5, h / 2 - 1e-5))
    pts = []
    corners = [(w / 2 - r, h / 2 - r, 0), (-w / 2 + r, h / 2 - r, 90), (-w / 2 + r, -h / 2 + r, 180), (w / 2 - r, -h / 2 + r, 270)]
    for cx, cy, a0 in corners:
        for k in range(seg + 1):
            a = math.radians(a0 + 90 * k / seg)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def arch(w, h_side, h_top, seg=6):
    """下が平らで上が丸い断面(ダストカバー、上部ハンドガード用)。中心は底辺の中央。"""
    pts = [(w / 2, 0.0), (w / 2, h_side)]
    for k in range(1, seg):
        a = math.pi * k / seg
        pts.append((w / 2 * math.cos(a), h_side + h_top * math.sin(a)))
    pts += [(-w / 2, h_side), (-w / 2, 0.0)]
    return pts


def ring(center, u, v, pts2d):
    """2D の断面 pts2d を、中心 center・横軸 u・縦軸 v の面に置いた 3D の点列にする。"""
    c, u, v = Vector(center), Vector(u).normalized(), Vector(v).normalized()
    return [c + u * x + v * y for (x, y) in pts2d]


def ring_y(y, z, pts2d, x=0.0):
    """Y(銃口方向)に垂直な断面。2D の (横, 縦) = (X, Z)。"""
    return ring((x, y, z), (1, 0, 0), (0, 0, 1), pts2d)


def loft(name, rings, mat, cap=True, smooth_angle=40.0):
    """同じ点数の断面を順につないだ筒。両端はふたをする。角度の大きい辺は角として残す。"""
    bm = bmesh.new()
    vs = [[bm.verts.new(p) for p in r] for r in rings]
    n = len(rings[0])
    for a, b in zip(vs[:-1], vs[1:]):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((a[i], a[j], b[j], b[i]))
    if cap:
        bm.faces.new(list(reversed(vs[0])))
        bm.faces.new(vs[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = _new_object(name, bm, mat)
    smooth(obj, smooth_angle)
    return obj


def smooth(obj, angle=40.0):
    """なめらかに見せつつ、angle 度より鋭い辺は角のまま残す(glTF にもそのまま出る)。"""
    obj.data.shade_smooth()
    obj.data.set_sharp_from_angle(angle=math.radians(angle))


def sweep_yz(name, path, profile2d, mat, smooth_angle=50.0):
    """YZ 平面上の折れ線 path に沿って断面 profile2d(横=X, 縦=進行方向に垂直)を流す。"""
    pts = [Vector(p) for p in path]
    rings = []
    for i, p in enumerate(pts):
        a = pts[max(i - 1, 0)]
        b = pts[min(i + 1, len(pts) - 1)]
        t = (b - a).normalized()
        n = Vector((0, -t.z, t.y))
        rings.append(ring(p, (1, 0, 0), n, profile2d))
    return loft(name, rings, mat, smooth_angle=smooth_angle)


def _apply_modifier(obj, mod):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod.name)


def bevel(obj, width, segments=2, angle=35.0, flat=False):
    """角を面取りして光を拾わせる(実物の金属部品は角が少し丸い)。
    flat=True は平面ばかりの部品用: 面ごとに平らに塗り、大きな面に斜めの陰が出ないようにする。"""
    m = obj.modifiers.new("bevel", "BEVEL")
    m.width = width
    m.segments = segments
    m.limit_method = "ANGLE"
    m.angle_limit = math.radians(angle)
    m.harden_normals = False
    _apply_modifier(obj, m)
    if flat:
        obj.data.shade_flat()
        return obj
    smooth(obj, 35.0)
    # 面取り後の大きな平面に丸みの陰が斜めに流れないよう、面積の大きい面の向きを優先した法線にする
    w = obj.modifiers.new("wn", "WEIGHTED_NORMAL")
    w.mode = "FACE_AREA"
    w.keep_sharp = True
    w.weight = 100
    _apply_modifier(obj, w)
    return obj


def subdivide(obj, levels=1):
    """木部や樹脂の丸みを出す。"""
    m = obj.modifiers.new("subd", "SUBSURF")
    m.levels = levels
    m.render_levels = levels
    _apply_modifier(obj, m)
    smooth(obj, 70.0)
    return obj


def cut(obj, cutter):
    """obj から cutter の形をくり抜く(排莢口、照門の切り欠きなど)。cutter は削除する。"""
    m = obj.modifiers.new("cut", "BOOLEAN")
    m.operation = "DIFFERENCE"
    m.solver = "EXACT"
    m.object = cutter
    _apply_modifier(obj, m)
    bpy.data.objects.remove(cutter, do_unlink=True)
    return obj


def join(name, objs):
    """複数の形を1つの部品にまとめる(素材は保ったまま)。"""
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = name
    obj.data.name = name
    return obj


def empty(name, loc, parent=None):
    e = bpy.data.objects.new(name, None)
    e.empty_display_size = 0.02
    e.location = loc
    bpy.context.collection.objects.link(e)
    if parent is not None:
        e.parent = parent
    return e


def set_pivot(obj, pivot):
    """部品の原点(回る軸・滑る基準)を pivot に移す。見た目の位置は変わらない。Godot ではこの点を中心に動く。"""
    pivot = Vector(pivot)
    obj.data.transform(Matrix.Translation(-pivot))
    obj.location = pivot
    return obj


def attach(child, parent):
    """child を parent の子にする(見た目の位置はそのまま)。親が動くと一緒に動く。"""
    bpy.context.view_layer.update()
    mw = child.matrix_world.copy()
    child.parent = parent
    child.matrix_parent_inverse = Matrix.Identity(4)
    child.matrix_world = mw
    return child


def make_root(name, parts, points):
    """parts: 部品オブジェクトのリスト / points: {名前: 位置}。全部を root の子にする。"""
    root = empty(name, (0, 0, 0))
    for p in parts:
        p.parent = root
    for k, loc in points.items():
        empty(k, loc, root)
    return root


def poly_count():
    total = 0
    for o in bpy.data.objects:
        if o.type == "MESH":
            total += sum(len(p.vertices) - 2 for p in o.data.polygons)
    return total


def export_glb(path):
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=os.path.abspath(path), export_format="GLB", export_yup=True,
                              export_apply=True, export_extras=False)


def render_views(out_dir, prefix, ads_eye=None, front_post=None, size=(1200, 675), eye_dist=0.12):
    """確認用の画像を Cycles(CPU)で描く。真横だけでなく、上・前後の斜め・一人称・構えた視点も出す。
    最後に全部を1枚に並べた {prefix}_sheet.png も作る(Pillow があれば)。"""
    out_dir = os.path.abspath(out_dir)
    os.makedirs(out_dir, exist_ok=True)
    # 2回目以降の呼び出し(姿勢を変えて撮り直す時)は、前回のライトとカメラを消してから置き直す
    for o in list(bpy.data.objects):
        if o.name.split(".")[0] in ("key", "rim", "top", "cam"):
            bpy.data.objects.remove(o, do_unlink=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 32
    scene.cycles.use_denoising = False
    scene.render.resolution_x, scene.render.resolution_y = size
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.75, 0.77, 0.8, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.9
    scene.world = world

    def add_light(name, rot, energy):
        ld = bpy.data.lights.new(name, "SUN")
        ld.energy = energy
        lo = bpy.data.objects.new(name, ld)
        lo.rotation_euler = [math.radians(a) for a in rot]
        bpy.context.collection.objects.link(lo)

    add_light("key", (50, 0, 140), 3.0)
    add_light("rim", (-60, 0, -30), 1.5)
    add_light("top", (0, 0, 0), 1.0)

    cam_data = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cam_data)
    bpy.context.collection.objects.link(cam)
    scene.camera = cam

    pts = []
    for o in bpy.data.objects:
        if o.type == "MESH":
            pts += [o.matrix_world @ Vector(c) for c in o.bound_box]
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    c = (mn + mx) / 2
    L = mx.y - mn.y
    H = (mx.z - mn.z) * size[0] / size[1]  # 横から撮るとき、高さがはみ出さない幅
    W = max(L, H)

    views = {
        "side_right": dict(ortho=W * 1.08, loc=c + Vector((1, 0, 0)), look=c),
        "side_left": dict(ortho=W * 1.08, loc=c + Vector((-1, 0, 0)), look=c),
        "top": dict(ortho=L * 1.08, loc=c + Vector((0, 0, 1)), look=c, up=Vector((0, 1, 0))),
        "front_quarter": dict(fov=30, loc=c + Vector((-1.0, 1.3, 0.55)) * L, look=c),
        "rear_quarter": dict(fov=30, loc=c + Vector((-0.9, -1.3, 0.7)) * L, look=c),
        # 一人称の見え方はゲーム内のスクリーンショット(--screenshot)で確かめる
    }
    if ads_eye is not None and front_post is not None:
        line = (front_post - ads_eye).normalized()
        views["aim"] = dict(fov=30, vfov=True, loc=ads_eye - line * eye_dist, look=front_post)
    files = []
    for vname, v in views.items():
        if "ortho" in v:
            cam_data.type = "ORTHO"
            cam_data.ortho_scale = v["ortho"]
        else:
            cam_data.type = "PERSP"
            if v.get("vfov"):
                cam_data.sensor_fit = "VERTICAL"
                cam_data.angle_y = math.radians(v["fov"])
            else:
                cam_data.sensor_fit = "AUTO"
                cam_data.angle = math.radians(v["fov"])
        cam_data.clip_start = 0.005
        cam.location = v["loc"]
        direction = v["look"] - v["loc"]
        if "up" in v:
            # 真上から見下ろし、画面の右を銃口(+Y)にする
            cam.rotation_euler = (0.0, 0.0, math.pi / 2)
        else:
            cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        path = os.path.join(out_dir, f"{prefix}_{vname}.png")
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        files.append((vname, path))
    _contact_sheet(files, os.path.join(out_dir, f"{prefix}_sheet.png"))
    return files


def _contact_sheet(files, out_path):
    try:
        from PIL import Image, ImageDraw
    except ImportError:
        print("[gunlib] Pillow が無いので一覧画像は作らない")
        return
    imgs = [(n, Image.open(p).convert("RGB")) for n, p in files]
    w, h = imgs[0][1].size
    tw, th = w // 2, h // 2
    cols = 2
    rows = (len(imgs) + cols - 1) // cols
    sheet = Image.new("RGB", (tw * cols, th * rows), (40, 40, 44))
    d = ImageDraw.Draw(sheet)
    try:
        from PIL import ImageFont
        font = ImageFont.load_default(size=28)
    except Exception:
        font = None
    for i, (n, im) in enumerate(imgs):
        x, y = (i % cols) * tw, (i // cols) * th
        sheet.paste(im.resize((tw, th)), (x, y))
        d.text((x + 10, y + 8), n, fill=(0, 0, 0), font=font)
    sheet.save(out_path)


def cli_args():
    """`blender -b -P script.py -- --out x.glb --render dir` と `python script.py --out ...` の両方に対応。"""
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1:]
    else:
        argv = argv[1:]
    args = {"out": None, "render": None}
    i = 0
    while i < len(argv):
        if argv[i] in ("--out", "--render") and i + 1 < len(argv):
            args[argv[i][2:]] = argv[i + 1]
            i += 2
        else:
            i += 1
    return args
