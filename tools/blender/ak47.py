"""ツンドラ47(元ネタ: AK-47)のモデル。

実行(Windows):
    "C:\\Program Files\\Blender Foundation\\Blender 5.3\\blender.exe" -b -P tools/blender/ak47.py -- --out assets/models/guns/ak47.glb --render tools/blender/renders
実行(bpy モジュール):
    python tools/blender/ak47.py --out assets/models/guns/ak47.glb --render tools/blender/renders

設計メモ(実銃の公開寸法から):
    全長 870mm、銃身長 415mm(薬室から)、30発の湾曲マガジン、木製の固定ストック。
    特徴部位: 前に湾曲したマガジン、三角の高い前方照準器(フロントサイト)、銃身上のガスチューブ、
    木製の上下ハンドガード、下がったストック、右側面の大きなセレクターレバー、
    銃身下のクリーニングロッド、マガジン上方の削り込み(AK-47 の削り出しレシーバー)。
    寸法は下の「生の座標」(グリップ上端の少し後ろ = y -0.02, z -0.03)で書き、最後に原点へ寄せる。
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gunlib as g  # noqa: E402

from mathutils import Matrix, Vector  # noqa: E402

# 生の座標 → 原点(グリップ上端)へのずらし量
OFF = Vector((0.0, 0.02, 0.03))

g.PALETTE["recess"] = ((0.012, 0.012, 0.014), 0.6, 0.6)

g.reset_scene()

# ---------------- レシーバー(本体) ----------------
receiver = g.prism("receiver_body", [
    (-0.125, -0.030), (0.135, -0.030), (0.135, 0.028), (-0.125, 0.028),
], 0.032, "steel", bevel=0.002)
dust_cover = g.prism("dust_cover", [
    (-0.127, 0.026), (-0.127, 0.035), (-0.112, 0.042), (0.0, 0.045),
    (0.100, 0.045), (0.114, 0.039), (0.114, 0.026),
], 0.034, "steel", bevel=0.002)
rear_sight_block = g.prism("rear_sight_block", [
    (0.114, 0.020), (0.114, 0.046), (0.150, 0.050), (0.180, 0.040), (0.180, 0.020),
], 0.030, "steel", bevel=0.002)
rear_sight_leaf = g.prism("rear_sight_leaf", [
    (0.120, 0.046), (0.120, 0.052), (0.168, 0.049), (0.168, 0.046),
], 0.016, "steel_worn")
# 削り出しレシーバーのマガジン上の凹み(左右)
cut_l = g.box("cut_l", (-0.0165, 0.090, -0.008), (0.002, 0.060, 0.020), "recess")
cut_r = g.box("cut_r", (0.0165, 0.090, -0.008), (0.002, 0.060, 0.020), "recess")
# 用心金(トリガーガード)
guard_bottom = g.box("guard_bottom", (0, 0.032, -0.057), (0.008, 0.070, 0.005), "steel")
guard_front = g.box("guard_front", (0, 0.064, -0.044), (0.008, 0.005, 0.028), "steel")
# ピストルグリップ(樹脂)
grip = g.prism("grip", [
    (0.000, -0.030), (-0.042, -0.030), (-0.080, -0.138), (-0.068, -0.146), (-0.040, -0.142),
], 0.030, "bakelite", bevel=0.003)
# 右側面のセレクターレバー(大きな板)
selector = g.prism("selector", [
    (-0.085, 0.014), (0.045, 0.012), (0.050, 0.002), (0.040, -0.004), (-0.080, 0.004),
], 0.003, "steel_worn", x=0.0175)
selector_tab = g.box("selector_tab", (0.0185, 0.044, -0.008), (0.004, 0.010, 0.016), "steel_worn")
# マガジンキャッチ(用心金の前)
mag_catch = g.prism("mag_catch", [
    (0.064, -0.030), (0.074, -0.030), (0.070, -0.050), (0.064, -0.050),
], 0.012, "steel_worn")
receiver_parts = [mag_catch, receiver, dust_cover, rear_sight_block, rear_sight_leaf, cut_l, cut_r,
                  guard_bottom, guard_front, grip, selector, selector_tab]

# ---------------- バレル(銃身まわり) ----------------
BARREL_Z = 0.008
barrel = g.tube_y("barrel_tube", 0.135, 0.505, 0.0095, "steel", z=BARREL_Z, segments=10)
muzzle_nut = g.tube_y("muzzle_nut", 0.500, 0.522, 0.0115, "steel_worn", z=BARREL_Z, segments=10)
gas_tube = g.tube_y("gas_tube", 0.290, 0.372, 0.0095, "steel", z=0.037, segments=10)
gas_block = g.prism("gas_block", [
    (0.352, -0.002), (0.352, 0.048), (0.372, 0.048), (0.392, 0.020), (0.392, -0.002),
], 0.022, "steel", bevel=0.002)
# 三角形の高い前方照準器
front_sight = g.prism("front_sight", [
    (0.462, -0.004), (0.462, 0.022), (0.472, 0.068), (0.486, 0.068), (0.496, 0.022), (0.496, -0.004),
], 0.022, "steel", bevel=0.002)
bayonet_lug = g.box("bayonet_lug", (0, 0.480, -0.012), (0.010, 0.026, 0.012), "steel")
cleaning_rod = g.tube_y("cleaning_rod", 0.300, 0.475, 0.0028, "steel_worn", z=-0.012, segments=6)
# 木製ハンドガード(下・上)
lower_hg = g.prism("lower_handguard", [
    (0.140, -0.024), (0.140, 0.016), (0.300, 0.016), (0.300, -0.008), (0.285, -0.030), (0.200, -0.033), (0.160, -0.031),
], 0.046, "wood", bevel=0.004)
upper_hg = g.prism("upper_handguard", [
    (0.182, 0.024), (0.182, 0.046), (0.192, 0.052), (0.282, 0.052), (0.292, 0.044), (0.292, 0.024),
], 0.030, "wood", bevel=0.004)
retainer = g.prism("hg_retainer", [
    (0.298, -0.030), (0.298, 0.050), (0.310, 0.050), (0.310, -0.030),
], 0.040, "steel", bevel=0.002)
barrel_parts = [barrel, muzzle_nut, gas_tube, gas_block, front_sight, bayonet_lug, cleaning_rod,
                lower_hg, upper_hg, retainer]

# ---------------- マガジン(前に湾曲した30発) ----------------
def mag_profile():
    """後ろの縁と前の縁を同心円の弧で作る。弧の中心はマガジンの前方上。"""
    cx, cz = 0.368, -0.030
    pts_rear, pts_front = [], []
    steps = 8
    for i in range(steps + 1):
        t = i / steps
        a = math.pi + 0.72 * t
        pts_rear.append((cx + 0.300 * math.cos(a), cz + 0.300 * math.sin(a)))
        pts_front.append((cx + 0.244 * math.cos(a), cz + 0.244 * math.sin(a)))
    # 上端はレシーバーの中へ少し差し込む
    top = [(pts_rear[0][0], -0.018), (pts_front[0][0], -0.018)]
    return [top[0]] + pts_rear + list(reversed(pts_front)) + [top[1]]


magazine = g.prism("magazine_body", mag_profile(), 0.026, "steel", bevel=0.002)
# 底板(マガジンの底を少し太く)
a = math.pi + 0.72
floor_c = Vector((0, 0.368 + 0.272 * math.cos(a), -0.030 + 0.272 * math.sin(a)))
mag_floor = g.box("mag_floor", (0, floor_c.y, floor_c.z), (0.030, 0.064, 0.008), "steel_worn")
# 底板はマガジンの軸に直角になるよう、自身の中心まわりに傾ける(前が上がる)
mag_floor.data.transform(Matrix.Translation((0, floor_c.y, floor_c.z)) @ Matrix.Rotation(0.72, 4, "X")
                         @ Matrix.Translation((0, -floor_c.y, -floor_c.z)))

# ---------------- ストック(木製、下がった形) ----------------
stock = g.prism("stock_body", [
    (-0.120, 0.008), (-0.120, -0.030), (-0.200, -0.070), (-0.352, -0.146),
    (-0.362, -0.144), (-0.362, -0.036), (-0.300, -0.024),
], 0.036, "wood", bevel=0.004)
butt_plate = g.prism("butt_plate", [
    (-0.362, -0.147), (-0.362, -0.034), (-0.370, -0.034), (-0.370, -0.147),
], 0.040, "steel", bevel=0.001)
stock_tang = g.box("stock_tang", (0, -0.135, -0.004), (0.026, 0.035, 0.010), "steel")

# ---------------- 動く部品 ----------------
bolt_handle = g.tube_x("bolt_handle", (0.030, 0.100, 0.020), 0.026, 0.0045, "steel_worn")
bolt_knob = g.tube_x("bolt_knob", (0.044, 0.100, 0.020), 0.008, 0.0075, "steel_worn")
trigger = g.prism("trigger", [
    (0.034, -0.030), (0.040, -0.030), (0.034, -0.048), (0.026, -0.052),
], 0.006, "steel_worn")

# ---------------- 部品ごとにまとめる ----------------
parts = [
    g.join("receiver", receiver_parts),
    g.join("barrel", barrel_parts),
    g.join("magazine", [magazine, mag_floor]),
    g.join("stock", [stock, butt_plate, stock_tang]),
    g.join("bolt_handle", [bolt_handle, bolt_knob]),
    trigger,
]
trigger.name = "trigger"

points = {
    "muzzle": (0, 0.524, BARREL_Z),
    "attach_barrel": (0, 0.135, BARREL_Z),
    "attach_magazine": (0, 0.090, -0.030),
    "attach_stock": (0, -0.125, -0.005),
    "attach_sight": (0, 0.150, 0.050),
    "attach_option": (0, 0.250, -0.034),
}

# 原点をグリップ上端へ寄せる
for p in parts:
    p.data.transform(Matrix.Translation(OFF))
root = g.make_root("ak47", parts, {k: Vector(v) + OFF for k, v in points.items()})

print(f"[ak47] ポリゴン数(三角形): {g.poly_count()}")

args = g.cli_args()
if args["out"]:
    g.export_glb(args["out"])
    print(f"[ak47] 書き出し: {args['out']}")
if args["render"]:
    g.render_views(args["render"], "ak47")
    print(f"[ak47] 画像: {args['render']}")
