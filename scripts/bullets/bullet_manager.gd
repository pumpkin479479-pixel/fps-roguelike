class_name BulletManager
extends Node3D
## 弾をまとめて動かす管理プログラム。
##
## 弾1発ごとにノードを作らず、数値の配列として持つ。描画は MultiMesh 1つ(描画命令1回)。
## 位置は MultiMesh のバッファ(1発あたり STRIDE 個の float)の中に直接持ち、
## 毎フレームそのバッファを RenderingServer に丸ごと渡す。
##
## 当たり判定:
##   対敵   … 物理エンジンを使わず、マス目の表(グリッド)で近くの敵とだけ距離を比べる
##   対自分 … 敵の弾だけ、登録されたプレイヤーとの距離を比べる
##   対地形 … 物理エンジンに線分で問い合わせる。terrain_check_interval フレームに1回に間引く
##
## GDScript で 5,000 発に届かない場合は、このファイルだけを C# / C++ に差し替える前提で、
## 外から使う関数は spawn() / register_target() / count だけにしてある。

enum Team { PLAYER = 0, ENEMY = 1 }

## MultiMesh のバッファ1発分: 変換行列12 + 色4 + カスタム4(x=大きさ)
const STRIDE := 20

@export var capacity := 20000
## 地形との判定を何フレームに1回にするか(1 = 毎フレーム)
@export var terrain_check_interval := 2
@export var terrain_mask := 1
## この範囲から出た弾は消す
@export var bounds_min := Vector3(-80, -10, -80)
@export var bounds_max := Vector3(80, 60, 80)
## 対敵グリッドのマス目の大きさ(m)
@export var grid_cell := 4.0
## 発光の強さ(グロー用に1より大きくする)
@export var glow_intensity := 2.5

var count := 0
## 計測用: 直近フレームの更新にかかった時間(マイクロ秒)
var last_update_usec := 0
var last_ray_count := 0

var _buf := PackedFloat32Array()
var _vel := PackedVector3Array()
var _life := PackedFloat32Array()
var _dmg := PackedFloat32Array()
var _rad := PackedFloat32Array()
var _team := PackedByteArray()
var _pierce := PackedByteArray()

var _mm: MultiMesh
var _mmi: MultiMeshInstance3D
var _ray := PhysicsRayQueryParameters3D.new()
var _frame := 0

# --- 敵(当たり判定の相手) ---
var _enemies: Array[Node3D] = []
var _e_pos := PackedVector3Array()
var _e_rad := PackedFloat32Array()
var _e_dmg := PackedFloat32Array()
var _grid_head := PackedInt32Array()
var _grid_next := PackedInt32Array()
var _grid_w := 0
var _grid_d := 0

# --- プレイヤー(敵弾の当たり判定の相手) ---
var _targets: Array[Node3D] = []


func _ready() -> void:
	add_to_group("bullet_manager")
	_buf.resize(capacity * STRIDE)
	_vel.resize(capacity)
	_life.resize(capacity)
	_dmg.resize(capacity)
	_rad.resize(capacity)
	_team.resize(capacity)
	_pierce.resize(capacity)

	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_mm.mesh = quad
	_mm.instance_count = capacity
	_mm.visible_instance_count = 0
	_mm.custom_aabb = AABB(bounds_min, bounds_max - bounds_min)

	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/bullet.gdshader")
	_mmi = MultiMeshInstance3D.new()
	_mmi.multimesh = _mm
	_mmi.material_override = mat
	_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mmi.custom_aabb = _mm.custom_aabb
	add_child(_mmi)

	_ray.collision_mask = terrain_mask
	_ray.hit_from_inside = false
	_grid_w = int(ceil((bounds_max.x - bounds_min.x) / grid_cell))
	_grid_d = int(ceil((bounds_max.z - bounds_min.z) / grid_cell))
	_grid_head.resize(_grid_w * _grid_d)


## 弾を1発出す。満杯なら false。
## size は見た目の直径(m)、radius は当たり判定の半径(m)。
func spawn(pos: Vector3, vel: Vector3, team: int, damage: float, life: float,
		size: float, color: Color, radius := -1.0, pierce := 0) -> bool:
	if count >= capacity:
		return false
	var i := count
	var o := i * STRIDE
	_buf[o] = 1.0; _buf[o + 1] = 0.0; _buf[o + 2] = 0.0; _buf[o + 3] = pos.x
	_buf[o + 4] = 0.0; _buf[o + 5] = 1.0; _buf[o + 6] = 0.0; _buf[o + 7] = pos.y
	_buf[o + 8] = 0.0; _buf[o + 9] = 0.0; _buf[o + 10] = 1.0; _buf[o + 11] = pos.z
	_buf[o + 12] = color.r * glow_intensity
	_buf[o + 13] = color.g * glow_intensity
	_buf[o + 14] = color.b * glow_intensity
	_buf[o + 15] = color.a
	_buf[o + 16] = size
	_buf[o + 17] = float(team)
	_buf[o + 18] = 0.0
	_buf[o + 19] = 0.0
	_vel[i] = vel
	_life[i] = life
	_dmg[i] = damage
	_rad[i] = radius if radius > 0.0 else size * 0.35
	_team[i] = team
	_pierce[i] = pierce
	count += 1
	return true


func clear() -> void:
	count = 0
	_mm.visible_instance_count = 0


## 敵弾を受ける相手(プレイヤー)を登録する。相手は take_bullet_hit(damage) と
## hit_radius プロパティを持つこと。
func register_target(node: Node3D) -> void:
	if node not in _targets:
		_targets.append(node)


func unregister_target(node: Node3D) -> void:
	_targets.erase(node)


func _process(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	_frame += 1
	_build_enemy_grid()
	_step(delta)
	_apply_enemy_damage()
	RenderingServer.multimesh_set_buffer(_mm.get_rid(), _buf)
	_mm.visible_instance_count = count
	last_update_usec = Time.get_ticks_usec() - t0


## 敵の位置をグリッドに登録する。敵は group "enemies" に入り、hit_radius と
## take_damage(amount) を持つこと。半径分はみ出すマスにも登録する。
func _build_enemy_grid() -> void:
	_grid_head.fill(-1)
	_enemies.clear()
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as Node3D
		if e and e.is_inside_tree() and not e.get("dead"):
			_enemies.append(e)
	var ne := _enemies.size()
	_e_pos.resize(ne)
	_e_rad.resize(ne)
	_e_dmg.resize(ne)
	_e_dmg.fill(0.0)
	# 1体が最大4マスに入るので、リンクの表は 4 倍確保する
	_grid_next.resize(ne * 4 * 2)
	var link := 0
	for k in ne:
		var e := _enemies[k]
		var p := e.global_position
		var r: float = e.get("hit_radius")
		_e_pos[k] = p
		_e_rad[k] = r
		var x0 := clampi(int((p.x - r - bounds_min.x) / grid_cell), 0, _grid_w - 1)
		var x1 := clampi(int((p.x + r - bounds_min.x) / grid_cell), 0, _grid_w - 1)
		var z0 := clampi(int((p.z - r - bounds_min.z) / grid_cell), 0, _grid_d - 1)
		var z1 := clampi(int((p.z + r - bounds_min.z) / grid_cell), 0, _grid_d - 1)
		for gx in range(x0, x1 + 1):
			for gz in range(z0, z1 + 1):
				var c := gz * _grid_w + gx
				# リンク表: [敵番号, 次のリンク]
				if link * 2 + 1 >= _grid_next.size():
					_grid_next.resize(_grid_next.size() * 2)
				_grid_next[link * 2] = k
				_grid_next[link * 2 + 1] = _grid_head[c]
				_grid_head[c] = link
				link += 1


func _step(dt: float) -> void:
	# 配列はローカルに取り出して操作する(メンバー変数への添字アクセスより速い)。
	# 取り出した時点でコピーが1回起きるが、memcpy なので数千発でも安い。
	var buf := _buf
	var vel := _vel
	var life := _life
	var dmg := _dmg
	var rad := _rad
	var team := _team
	var pierce := _pierce
	_buf = PackedFloat32Array()  # 参照を外してコピーを避ける

	var bmin := bounds_min
	var bmax := bounds_max
	var cell := grid_cell
	var gw := _grid_w
	var gd := _grid_d
	var head := _grid_head
	var nxt := _grid_next
	var e_pos := _e_pos
	var e_rad := _e_rad
	var e_dmg := _e_dmg
	var has_enemies := _enemies.size() > 0

	var t_pos := PackedVector3Array()
	var t_rad := PackedFloat32Array()
	var t_hit := PackedFloat32Array()
	for t in _targets:
		t_pos.append(t.global_position + Vector3(0, 0.9, 0))
		t_rad.append(t.get("hit_radius"))
		t_hit.append(0.0)
	var nt := t_pos.size()

	var space := get_world_3d().direct_space_state
	var ray := _ray
	var interval := terrain_check_interval
	var phase := _frame % interval
	var rays := 0

	var i := 0
	var n := count
	while i < n:
		var o := i * STRIDE
		var v := vel[i]
		var px := buf[o + 3]
		var py := buf[o + 7]
		var pz := buf[o + 11]
		var nx := px + v.x * dt
		var ny := py + v.y * dt
		var nz := pz + v.z * dt
		var l := life[i] - dt
		var kill := l <= 0.0 \
			or nx < bmin.x or nx > bmax.x or ny < bmin.y or ny > bmax.y \
			or nz < bmin.z or nz > bmax.z

		if not kill:
			var r := rad[i]
			if team[i] == Team.PLAYER:
				if has_enemies:
					var gx := int((nx - bmin.x) / cell)
					var gz := int((nz - bmin.z) / cell)
					if gx >= 0 and gx < gw and gz >= 0 and gz < gd:
						var lk := head[gz * gw + gx]
						while lk >= 0:
							var k := nxt[lk * 2]
							var ep := e_pos[k]
							var rr := e_rad[k] + r
							var dx := ep.x - nx
							var dy := ep.y - ny
							var dz := ep.z - nz
							if dx * dx + dy * dy + dz * dz < rr * rr:
								e_dmg[k] += dmg[i]
								if pierce[i] > 0:
									pierce[i] -= 1
								else:
									kill = true
								break
							lk = nxt[lk * 2 + 1]
			else:
				for k in nt:
					var tp := t_pos[k]
					var rr := t_rad[k] + r
					var dx := tp.x - nx
					var dy := tp.y - ny
					var dz := tp.z - nz
					# プレイヤーは縦長なので y 方向を半分に縮めて判定する
					if dx * dx + dy * dy * 0.25 + dz * dz < rr * rr:
						t_hit[k] += dmg[i]
						kill = true
						break

		# 地形: interval フレームに1回、その間に進む分をまとめて線分で問い合わせる
		if not kill and (i % interval) == phase:
			ray.from = Vector3(px, py, pz)
			ray.to = Vector3(px + v.x * dt * interval, py + v.y * dt * interval, pz + v.z * dt * interval)
			rays += 1
			if not space.intersect_ray(ray).is_empty():
				kill = true

		if kill:
			# 最後の弾をこの位置に移して詰める(順番は保たない)
			n -= 1
			if i != n:
				var src := n * STRIDE
				for j in STRIDE:
					buf[o + j] = buf[src + j]
				vel[i] = vel[n]
				life[i] = life[n]
				dmg[i] = dmg[n]
				rad[i] = rad[n]
				team[i] = team[n]
				pierce[i] = pierce[n]
			continue

		buf[o + 3] = nx
		buf[o + 7] = ny
		buf[o + 11] = nz
		life[i] = l
		i += 1

	count = n
	last_ray_count = rays
	_buf = buf
	_vel = vel
	_life = life
	_dmg = dmg
	_rad = rad
	_team = team
	_pierce = pierce
	_e_dmg = e_dmg

	for k in nt:
		if t_hit[k] > 0.0:
			_targets[k].call("take_bullet_hit", t_hit[k])


## 同じ敵への1フレーム分の命中はまとめて1回だけ渡す(ダメージ数字も1つにまとまる)
func _apply_enemy_damage() -> void:
	for k in _enemies.size():
		if _e_dmg[k] > 0.0 and is_instance_valid(_enemies[k]):
			_enemies[k].call("take_damage", _e_dmg[k])


## 一瞬で届く弾(レールガンなど)用。線分上の敵にダメージを与え、地形に当たった点を返す。
## pierce は貫通できる敵の数(-1 で無制限)。
func hitscan(from: Vector3, dir: Vector3, max_dist: float, damage: float, pierce := -1) -> Vector3:
	var to := from + dir * max_dist
	var q := PhysicsRayQueryParameters3D.create(from, to, terrain_mask)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		to = hit.position
	var seg_len := from.distance_to(to)
	var hits: Array = []
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as Node3D
		if e == null or e.get("dead"):
			continue
		var t := clampf((e.global_position - from).dot(dir), 0.0, seg_len)
		var closest := from + dir * t
		var r: float = e.get("hit_radius")
		if closest.distance_squared_to(e.global_position) < r * r:
			hits.append([t, e])
	hits.sort_custom(func(a, b): return a[0] < b[0])
	var left := pierce
	for h in hits:
		h[1].call("take_damage", damage)
		if left == 0:
			return from + dir * float(h[0])
		left -= 1
	return to
