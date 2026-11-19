extends Node3D
## 素材の確認用: 同じ銃を 使い込み 0 / 0.5 / 1 で並べて近くから見る。
##   godot --path . res://scenes/gun_closeup.tscn -- --gun=ak47 [--screenshot=out.png]

func _ready() -> void:
	var id := "ak47"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--gun="):
			id = a.trim_prefix("--gun=")
	var t := load("res://data/guns/%s.tres" % id) as GunType
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.5, 0.52, 0.55)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.62, 0.66)
	env.environment.ambient_light_energy = 0.6
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 1.6
	add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 200, 0)
	rim.light_energy = 0.6
	add_child(rim)
	for k in 3:
		var v := GunVisual.build(t, k * 0.5, 7.0)
		v.rotation_degrees = Vector3(0, 90, 0)  # 銃口を左へ
		v.position = Vector3(0.22, 0.34 - k * 0.34, 0)
		add_child(v)
		var l := Label3D.new()
		l.text = "使い込み %.1f" % (k * 0.5)
		l.no_depth_test = true
		l.font_size = 24
		l.pixel_size = 0.0008
		l.position = v.position + Vector3(0.05, 0.12, 0.05)
		add_child(l)
	var cam := Camera3D.new()
	cam.position = Vector3(0.05, -0.05, 1.45)
	cam.rotation_degrees = Vector3(0, 0, 0)
	cam.position.y = 0.02
	cam.fov = 45
	add_child(cam)
