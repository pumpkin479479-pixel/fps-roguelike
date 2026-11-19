class_name GunVisual
extends RefCounted
## 銃の見た目を組み立てる。銃口は -Z 方向、原点はグリップを握る位置。
## Blender で作ったモデル(model_path)があればそれを使い、無ければ寸法から仮の箱モデルを作る。
## どちらの場合も "muzzle" という名前の点を持つ(弾はここから出る)。

const SURFACE_SHADER := preload("res://shaders/gun_surface.gdshader")
## Blender の素材名 → (種類 0=金属 1=木 2=樹脂, 擦れて出る色)
const SURFACES := {
	"steel": [0, Color(0.42, 0.42, 0.44)],
	"steel_worn": [0, Color(0.5, 0.5, 0.52)],
	"steel_bright": [0, Color(0.5, 0.5, 0.52)],
	"wood": [1, Color()],
	"wood_dark": [1, Color()],
	"bakelite": [2, Color()],
}


## 拾った銃1丁の見た目。使い込み具合と模様の位置は銃のシード値で決まる(同じ銃は同じ見た目)。
static func build_instance(g: GunInstance) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = g.seed_value
	# レア度が高いほど手入れがいい(傷が少ない)
	var wear := clampf(rng.randf_range(0.25, 1.0) - float(g.rarity) * 0.18, 0.05, 1.0)
	return build(g.type, wear, rng.randf_range(0.0, 50.0))


static func build(gun: GunType, wear := 0.5, pattern_seed := 0.0) -> Node3D:
	if gun.model_path != "" and ResourceLoader.exists(gun.model_path):
		var scene := load(gun.model_path) as PackedScene
		if scene:
			var root := scene.instantiate() as Node3D
			if root.find_child("muzzle", true, false) == null:
				var m := Marker3D.new()
				m.name = "muzzle"
				m.position = Vector3(0, 0.05, -0.8)
				root.add_child(m)
			_apply_surfaces(root, wear, pattern_seed)
			return root
	return _placeholder(gun)


## Blender で付けた単色の素材を、傷・擦れ・木目の出る素材に置き換える
static func _apply_surfaces(root: Node, wear: float, pattern_seed: float) -> void:
	var cache := {}
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		for k in mesh.get_surface_count():
			var src := mesh.surface_get_material(k) as BaseMaterial3D
			if src == null or not SURFACES.has(src.resource_name):
				continue
			if not cache.has(src.resource_name):
				var info: Array = SURFACES[src.resource_name]
				var sm := ShaderMaterial.new()
				sm.shader = SURFACE_SHADER
				sm.set_shader_parameter("base_color", src.albedo_color)
				sm.set_shader_parameter("metallic_value", src.metallic)
				sm.set_shader_parameter("roughness_value", src.roughness)
				sm.set_shader_parameter("kind", info[0])
				sm.set_shader_parameter("edge_color", info[1])
				sm.set_shader_parameter("wear", wear)
				sm.set_shader_parameter("seed", pattern_seed)
				cache[src.resource_name] = sm
			(mi as MeshInstance3D).set_surface_override_material(k, cache[src.resource_name])


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
	var grip := _box(root, Vector3(0, -0.055, grip_z), Vector3(0.03, 0.12, 0.045), accent)
	grip.rotation_degrees.x = -15
	# 銃身
	var barrel_z := -body_len * 0.85 - barrel_len * 0.5
	var r := 0.014 if gun.era < 5 else 0.03
	if barrel_len > 0.0:  # 拳銃は銃身がスライドの中に隠れる
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
