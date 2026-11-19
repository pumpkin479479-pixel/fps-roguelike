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
from mathutils import Vector

# 共通パレット: 名前 → (色, 金属感, 粗さ)
PALETTE = {
    "steel": ((0.035, 0.037, 0.042), 0.85, 0.42),   # 黒染めの鉄
    "steel_worn": ((0.08, 0.08, 0.085), 0.9, 0.35),  # 擦れた鉄(角の部品)
    "wood": ((0.26, 0.085, 0.025), 0.0, 0.55),       # 赤みのある木(ラッカー仕上げ)
    "wood_dark": ((0.14, 0.05, 0.018), 0.0, 0.6),
    "bakelite": ((0.16, 0.045, 0.02), 0.0, 0.45),    # 樹脂(オレンジがかった茶)
    "brass": ((0.55, 0.38, 0.12), 0.95, 0.3),
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
    return _new_object(name, bm, mat)


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
    return _new_object(name, bm, mat)


def tube_x(name, center, length, radius, mat, segments=8):
    """X 方向の円柱(ボルトハンドルの軸など)。"""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segments, radius1=radius, radius2=radius, depth=length)
    for v in bm.verts:
        cx, cy, cz = v.co
        v.co = Vector((cz + center[0], cy + center[1], cx + center[2]))
    return _new_object(name, bm, mat)


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


def render_views(out_dir, prefix, size=(1400, 700)):
    """横・斜め・一人称の3枚を Cycles(CPU)で描く。実銃写真と見比べるための画像。"""
    os.makedirs(out_dir, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 24
    scene.cycles.use_denoising = False
    scene.render.resolution_x, scene.render.resolution_y = size
    scene.render.film_transparent = False
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

    cam_data = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cam_data)
    bpy.context.collection.objects.link(cam)
    scene.camera = cam

    # バウンディングボックスから中心と大きさを求める
    pts = []
    for o in bpy.data.objects:
        if o.type == "MESH":
            pts += [o.matrix_world @ Vector(c) for c in o.bound_box]
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    center = (mn + mx) / 2
    length = mx.y - mn.y

    views = {
        # 右側面(正投影)
        "side": dict(ortho=length * 1.1, loc=center + Vector((1.0, 0, 0)), look=center),
        # 左斜め前上
        "three_quarter": dict(fov=30, loc=center + Vector((-1.2, 1.0, 0.6)) * length, look=center),
        # 一人称(ゲーム中の見え方に近い)
        "first_person": dict(fov=70, loc=Vector((-0.2, -0.38, 0.17)), look=Vector((-0.12, 0.6, 0.06))),
    }
    for vname, v in views.items():
        if "ortho" in v:
            cam_data.type = "ORTHO"
            cam_data.ortho_scale = v["ortho"]
        else:
            cam_data.type = "PERSP"
            cam_data.angle = math.radians(v["fov"])
        cam_data.clip_start = 0.01
        cam.location = v["loc"]
        direction = v["look"] - v["loc"]
        cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(out_dir, f"{prefix}_{vname}.png")
        bpy.ops.render.render(write_still=True)


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
