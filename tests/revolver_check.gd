extends Node
## リボルバーの動き(撃鉄・シリンダー・振り出しリロード)を確かめる。
##   godot --path . res://tests/revolver_check.tscn -- --shots=DIR
## 撃つ → 撃った後 → リロードの途中(振り出し・排莢・装填・戻し)を順に撮り、部品の角度を表示する。
## --shots を付けなければ数値だけを表示する(--headless でも動く)。

func _ready() -> void:
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			dir = a.trim_prefix("--shots=")
	var r: Node3D = load("res://scenes/test_range.tscn").instantiate()
	add_child(r)
	await get_tree().physics_frame
	var p: Player = get_tree().get_first_node_in_group("player")
	p.invuln = 999.0
	var h := p.holder
	h.give(GunInstance.roll(load("res://data/guns/revolver357.tres"), 7))
	h.switch_to(h.slots.size() - 1)
	var g := h.gun()
	await _wait(0.6)
	await _shot(dir, "0_idle", h)
	h._fire(g)
	await _wait(0.03)
	await _shot(dir, "1_fired", h)
	await _wait(0.4)
	await _shot(dir, "2_next", h)
	h._fire(g)
	await _wait(0.4)
	print("[rev] 弾 %d/%d" % [g.ammo, g.magazine])
	h._start_reload(g)
	var T := g.reload_time
	for f in [0.12, 0.22, 0.30, 0.50, 0.62, 0.86]:
		await _wait_until(h, T * (1.0 - f))
		await _shot(dir, "3_reload_%02d" % int(f * 100), h)
	await _wait(T * 0.2)
	print("[rev] リロード後 弾 %d/%d  reloading=%s" % [g.ammo, g.magazine, h.reloading])
	await _shot(dir, "4_done", h)
	get_tree().quit()


func _wait(sec: float) -> void:
	var end := Time.get_ticks_msec() + int(sec * 1000.0)
	while Time.get_ticks_msec() < end:
		await get_tree().process_frame


func _wait_until(h: GunHolder, left: float) -> void:
	while h.reloading and h.reload_left > left:
		await get_tree().process_frame


func _shot(dir: String, name: String, h: GunHolder) -> void:
	var v := h.get_child(h.get_child_count() - 1) as Node3D
	var parts := []
	for n in ["hammer", "trigger", "cylinder", "crane"]:
		var node := v.find_child(n, true, false) as Node3D
		if node:
			parts.append("%s=(%.2f,%.2f)" % [n, node.rotation.x, node.rotation.z])
	var shown := 0
	for k in 6:
		var b := v.find_child("bullet_%d" % k, true, false) as Node3D
		var rnd := v.find_child("round_%d" % k, true, false) as Node3D
		if b and rnd and rnd.visible and b.visible:
			shown += 1
	print("[rev] %s  %s  弾頭の見える弾 %d" % [name, " ".join(parts), shown])
	if dir == "":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, name])
