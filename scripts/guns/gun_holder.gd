class_name GunHolder
extends Node3D
## 手に持った銃(最大2丁)の発射・リロード・持ち替え・一人称の見た目。
## カメラの子に置く。腕は出さず、銃だけが浮いて反動で跳ねる表現。

signal gun_changed

const MAX_SLOTS := 2
const HIP_POS := Vector3(0.15, -0.21, -0.42)
## 腰だめの向き(ラジアン): 銃口を少し内側・上へ向け、ストックは右下の画面外へ逃がす
const HIP_ROT := Vector3(0.05, 0.07, 0.03)
const ADS_POS := Vector3(0.0, -0.13, -0.42)
const BASE_SWAP_TIME := 0.3

var slots: Array[GunInstance] = []
var current := 0
var aiming := false
var reloading := false
var reload_left := 0.0
var charge := 0.0
var swap_left := 0.0

var _cooldown := 0.0
var _semi_ready := true
var _view: Node3D
var _muzzle: Node3D
var _ads_pos := ADS_POS
## 構えたとき、照門と照星を結ぶ線が水平になるように銃を傾ける角度(ラジアン)
var _ads_pitch := 0.0
var _aim_t := 0.0
var _flash: OmniLight3D
var _kick := 0.0
## 可動部: モデルの "bolt"(ボルトとコッキングハンドル)を撃つたびに後ろへ動かす
var _bolt: Node3D
var _bolt_rest := Vector3.ZERO
var _bolt_t := 1.0
var _eject: Node3D
const BOLT_TRAVEL := 0.055
## リボルバーの撃鉄・シリンダー・振り出しリロード(モデルに "cylinder" がある銃だけ)
var _rig: RevolverRig
var _bm: BulletManager
var _player: Player
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_player = owner as Player
	_bm = get_tree().get_first_node_in_group("bullet_manager") as BulletManager
	_flash = OmniLight3D.new()
	_flash.light_color = Color(1.0, 0.7, 0.35)
	_flash.omni_range = 6.0
	_flash.light_energy = 0.0
	_flash.shadow_enabled = false
	add_child(_flash)
	# 銃だけを照らす弱い補助光(部屋の暗い所でも銃の形が見えるように)
	var fill := OmniLight3D.new()
	fill.light_color = Color(1.0, 0.97, 0.92)
	fill.light_energy = 0.5
	fill.omni_range = 1.2
	fill.position = Vector3(-0.15, 0.25, 0.1)
	fill.shadow_enabled = false
	get_parent().add_child.call_deferred(fill)
	position = HIP_POS


func gun() -> GunInstance:
	return slots[current] if current < slots.size() else null


## 銃を拾う。空き枠があればそこへ、無ければ今の銃と入れ替えて、捨てた銃を返す。
func give(g: GunInstance) -> GunInstance:
	var dropped: GunInstance = null
	if slots.size() < MAX_SLOTS:
		slots.append(g)
		current = slots.size() - 1
	else:
		dropped = slots[current]
		slots[current] = g
	_equip()
	return dropped


func switch_to(idx: int) -> void:
	if idx == current or idx < 0 or idx >= slots.size():
		return
	current = idx
	_equip()


func _equip() -> void:
	reloading = false
	charge = 0.0
	if _view:
		_view.queue_free()
	var g := gun()
	if g == null:
		return
	_view = GunVisual.build_instance(g)
	add_child(_view)
	_muzzle = GunVisual.find_muzzle(_view)
	_bolt = _view.find_child("bolt", true, false) as Node3D
	_bolt_rest = _bolt.position if _bolt else Vector3.ZERO
	_bolt_t = 1.0
	_eject = _view.find_child("ejection_port", true, false) as Node3D
	_rig = RevolverRig.attach(_view)
	if _rig:
		_rig.set_loaded(g.ammo)
	# モデルに照準点(ads_eye)があれば、構えたときに照準線が画面中央に来るよう位置を決める
	var eye := _view.find_child("ads_eye", true, false) as Node3D
	var post := _view.find_child("front_post_tip", true, false) as Node3D
	_ads_pitch = 0.0
	if eye:
		var inv := _view.global_transform.affine_inverse()
		var eye_l := (inv * eye.global_transform).origin
		if post:
			var d := (inv * post.global_transform).origin - eye_l
			_ads_pitch = -atan2(d.y, -d.z)
		_ads_pos = Vector3(0, 0, -g.type.ads_eye_dist) - Basis(Vector3.RIGHT, _ads_pitch) * eye_l
	else:
		_ads_pos = ADS_POS
	# 重い銃ほど持ち替えが遅い
	swap_left = BASE_SWAP_TIME / GunInstance.speed_multiplier(g.weight)
	if _player:
		_player.speed_mult = GunInstance.speed_multiplier(g.weight)
	gun_changed.emit()


func _process(dt: float) -> void:
	var g := gun()
	if g == null:
		return
	_cooldown -= dt
	swap_left = maxf(0.0, swap_left - dt)

	if Input.is_action_just_pressed("weapon_1"):
		switch_to(0)
	elif Input.is_action_just_pressed("weapon_2"):
		switch_to(1)
	elif Input.is_action_just_pressed("weapon_next") or Input.is_action_just_pressed("weapon_prev"):
		switch_to((current + 1) % slots.size())
	g = gun()

	aiming = Input.is_action_pressed("aim") and not reloading
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

	if reloading:
		reload_left -= dt
		if reload_left <= 0.0:
			reloading = false
			g.ammo = g.magazine
			if _rig:
				_rig.finish_reload(g.ammo)
	elif Input.is_action_just_pressed("reload") and g.ammo < g.magazine:
		_start_reload(g)

	var trigger := Input.is_action_pressed("fire") and captured
	if not trigger:
		_semi_ready = true

	if not reloading and swap_left <= 0.0:
		match g.type.fire_mode:
			GunType.FireMode.AUTO:
				while trigger and _cooldown <= 0.0 and g.ammo > 0:
					_fire(g)
					_cooldown += 60.0 / g.rpm
			GunType.FireMode.SEMI:
				if trigger and _semi_ready and _cooldown <= 0.0 and g.ammo > 0:
					_semi_ready = false
					_fire(g)
					_cooldown = 60.0 / g.rpm
			GunType.FireMode.CHARGE:
				if trigger and g.ammo > 0 and _cooldown <= 0.0:
					charge = minf(1.0, charge + dt / maxf(g.charge_time, 0.01))
				elif charge >= 1.0:
					_fire(g)
					_cooldown = 60.0 / g.rpm
					charge = 0.0
				else:
					charge = 0.0
		if g.ammo <= 0 and trigger and not reloading:
			_start_reload(g)
	_cooldown = maxf(_cooldown, -0.05)

	# 見た目: 構え位置、反動、持ち替えの下げ
	var target := _ads_pos if aiming else g.type.hip_pos
	target.y -= swap_left * 1.2
	var reload_rot := Vector3(0.6, 0, 0.5)
	if reloading and _rig:
		var pose := _rig.reload_pose()
		reload_rot = pose[0]
		target += pose[1]
	elif reloading:
		target.y -= 0.12
	position = position.lerp(target, clampf(dt * 16.0, 0, 1))
	_kick = lerpf(_kick, 0.0, clampf(dt * 14.0, 0, 1))
	if _view:
		_aim_t = move_toward(_aim_t, 1.0 if aiming else 0.0, dt * 8.0)
		# 構えている間は跳ねを小さくして、撃っている最中も照準器がずれすぎないように
		var kick := _kick * lerpf(1.0, 0.3, _aim_t)
		_view.position = Vector3(0, 0, kick * 0.08)
		rotation = HIP_ROT * (1.0 - _aim_t)
		_view.rotation = Vector3(kick * g.type.kick_flip + (reload_rot.x if reloading else 0.0) + _ads_pitch * _aim_t,
			reload_rot.y if reloading else 0.0, reload_rot.z if reloading else 0.0)
		_update_bolt(dt, g)
		if _rig:
			_rig.update(dt, get_tree().current_scene, _player.velocity if _player else Vector3.ZERO, _rng)
		if g.type.fire_mode == GunType.FireMode.CHARGE:
			_view.position.x = _rng.randf_range(-1, 1) * 0.004 * charge
	_flash.light_energy = maxf(0.0, _flash.light_energy - dt * 60.0)


func _start_reload(g: GunInstance) -> void:
	reloading = true
	reload_left = g.reload_time
	charge = 0.0
	if _rig:
		_rig.start_reload(g.reload_time)


func _fire(g: GunInstance) -> void:
	g.ammo -= 1
	var cam := get_viewport().get_camera_3d()
	var origin := cam.global_position
	var fwd := -cam.global_basis.z
	# 狙う点: 画面中央の先にある地形(敵も撃ちやすいよう、最大100m)
	var q := PhysicsRayQueryParameters3D.create(origin, origin + fwd * 100.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var aim_point: Vector3 = hit.position if not hit.is_empty() else origin + fwd * 100.0
	var muzzle := _muzzle.global_position if _muzzle else origin
	# 近すぎる壁を狙ったときに銃口の向きが暴れないように
	if muzzle.distance_to(aim_point) < 2.0:
		aim_point = origin + fwd * 2.0
	var base_dir := (aim_point - muzzle).normalized()
	var spread := deg_to_rad(g.spread_deg) * (0.4 if aiming else 1.0)
	var t := g.type

	if t.hitscan:
		var end := _bm.hitscan(origin, fwd, 200.0, g.damage, t.pierce)
		Beam.spawn(get_tree().current_scene, muzzle, end, t.bullet_color)
	else:
		for _p in g.pellets:
			var dir := _spread_dir(base_dir, spread)
			_bm.spawn(muzzle, dir * g.bullet_speed, BulletManager.Team.PLAYER, g.damage, t.bullet_life,
				t.bullet_size, t.bullet_color, maxf(t.bullet_size * 0.6, 0.12))

	_kick = minf(_kick + 0.4 + g.recoil * 0.15, 1.5)
	_bolt_t = 0.0
	if _rig:
		_rig.on_fire(g.rpm)
	if _eject:
		Casing.spawn(get_tree().current_scene, _eject.global_transform, _player.velocity if _player else Vector3.ZERO, _rng)
	_flash.global_position = muzzle
	_flash.light_energy = 3.0
	if _player:
		_player.add_recoil(g.recoil * (0.5 if aiming else 1.0))


## ボルトの往復: 1発の間隔より少し短い時間で、素早く下がってから戻る
func _update_bolt(dt: float, g: GunInstance) -> void:
	if _bolt == null:
		return
	var cycle := minf(60.0 / g.rpm * 0.9, 0.12)
	_bolt_t = minf(1.0, _bolt_t + dt / cycle)
	var k := _bolt_t / 0.35 if _bolt_t < 0.35 else 1.0 - (_bolt_t - 0.35) / 0.65
	_bolt.position = _bolt_rest + Vector3(0, 0, BOLT_TRAVEL * clampf(k, 0.0, 1.0))


func _spread_dir(dir: Vector3, spread: float) -> Vector3:
	if spread <= 0.0:
		return dir
	var side := dir.cross(Vector3.UP)
	if side.length_squared() < 0.001:
		side = Vector3.RIGHT
	side = side.normalized()
	var up := side.cross(dir).normalized()
	# 円の中に一様に散らす
	var a := _rng.randf() * TAU
	var r := sqrt(_rng.randf()) * tan(spread)
	return (dir + side * cos(a) * r + up * sin(a) * r).normalized()


## レールガンの軌跡(一瞬で消える光の線)
class Beam extends MeshInstance3D:
	var _t := 0.0

	static func spawn(parent: Node, from: Vector3, to: Vector3, color: Color, radius := 0.05) -> void:
		var b := Beam.new()
		var len := from.distance_to(to)
		var mesh := CylinderMesh.new()
		mesh.top_radius = radius
		mesh.bottom_radius = radius
		mesh.height = len
		mesh.radial_segments = 6
		mesh.rings = 1
		b.mesh = mesh
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_color = Color(color.r * 4.0, color.g * 4.0, color.b * 4.0, 1.0)
		b.material_override = m
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(b)
		var mid := (from + to) * 0.5
		var dir := (to - from).normalized()
		var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
		b.global_transform = Transform3D(Basis.looking_at(dir, up), mid)
		b.rotate_object_local(Vector3.RIGHT, PI * 0.5)

	func _process(dt: float) -> void:
		_t += dt
		var k := 1.0 - _t / 0.35
		if k <= 0.0:
			queue_free()
			return
		scale = Vector3(k, 1, k)


## 飛び出す薬莢(真鍮の小さな筒)。排莢口から右上へ回転しながら飛び、少しして消える
class Casing extends MeshInstance3D:
	const MAX := 48
	static var _mesh: CylinderMesh
	static var _live: Array[Casing] = []
	var vel := Vector3.ZERO
	var spin := Vector3.ZERO
	var life := 1.2

	static func spawn(parent: Node, at: Transform3D, base_vel: Vector3, rng: RandomNumberGenerator) -> void:
		var b := at.basis.orthonormalized()
		# 銃の右(+X)・少し上・少し後ろへ。筒の向きは銃の左右
		var vel := base_vel + b.x * rng.randf_range(2.2, 3.0) + b.y * rng.randf_range(1.0, 1.8) + b.z * rng.randf_range(0.2, 0.7)
		_make(parent, Transform3D(b * Basis(Vector3.FORWARD, PI * 0.5), at.origin), vel, rng)

	## リボルバーの排莢: 振り出したシリンダーから、押し出された薬莢が後ろ下へこぼれ落ちる。
	## at は薬莢(round_k)の位置と向き。full は撃っていない弾(今は見た目を分けない)
	static func spawn_dropped(parent: Node, at: Transform3D, base_vel: Vector3, rng: RandomNumberGenerator, _full := false) -> void:
		var b := at.basis.orthonormalized()
		var vel := base_vel + b.z * rng.randf_range(0.4, 0.9) + Vector3(rng.randf_range(-0.3, 0.3), -rng.randf_range(0.3, 0.8), 0)
		# 薬莢の後端(round_k の原点)から前へ半分ずらした所が中心。筒の向きは銃の前後
		var center := at.origin - b.z * 0.016
		_make(parent, Transform3D(b * Basis(Vector3.RIGHT, PI * 0.5), center), vel, rng)

	static func _make(parent: Node, xf: Transform3D, vel: Vector3, rng: RandomNumberGenerator) -> void:
		if _mesh == null:
			_mesh = CylinderMesh.new()
			_mesh.top_radius = 0.0034
			_mesh.bottom_radius = 0.0046
			_mesh.height = 0.032
			_mesh.radial_segments = 8
			_mesh.rings = 1
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.85, 0.62, 0.25)
			m.metallic = 0.85
			m.roughness = 0.3
			_mesh.material = m
		while _live.size() >= MAX:
			var old: Casing = _live.pop_front()
			if is_instance_valid(old):
				old.queue_free()
		var c := Casing.new()
		c.mesh = _mesh
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(c)
		c.global_transform = xf
		c.vel = vel
		c.spin = Vector3(rng.randf_range(-20, 20), rng.randf_range(-30, 30), rng.randf_range(-20, 20))
		_live.append(c)

	func _process(dt: float) -> void:
		life -= dt
		if life <= 0.0:
			_live.erase(self)
			queue_free()
			return
		vel.y -= 9.8 * dt
		global_position += vel * dt
		rotate_object_local(Vector3.RIGHT, spin.x * dt)
		rotate_object_local(Vector3.UP, spin.y * dt)
