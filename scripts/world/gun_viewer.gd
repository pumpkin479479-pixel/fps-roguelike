class_name GunViewer
extends Node3D
## 銃の観察台: 手に持たない状態の銃を台の上に置き、まわりをぐるぐる回って見ながら、撃つ・リロードを試す。
## 銃口は射撃場の的の方を向いていて、撃った弾は的に当たる。
##
## 操作: 左ドラッグ 回る / ホイール 近づく・離れる / 右ドラッグ 注目点を上下
##       F 撃つ(押しっぱなしで連射) / R リロード / Tab・Shift+Tab 銃を切り替え
##       Space 自動回転 / L 撃つ→リロードを自動でくり返す / T スロー(1/4) / H 構えたときの傾きも見せる
##       1〜4 視点(右・左・上・後ろ) / Esc 試射場へ戻る
##
## 起動(開発用):
##   godot --path . res://scenes/gun_viewer.tscn -- --gun=revolver357 [--spin=30] [--auto] [--slow=0.25]
##   撮影: --shots=DIR [--angles=0,90,180,270] [--times=0.5,1.2,2.0]
##     --angles: 撃たずに、その角度(度。0 = 銃の右側)から順に撮る → DIR/angle_<角度>.png
##     --times : 起動からの秒数ごとに撮る(--auto と合わせると動きの途中を撮れる)→ DIR/time_<秒>.png
##   どちらも撮り終えたら終了する。--screenshot=out.png(1枚だけ)も使える。

## 試射場から開くとき、持っていた銃の id をここに入れておく
static var start_gun_id := ""

const GUN_HEIGHT := 1.3
const SLOW := 0.25

var _types: Array[GunType] = []
var _type_idx := 0
var _gun: GunInstance
var _mount: Node3D      # 反動で動く台(銃の親)
var _view: Node3D
var _muzzle: Node3D
var _eject: Node3D
var _bolt: Node3D
var _bolt_rest := Vector3.ZERO
var _bolt_t := 1.0
var _rig: RevolverRig
var _flash: OmniLight3D
var _rng := RandomNumberGenerator.new()

var _cam: Camera3D
var _yaw := 0.0         # 0 = 銃の右側から見る
var _pitch := 0.25
var _dist := 0.75
var _focus_y := 0.0
var _drag_l := false
var _drag_r := false
var _spin := 0.0        # 自動回転(度/秒)

var _cooldown := 0.0
var _kick := 0.0
var _reloading := false
var _reload_left := 0.0
var _auto := false
var _auto_wait := 0.0
var _slow := false
var _show_pose := false
var _label: Label
var _scripted := false


func _ready() -> void:
	_rng.seed = 7
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	RoomBuilder.build(self, false)
	_load_types()
	_build_range()

	# 銃を置く台
	var stand := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.12
	sm.bottom_radius = 0.18
	sm.height = GUN_HEIGHT - 0.5
	stand.mesh = sm
	stand.position = Vector3(0, sm.height * 0.5, 0)
	var stand_mat := StandardMaterial3D.new()
	stand_mat.albedo_color = Color(0.22, 0.23, 0.26)
	stand.material_override = stand_mat
	add_child(stand)

	_mount = Node3D.new()
	_mount.position = Vector3(0, GUN_HEIGHT, 0)
	add_child(_mount)
	_flash = OmniLight3D.new()
	_flash.light_color = Color(1.0, 0.7, 0.35)
	_flash.omni_range = 5.0
	_flash.light_energy = 0.0
	add_child(_flash)
	# 銃のまわりを明るくする補助光
	for p: Vector3 in [Vector3(0.6, 0.8, 0.6), Vector3(-0.6, 0.5, -0.4)]:
		var fill := OmniLight3D.new()
		fill.light_energy = 0.6
		fill.omni_range = 2.5
		fill.position = Vector3(0, GUN_HEIGHT, 0) + p
		add_child(fill)

	_cam = Camera3D.new()
	_cam.fov = 45
	_cam.near = 0.01
	add_child(_cam)
	_make_ui()

	var id := start_gun_id
	var shots := ""
	var angles: Array[float] = []
	var times: Array[float] = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--gun="):
			id = a.trim_prefix("--gun=")
		elif a.begins_with("--spin="):
			_spin = float(a.trim_prefix("--spin="))
		elif a == "--auto":
			_auto = true
		elif a.begins_with("--slow="):
			Engine.time_scale = float(a.trim_prefix("--slow="))
			_slow = Engine.time_scale < 1.0
		elif a.begins_with("--shots="):
			shots = a.trim_prefix("--shots=")
		elif a.begins_with("--angles="):
			for s in a.trim_prefix("--angles=").split(","):
				angles.append(float(s))
		elif a.begins_with("--times="):
			for s in a.trim_prefix("--times=").split(","):
				times.append(float(s))
	for i in _types.size():
		if _types[i].id == id:
			_type_idx = i
	_equip()
	_update_cam()
	if shots != "":
		_scripted = true
		_run_shots(shots, angles, times)


func _load_types() -> void:
	for f in DirAccess.get_files_at("res://data/guns/"):
		var path := "res://data/guns/" + f.trim_suffix(".remap")
		if path.ends_with(".tres"):
			var t := load(path) as GunType
			if t:
				_types.append(t)


## 的: 10m / 20m / 30m に、銃の正面(-Z)へ並べる
func _build_range() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.85, 0.82)
	var ring := StandardMaterial3D.new()
	ring.albedo_color = Color(0.85, 0.15, 0.12)
	for d: float in [10.0, 20.0, 30.0]:
		for x: float in [-2.0, 0.0, 2.0]:
			var body := StaticBody3D.new()
			body.collision_layer = 1
			body.position = Vector3(x * d / 10.0, GUN_HEIGHT, -d)
			var col := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(1.0, 1.0, 0.1)
			col.shape = shape
			body.add_child(col)
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = shape.size
			mi.mesh = bm
			mi.material_override = mat
			body.add_child(mi)
			var dot := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.15
			cm.bottom_radius = 0.15
			cm.height = 0.02
			dot.mesh = cm
			dot.material_override = ring
			dot.rotation_degrees = Vector3(90, 0, 0)
			dot.position = Vector3(0, 0, 0.06)
			body.add_child(dot)
			# 的の足
			var leg := MeshInstance3D.new()
			var lm := BoxMesh.new()
			lm.size = Vector3(0.08, GUN_HEIGHT - 0.5, 0.08)
			leg.mesh = lm
			leg.position = Vector3(0, -0.5 - lm.size.y * 0.5, 0)
			body.add_child(leg)
			add_child(body)


func _make_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(16, 12)
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	layer.add_child(_label)


func _equip() -> void:
	if _view:
		_view.queue_free()
	var t := _types[_type_idx]
	_gun = GunInstance.roll(t, 7)
	_view = GunVisual.build_instance(_gun)
	_mount.add_child(_view)
	# 銃の真ん中あたりを見る(モデルの原点はグリップ)
	var aabb := _aabb(_view)
	_view.position = Vector3(0, 0, 0)
	_focus_y = aabb.get_center().y
	_dist = clampf(aabb.size.length() * 1.15, 0.35, 2.0)
	_muzzle = GunVisual.find_muzzle(_view)
	_eject = _view.find_child("ejection_port", true, false) as Node3D
	_bolt = _view.find_child("bolt", true, false) as Node3D
	_bolt_rest = _bolt.position if _bolt else Vector3.ZERO
	_bolt_t = 1.0
	_rig = RevolverRig.attach(_view)
	if _rig:
		_rig.set_loaded(_gun.ammo)
	_reloading = false
	_cooldown = 0.0
	_update_cam()


static func _aabb(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var xf := root.global_transform.affine_inverse() * m.global_transform
		var b := xf * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _update_cam() -> void:
	var focus := Vector3(0, GUN_HEIGHT + _focus_y, 0)
	# yaw 0 = 右側(+X)から見る
	var dir := Vector3(cos(_pitch) * cos(_yaw), sin(_pitch), cos(_pitch) * sin(_yaw))
	_cam.position = focus + dir * _dist
	_cam.look_at(focus, Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				_drag_l = mb.pressed
			MOUSE_BUTTON_RIGHT:
				_drag_r = mb.pressed
			MOUSE_BUTTON_WHEEL_UP:
				_dist = maxf(0.2, _dist * 0.9)
			MOUSE_BUTTON_WHEEL_DOWN:
				_dist = minf(6.0, _dist / 0.9)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _drag_l:
			_yaw += mm.relative.x * 0.008
			_pitch = clampf(_pitch + mm.relative.y * 0.008, -1.4, 1.4)
		elif _drag_r:
			_focus_y += mm.relative.y * 0.0015 * _dist
	elif event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		match k.physical_keycode:
			KEY_R:
				_start_reload()
			KEY_TAB:
				_type_idx = posmod(_type_idx + (-1 if k.shift_pressed else 1), _types.size())
				_equip()
			KEY_SPACE:
				_spin = 0.0 if _spin != 0.0 else 30.0
			KEY_L:
				_auto = not _auto
			KEY_T:
				_slow = not _slow
				Engine.time_scale = SLOW if _slow else 1.0
			KEY_H:
				_show_pose = not _show_pose
			KEY_1:
				_set_view(0.0, 0.1)
			KEY_2:
				_set_view(PI, 0.1)
			KEY_3:
				_set_view(0.0, 1.35)
			KEY_4:
				_set_view(PI * 0.5, 0.2)
			KEY_ESCAPE:
				Engine.time_scale = 1.0
				get_tree().change_scene_to_file("res://scenes/test_range.tscn")


func _set_view(yaw: float, pitch: float) -> void:
	_yaw = yaw
	_pitch = pitch


func _process(dt: float) -> void:
	# スローでも操作の速さは変えない(回転・カメラは実時間)
	var real_dt := dt / maxf(Engine.time_scale, 0.01)
	_yaw += deg_to_rad(_spin) * real_dt
	_update_cam()
	_cooldown -= dt

	if _reloading:
		_reload_left -= dt
		if _reload_left <= 0.0:
			_reloading = false
			_gun.ammo = _gun.magazine
			if _rig:
				_rig.finish_reload(_gun.ammo)
			_auto_wait = 0.5
	elif not _scripted or _auto:
		var want := Input.is_physical_key_pressed(KEY_F) and not _scripted
		var auto_t := _types[_type_idx].fire_mode == GunType.FireMode.AUTO
		if _auto:
			_auto_wait -= dt
			want = _auto_wait <= 0.0
		if want and _cooldown <= 0.0:
			if _gun.ammo > 0:
				_fire()
				_cooldown = 60.0 / _gun.rpm
				if _auto and not auto_t:
					_auto_wait = maxf(60.0 / _gun.rpm, 0.35)
				if not auto_t and not _auto:
					_cooldown = maxf(_cooldown, 0.18)
			else:
				_start_reload()

	# 反動: 台ごと少し後ろへ下がり、銃口が跳ね上がる
	_kick = lerpf(_kick, 0.0, clampf(dt * 12.0, 0, 1))
	var pose_rot := Vector3.ZERO
	var pose_off := Vector3.ZERO
	if _show_pose and _rig and _reloading:
		var pose := _rig.reload_pose()
		pose_rot = pose[0]
		pose_off = pose[1]
	_view.position = Vector3(0, 0, _kick * 0.04) + pose_off
	_view.rotation = Vector3(_kick * 0.35, 0, 0) + pose_rot
	_update_bolt(dt)
	if _rig:
		_rig.update(dt, self, Vector3.ZERO, _rng)
	_flash.light_energy = maxf(0.0, _flash.light_energy - dt * 60.0)
	_update_label()


func _fire() -> void:
	_gun.ammo -= 1
	var t := _gun.type
	var from := _muzzle.global_position
	var fwd := -_mount.global_basis.z  # 反動で跳ねる前の向き(的の方)
	var q := PhysicsRayQueryParameters3D.create(from, from + fwd * 60.0)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var end: Vector3 = hit.position if not hit.is_empty() else from + fwd * 60.0
	GunHolder.Beam.spawn(self, from, end, t.bullet_color, 0.004)
	_kick = minf(_kick + 0.35 + _gun.recoil * 0.12, 1.2)
	_bolt_t = 0.0
	if _rig:
		_rig.on_fire(_gun.rpm)
	if _eject:
		GunHolder.Casing.spawn(self, _eject.global_transform, Vector3.ZERO, _rng)
	_flash.global_position = from
	_flash.light_energy = 3.0


func _start_reload() -> void:
	if _reloading or _gun.ammo >= _gun.magazine:
		return
	_reloading = true
	_reload_left = _gun.reload_time
	if _rig:
		_rig.start_reload(_gun.reload_time)


func _update_bolt(dt: float) -> void:
	if _bolt == null:
		return
	var cycle := minf(60.0 / _gun.rpm * 0.9, 0.12)
	_bolt_t = minf(1.0, _bolt_t + dt / cycle)
	var k := _bolt_t / 0.35 if _bolt_t < 0.35 else 1.0 - (_bolt_t - 0.35) / 0.65
	_bolt.position = _bolt_rest + Vector3(0, 0, GunHolder.BOLT_TRAVEL * clampf(k, 0.0, 1.0))


func _update_label() -> void:
	var t := _gun.type
	var state := "リロード中" if _reloading else "弾 %d / %d" % [_gun.ammo, _gun.magazine]
	_label.text = "%s  (%d/%d)   %s%s%s\n" % [t.display_name, _type_idx + 1, _types.size(), state,
		"   [スロー]" if _slow else "", "   [自動]" if _auto else ""] \
		+ "左ドラッグ 回る / ホイール 距離 / 右ドラッグ 上下\n" \
		+ "F 撃つ / R リロード / Tab 銃の切り替え / Space 自動回転 / L 撃つ→リロードをくり返す\n" \
		+ "T スロー / H リロード時の傾きも見せる / 1〜4 右・左・上・後ろ / Esc 試射場へ"


func _run_shots(dir: String, angles: Array[float], times: Array[float]) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	_label.visible = false
	var start := Time.get_ticks_msec()
	await _wait_real(0.5)
	for a in angles:
		_yaw = deg_to_rad(a)
		_update_cam()
		await _wait_real(0.2)
		await _save("%s/angle_%03d.png" % [dir, int(a)])
	for s in times:
		while (Time.get_ticks_msec() - start) / 1000.0 < s:
			await get_tree().process_frame
		await _save("%s/time_%05.2f.png" % [dir, s])
	get_tree().quit()


func _wait_real(sec: float) -> void:
	var end := Time.get_ticks_msec() + int(sec * 1000.0)
	while Time.get_ticks_msec() < end:
		await get_tree().process_frame


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("[viewer] ", path)
