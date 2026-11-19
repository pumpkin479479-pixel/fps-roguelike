extends Node3D
## 弾幕の負荷テスト。
##
## 弾の数を段階的に増やし、各段階でフレーム時間を記録する。敵150体(判定用のダミー)も同時に動かす。
## 結果は user://bench/ に CSV で保存し、コンソールにも表を出す。
##
## 実行例(Windows):
##   Godot_v4.7.2-stable_win64_console.exe --path F:\GameDev\fps-roguelike res://scenes/bench.tscn
## 引数(-- の後ろ):
##   --steps=1000,3000,5000   試す弾数
##   --hold=5                 1段階あたりの計測秒数
##   --enemies=150            ダミー敵の数
##   --quit                   終わったら自動で閉じる

const TARGET_MS := 1000.0 / 60.0

var steps: Array[int] = [500, 1000, 2000, 3000, 5000, 7500, 10000]
var hold_sec := 5.0
var warmup_sec := 1.5
var enemy_count := 150
var auto_quit := false

var _bm: BulletManager
var _cam: Camera3D
var _label: Label
var _step_idx := -1
var _t := 0.0
var _samples := PackedFloat32Array()
var _upd := PackedFloat32Array()
var _rays := PackedFloat32Array()
var _results: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _dummies: Array[Node3D] = []
var _emit_points: Array[Vector3] = []


func _ready() -> void:
	_parse_args()
	_rng.seed = 12345
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0

	RoomBuilder.build(self)
	_bm = BulletManager.new()
	_bm.capacity = maxi(20000, steps.max() + 2000)
	add_child(_bm)

	_cam = Camera3D.new()
	_cam.position = Vector3(0, 6, 28)
	_cam.fov = 80
	add_child(_cam)
	_cam.look_at(Vector3(0, 3, 0))

	for k in enemy_count:
		var d := BenchDummy.new()
		d.position = Vector3(_rng.randf_range(-28, 28), _rng.randf_range(1, 6), _rng.randf_range(-28, 28))
		d.seed_offset = k
		add_child(d)
		_dummies.append(d)
	for k in 24:
		var a := TAU * k / 24.0
		_emit_points.append(Vector3(cos(a) * 12, 3 + (k % 3) * 2.0, sin(a) * 12))

	var layer := CanvasLayer.new()
	_label = Label.new()
	_label.position = Vector2(16, 16)
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	layer.add_child(_label)
	add_child(layer)

	print("[bench] Godot %s / %s / %s" % [Engine.get_version_info().string,
		RenderingServer.get_video_adapter_name(), OS.get_processor_name()])
	_next_step()


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--steps="):
			steps.clear()
			for s in a.trim_prefix("--steps=").split(","):
				steps.append(int(s))
		elif a.begins_with("--hold="):
			hold_sec = float(a.trim_prefix("--hold="))
		elif a.begins_with("--enemies="):
			enemy_count = int(a.trim_prefix("--enemies="))
		elif a == "--quit":
			auto_quit = true


func _next_step() -> void:
	_step_idx += 1
	_t = 0.0
	_samples.clear()
	_upd.clear()
	_rays.clear()
	if _step_idx >= steps.size():
		_finish()


func _process(delta: float) -> void:
	if _step_idx >= steps.size():
		return
	var target := steps[_step_idx]
	_fill_bullets(target)
	_cam.position = Vector3(sin(Time.get_ticks_msec() * 0.0002) * 20, 6, cos(Time.get_ticks_msec() * 0.0002) * 20)
	_cam.look_at(Vector3(0, 3, 0))

	_t += delta
	if _t > warmup_sec:
		_samples.append(delta * 1000.0)
		_upd.append(_bm.last_update_usec / 1000.0)
		_rays.append(_bm.last_ray_count)
	if _t > warmup_sec + hold_sec:
		_record(target)
		_next_step()

	_label.text = "弾幕負荷テスト  目標 %d 発 / 現在 %d 発\nFPS %d   フレーム %.2f ms   弾の更新 %.2f ms\n%s" % [
		target, _bm.count, Engine.get_frames_per_second(), delta * 1000.0,
		_bm.last_update_usec / 1000.0, _summary_text()]


## 弾数が目標に届くまで、発射点から弾を補充する。3割は自分の弾(敵に当たる)、7割は敵の弾。
func _fill_bullets(target: int) -> void:
	var need := target - _bm.count
	var budget := mini(need, maxi(200, target / 10))
	for _k in budget:
		var p: Vector3 = _emit_points[_rng.randi() % _emit_points.size()]
		var dir := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.25, 0.35), _rng.randf_range(-1, 1)).normalized()
		var player := _rng.randf() < 0.3
		var speed := _rng.randf_range(8.0, 22.0)
		var col := Color(1.0, 0.75, 0.3) if player else Color.from_hsv(_rng.randf(), 0.8, 1.0)
		_bm.spawn(p, dir * speed, BulletManager.Team.PLAYER if player else BulletManager.Team.ENEMY,
			1.0, _rng.randf_range(2.0, 5.0), 0.35 if player else 0.6, col)


func _record(target: int) -> void:
	var sorted := _samples.duplicate()
	sorted.sort()
	var n := sorted.size()
	if n == 0:
		return
	var avg := 0.0
	for s in sorted:
		avg += s
	avg /= n
	var upd := 0.0
	for s in _upd:
		upd += s
	upd /= _upd.size()
	var rays := 0.0
	for s in _rays:
		rays += s
	rays /= _rays.size()
	var r := {
		"bullets": target,
		"avg_ms": avg,
		"p95_ms": sorted[int(n * 0.95)],
		"p99_ms": sorted[mini(n - 1, int(n * 0.99))],
		"fps": 1000.0 / avg,
		"bullet_update_ms": upd,
		"rays_per_frame": rays,
		"ok": avg <= TARGET_MS and sorted[int(n * 0.95)] <= TARGET_MS * 1.25,
	}
	_results.append(r)
	print("[bench] %6d 発  平均 %6.2f ms (%5.0f fps)  p95 %6.2f ms  弾の更新 %6.2f ms  地形判定 %5.0f 回/フレーム  %s" % [
		r.bullets, r.avg_ms, r.fps, r.p95_ms, r.bullet_update_ms, r.rays_per_frame, "OK" if r.ok else "NG"])


func _summary_text() -> String:
	var s := ""
	for r in _results:
		s += "\n%6d 発: %.2f ms (%d fps)  弾の更新 %.2f ms  %s" % [
			r.bullets, r.avg_ms, int(r.fps), r.bullet_update_ms, "OK" if r.ok else "NG"]
	return s


func _finish() -> void:
	DirAccess.make_dir_recursive_absolute("user://bench")
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var path := "user://bench/bullet_bench_%s.csv" % stamp
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_line("# Godot %s / GPU %s / CPU %s / enemies %d" % [Engine.get_version_info().string,
			RenderingServer.get_video_adapter_name(), OS.get_processor_name(), enemy_count])
		f.store_line("bullets,avg_ms,p95_ms,p99_ms,fps,bullet_update_ms,rays_per_frame,ok")
		for r in _results:
			f.store_line("%d,%.3f,%.3f,%.3f,%.1f,%.3f,%.0f,%s" % [r.bullets, r.avg_ms, r.p95_ms, r.p99_ms,
				r.fps, r.bullet_update_ms, r.rays_per_frame, r.ok])
		f.close()
	print("[bench] 保存先: %s" % ProjectSettings.globalize_path(path))
	if auto_quit:
		get_tree().quit()


## 負荷テスト用の動く的。弾が当たっても死なない。
class BenchDummy extends Node3D:
	var hit_radius := 0.8
	var dead := false
	var seed_offset := 0
	var _base: Vector3

	func _ready() -> void:
		add_to_group("enemies")
		_base = position
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(1.6, 1.6)
		mi.mesh = q
		var m := StandardMaterial3D.new()
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.albedo_color = Color(0.8, 0.2, 0.3)
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = m
		add_child(mi)

	func _process(_dt: float) -> void:
		var t := Time.get_ticks_msec() * 0.001 + seed_offset
		position = _base + Vector3(sin(t * 0.7) * 3.0, sin(t * 1.3) * 0.5, cos(t * 0.9) * 3.0)

	func take_damage(_amount: float) -> void:
		pass
