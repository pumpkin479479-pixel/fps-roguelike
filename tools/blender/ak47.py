"""ツンドラ47(元ネタ: AK-47 Type 3、削り出しレシーバー)のモデル。

実行(Windows):
    tools\\blender\\build_all.bat
実行(bpy モジュール):
    python tools/blender/ak47.py --out assets/models/guns/ak47.glb --render tools/blender/renders

設計メモ(実銃の公開寸法から。単位 m):
    全長 0.870、銃身長 0.415(薬室から)、レシーバー幅 約0.032、30発の湾曲マガジン、木製固定ストック。
    特徴部位:
      上面   … 丸いダストカバーと後端のリコイルスプリングのボタン、レシーバー前端のリアサイト
               (前で蝶番、後端に U 字の切り欠き、スライダー)、半円の上部ハンドガード、ガスチューブ、
               45度のガスブロック、耳(左右の板)に囲まれた柱のフロントサイト
      右側面 … 長いセレクターレバー、排莢口から見えるボルトキャリアとハンドル
      左側面 … 機関部のピン、マガジン上の削り込み
      下面   … 前に湾曲したリブ付きマガジン、トリガーガードとマガジンキャッチ、クリーニングロッド
    真横から押し出しただけの板にしないよう、本体・ハンドガード・ストック・グリップ・マガジンは
    角を丸めた断面をつないで作る(gunlib.loft)。
    寸法は「生の座標」(グリップ上端の少し後ろが y=-0.02, z=-0.03)で書き、最後に原点へ寄せる。
    照準線: リアサイトの切り欠き (y 0.121, z 0.0565) → フロントサイトの柱の先 (y 0.479, z 0.062)。
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gunlib as g  # noqa: E402

from mathutils import Matrix, Vector  # noqa: E402

OFF = Vector((0.0, 0.02, 0.03))  # 生の座標 → 原点(グリップ上端)
BARREL_Z = 0.008
RR = g.rounded_rect

g.PALETTE["recess"] = ((0.010, 0.010, 0.012), 0.5, 0.7)
g.reset_scene()


def sec(y, zc, w, h, r, x=0.0, seg=2):
    """Y に垂直な角丸断面(中心の高さ zc)。"""
    return g.ring_y(y, zc, RR(w, h, r, seg), x)


# ======================= レシーバー(本体) =======================
receiver = g.loft("receiver_body", [
    sec(-0.131, -0.006, 0.030, 0.044, 0.004),
    sec(-0.125, -0.002, 0.033, 0.056, 0.004),
    sec(0.135, -0.002, 0.033, 0.056, 0.004),
], "steel", smooth_angle=35)
# マガジン上の削り込み(左右、深さ 2mm)と排莢口(右、壁を抜く)を実際にくり抜く
for sx in (-1, 1):
    g.cut(receiver, g.box("c", (sx * 0.0175, 0.090, -0.009), (0.004, 0.064, 0.017), "recess", bevel=0.002))
g.cut(receiver, g.box("c", (0.0150, 0.052, 0.014), (0.010, 0.088, 0.017), "recess", bevel=0.002))
g.bevel(receiver, 0.0012, 2)
# 排莢口の奥に見えるボルトキャリアとボルト
bolt_carrier = g.loft("bolt_carrier_visible", [sec(0.006, 0.014, 0.022, 0.016, 0.004, seg=3), sec(0.098, 0.014, 0.022, 0.016, 0.004, seg=3)], "steel_worn")
bolt_face = g.tube_y("bolt_head", 0.098, 0.112, 0.0065, "steel", z=0.012, segments=16)
# ダストカバー(上が丸い)と後端のボタン
dust_cover = g.loft("dust_cover", [
    g.ring_y(-0.130, 0.022, g.arch(0.030, 0.004, 0.010)),
    g.ring_y(-0.124, 0.022, g.arch(0.035, 0.006, 0.015)),
    g.ring_y(0.106, 0.022, g.arch(0.035, 0.006, 0.015)),
    g.ring_y(0.114, 0.022, g.arch(0.033, 0.006, 0.013)),
], "steel", smooth_angle=50)
spring_button = g.tube_y("spring_button", -0.138, -0.128, 0.0045, "steel_worn", z=0.030, segments=16)
g.bevel(spring_button, 0.0008, 2)
# リアサイトの台(前へ細くなる)
rs_block = g.loft("rear_sight_block", [
    sec(0.110, 0.022, 0.032, 0.048, 0.006),
    sec(0.150, 0.024, 0.030, 0.046, 0.007),
    sec(0.185, 0.017, 0.026, 0.032, 0.008),
], "steel", smooth_angle=40)
# リアサイトのリーフ(前で蝶番、後端に U 字の切り欠き)とスライダー
leaf = g.prism("rs_leaf", [(0.118, 0.0475), (0.118, 0.0505), (0.172, 0.0505), (0.172, 0.0475)], 0.014, "steel_worn")
# 照門: 後端の板に U 字の切り欠きを実際に開ける(幅 2.4mm、深さ 3mm)
notch = g.box("rs_notch", (0, 0.121, 0.0535), (0.014, 0.004, 0.008), "steel_worn")
g.cut(notch, g.box("c", (0, 0.121, 0.0565), (0.0024, 0.01, 0.006), "recess"))
g.bevel(notch, 0.0004, 1)
leaf_rib = g.box("rs_leaf_rib", (0, 0.145, 0.0512), (0.004, 0.050, 0.0015), "steel_worn")
slider = g.box("rs_slider", (0, 0.146, 0.0505), (0.020, 0.010, 0.006), "steel", bevel=0.001)
slider_btn = g.tube_x("rs_slider_btn", (0.0115, 0.146, 0.0505), 0.004, 0.0028, "steel_worn")
hinge = g.tube_x("rs_hinge", (0, 0.172, 0.047), 0.030, 0.003, "steel")
gas_latch = g.box("gas_tube_latch", (0.0155, 0.172, 0.032), (0.004, 0.016, 0.006), "steel_worn", bevel=0.001)
# トリガーガード、マガジンキャッチ
guard = g.sweep_yz("trigger_guard", [(0, -0.004, -0.029), (0, -0.002, -0.046), (0, 0.006, -0.056), (0, 0.020, -0.058),
                                      (0, 0.050, -0.058), (0, 0.062, -0.054), (0, 0.067, -0.044), (0, 0.068, -0.029)],
                   RR(0.010, 0.0035, 0.0015, 2), "steel")
guard_bottom = guard
guard_front = g.box("guard_rivet", (0, 0.064, -0.031), (0.011, 0.004, 0.004), "steel")
mag_catch = g.prism("mag_catch", [(0.069, -0.030), (0.077, -0.030), (0.081, -0.055), (0.072, -0.058)], 0.013, "steel_worn", bevel=0.001)
# ピストルグリップ(斜め下後ろへ伸びる。断面は角丸)
gt, gb = Vector((0, -0.021, -0.026)), Vector((0, -0.062, -0.146))
axis = (gb - gt).normalized()
fwd = Vector((0, -axis.z, axis.y))  # 軸に垂直で前向き
grip_rings = []
for t, w, d in [(0.0, 0.026, 0.040), (0.25, 0.030, 0.045), (0.6, 0.031, 0.044), (0.92, 0.029, 0.040), (1.0, 0.026, 0.036)]:
    grip_rings.append(g.ring(gt + (gb - gt) * t, (1, 0, 0), fwd, RR(w, d, 0.010, 3)))
grip = g.loft("grip", grip_rings, "bakelite", smooth_angle=60)
g.bevel(grip, 0.004, 3, angle=50)
# セレクターレバー(右側面の長い板)と軸
selector = g.prism("selector", [
    (-0.096, 0.010), (-0.088, 0.018), (0.050, 0.017), (0.060, 0.009), (0.052, 0.003), (-0.088, 0.004),
], 0.0025, "steel_worn", x=0.0178)
selector_tab = g.box("selector_tab", (0.0200, 0.058, 0.0085), (0.0045, 0.008, 0.012), "steel_worn", bevel=0.001)
selector_pivot = g.tube_x("selector_pivot", (0.018, -0.090, 0.011), 0.004, 0.0045, "steel")
# 機関部のピン(左右)
pins = []
for side in (-1, 1):
    for (py, pz) in [(-0.008, -0.016), (0.018, -0.012), (0.040, -0.012)]:
        pins.append(g.tube_x(f"pin_{side}_{py}", (side * 0.0168, py, pz), 0.002, 0.0025, "steel_worn"))
receiver_parts = [receiver, bolt_carrier, bolt_face, dust_cover, spring_button, rs_block, leaf,
                  notch, leaf_rib, slider, slider_btn, hinge, gas_latch, guard_bottom, guard_front, mag_catch,
                  grip, selector, selector_tab, selector_pivot] + pins

# ======================= バレル(銃身まわり) =======================
barrel = g.tube_y("barrel_tube", 0.180, 0.500, 0.0095, "steel", z=BARREL_Z, segments=24)
muzzle_nut = g.tube_y("muzzle_nut", 0.495, 0.522, 0.0112, "steel_worn", z=BARREL_Z, segments=24, radius1=0.0104)
g.bevel(muzzle_nut, 0.0008, 2)
g.cut(muzzle_nut, g.tube_y("c", 0.510, 0.53, 0.0043, "recess", z=BARREL_Z, segments=16))
# フロントサイト: 銃身を抱く台、左右の耳、中央の柱
fs_base = g.loft("fs_base", [sec(0.462, 0.008, 0.024, 0.030, 0.008), sec(0.496, 0.008, 0.024, 0.030, 0.008)], "steel")
fs_tower = g.prism("fs_tower", [(0.468, 0.020), (0.471, 0.040), (0.487, 0.040), (0.490, 0.020)], 0.008, "steel", bevel=0.001)
ears = [g.prism(f"fs_ear_{s}", [(0.464, 0.020), (0.469, 0.066), (0.489, 0.066), (0.494, 0.020)], 0.0028, "steel", x=s * 0.0085)
        for s in (-1, 1)]
fs_post = g.tube_y("fs_post_tmp", 0, 0.024, 0.0013, "steel_worn", segments=10)
fs_post.data.transform(Matrix.Translation((0, 0.479, 0.050)) @ Matrix.Rotation(math.radians(90), 4, "X") @ Matrix.Translation((0, -0.012, 0)))
fs_post.name = "fs_post"
for e in ears:
    g.bevel(e, 0.0006, 2)
g.bevel(fs_base, 0.001, 2)
bayonet_lug = g.box("bayonet_lug", (0, 0.481, -0.014), (0.010, 0.026, 0.010), "steel", bevel=0.001)
# ガスブロック(45度)とガスチューブ
gas_block = g.prism("gas_block", [
    (0.352, -0.004), (0.352, 0.049), (0.372, 0.049), (0.394, 0.022), (0.394, -0.004),
], 0.024, "steel", bevel=0.003)
gas_tube = g.tube_y("gas_tube", 0.288, 0.358, 0.0095, "steel", z=0.037, segments=24)
front_sling = g.sweep_yz("front_sling_loop", [(0, 0.360, 0.004), (0, 0.364, -0.010), (0, 0.376, -0.012), (0, 0.384, -0.010), (0, 0.388, 0.004)],
                         RR(0.003, 0.003, 0.0012, 2), "steel_worn")
front_sling.data.transform(Matrix.Translation((-0.014, 0, 0)))
# 上部ハンドガード(半円)
upper_hg = g.loft("upper_handguard", [
    g.ring_y(0.186, 0.026, g.arch(0.028, 0.004, 0.012)),
    g.ring_y(0.194, 0.024, g.arch(0.033, 0.006, 0.017)),
    g.ring_y(0.284, 0.024, g.arch(0.033, 0.006, 0.017)),
    g.ring_y(0.292, 0.026, g.arch(0.028, 0.004, 0.013)),
], "wood", smooth_angle=60)
# 下部ハンドガード(指のかかるふくらみ)
lower_hg = g.loft("lower_handguard", [
    sec(0.142, -0.004, 0.040, 0.038, 0.012, seg=3),
    sec(0.152, -0.007, 0.048, 0.045, 0.015, seg=3),
    sec(0.175, -0.009, 0.053, 0.049, 0.017, seg=3),   # 手のひらが当たるふくらみ
    sec(0.205, -0.007, 0.047, 0.045, 0.015, seg=3),
    sec(0.240, -0.007, 0.046, 0.044, 0.015, seg=3),
    sec(0.272, -0.009, 0.052, 0.048, 0.017, seg=3),
    sec(0.290, -0.006, 0.047, 0.043, 0.014, seg=3),
    sec(0.296, -0.004, 0.044, 0.040, 0.012, seg=3),
], "wood", smooth_angle=60)
g.bevel(lower_hg, 0.004, 3, angle=50)
g.bevel(upper_hg, 0.003, 3, angle=50)
retainer = g.loft("hg_retainer", [sec(0.296, 0.008, 0.050, 0.064, 0.012, seg=3), sec(0.310, 0.008, 0.050, 0.064, 0.012, seg=3)], "steel")
retainer_lever = g.box("hg_retainer_lever", (0.026, 0.303, 0.000), (0.004, 0.010, 0.030), "steel_worn", bevel=0.001)
cleaning_rod = g.tube_y("cleaning_rod", 0.310, 0.490, 0.0028, "steel_worn", z=-0.014, segments=6)
rod_head = g.box("cleaning_rod_head", (0, 0.492, -0.014), (0.006, 0.006, 0.008), "steel_worn")
barrel_parts = [front_sling, barrel, muzzle_nut, fs_base, fs_tower, fs_post, bayonet_lug, gas_block, gas_tube,
                upper_hg, lower_hg, retainer, retainer_lever, cleaning_rod, rod_head] + ears

# ======================= マガジン(前に湾曲、リブ付き) =======================
MC = Vector((0, 0.368, -0.030))  # 弧の中心
MR = 0.272                       # 弧の半径(マガジンの中心線)
SWEEP = 0.72


def mag_frame(t):
    a = math.pi + SWEEP * t
    radial = Vector((0, math.cos(a), math.sin(a)))  # 中心 → マガジン(後ろ下向き)
    return MC + radial * MR, radial


mag_rings, floor_rings = [], []
for i in range(12):
    t = -0.05 + 1.05 * i / 11
    p, radial = mag_frame(t)
    mag_rings.append(g.ring(p, (1, 0, 0), radial, RR(0.0265, 0.050 + 0.008 * max(t, 0), 0.004, 2)))
magazine = g.loft("magazine_body", mag_rings, "steel", smooth_angle=30)
for t, w, d in [(1.0, 0.030, 0.064), (1.04, 0.030, 0.064)]:
    p, radial = mag_frame(t)
    floor_rings.append(g.ring(p, (1, 0, 0), radial, RR(w, d, 0.003)))
mag_floor = g.loft("mag_floor", floor_rings, "steel_worn")
ribs = []
for side in (-1, 1):
    for off in (-0.012, 0.012):
        rr = []
        for i in range(8):
            t = 0.12 + 0.76 * i / 7
            p, radial = mag_frame(t)
            rr.append(g.ring(p + Vector((side * 0.0138, 0, 0)) + radial * off, (1, 0, 0), radial, RR(0.0022, 0.004, 0.001, 1)))
        ribs.append(g.loft(f"mag_rib_{side}_{off}", rr, "steel"))
spine = []
for i in range(10):
    t = -0.02 + 1.0 * i / 9
    p, radial = mag_frame(t)
    spine.append(g.ring(p + radial * (0.025 + 0.004 * max(t, 0)), (1, 0, 0), radial, RR(0.010, 0.004, 0.0015, 2)))
mag_spine = g.loft("mag_spine", spine, "steel")
mag_lug = g.box("mag_front_lug", (0, 0.124, -0.026), (0.012, 0.008, 0.010), "steel")

# ======================= ストック(木製、下がった形) =======================
stock = g.loft("stock_body", [
    sec(-0.122, -0.010, 0.030, 0.040, 0.008, seg=3),
    sec(-0.170, -0.024, 0.034, 0.058, 0.010, seg=3),
    sec(-0.250, -0.050, 0.038, 0.086, 0.012, seg=3),
    sec(-0.358, -0.089, 0.042, 0.112, 0.012, seg=3),
], "wood", smooth_angle=60)
g.bevel(stock, 0.004, 3, angle=50)
butt_plate = g.loft("butt_plate", [sec(-0.358, -0.089, 0.043, 0.114, 0.012, seg=3), sec(-0.368, -0.089, 0.043, 0.114, 0.012, seg=3)], "steel")
stock_tang = g.box("stock_tang", (0, -0.136, 0.005), (0.026, 0.030, 0.008), "steel", bevel=0.001)
sling_loop = g.box("stock_sling_loop", (-0.0215, -0.215, -0.045), (0.003, 0.022, 0.008), "steel_worn", bevel=0.001)

# ======================= 動く部品 =======================
bolt_handle = g.tube_x("bolt_handle", (0.030, 0.090, 0.016), 0.028, 0.0045, "steel_worn")
bolt_knob = g.tube_x("bolt_knob", (0.045, 0.090, 0.016), 0.010, 0.0075, "steel_worn", segments=20)
trigger = g.prism("trigger", [(0.034, -0.030), (0.041, -0.030), (0.037, -0.044), (0.030, -0.052), (0.028, -0.049), (0.033, -0.040)],
                  0.006, "steel_worn")

# ======================= まとめる =======================
parts = [
    g.join("receiver", receiver_parts),
    g.join("barrel", barrel_parts),
    g.join("magazine", [magazine, mag_floor, mag_lug, mag_spine] + ribs),
    g.join("stock", [stock, butt_plate, stock_tang, sling_loop]),
    g.join("bolt_handle", [bolt_handle, bolt_knob]),
    trigger,
]
trigger.name = "trigger"

points = {
    "muzzle": (0, 0.524, BARREL_Z),
    "ads_eye": (0, 0.121, 0.0565),     # リアサイトの切り欠き。構えたとき目がこの延長線上に来る
    "attach_barrel": (0, 0.135, BARREL_Z),
    "attach_magazine": (0, 0.090, -0.030),
    "attach_stock": (0, -0.125, -0.005),
    "attach_sight": (0, 0.150, 0.052),
    "attach_option": (0, 0.250, -0.034),
}

for p in parts:
    p.data.transform(Matrix.Translation(OFF))
root = g.make_root("ak47", parts, {k: Vector(v) + OFF for k, v in points.items()})

print(f"[ak47] ポリゴン数(三角形): {g.poly_count()}")

args = g.cli_args()
if args["out"]:
    g.export_glb(args["out"])
    print(f"[ak47] 書き出し: {args['out']}")
if args["render"]:
    g.render_views(args["render"], "ak47", ads_eye=Vector(points["ads_eye"]) + OFF,
                   front_post=Vector((0, 0.479, 0.062)) + OFF)
    print(f"[ak47] 画像: {args['render']}")
