class_name RoomBuilder
extends RefCounted
## 試射場と負荷テスト用の部屋をコードで組み立てる。
## 4m 単位の箱と板だけで作る(設計書の部屋テンプレートと同じ考え方)。

const SIZE := 64.0
const WALL_H := 10.0


static func build(parent: Node3D, with_obstacles := true) -> void:
	_environment(parent)
	var floor_mat := _mat(Color(0.32, 0.34, 0.38), true)
	var wall_mat := _mat(Color(0.45, 0.47, 0.52), true)
	var box_mat := _mat(Color(0.62, 0.48, 0.30), false)
	var plat_mat := _mat(Color(0.30, 0.45, 0.60), false)

	_box(parent, Vector3(0, -0.5, 0), Vector3(SIZE, 1, SIZE), floor_mat)
	var h := SIZE * 0.5
	_box(parent, Vector3(0, WALL_H * 0.5, -h - 0.5), Vector3(SIZE + 2, WALL_H, 1), wall_mat)
	_box(parent, Vector3(0, WALL_H * 0.5, h + 0.5), Vector3(SIZE + 2, WALL_H, 1), wall_mat)
	_box(parent, Vector3(-h - 0.5, WALL_H * 0.5, 0), Vector3(1, WALL_H, SIZE), wall_mat)
	_box(parent, Vector3(h + 0.5, WALL_H * 0.5, 0), Vector3(1, WALL_H, SIZE), wall_mat)
	if not with_obstacles:
		return

	# 遮蔽物の箱
	for p: Vector3 in [Vector3(-8, 0, -6), Vector3(10, 0, -12), Vector3(-14, 0, 10),
			Vector3(6, 0, 14), Vector3(18, 0, 4), Vector3(-20, 0, -18)]:
		_box(parent, p + Vector3(0, 1, 0), Vector3(2, 2, 2), box_mat)
	# 柱
	for p: Vector3 in [Vector3(-16, 0, -4), Vector3(16, 0, -20), Vector3(0, 0, -24), Vector3(22, 0, 20)]:
		_box(parent, p + Vector3(0, 4, 0), Vector3(2, 8, 2), wall_mat)
	# 二段ジャンプ用の足場
	_box(parent, Vector3(-22, 2.5, 18), Vector3(6, 0.5, 6), plat_mat)
	_box(parent, Vector3(-12, 5.0, 24), Vector3(6, 0.5, 6), plat_mat)
	_box(parent, Vector3(0, 7.0, 26), Vector3(8, 0.5, 4), plat_mat)
	# スライディング加速用の坂(手前が低い)
	_ramp(parent, Vector3(20, 0, -2), Vector3(8, 4, 16), plat_mat)


static func _environment(parent: Node3D) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.18, 0.22, 0.35)
	sky_mat.sky_horizon_color = Color(0.55, 0.50, 0.55)
	sky_mat.ground_bottom_color = Color(0.1, 0.1, 0.12)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.2
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	parent.add_child(sun)


static func _mat(c: Color, grid: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	if grid:
		# 4m ごとの格子を三平面投影で描く(距離感と速度感をつかみやすくする)
		var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
		img.fill(Color(1, 1, 1))
		for k in 64:
			for e in [0, 1]:
				img.set_pixel(k, e, Color(0.7, 0.7, 0.7))
				img.set_pixel(e, k, Color(0.7, 0.7, 0.7))
		m.albedo_texture = ImageTexture.create_from_image(img)
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3(0.25, 0.25, 0.25)
	return m


static func _box(parent: Node3D, center: Vector3, size: Vector3, mat: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = center
	body.collision_layer = 1
	body.collision_mask = 0
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	parent.add_child(body)
	return body


## base: 坂の低い側の中央の床位置。size.x=幅, size.y=高さ, size.z=奥行き(-z 方向へ登る)
static func _ramp(parent: Node3D, base: Vector3, size: Vector3, mat: Material) -> void:
	var length := sqrt(size.z * size.z + size.y * size.y)
	var angle := atan2(size.y, size.z)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = base + Vector3(0, size.y * 0.5, -size.z * 0.5)
	body.rotation.x = angle
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size.x, 0.4, length)
	mi.mesh = mesh
	mi.material_override = mat
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	cs.shape = shape
	body.add_child(cs)
	parent.add_child(body)
