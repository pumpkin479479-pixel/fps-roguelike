class_name GunVisual
extends RefCounted
## 銃の見た目を組み立てる。銃口は -Z 方向、原点はグリップを握る位置。
## Blender で作ったモデル(model_path)があればそれを使い、無ければ寸法から仮の箱モデルを作る。
## どちらの場合も "muzzle" という名前の点を持つ(弾はここから出る)。

static func build(gun: GunType) -> Node3D:
	if gun.model_path != "" and ResourceLoader.exists(gun.model_path):
		var scene := load(gun.model_path) as PackedScene
		if scene:
			var root := scene.instantiate() as Node3D
			if root.find_child("muzzle", true, false) == null:
				var m := Marker3D.new()
				m.name = "muzzle"
				m.position = Vector3(0, 0.05, -0.8)
				root.add_child(m)
			return root
	return _placeholder(gun)


static func find_muzzle(root: Node3D) -> Node3D:
	var m := root.find_child("muzzle", true, false) as Node3D
	return m if m else root


static func _placeholder(gun: GunType) -> Node3D:
	var root := Node3D.new()
	var body := _mat(gun.body_color, gun.era == 5)
	var accent := _mat(gun.accent_color, gun.era == 5)
	var d := gun.placeholder_dims
	var body_len := d.x
	var body_h := d.y
	var barrel_len := d.z

	var pistol := body_len <= 0.25
	# 本体(グリップの少し前から前へ伸びる)
	_box(root, Vector3(0, body_h * 0.5, -body_len * 0.35), Vector3(0.05, body_h, body_len), body)
	# グリップ
	var grip_z := -body_len * 0.1 if pistol else 0.02
	var grip := _box(root, Vector3(0, -0.05, grip_z), Vector3(0.035, 0.12, 0.05), accent)
	grip.rotation_degrees.x = -15
	# 銃身
	var barrel_z := -body_len * 0.85 - barrel_len * 0.5
	var r := 0.014 if gun.era < 5 else 0.03
	var barrel := _cyl(root, Vector3(0, body_h * 0.65, barrel_z), r, r, barrel_len, body)
	barrel.rotation_degrees.x = 90
	var tip_z := barrel_z - barrel_len * 0.5
	if gun.flared_muzzle:
		var flare := _cyl(root, Vector3(0, body_h * 0.65, tip_z - 0.05), 0.06, r, 0.1, accent)
		flare.rotation_degrees.x = -90  # 太い側(top)を銃口側(-Z)へ向ける
		tip_z -= 0.1
	# ストック(拳銃以外)
	if body_len > 0.25:
		var stock := _box(root, Vector3(0, body_h * 0.2, body_len * 0.1 + 0.15), Vector3(0.04, 0.09, 0.3), accent)
		stock.rotation_degrees.x = 6
	# マガジン
	match gun.mag_shape:
		0 when pistol:
			pass  # 拳銃のマガジンはグリップの中
		0:
			var mag := _box(root, Vector3(0, -0.07, -body_len * 0.45), Vector3(0.03, 0.16, 0.05), body)
			mag.rotation_degrees.x = 12
		1:
			var drum := _cyl(root, Vector3(0, -0.06, -body_len * 0.5), 0.07, 0.07, 0.05, body)
			drum.rotation_degrees.z = 90
		3:
			var cell := _box(root, Vector3(0, body_h + 0.03, -body_len * 0.2), Vector3(0.06, 0.05, 0.14), _glow(gun.accent_color))
			cell.name = "cell"
	if gun.era == 5:
		# 未来銃: 発光ライン
		_box(root, Vector3(0.03, body_h * 0.5, -body_len * 0.4), Vector3(0.005, 0.02, body_len * 0.9), _glow(gun.accent_color))
		_box(root, Vector3(-0.03, body_h * 0.5, -body_len * 0.4), Vector3(0.005, 0.02, body_len * 0.9), _glow(gun.accent_color))
	var muzzle := Marker3D.new()
	muzzle.name = "muzzle"
	muzzle.position = Vector3(0, body_h * 0.65, tip_z)
	root.add_child(muzzle)
	return root


static func _mat(c: Color, metallic: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.35 if metallic else 0.6
	m.metallic = 0.7 if metallic else 0.3
	return m


static func _glow(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 3.0
	return m


static func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _cyl(parent: Node3D, pos: Vector3, top: float, bottom: float, h: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = h
	mesh.radial_segments = 10
	mesh.rings = 1
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi
