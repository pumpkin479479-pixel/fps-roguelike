class_name RevolverRig
extends RefCounted
## リボルバーの可動部を動かす(モデルに "cylinder" があるときに GunHolder が作る)。
##   撃つ: 撃鉄が一瞬起きて落ちる(フレームに密着)・引き金が下がる → シリンダーが 60° 回って次の弾が上に来る
##         待機中の撃鉄は前に倒れている(ダブルアクション)
##   リロード: クレーンごとシリンダーを左へ振り出す → 押し棒で薬莢を押し出して落とす
##             → 新しい弾を後ろから差し込む → シリンダーを戻す
## 部品の名前と回転の向きは tools/blender/revolver.py と合わせている。
## (Blender の +Y 軸まわり = Godot の -Z 軸まわり。X 軸まわりは同じ向き)

const CHAMBERS := 6
const CRANE_SWING := deg_to_rad(95.0)   # revolver.py の CRANE_SWING_DEG
const HAMMER_COCKED := 0.55             # 撃鉄を起こした角度(rotation.x)
const TRIGGER_PULL := -0.35
const EJECT_TRAVEL := 0.016             # 押し棒で薬莢が下がる距離(m)
const LOAD_FROM := 0.045                # 新しい弾が差し込まれ始める位置(シリンダーの後ろ、m)

var _crane: Node3D
var _cylinder: Node3D
var _ejector: Node3D
var _hammer: Node3D
var _trigger: Node3D
var _rounds: Array[Node3D] = []
var _bullets: Array[Node3D] = []
var _round_rest: Array[Vector3] = []
var _ejector_rest := Vector3.ZERO

## これまでに送った回数(シリンダーの角度 = n × 60°)
var _index := 0
var _turn_from := 0.0
## 撃ってからの進み(0〜1)。1 で撃鉄が起ききり、シリンダーが回りきった状態
var _fire_t := 1.0
var _cycle := 0.3

var _reloading := false
var _reload_time := 1.0
var _reload_t := 0.0
var _ejected := false


static func attach(view: Node3D) -> RevolverRig:
	var cyl := view.find_child("cylinder", true, false) as Node3D
	if cyl == null:
		return null
	var r := RevolverRig.new()
	r._cylinder = cyl
	r._crane = view.find_child("crane", true, false) as Node3D
	r._ejector = view.find_child("ejector", true, false) as Node3D
	r._hammer = view.find_child("hammer", true, false) as Node3D
	r._trigger = view.find_child("trigger", true, false) as Node3D
	for k in CHAMBERS:
		var rnd := view.find_child("round_%d" % k, true, false) as Node3D
		r._rounds.append(rnd)
		r._bullets.append(view.find_child("bullet_%d" % k, true, false) as Node3D)
		r._round_rest.append(rnd.position if rnd else Vector3.ZERO)
	if r._ejector:
		r._ejector_rest = r._ejector.position
	return r


## 一番上(銃身の後ろ)にある薬室の番号
func _top_chamber() -> int:
	return posmod(-_index, CHAMBERS)


## 弾の残りに合わせて、撃った薬室は弾頭を隠す(薬莢は残る)
func set_loaded(ammo: int) -> void:
	for i in CHAMBERS:
		var k := posmod(-(_index + i), CHAMBERS)
		if _bullets[k]:
			_bullets[k].visible = i < ammo
		if _rounds[k]:
			_rounds[k].visible = true
	if _hammer:
		_hammer.rotation.x = 0.0


func on_fire(rpm: float) -> void:
	var k := _top_chamber()
	if _bullets[k]:
		_bullets[k].visible = false
	_turn_from = _index * TAU / CHAMBERS
	_index += 1
	_fire_t = 0.0
	_cycle = clampf(60.0 / rpm * 0.85, 0.12, 0.3)


func start_reload(time: float) -> void:
	_reloading = true
	_reload_time = maxf(time, 0.5)
	_reload_t = 0.0
	_ejected = false
	_fire_t = 1.0


func finish_reload(ammo: int) -> void:
	_reloading = false
	_set_crane(0.0)
	set_loaded(ammo)
	for k in CHAMBERS:
		if _rounds[k]:
			_rounds[k].position = _round_rest[k]
	if _ejector:
		_ejector.position = _ejector_rest


## 毎フレーム。casing_parent は排莢した薬莢を置く場所、player_vel は持ち主の速度
func update(dt: float, casing_parent: Node, player_vel: Vector3, rng: RandomNumberGenerator) -> void:
	if _reloading:
		_reload_t = minf(1.0, _reload_t + dt / _reload_time)
		_update_reload(casing_parent, player_vel, rng)
		return
	_fire_t = minf(1.0, _fire_t + dt / _cycle)
	# 0〜0.12: 起きていた撃鉄が落ちる / 0.2〜1: 引き金が戻り、シリンダーが回る
	var fall := clampf(_fire_t / 0.12, 0.0, 1.0)
	var k := clampf((_fire_t - 0.2) / 0.8, 0.0, 1.0)
	var e := k * k * (3.0 - 2.0 * k)
	if _hammer:
		_hammer.rotation.x = HAMMER_COCKED * (1.0 - fall) * (1.0 - fall)
	if _trigger:
		_trigger.rotation.x = TRIGGER_PULL * (1.0 - e)
	_cylinder.rotation.z = lerpf(_turn_from, _index * TAU / CHAMBERS, e)


func _set_crane(a: float) -> void:
	if _crane:
		_crane.rotation.z = a


static func _ramp(t: float, a: float, b: float) -> float:
	var k := clampf((t - a) / (b - a), 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)


func _update_reload(casing_parent: Node, player_vel: Vector3, rng: RandomNumberGenerator) -> void:
	var t := _reload_t
	_cylinder.rotation.z = _index * TAU / CHAMBERS
	if _hammer:
		_hammer.rotation.x = 0.0   # 振り出す間は撃鉄を寝かせる
	# 振り出す(0.05〜0.15)、戻す(0.80〜0.90)
	_set_crane(CRANE_SWING * (_ramp(t, 0.05, 0.15) - _ramp(t, 0.80, 0.90)))
	# 押し棒で薬莢を押し出す(0.16〜0.24)、押し棒が戻る(0.28〜0.34)。そのあと空のシリンダーを少し見せる
	var push := EJECT_TRAVEL * 1.3 * (_ramp(t, 0.16, 0.24) - _ramp(t, 0.28, 0.34))
	if _ejector:
		_ejector.position = _ejector_rest + Vector3(0, 0, push)
	if not _ejected:
		for k in CHAMBERS:
			if _rounds[k]:
				_rounds[k].position = _round_rest[k] + Vector3(0, 0, push)
		if t >= 0.24:
			_ejected = true
			for k in CHAMBERS:
				var rnd := _rounds[k]
				if rnd == null or not rnd.visible:
					continue
				var full := _bullets[k] != null and _bullets[k].visible
				GunHolder.Casing.spawn_dropped(casing_parent, rnd.global_transform, player_vel, rng, full)
				rnd.visible = false
		return
	# 新しい弾を後ろから差し込む(0.48〜0.70)
	var load_k := _ramp(t, 0.48, 0.70)
	var show := t >= 0.44
	for k in CHAMBERS:
		if _rounds[k] == null:
			continue
		_rounds[k].visible = show
		if _bullets[k]:
			_bullets[k].visible = true
		_rounds[k].position = _round_rest[k] + Vector3(0, 0, LOAD_FROM * (1.0 - load_k))


## リロード中の銃の姿勢(回転, 位置のずれ)。排莢は銃口を上へ、装填は銃口を下へ向ける
func reload_pose() -> Array:
	var t := _reload_t
	var up := _ramp(t, 0.0, 0.12) * (1.0 - _ramp(t, 0.34, 0.44))
	var down := _ramp(t, 0.34, 0.44) * (1.0 - _ramp(t, 0.85, 1.0))
	var tilt := _ramp(t, 0.0, 0.12) * (1.0 - _ramp(t, 0.85, 1.0))
	var rot := Vector3(0.9 * up - 0.8 * down, 0.35 * tilt, -0.25 * tilt)
	var off := Vector3(-0.10, 0.07 * up + 0.05 * down, 0.05) * tilt
	return [rot, off]


func is_reloading() -> bool:
	return _reloading
