"""ハウンド357(元ネタ: 中型の振り出し式 .357 リボルバー、4インチ銃身)のモデル。

部品ごとに作って組み立てる。動く部品は原点を回転軸・滑る基準に置き、親子にして Godot 側のコードで動かす:
    hammer  … 撃鉄。X 軸まわりに回る(+で起きる)
    trigger … 引き金。X 軸まわりに回る(-で引かれる)
    crane   … シリンダーを支える腕。銃身と平行な軸まわりに回り、シリンダーを左へ振り出す
      cylinder … シリンダー。銃身と平行な軸まわりに 60° ずつ回る
        ejector  … エジェクター(星形の板と押し棒)。後ろへ滑って薬莢を押し出す
        round_0..5 … 薬莢(真鍮)。子に bullet_0..5(弾頭)。撃った薬室は弾頭を隠す
外から見えない内部のバネ等は作らない。照準器は構えた画面から逆算する(下の「照準像の設計」)。

実行(Windows):  tools\\blender\\build_all.bat
実行(bpy):      python tools/blender/revolver.py --out assets/models/guns/revolver357.glb --render tools/blender/renders
座標: Blender の +Y が銃口方向、+Z が上、+X が右。原点はグリップを握る所の上端。単位 m。
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gunlib as g  # noqa: E402

from mathutils import Vector  # noqa: E402

RR = g.rounded_rect
g.reset_scene()

# ======================= 基本寸法 =======================
# 設定画 docs/concept/revolver/rev_side.png(左側面)を 1px = 0.19mm として読み取った値。
# 原点は「引き金の上のフレーム下面」と「グリップ上端」の交点あたり。
BORE_Z = 0.043                 # 銃身の中心の高さ
CHAMBER_R = 0.0135             # シリンダー軸から薬室までの距離
CYL_AXIS_Z = BORE_Z - CHAMBER_R
CYL_R = 0.0195                 # シリンダーの半径(直径 39mm)
CYL_Y0, CYL_Y1 = 0.0135, 0.0535  # シリンダーの後端・前端
CHAMBER_HOLE = 0.0048
BARREL_Y0, BARREL_Y1 = 0.060, 0.176
BARREL_R = 0.0085
FRAME_TOP = 0.056
WIN_Y0, WIN_Y1, WIN_Z0, WIN_Z1 = 0.0125, 0.0525, 0.0085, 0.0500  # シリンダーの窓
CRANE_P = (-0.0135, 0.0065)    # クレーンの回転軸(X, Z)。銃身と平行。ここを中心に左下へ振り出す
CRANE_SWING_DEG = 95.0         # 振り出す角度(Godot 側の revolver_rig.gd と同じ)
ROD_Y1 = 0.104                 # 押し棒の先端
CHAMBER_ANGLES = [math.radians(90 + 60 * k) for k in range(6)]  # 0 番が一番上(銃身の後ろ)

# ======================= 照準像の設計(構えた画面から逆算) =======================
ADS_VFOV_DEG = 52.0
SCREEN_H = 900
EYE_DIST = 0.24                # 目から照門まで(data/guns/revolver357.tres の ads_eye_dist と同じ)
PX_PER_RAD = (SCREEN_H / 2) / math.tan(math.radians(ADS_VFOV_DEG / 2))
REAR_Y, FRONT_Y = 0.004, 0.166
FRONT_DIST = EYE_DIST + (FRONT_Y - REAR_Y)
SIGHT_PX = dict(notch_w=58, notch_depth=26, rear_w=150, post_w=18)
NOTCH_TOP = 0.0645             # 上面(0.056)より 8.5mm 上。撃鉄の頭(0.054)が溝を塞がない高さ


def at_rear(px):
    return px / PX_PER_RAD * EYE_DIST


def at_front(px):
    return px / PX_PER_RAD * FRONT_DIST


NOTCH_W, NOTCH_DEPTH, REAR_W = at_rear(SIGHT_PX["notch_w"]), at_rear(SIGHT_PX["notch_depth"]), at_rear(SIGHT_PX["rear_w"])
POST_W = at_front(SIGHT_PX["post_w"])
POST_TIP = NOTCH_TOP
print(f"[revolver] 照準: 溝 幅{NOTCH_W * 1000:.1f} 深さ{NOTCH_DEPTH * 1000:.1f} 照門幅{REAR_W * 1000:.1f} 照星 幅{POST_W * 1000:.1f} (mm)")


def capsule(ax, az, bx, bz, r, n=8):
    """(ax,az) と (bx,bz) を結ぶ丸い板の輪郭(XZ 面)。"""
    ang = math.atan2(bz - az, bx - ax)
    pts = []
    for i in range(n + 1):
        t = ang + math.pi / 2 + math.pi * i / n
        pts.append((ax + r * math.cos(t), az + r * math.sin(t)))
    for i in range(n + 1):
        t = ang - math.pi / 2 + math.pi * i / n
        pts.append((bx + r * math.cos(t), bz + r * math.sin(t)))
    return pts


def capsule_y(name, y0, y1, r, mat):
    """クレーンの腕の形を Y 方向に押し出す。"""
    px, pz = CRANE_P
    return g.loft(name, [g.ring_y(y0, 0.0, capsule(px, pz, 0.0, CYL_AXIS_Z, r)),
                         g.ring_y(y1, 0.0, capsule(px, pz, 0.0, CYL_AXIS_Z, r))], mat, smooth_angle=50)


# ======================= フレーム(動かない本体。横から見た形を1枚で作り、窓と溝を削る) =======================
FW = 0.026  # フレームの厚み(シリンダー直径 39mm より細く、シリンダーが左右に張り出して見える)
frame_body = g.prism("frame_body", [
    (0.070, FRAME_TOP), (0.070, 0.022), (0.065, 0.008), (0.055, 0.000),     # 前(銃身の付け根)
    (0.000, 0.000), (-0.012, 0.006), (-0.028, 0.017), (-0.035, 0.026),       # 下 → 後ろ(グリップに隠れる)
    (-0.034, 0.034), (-0.024, 0.044), (-0.012, 0.052), (-0.004, FRAME_TOP),  # 撃鉄の後ろの丸い背
], FW, "steel")
g.cut(frame_body, g.box("c", (0, (WIN_Y0 + WIN_Y1) / 2, (WIN_Z0 + WIN_Z1) / 2),
                        (0.05, WIN_Y1 - WIN_Y0, WIN_Z1 - WIN_Z0), "recess"))            # シリンダーの窓
g.cut(frame_body, g.box("c", (0, -0.019, 0.047), (0.0085, 0.042, 0.050), "recess"))  # 撃鉄の溝
# クレーンの腕が収まる切り欠き(左へ抜ける)
g.cut(frame_body, capsule_y("c", WIN_Y1 - 0.001, 0.0612, 0.0063, "recess"))
g.cut(frame_body, g.box("c", (-0.022, 0.057, 0.008), (0.020, 0.0092, 0.020), "recess"))
g.bevel(frame_body, 0.0020, 2, flat=True)
# 用心鉄(丸い輪)
guard_path = [(0, 0.044, 0.002)]
for i in range(15):  # 前の縦棒から、丸く後ろへ回る
    t = math.pi * i / 14
    guard_path.append((0, 0.024 + 0.020 * math.cos(t), -0.010 - 0.017 * math.sin(t)))
guard_path.append((0, 0.004, 0.002))
guard = g.sweep_yz("trigger_guard", guard_path,
                   RR(0.009, 0.0045, 0.0018, 2), "steel")
# シリンダーを外すラッチ(左側、シリンダーの後ろ)
latch = g.box("cylinder_latch", (-(FW / 2 + 0.0015), 0.002, 0.031), (0.006, 0.013, 0.008), "steel_worn", bevel=0.0015)
# 側面のネジ(右と左)
screws = [g.tube_x(f"side_screw_{i}", (sx * (FW / 2 + 0.0003), py, pz), 0.002, 0.0026, "steel_worn", segments=14)
          for i, (sx, py, pz) in enumerate([(1, -0.020, 0.024), (1, 0.004, 0.005), (1, 0.062, 0.030), (-1, -0.020, 0.024)])]
frame = g.join("frame", [frame_body, guard, latch] + screws)

# ======================= 照門(トップストラップ後端の四角い調整式) =======================
rear_sight = g.box("rear_sight_body", (0, REAR_Y, (FRAME_TOP + NOTCH_TOP) / 2), (REAR_W, 0.012, NOTCH_TOP - FRAME_TOP + 0.001),
                   "steel", bevel=0.0012)
g.cut(rear_sight, g.box("c", (0, REAR_Y, NOTCH_TOP), (NOTCH_W, 0.03, NOTCH_DEPTH * 2), "recess"))
rs_screw = g.tube_x("rear_sight_screw", (REAR_W / 2 + 0.001, REAR_Y, (FRAME_TOP + NOTCH_TOP) / 2), 0.002, 0.0022, "steel_worn",
                    segments=12)

# ======================= 銃身(上にベンチリブ、下に押し棒を覆う長いラグ) =======================
barrel = g.tube_y("barrel_tube", BARREL_Y0, BARREL_Y1, BARREL_R, "steel", z=BORE_Z, segments=32)
g.cut(barrel, g.tube_y("c", BARREL_Y1 - 0.010, BARREL_Y1 + 0.01, 0.0045, "recess", z=BORE_Z, segments=20))  # 銃口
RIB_Z, RIB_H = BORE_Z + 0.0095, 0.0055
RIB_TOP = RIB_Z + RIB_H / 2
rib = g.box("barrel_rib", (0, (BARREL_Y0 + BARREL_Y1) / 2, RIB_Z), (0.0085, BARREL_Y1 - BARREL_Y0, RIB_H), "steel", bevel=0.001)
for yc in (0.084, 0.108, 0.132):  # ベンチリブの長い穴
    g.cut(rib, g.box("c", (0, yc, RIB_Z - 0.0008), (0.02, 0.016, 0.0030), "recess"))
LUG_Z0 = 0.020
# 断面は下が丸い(四角い箱に見えないように)。上半分は銃身に埋まる
LUG_SEC = RR(0.0165, BORE_Z - LUG_Z0, 0.0078, 5)
lug = g.loft("barrel_lug", [g.ring_y(BARREL_Y0, (BORE_Z + LUG_Z0) / 2, LUG_SEC),
                            g.ring_y(BARREL_Y1, (BORE_Z + LUG_Z0) / 2, LUG_SEC)], "steel", smooth_angle=50)
g.cut(lug, g.tube_y("c", BARREL_Y0 - 0.001, ROD_Y1 + 0.002, 0.0045, "recess", z=CYL_AXIS_Z, segments=20))   # 押し棒の通る穴
g.cut(lug, g.box("c", (0, (0.068 + ROD_Y1 + 0.002) / 2, CYL_AXIS_Z), (0.03, ROD_Y1 + 0.002 - 0.068, 0.0072), "recess"))  # 横から見える窓
# 照星(リブの上のランプ)
front_sight = g.prism("front_sight", [(FRONT_Y - 0.016, RIB_TOP - 0.0005), (FRONT_Y - 0.002, POST_TIP), (FRONT_Y + 0.004, POST_TIP),
                                      (FRONT_Y + 0.006, RIB_TOP - 0.0005)], POST_W, "steel_worn", bevel=0.0006)
sight_dot = g.prism("front_sight_insert", [(FRONT_Y - 0.0050, POST_TIP - 0.0040), (FRONT_Y - 0.0020, POST_TIP + 0.0002),
                                           (FRONT_Y + 0.0010, POST_TIP + 0.0002), (FRONT_Y + 0.0010, POST_TIP - 0.0040)],
                    POST_W + 0.0004, "sight_orange")
bore = g.tube_y("bore_dark", BARREL_Y1 - 0.011, BARREL_Y1 - 0.009, 0.0046, "recess", z=BORE_Z, segments=20)
barrel_all = g.join("barrel", [barrel, rib, lug, bore, front_sight, sight_dot])

# ======================= グリップ(木。設定画のように下へ広がる) =======================
gt, gb = Vector((0, -0.017, 0.016)), Vector((0, -0.044, -0.060))
axis = (gb - gt).normalized()
fwd = Vector((0, -axis.z, axis.y))
grip_rings = []
# (位置, 幅, 前後の奥行き, 前後のずれ): 肩で広く → 中指の上でくびれ → 手のひらで膨らみ → 底で広がる
for t, w, d, o in [(0.0, 0.028, 0.034, 0.000), (0.10, 0.033, 0.042, -0.002), (0.30, 0.031, 0.036, 0.001),
                   (0.55, 0.035, 0.043, -0.001), (0.80, 0.036, 0.047, -0.003), (0.95, 0.034, 0.050, -0.004),
                   (1.0, 0.030, 0.047, -0.004)]:
    grip_rings.append(g.ring(gt + (gb - gt) * t + fwd * o, (1, 0, 0), fwd, RR(w, d, w * 0.45, 5)))
grip = g.loft("grip", grip_rings, "wood", smooth_angle=60)
g.bevel(grip, 0.003, 3, angle=50)
grip_screw = g.tube_x("grip_screw", (0.0185, -0.030, -0.020), 0.002, 0.0030, "steel_worn", segments=14)
grip = g.join("grip", [grip, grip_screw])

# ======================= 撃鉄(軸: X、原点は軸ピン。+ に回すと起きる) =======================
HAMMER_PIVOT = (0, -0.008, 0.028)
hammer = g.prism("hammer", [(-0.004, 0.022), (0.001, 0.030), (0.001, 0.048), (-0.005, 0.0525), (-0.013, 0.0538),
                            (-0.022, 0.0540), (-0.030, 0.0548), (-0.036, 0.0545), (-0.039, 0.0520), (-0.033, 0.0495),
                            (-0.025, 0.0475), (-0.018, 0.0425), (-0.014, 0.034), (-0.013, 0.024)],
                 0.0075, "steel_worn", bevel=0.0008)
for k in range(4):  # 指をかける所の刻み
    g.cut(hammer, g.box("c", (0, -0.024 - k * 0.0035, 0.0545), (0.02, 0.0012, 0.003), "recess"))
hammer_pin = g.tube_x("hammer_pin", (0, HAMMER_PIVOT[1], HAMMER_PIVOT[2]), 0.0345, 0.0024, "steel_worn", segments=12)
g.set_pivot(hammer, HAMMER_PIVOT)

# ======================= 引き金(軸: X。- に回すと引かれる) =======================
TRIGGER_PIVOT = (0, 0.021, 0.001)
trigger = g.prism("trigger", [(0.017, 0.004), (0.025, 0.004), (0.024, -0.006), (0.026, -0.016), (0.031, -0.022),
                              (0.027, -0.0235), (0.019, -0.016), (0.016, -0.006)], 0.0075, "steel_worn", bevel=0.0008)
g.set_pivot(trigger, TRIGGER_PIVOT)

# ======================= シリンダー(6発) =======================
cyl = g.tube_y("cylinder_body", CYL_Y0, CYL_Y1, CYL_R, "steel", z=CYL_AXIS_Z, segments=48)
g.bevel(cyl, 0.0015, 2, angle=30)
for a in CHAMBER_ANGLES:  # 薬室
    g.cut(cyl, g.tube_y("c", CYL_Y0 - 0.002, CYL_Y1 + 0.002, CHAMBER_HOLE, "recess",
                        x=CHAMBER_R * math.cos(a), z=CYL_AXIS_Z + CHAMBER_R * math.sin(a), segments=20))
for a in CHAMBER_ANGLES:  # 溝(フルート)。薬室と薬室の間、前から後ろの手前まで
    b = a + math.radians(30)
    g.cut(cyl, g.tube_y("c", CYL_Y0 + 0.011, CYL_Y1 + 0.01, 0.0040, "recess",
                        x=(CYL_R + 0.0012) * math.cos(b), z=CYL_AXIS_Z + (CYL_R + 0.0012) * math.sin(b), segments=16))
g.cut(cyl, g.tube_y("c", CYL_Y0 - 0.001, CYL_Y0 + 0.0022, 0.0100, "recess", z=CYL_AXIS_Z, segments=24))  # 星形の板の座
cylinder = cyl
cylinder.name = "cylinder"
g.set_pivot(cylinder, (0, CYL_Y0, CYL_AXIS_Z))

# エジェクター: 星形の板 + 押し棒(シリンダー軸の上)。後ろへ滑って薬莢を押し出す
star = g.tube_y("ejector_star", CYL_Y0 - 0.0002, CYL_Y0 + 0.0020, 0.0096, "steel_worn", z=CYL_AXIS_Z, segments=24)
rod = g.tube_y("ejector_rod", CYL_Y1, ROD_Y1, 0.0032, "steel_worn", z=CYL_AXIS_Z, segments=16)
rod_head = g.tube_y("ejector_rod_head", ROD_Y1 - 0.007, ROD_Y1, 0.0041, "steel_worn", z=CYL_AXIS_Z, segments=16)
ejector = g.join("ejector", [star, rod, rod_head])
g.set_pivot(ejector, (0, CYL_Y0, CYL_AXIS_Z))

# 弾: 薬莢(縁・雷管つき)と弾頭。薬室ごとに1つ
rounds = []
for k, a in enumerate(CHAMBER_ANGLES):
    x, z = CHAMBER_R * math.cos(a), CYL_AXIS_Z + CHAMBER_R * math.sin(a)
    case = g.tube_y("case", CYL_Y0, CYL_Y0 + 0.033, 0.0046, "brass", x=x, z=z, segments=16)
    rim = g.tube_y("rim", CYL_Y0 - 0.0013, CYL_Y0, 0.0055, "brass", x=x, z=z, segments=16)
    primer = g.tube_y("primer", CYL_Y0 - 0.0016, CYL_Y0 - 0.0012, 0.0020, "primer", x=x, z=z, segments=12)
    rnd = g.join(f"round_{k}", [case, rim, primer])
    g.set_pivot(rnd, (x, CYL_Y0, z))
    bullet = g.tube_y(f"bullet_{k}", CYL_Y0 + 0.033, CYL_Y0 + 0.040, 0.0044, "copper", x=x, z=z, segments=16, radius1=0.0026)
    g.set_pivot(bullet, (x, CYL_Y0 + 0.033, z))
    g.attach(bullet, rnd)
    rounds.append(rnd)

# ======================= クレーン(シリンダーを振り出す腕) =======================
px, pz = CRANE_P
arm = capsule_y("crane_arm", CYL_Y1 + 0.0003, 0.0600, 0.0055, "steel")
sleeve = g.tube_y("crane_sleeve", CYL_Y1, 0.0605, 0.0042, "steel", x=px, z=pz, segments=16)
crane = g.join("crane", [arm, sleeve])
g.set_pivot(crane, (px, CYL_Y0, pz))

# 親子: crane → cylinder → (ejector, round_k → bullet_k)
g.attach(cylinder, crane)
g.attach(ejector, cylinder)
for rnd in rounds:
    g.attach(rnd, cylinder)

# ======================= まとめる =======================
points = {
    "muzzle": (0, BARREL_Y1 + 0.001, BORE_Z),
    "ads_eye": (0, REAR_Y, NOTCH_TOP),
    "front_post_tip": (0, FRONT_Y, POST_TIP),
    "attach_barrel": (0, BARREL_Y0, BORE_Z),
    "attach_sight": (0, 0.030, FRAME_TOP + 0.001),
    "attach_option": (0, 0.120, CYL_AXIS_Z - 0.012),
}
parts = [frame, rear_sight, rs_screw, barrel_all, grip, hammer, hammer_pin, trigger, crane]
root = g.make_root("revolver357", parts, points)
print(f"[revolver] ポリゴン数(三角形): {g.poly_count()}")

args = g.cli_args()
if args["out"]:
    g.export_glb(args["out"])
    print(f"[revolver] 書き出し: {args['out']}")
if args["render"]:
    g.render_views(args["render"], "revolver", ads_eye=Vector(points["ads_eye"]), front_post=Vector(points["front_post_tip"]),
                   eye_dist=EYE_DIST)
    # 振り出して排莢している姿勢も撮る(動きの確認)
    crane.rotation_euler[1] = math.radians(-CRANE_SWING_DEG)
    ejector.location.y -= 0.016
    for rnd in rounds:
        rnd.location.y -= 0.016
    hammer.rotation_euler[0] = math.radians(35)
    g.render_views(args["render"], "revolver_open")
    print(f"[revolver] 画像: {args['render']}")
