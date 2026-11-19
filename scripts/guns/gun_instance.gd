class_name GunInstance
extends RefCounted
## ドロップした1丁の銃。銃種 + シード値 + レベルだけで性能が決まる
## (通信やセーブでは type_id / seed / level / rarity の数十バイトを送れば同じ銃が再現できる)。
##
## M1 ではパーツ枠はまだ無く、各性能に ±15% のばらつきとレア度の補正を掛けるだけ。
## M3 で「各枠のパーツを抽選 → 性能 = 基礎値 × パーツ倍率 × レベル補正」に置き換える。

enum Rarity { COMMON, RARE, EPIC, LEGEND }
const RARITY_NAMES := ["コモン", "レア", "エピック", "レジェンド"]
const RARITY_COLORS := [Color(0.85, 0.85, 0.85), Color(0.35, 0.65, 1.0), Color(0.75, 0.4, 1.0), Color(1.0, 0.7, 0.2)]
## レア度ごとのダメージ補正
const RARITY_DAMAGE := [1.0, 1.1, 1.22, 1.35]

var type: GunType
var seed_value := 0
var level := 1
var rarity := Rarity.COMMON

# 最終性能
var damage := 0.0
var rpm := 0.0
var magazine := 0
var reload_time := 0.0
var pellets := 1
var spread_deg := 0.0
var bullet_speed := 0.0
var recoil := 0.0
var weight := 0.0
var charge_time := 0.0

## 実行中の状態
var ammo := 0


static func roll(gun_type: GunType, seed_val: int, lvl := 1) -> GunInstance:
	var g := GunInstance.new()
	g.type = gun_type
	g.seed_value = seed_val
	g.level = lvl
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var r := rng.randf()
	g.rarity = Rarity.LEGEND if r > 0.97 else Rarity.EPIC if r > 0.85 else Rarity.RARE if r > 0.55 else Rarity.COMMON
	# ばらつき: 0.85〜1.15。良い方向に振れるほうが嬉しい性能と、小さいほうが嬉しい性能がある
	var lv := 1.0 + 0.08 * (lvl - 1)
	g.damage = gun_type.damage * _v(rng) * RARITY_DAMAGE[g.rarity] * lv
	g.rpm = gun_type.rpm * _v(rng)
	g.magazine = maxi(1, roundi(gun_type.magazine * _v(rng)))
	g.reload_time = gun_type.reload_time * _v(rng)
	g.pellets = maxi(1, roundi(gun_type.pellets * _v(rng)))
	g.spread_deg = gun_type.spread_deg * _v(rng)
	g.bullet_speed = gun_type.bullet_speed * _v(rng)
	g.recoil = gun_type.recoil * _v(rng)
	g.weight = gun_type.weight * _v(rng)
	g.charge_time = gun_type.charge_time * _v(rng)
	g.ammo = g.magazine
	return g


static func _v(rng: RandomNumberGenerator) -> float:
	return rng.randf_range(0.85, 1.15)


func display_name() -> String:
	return type.display_name


## 重さ → 移動速度の倍率。3kg を基準に、重いほど遅く(最大 -25%)、軽い拳銃は少し速い(最大 +5%)
static func speed_multiplier(total_weight: float) -> float:
	return clampf(1.0 - (total_weight - 3.0) * 0.045, 0.75, 1.05)


func dps() -> float:
	return damage * pellets * rpm / 60.0


func stat_lines() -> PackedStringArray:
	var mode := ["フルオート", "セミオート", "チャージ"][type.fire_mode] as String
	return PackedStringArray([
		"%s  Lv%d  %s" % [RARITY_NAMES[rarity], level, mode],
		"威力 %.0f%s   連射 %.0f/分" % [damage, (" ×%d" % pellets) if pellets > 1 else "", rpm],
		"装弾 %d   リロード %.2f秒" % [magazine, reload_time],
		"拡散 %.1f°   弾速 %.0f m/s" % [spread_deg, bullet_speed],
		"重さ %.1f kg (移動 %+d%%)   DPS %.0f" % [weight, roundi((speed_multiplier(weight) - 1.0) * 100.0), dps()],
	])
