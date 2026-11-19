extends Node
## 構えたときに、照門(ads_eye)と照星の先が画面中央に来ているかを数値で確かめる。
##   godot --headless --path . res://tests/ads_check.tscn
## 期待: どちらも画面中央から数ピクセル以内

func _ready() -> void:
	var r: Node3D = load("res://scenes/test_range.tscn").instantiate()
	add_child(r)
	await get_tree().physics_frame
	var p: Player = get_tree().get_first_node_in_group("player")
	p.invuln = 999.0
	p.holder.give(GunInstance.roll(load("res://data/guns/ak47.tres"), 1))
	p.holder.switch_to(1)
	Input.action_press("aim")
	for _k in 90:
		await get_tree().process_frame
	var cam := p.camera
	var view := p.holder.get_child(p.holder.get_child_count() - 1) as Node3D
	var eye := view.find_child("ads_eye", true, false) as Node3D
	var post := view.find_child("front_post_tip", true, false) as Node3D
	var size := get_viewport().get_visible_rect().size
	print("[ads] 画面 %s  中央 %s" % [size, size * 0.5])
	if eye:
		print("[ads] 照門 %s" % cam.unproject_position(eye.global_position))
	if post:
		print("[ads] 照星 %s" % cam.unproject_position(post.global_position))
	get_tree().quit()
