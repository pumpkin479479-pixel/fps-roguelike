class_name GunPickup
extends Area3D
## 床に落ちている銃。E で拾う。銃の見た目、名前、レア度、性能を表示する。

var gun: GunInstance
var _model: Node3D
var _t := 0.0


static func create(g: GunInstance, pos: Vector3) -> GunPickup:
	var p := GunPickup.new()
	p.gun = g
	p.position = pos
	return p


func _ready() -> void:
	add_to_group("pickups")
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	var cs := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.7
	cs.shape = shape
	add_child(cs)

	_model = GunVisual.build_instance(gun)
	_model.scale = Vector3.ONE * 1.4
	_model.position.y = 0.6
	add_child(_model)

	# レア度の色の光
	var light := OmniLight3D.new()
	light.light_color = GunInstance.RARITY_COLORS[gun.rarity]
	light.light_energy = 1.5
	light.omni_range = 2.5
	light.position.y = 0.6
	add_child(light)

	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.text = "%s\n%s" % [gun.display_name(), GunInstance.RARITY_NAMES[gun.rarity]]
	label.modulate = GunInstance.RARITY_COLORS[gun.rarity]
	label.outline_size = 10
	label.font_size = 48
	label.pixel_size = 0.004
	label.position.y = 1.4
	add_child(label)


func _process(dt: float) -> void:
	_t += dt
	_model.rotation.y = _t * 1.2
	_model.position.y = 0.6 + sin(_t * 2.0) * 0.08
