extends Node3D
## 銃の見た目の確認用。6種を横向きに並べて表示する(マウスドラッグで回転、ホイールで拡大)。
## `-- --screenshot=out.png` を付けると画像を保存して終了する(AI の見た目確認用)。

var _pivot: Node3D
var _cam: Camera3D
var _dragging := false
var _dist := 4.6


func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.82, 0.84, 0.88)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.6, 0.65)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	add_child(sun)

	_pivot = Node3D.new()
	add_child(_pivot)
	var idx := 0
	for f in DirAccess.get_files_at("res://data/guns/"):
		var path := "res://data/guns/" + f.trim_suffix(".remap")
		if not path.ends_with(".tres"):
			continue
		var t := load(path) as GunType
		var v := GunVisual.build(t)
		# 銃口(-Z)を右に向けて横から見る
		v.rotation_degrees.y = -90
		var col := idx % 2
		var row := idx / 2
		var x0 := -1.05 if col == 0 else 1.05
		var y := 0.75 - row * 0.65
		idx += 1
		v.position = Vector3(x0, y, 0)
		_pivot.add_child(v)
		var l := Label3D.new()
		l.text = "%s(%s)" % [t.display_name, t.reference]
		l.font_size = 32
		l.pixel_size = 0.002
		l.modulate = Color.BLACK
		l.outline_size = 0
		l.position = Vector3(x0 - 0.75, y + 0.22, 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_pivot.add_child(l)

	_cam = Camera3D.new()
	_cam.fov = 40
	add_child(_cam)
	_update_cam()


func _update_cam() -> void:
	_cam.position = Vector3(0, 0.1, _dist)
	_cam.look_at(Vector3(0, 0.1, 0))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = maxf(0.8, _dist - 0.2)
			_update_cam()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = minf(8.0, _dist + 0.2)
			_update_cam()
	elif event is InputEventMouseMotion and _dragging:
		_pivot.rotate_y(event.relative.x * 0.01)
