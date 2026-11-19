extends Node3D
## 試射場(M1 のメインシーン)。
## 部屋、プレイヤー、敵、落ちている銃を用意する。敵を倒すと一定確率で銃が丸ごと落ちる。
##   F3 … 弾幕ショー(重装の敵を増やして画面を弾で埋める。負荷の体感用)
##   F4 … 足元にランダムな銃を1丁落とす

const GUN_DIR := "res://data/guns/"
const SHOOTERS := 6
const HEAVIES := 2
const DROP_CHANCE := 0.45

var gun_types: Array[GunType] = []
var storm := false

var _bm: BulletManager
var _player: Player
var _rng := RandomNumberGenerator.new()
var _storm_enemies: Array[Enemy] = []


func _ready() -> void:
	_rng.randomize()
	_load_gun_types()
	RoomBuilder.build(self)

	_bm = BulletManager.new()
	add_child(_bm)

	_player = preload("res://scenes/player.tscn").instantiate()
	_player.position = Vector3(0, 0.1, 22)
	add_child(_player)
	_player.add_to_group("player")
	# 初期装備: 拳銃(開発用に `-- --start-gun=ak47` で変えられる)
	var start_id := "m1911"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--start-gun="):
			start_id = a.trim_prefix("--start-gun=")
	if GunViewer.carry_gun:
		# 観察台から戻ったときは、見ていた銃をそのまま持つ
		_player.holder.give(GunViewer.carry_gun)
		GunViewer.carry_gun = null
	else:
		_player.holder.give(GunInstance.roll(_find_type(start_id), _rng.randi()))

	var hud := preload("res://scripts/ui/hud.gd").new()
	hud.setup(_player, _bm, self)
	add_child(hud)

	for k in SHOOTERS:
		_spawn_enemy(Enemy.Kind.SHOOTER)
	for k in HEAVIES:
		_spawn_enemy(Enemy.Kind.HEAVY)

	# 6種を1丁ずつ床に並べる
	var x := -12.5
	for t in gun_types:
		add_child(GunPickup.create(GunInstance.roll(t, _rng.randi()), Vector3(x, 0, 18)))
		x += 5.0


func _load_gun_types() -> void:
	for f in DirAccess.get_files_at(GUN_DIR):
		# 書き出し後は .tres.remap になるので両方を見る
		var path := GUN_DIR + f.trim_suffix(".remap")
		if path.ends_with(".tres"):
			var t := load(path) as GunType
			if t:
				gun_types.append(t)


func _find_type(id: String) -> GunType:
	for t in gun_types:
		if t.id == id:
			return t
	return gun_types[0]


func _spawn_enemy(kind: Enemy.Kind, fury := 1.0) -> Enemy:
	var pos := Vector3(_rng.randf_range(-24, 24), _rng.randf_range(2.0, 5.0), _rng.randf_range(-26, 6))
	var e := Enemy.new().setup(kind, pos, fury)
	e.killed.connect(_on_enemy_killed)
	add_child(e)
	return e


func _on_enemy_killed(e: Enemy) -> void:
	if _rng.randf() < DROP_CHANCE:
		var t := gun_types[_rng.randi() % gun_types.size()]
		var p := e.global_position
		p.y = 0.0
		call_deferred("add_child", GunPickup.create(GunInstance.roll(t, _rng.randi()), p))
	if e in _storm_enemies:
		_storm_enemies.erase(e)
		return
	# 少し待って同じ種類を補充する
	var kind := e.kind
	get_tree().create_timer(3.0).timeout.connect(func(): _spawn_enemy(kind))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("bullet_storm"):
		storm = not storm
		if storm:
			for k in 8:
				_storm_enemies.append(_spawn_enemy(Enemy.Kind.HEAVY, 3.0))
		else:
			for e in _storm_enemies:
				if is_instance_valid(e):
					e.queue_free()
			_storm_enemies.clear()
	elif event.is_action_pressed("gun_viewer"):
		# 持っている銃を観察台で見る
		var g := _player.holder.gun()
		GunViewer.start_gun_id = g.type.id if g else ""
		GunViewer.carry_gun = g
		get_tree().change_scene_to_file.call_deferred("res://scenes/gun_viewer.tscn")
	elif event.is_action_pressed("spawn_gun"):
		var t := gun_types[_rng.randi() % gun_types.size()]
		var p := _player.global_position - _player.global_basis.z * 2.0
		p.y = _player.global_position.y
		add_child(GunPickup.create(GunInstance.roll(t, _rng.randi()), p))


func _physics_process(_dt: float) -> void:
	# E で正面の銃を拾う
	if Input.is_action_just_pressed("interact"):
		var p := looked_pickup()
		if p:
			var dropped := _player.holder.give(p.gun)
			var pos := p.global_position
			p.queue_free()
			if dropped:
				add_child(GunPickup.create(dropped, pos))


## 視線の先 4m 以内にある銃。無ければ近くの銃(足元に落ちたものを拾いやすく)
func looked_pickup() -> GunPickup:
	var cam := _player.camera
	var from := cam.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from - cam.global_basis.z * 4.0, 8 | 1)
	q.collide_with_areas = true
	q.collide_with_bodies = true
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty() and hit.collider is GunPickup:
		return hit.collider
	var best: GunPickup = null
	var best_d := 1.6
	for n in get_tree().get_nodes_in_group("pickups"):
		var d := (n as Node3D).global_position.distance_to(_player.global_position)
		if d < best_d:
			best_d = d
			best = n
	return best
