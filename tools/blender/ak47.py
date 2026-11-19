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

g.PALETTE["steel_bright"] = ((0.12, 0.12, 0.13), 0.65, 0.40)
g.PALETTE["recess"] = ((0.010, 0.010, 0.012), 0.5, 0.7)
g.reset_scene()


# ======================= 照準像の設計(構えた画面から逆算) =======================
# 先に「構えたとき 1600x900 の画面でどう見えるか」をピクセルで決め、目からの距離で実寸に直す。
# 画面上の大きさ(px) = 実寸 / 距離 * PX_PER_RAD。照門は目に近いので小さく、照星は遠いので太くなる。
FAT, SHORT, PIVOT = 1.15, 0.82, 0.135   # デフォルメ(下の stylize と共通): 左右に太く、銃身側を短く
ADS_VFOV_DEG = 52.0          # 構え中の縦の視野角(player.gd: 85 - 33)
SCREEN_H = 900
EYE_DIST = 0.17              # 目から照門までの距離(data/guns/ak47.tres の ads_eye_dist と同じ値にする)
PX_PER_RAD = (SCREEN_H / 2) / math.tan(math.radians(ADS_VFOV_DEG / 2))
REAR_Y, POST_Y = 0.119, 0.479                       # 生の座標での照門・照星の位置
FRONT_DIST = EYE_DIST + (PIVOT + (POST_Y - PIVOT) * SHORT) - REAR_Y  # 目から照星まで(銃身側の縮みを考慮)
SIGHT_PX = dict(notch_w=90, notch_depth=45, rear_w=250, post_w=14, ear_gap=72, ear_thick=11)


def at_rear(px):
    return px / PX_PER_RAD * EYE_DIST


def at_front(px):
    return px / PX_PER_RAD * FRONT_DIST


NOTCH_W = at_rear(SIGHT_PX["notch_w"]) / FAT          # 生の座標の幅(あとで FAT 倍される)
NOTCH_DEPTH = at_rear(SIGHT_PX["notch_depth"])
REAR_W = at_rear(SIGHT_PX["rear_w"]) / FAT
POST_R = at_front(SIGHT_PX["post_w"]) / 2 / FAT
EAR_HALF_T = at_front(SIGHT_PX["ear_thick"]) / 2 / FAT
EAR_X = (at_front(SIGHT_PX["ear_gap"]) / 2) / FAT + EAR_HALF_T   # 耳の板の中心
NOTCH_TOP = 0.0700   # 照準線の高さ。上蓋から十分上げて、構えたとき上蓋が視界を塞がないように
POST_TIP = NOTCH_TOP + 0.004
print(f"[ak47] 照準: 溝 幅{NOTCH_W * FAT * 1000:.1f} 深さ{NOTCH_DEPTH * 1000:.1f} 照門幅{REAR_W * FAT * 1000:.1f} "
      f"柱 太さ{POST_R * 2 * FAT * 1000:.1f} 耳の空き{(EAR_X + EAR_HALF_T * 0.7 - EAR_HALF_T) * 2 * FAT * 1000:.1f} 厚さ{EAR_HALF_T * 2 * FAT * 1000:.1f} (mm)")


def sec(y, zc, w, h, r, x=0.0, seg=2):
    """Y に垂直な角丸断面(中心の高さ zc)。"""
    return g.ring_y(y, zc, RR(w, h, r, seg), x)


# ======================= レシーバー(本体) =======================
# 後端の下側は斜めに切れ上がり(約15度)、そこへストックが差し込まれる
receiver = g.prism("receiver_body", [
    (-0.128, 0.026), (-0.128, -0.006), (-0.118, -0.030), (0.135, -0.030), (0.135, 0.026),
], 0.033, "steel")
# 削り出しレシーバーの肉抜き(左右、長さ 95mm・高さ 17mm・深さ 4mm、前端は半円、後端は斜面)
for sx in (-1, 1):
    # 重なった形を1つにまとめてから削ると失敗するので、箱と半円を順に削る
    g.cut(receiver, g.prism("c", [(0.046, -0.0185), (0.030, -0.0015), (0.121, -0.0015), (0.121, -0.0185)], 0.010, "recess", x=sx * 0.0175))
    g.cut(receiver, g.tube_x("c2", (sx * 0.0175, 0.121, -0.010), 0.010, 0.0085, "recess", segments=24))
# 排莢口(右、長さ 100mm・高さ 20mm)。壁を抜いて中のボルトキャリアを見せる
g.cut(receiver, g.box("c", (0.0150, 0.050, 0.015), (0.010, 0.100, 0.020), "recess"))
g.bevel(receiver, 0.0022, 3, flat=True)
# 排莢口の奥に見えるボルトキャリア(少し明るい鉄)とボルト
bolt_carrier = g.loft("bolt_carrier_visible", [sec(0.000, 0.015, 0.024, 0.018, 0.004, seg=3), sec(0.098, 0.015, 0.024, 0.018, 0.004, seg=3)], "steel_bright")
bolt_face = g.tube_y("bolt_head", 0.098, 0.112, 0.0065, "steel", z=0.012, segments=16)
# ダストカバー(上が丸い)と後端のボタン
def dc_section(w, h_side, top_w, h_top):
    """ダストカバーの断面: 上面は幅 top_w の平らな面、そこから左右へ丸く落ちる。"""
    n = 10
    pts = [(w / 2, 0.0), (w / 2, h_side)]
    for k in range(1, n):
        a = math.pi / 2 * k / n
        pts.append((top_w / 2 + (w - top_w) / 2 * math.cos(a), h_side + (h_top - h_side) * math.sin(a)))
    pts += [(top_w / 2, h_top)]
    for k in range(1, 4):  # 上面もわずかに丸い
        x = top_w / 2 * (1 - 2 * k / 4)
        pts.append((x, h_top + 0.0008 * math.sin(math.pi * k / 4)))
    pts += [(-top_w / 2, h_top)]
    for k in range(n - 1, 0, -1):
        a = math.pi / 2 * k / n
        pts.append((-top_w / 2 - (w - top_w) / 2 * math.cos(a), h_side + (h_top - h_side) * math.sin(a)))
    pts += [(-w / 2, h_side), (-w / 2, 0.0)]
    return pts


dust_cover = g.loft("dust_cover", [
    g.ring_y(-0.134, 0.022, dc_section(0.027, 0.002, 0.007, 0.007)),
    g.ring_y(-0.128, 0.022, dc_section(0.033, 0.006, 0.014, 0.016)),
    g.ring_y(-0.122, 0.022, dc_section(0.035, 0.009, 0.016, 0.026)),
    g.ring_y(0.104, 0.022, dc_section(0.035, 0.009, 0.016, 0.026)),
    g.ring_y(0.112, 0.022, dc_section(0.033, 0.009, 0.015, 0.024)),
], "steel", smooth_angle=30)
# 後部の段(ダストカバー後端の補強の盛り上がり)
dc_step = g.loft("dust_cover_step", [
    g.ring_y(-0.121, 0.022, dc_section(0.0356, 0.009, 0.0166, 0.0265)),
    g.ring_y(-0.100, 0.022, dc_section(0.0356, 0.009, 0.0166, 0.0265)),
], "steel", smooth_angle=30)
dc_seams = [g.box(f"dust_cover_seam_{s}", (s * 0.0172, -0.005, 0.0225), (0.0012, 0.215, 0.0010), "recess") for s in (-1, 1)]
spring_button = g.tube_y("spring_button", -0.140, -0.128, 0.0062, "steel_worn", z=0.030, segments=20)
g.bevel(spring_button, 0.0008, 2)
# リアサイトの台(前へ細くなる)
rs_block = g.loft("rear_sight_block", [
    sec(0.110, 0.022, 0.032, 0.048, 0.006),
    sec(0.150, 0.024, 0.030, 0.046, 0.007),
    sec(0.185, 0.017, 0.026, 0.032, 0.008),
], "steel", smooth_angle=40)
# リアサイトのリーフ(前で蝶番、後端に U 字の切り欠き)とスライダー
# 照尺板: 厚さ 2.5mm、幅 16mm、前の蝶番から後ろへ少し上がりながら伸びる
leaf = g.prism("rs_leaf", [(0.119, 0.0460), (0.119, 0.0485), (0.172, 0.0470), (0.172, 0.0445)], 0.016, "steel_worn")
g.bevel(leaf, 0.0005, 1)
# 照門: 板の幅・U 字の幅と深さは上の照準像の設計から(底が丸い U)
notch = g.prism("rs_notch", [(0.116, 0.0430), (0.116, NOTCH_TOP), (0.122, NOTCH_TOP), (0.122, 0.0430)], REAR_W, "steel_worn")
_u_r = NOTCH_W / 2
_u_c = NOTCH_TOP - NOTCH_DEPTH + _u_r
# 円柱を先に削り、箱は円柱の側面と面が重ならないようにわずかに細くする(重なると削りに失敗する)
g.cut(notch, g.tube_y("c2", 0.110, 0.131, _u_r, "recess", z=_u_c, segments=32))
g.cut(notch, g.box("c1", (0, 0.1190, _u_c + 0.0102), (NOTCH_W * 0.99, 0.01, 0.020), "recess"))
g.bevel(notch, 0.0018, 3)
rs_knobs = [g.tube_x(f"rs_knob_{sx}", (sx * (REAR_W / 2 + 0.0015), 0.1205, 0.0490), 0.004, 0.0042, "steel", segments=16) for sx in (-1, 1)]
leaf_rib = g.box("rs_leaf_rib", (0, 0.145, 0.0490), (0.004, 0.050, 0.0015), "steel_worn")
slider = g.box("rs_slider", (0, 0.146, 0.0480), (0.020, 0.010, 0.006), "steel", bevel=0.001)
slider_btn = g.tube_x("rs_slider_btn", (0.0115, 0.146, 0.0480), 0.004, 0.0028, "steel_worn")
hinge = g.tube_x("rs_hinge", (0, 0.172, 0.047), 0.030, 0.003, "steel")
gas_latch = g.box("gas_tube_latch", (0.0155, 0.172, 0.032), (0.004, 0.016, 0.006), "steel_worn", bevel=0.001)
# トリガーガード、マガジンキャッチ
guard = g.sweep_yz("trigger_guard", [(0, -0.004, -0.029), (0, -0.002, -0.046), (0, 0.006, -0.056), (0, 0.020, -0.058),
                                      (0, 0.050, -0.058), (0, 0.062, -0.054), (0, 0.067, -0.044), (0, 0.068, -0.029)],
                   RR(0.012, 0.003, 0.0013, 2), "steel")
guard_bottom = guard
guard_front = g.box("guard_rivet", (0, 0.064, -0.031), (0.011, 0.004, 0.004), "steel")
mag_catch = g.prism("mag_catch", [(0.069, -0.030), (0.078, -0.030), (0.084, -0.047), (0.086, -0.058), (0.074, -0.060), (0.072, -0.046)],
                    0.011, "steel_worn", bevel=0.0012)
# ピストルグリップ(斜め下後ろへ伸びる。断面は角丸)
gt, gb = Vector((0, -0.021, -0.026)), Vector((0, -0.062, -0.146))
axis = (gb - gt).normalized()
fwd = Vector((0, -axis.z, axis.y))  # 軸に垂直で前向き
grip_rings = []
for t, w, d in [(0.0, 0.026, 0.040), (0.25, 0.030, 0.045), (0.6, 0.031, 0.044), (0.92, 0.029, 0.040), (1.0, 0.026, 0.036)]:
    grip_rings.append(g.ring(gt + (gb - gt) * t, (1, 0, 0), fwd, RR(w, d, w * 0.45, 5)))
grip = g.loft("grip", grip_rings, "bakelite", smooth_angle=60)
g.bevel(grip, 0.004, 3, angle=50)
# セレクターレバー(右側面の長い板)と軸
selector = g.prism("selector", [
    (-0.096, 0.011), (-0.086, 0.020), (0.040, 0.019), (0.052, 0.010), (0.042, 0.002), (-0.086, 0.003),
], 0.0040, "steel_worn", x=0.0185, bevel=0.0012)
selector_tab = g.box("selector_tab", (0.0215, 0.048, 0.0090), (0.0060, 0.010, 0.016), "steel_worn", bevel=0.0015)
selector_pivot = g.tube_x("selector_pivot", (0.0200, -0.090, 0.011), 0.006, 0.0068, "steel", segments=20)
g.bevel(selector_pivot, 0.0012, 2)
# 機関部のピン(左右)
pins = []
for side in (-1, 1):
    for (py, pz) in [(-0.008, -0.016), (0.018, -0.012), (0.040, -0.012)]:
        pins.append(g.tube_x(f"pin_{side}_{py}", (side * 0.0170, py, pz), 0.0025, 0.0034, "steel_worn", segments=14))
receiver_parts = dc_seams + [receiver, dust_cover, dc_step, spring_button, rs_block, leaf,
                  notch, leaf_rib, slider, slider_btn] + rs_knobs + [hinge, gas_latch, guard_bottom, guard_front, mag_catch,
                  grip, selector, selector_tab, selector_pivot] + pins

# ======================= バレル(銃身まわり) =======================
barrel = g.tube_y("barrel_tube", 0.180, 0.500, 0.0095, "steel", z=BARREL_Z, segments=24)
muzzle_nut = g.tube_y("muzzle_nut", 0.495, 0.522, 0.0112, "steel_worn", z=BARREL_Z, segments=24, radius1=0.0104)
g.bevel(muzzle_nut, 0.0008, 2)
g.cut(muzzle_nut, g.tube_y("c", 0.510, 0.53, 0.0043, "recess", z=BARREL_Z, segments=16))
bore = g.tube_y("bore_dark", 0.508, 0.5105, 0.0044, "recess", z=BARREL_Z, segments=16)
# フロントサイト: 銃身を抱く台、左右の耳、中央の柱
fs_base = g.loft("fs_base", [sec(0.462, 0.010, 2 * (EAR_X + EAR_HALF_T * 1.7) + 0.002, 0.034, 0.009), sec(0.496, 0.010, 2 * (EAR_X + EAR_HALF_T * 1.7) + 0.002, 0.034, 0.009)], "steel")
fs_tower = g.prism("fs_tower", [(0.468, 0.020), (0.471, POST_TIP - 0.022), (0.487, POST_TIP - 0.022), (0.490, 0.020)], 0.008, "steel", bevel=0.001)
def ear_section(side, top):
    """照星の耳の断面(正面から見た形): 馬蹄形。台から立ち上がり、柱を大きく囲んで、上端だけ内側へ曲がる。
    中心の位置 EAR_X と厚さは照準像の設計から(柱の左右が広く空くように)。"""
    outer, inner = [], []
    for k in range(9):
        t = k / 8
        z = 0.024 + (top - 0.024) * t
        # 上端の内側への返しは控えめにし、そのぶん全体を外へ出して、柱の左右の空きを狙いどおりに保つ
        x = EAR_X + EAR_HALF_T * 0.7 - EAR_HALF_T * 0.7 * max(0.0, t - 0.75) / 0.25
        outer.append((side * (x + EAR_HALF_T), z))
        inner.append((side * (x - EAR_HALF_T), z))
    pts = outer + list(reversed(inner))
    return pts if side > 0 else list(reversed(pts))


# 耳は前縁が斜め(前が低い)
ears = [g.loft(f"fs_ear_{s}", [g.ring_y(0.470, 0.0, ear_section(s, 0.054)), g.ring_y(0.477, 0.0, ear_section(s, POST_TIP + 0.006)),
                               g.ring_y(0.487, 0.0, ear_section(s, POST_TIP + 0.006))], "steel", smooth_angle=40)
        for s in (-1, 1)]
fs_post = g.tube_y("fs_post_tmp", 0, 0.024, POST_R, "steel_worn", segments=16)
fs_post.data.transform(Matrix.Translation((0, 0.479, POST_TIP - 0.012)) @ Matrix.Rotation(math.radians(90), 4, "X") @ Matrix.Translation((0, -0.012, 0)))
fs_post.name = "fs_post"
g.bevel(fs_base, 0.001, 2)
bayonet_lug = g.box("bayonet_lug", (0, 0.481, -0.014), (0.010, 0.026, 0.010), "steel", bevel=0.001)
# ガスブロック(45度)とガスチューブ
gas_collar = g.tube_y("gas_block_collar", 0.364, 0.394, 0.0130, "steel", z=BARREL_Z, segments=24)
g.bevel(gas_collar, 0.0012, 2)
gas_link = g.prism("gas_block_link", [
    (0.366, 0.012), (0.366, 0.030), (0.374, 0.036), (0.394, 0.016), (0.394, 0.012),
], 0.016, "steel", bevel=0.002)
gas_cyl = g.tube_y("gas_block_cylinder", 0.350, 0.377, 0.0115, "steel", z=0.037, segments=24)
g.bevel(gas_cyl, 0.0012, 2)
gas_block = g.join("gas_block", [gas_collar, gas_link, gas_cyl])
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
    sec(0.134, -0.004, 0.040, 0.038, 0.014, seg=4),
    sec(0.150, -0.0075, 0.047, 0.045, 0.017, seg=4),
    sec(0.180, -0.0085, 0.051, 0.047, 0.018, seg=4),   # 手のひらが当たる横のふくらみ
    sec(0.230, -0.0085, 0.049, 0.047, 0.018, seg=4),
    sec(0.275, -0.0085, 0.050, 0.047, 0.018, seg=4),
    sec(0.290, -0.0065, 0.047, 0.043, 0.016, seg=4),
    sec(0.296, -0.004, 0.044, 0.038, 0.014, seg=4),
], "wood", smooth_angle=60)
g.bevel(lower_hg, 0.004, 3, angle=50)
g.bevel(upper_hg, 0.003, 3, angle=50)
hg_rear_ferrule = g.loft("hg_rear_ferrule", [sec(0.128, -0.004, 0.042, 0.040, 0.012, seg=3), sec(0.138, -0.004, 0.042, 0.040, 0.012, seg=3)], "steel")
g.bevel(hg_rear_ferrule, 0.0008, 2)
uhg_caps = [g.loft(f"upper_hg_cap_{k}", [g.ring_y(y0, 0.025, g.arch(0.035, 0.006, 0.018)), g.ring_y(y0 + 0.007, 0.025, g.arch(0.035, 0.006, 0.018))], "steel")
            for k, y0 in enumerate((0.283, 0.186))]
retainer = g.loft("hg_retainer", [sec(0.296, 0.008, 0.050, 0.064, 0.012, seg=3), sec(0.310, 0.008, 0.050, 0.064, 0.012, seg=3)], "steel")
retainer_lever = g.box("hg_retainer_lever", (0.026, 0.303, 0.000), (0.004, 0.010, 0.030), "steel_worn", bevel=0.001)
cleaning_rod = g.tube_y("cleaning_rod", 0.310, 0.490, 0.0028, "steel_worn", z=-0.014, segments=6)
rod_head = g.box("cleaning_rod_head", (0, 0.492, -0.014), (0.006, 0.006, 0.008), "steel_worn")
barrel_parts = [bore, front_sling, barrel, muzzle_nut, fs_base, fs_tower, fs_post, bayonet_lug, gas_block, gas_tube,
                upper_hg, lower_hg, hg_rear_ferrule, retainer, retainer_lever, cleaning_rod, rod_head] + ears + uhg_caps

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
    mag_rings.append(g.ring(p, (1, 0, 0), radial, RR(0.0290, 0.058 + 0.008 * max(t, 0), 0.005, 2)))
magazine = g.loft("magazine_body", mag_rings, "steel", smooth_angle=30)
for t, w, d in [(1.0, 0.032, 0.070), (1.022, 0.032, 0.070)]:
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
            rr.append(g.ring(p + Vector((side * 0.0150, 0, 0)) + radial * off, (1, 0, 0), radial, RR(0.0030, 0.0055, 0.0012, 2)))
        ribs.append(g.loft(f"mag_rib_{side}_{off}", rr, "steel"))
spine = []
for i in range(10):
    t = -0.02 + 1.0 * i / 9
    p, radial = mag_frame(t)
    spine.append(g.ring(p + radial * (0.029 + 0.004 * max(t, 0)), (1, 0, 0), radial, RR(0.010, 0.004, 0.0015, 2)))
mag_spine = g.loft("mag_spine", spine, "steel")
mag_lug = g.box("mag_front_lug", (0, 0.124, -0.026), (0.012, 0.008, 0.010), "steel")

# ======================= ストック(木製、下がった形) =======================
# 付け根で一度細くくびれ(首)、肩に向かって広がる。断面は上下を丸めた楕円に近い形
stock = g.loft("stock_body", [
    sec(-0.118, -0.008, 0.029, 0.044, 0.012, seg=5),
    sec(-0.140, -0.014, 0.027, 0.040, 0.012, seg=5),   # 首
    sec(-0.175, -0.026, 0.031, 0.052, 0.014, seg=5),
    sec(-0.250, -0.051, 0.039, 0.084, 0.018, seg=5),   # 横がふくらんだ楕円に近い断面
    sec(-0.330, -0.072, 0.042, 0.094, 0.019, seg=5),
    sec(-0.358, -0.079, 0.042, 0.098, 0.018, seg=5),
], "wood", smooth_angle=60)
g.bevel(stock, 0.004, 3, angle=50)
butt_plate = g.loft("butt_plate", [sec(-0.358, -0.079, 0.043, 0.100, 0.018, seg=5), sec(-0.367, -0.079, 0.043, 0.100, 0.018, seg=5)], "steel")
g.bevel(butt_plate, 0.0015, 2)
# レシーバー後端の下でストックを受ける座金と、木部の上を後ろへ伸びるタング(幅 14mm・長さ 40mm)
stock_tang = g.loft("stock_tang", [
    sec(-0.120, 0.0150, 0.016, 0.004, 0.0015, seg=2),
    sec(-0.140, 0.0075, 0.015, 0.003, 0.0013, seg=2),
    sec(-0.160, 0.0040, 0.012, 0.003, 0.0013, seg=2),
], "steel")
tang_screw = g.tube_x("tang_screw_tmp", (0, -0.150, 0.0065), 0.004, 0.0028, "steel_worn", segments=12)
tang_screw.data.transform(Matrix.Translation((0, -0.150, 0.0065)) @ Matrix.Rotation(math.radians(90), 4, "Y") @ Matrix.Translation((0, 0.150, -0.0065)))
stock_collar = g.loft("stock_collar", [sec(-0.130, -0.004, 0.034, 0.024, 0.006, seg=3), sec(-0.120, 0.000, 0.034, 0.030, 0.006, seg=3)], "steel")
sling_loop = g.sweep_yz("rear_sling_loop", [(0, -0.122, -0.020), (0, -0.126, -0.030), (0, -0.112, -0.034), (0, -0.104, -0.030), (0, -0.106, -0.020)],
                        RR(0.003, 0.003, 0.0012, 2), "steel_worn")
sling_loop.data.transform(Matrix.Translation((-0.0185, 0, 0)))

# ======================= 動く部品 =======================
# コッキングハンドル: ボルトキャリア前端から右へ約 22mm、先が少し上へ反る一体の形
hpath = [Vector((0.012, 0.094, 0.015)), Vector((0.022, 0.094, 0.015)), Vector((0.031, 0.094, 0.016)),
         Vector((0.038, 0.094, 0.019)), Vector((0.042, 0.094, 0.023))]
hrings = []
for i, hp in enumerate(hpath):
    a, b = hpath[max(i - 1, 0)], hpath[min(i + 1, len(hpath) - 1)]
    t = (b - a).normalized()
    v = Vector((-t.z, 0, t.x))
    w = 0.016 if i < len(hpath) - 1 else 0.015   # 前後の厚み
    h = 0.010 if i < 2 else 0.014                # 先が太い
    hrings.append(g.ring(hp, (0, 1, 0), v, RR(w, h, 0.0035, 3)))
bolt_handle = g.loft("bolt_handle_body", hrings, "steel_worn", smooth_angle=60)
bolt_knob = g.box("bolt_handle_root", (0.0145, 0.094, 0.015), (0.006, 0.014, 0.010), "steel_worn", bevel=0.001)
trigger = g.prism("trigger", [(0.034, -0.030), (0.041, -0.030), (0.037, -0.044), (0.030, -0.052), (0.028, -0.049), (0.033, -0.040)],
                  0.006, "steel_worn")

# ======================= まとめる =======================
parts = [
    g.join("receiver", receiver_parts),
    g.join("barrel", barrel_parts),
    g.join("magazine", [magazine, mag_floor, mag_lug, mag_spine] + ribs),
    g.join("stock", [stock, butt_plate, stock_tang, tang_screw, stock_collar, sling_loop]),
    g.join("bolt", [bolt_carrier, bolt_face, bolt_handle, bolt_knob]),  # 撃つたびに後ろへ動く(Godot 側で動かす)
    trigger,
]
trigger.name = "trigger"

points = {
    "muzzle": (0, 0.524, BARREL_Z),
    "ejection_port": (0.018, 0.050, 0.015),  # 薬莢が出る所(排莢口の右)
    "ads_eye": (0, 0.1190, NOTCH_TOP),    # 照門の溝の上端。構えたとき目がこの延長線上に来る
    "front_post_tip": (0, 0.479, POST_TIP),
    "attach_barrel": (0, 0.135, BARREL_Z),
    "attach_magazine": (0, 0.090, -0.030),
    "attach_stock": (0, -0.125, -0.005),
    "attach_sight": (0, 0.150, 0.052),
    "attach_option": (0, 0.250, -0.034),
}

# デフォルメ(設定画の「中くらい」): 全体を左右に 15% 太く、銃身まわり(y > 0.135)を 18% 短く
def stylize(v):
    v = Vector(v)
    v.x *= FAT
    if v.y > PIVOT:
        v.y = PIVOT + (v.y - PIVOT) * SHORT
    return v


for p in parts:
    for vert in p.data.vertices:
        vert.co = stylize(vert.co)
    p.data.update()
    p.data.transform(Matrix.Translation(OFF))
points = {k: tuple(stylize(v)) for k, v in points.items()}
root = g.make_root("ak47", parts, {k: Vector(v) + OFF for k, v in points.items()})

print(f"[ak47] ポリゴン数(三角形): {g.poly_count()}")

args = g.cli_args()
if args["out"]:
    g.export_glb(args["out"])
    print(f"[ak47] 書き出し: {args['out']}")
if args["render"]:
    g.render_views(args["render"], "ak47", ads_eye=Vector(points["ads_eye"]) + OFF,
                   front_post=Vector(points["front_post_tip"]) + OFF, eye_dist=0.14)
    print(f"[ak47] 画像: {args['render']}")
