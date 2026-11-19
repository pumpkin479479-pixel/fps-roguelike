extends Node
## 移動の動作確認(描画なしで実行できる)。入力を順に押して、速度と高さを記録する。
##   godot --headless --path . res://tests/movement_smoke.tscn
## 期待: 歩き≒7.5 / ダッシュ≒11.5 / スライディング開始で14以上 / 二段ジャンプで2回上昇 / 回避で一瞬22前後

var _range: Node3D
var _p: Player
var _log := []


func _ready() -> void:
	_range = load("res://scenes/test_range.tscn").instantiate()
	add_child(_range)
	await get_tree().physics_frame
	_p = get_tree().get_first_node_in_group("player")
	_p.global_position = Vector3(0, 0.1, 10)
	_p.rotation = Vector3.ZERO
	_p.invuln = 999.0  # 敵の弾で倒れないように
	await _wait(20)

	Input.action_press("move_forward")
	await _wait(60)
	_note("歩き")
	Input.action_press("dash")
	await _wait(60)
	_note("ダッシュ")
	Input.action_press("crouch")
	await _wait(3)
	_note("スライディング開始")
	await _wait(30)
	_note("スライディング0.5秒後")
	Input.action_release("crouch")
	Input.action_release("dash")
	Input.action_release("move_forward")
	_p.global_position = Vector3(0, 0.1, 10)
	_p.velocity = Vector3.ZERO
	await _wait(30)

	var y0 := _p.global_position.y
	Input.action_press("jump")
	await _wait(2)
	Input.action_release("jump")
	await _wait(20)
	var y1 := _p.global_position.y
	Input.action_press("jump")
	await _wait(2)
	Input.action_release("jump")
	await _wait(20)
	var y2 := _p.global_position.y
	_log.append("ジャンプ: 地面 %.2f → 1段目 %.2f → 2段目 %.2f" % [y0, y1, y2])
	await _wait(90)

	Input.action_press("move_left")
	Input.action_press("dodge")
	await _wait(3)
	_note("回避中")
	Input.action_release("dodge")
	Input.action_release("move_left")
	await _wait(20)
	_log.append("回避の再使用まで %.2f 秒" % _p.dodge_cooldown)

	# 重い銃(レールガン)に持ち替えて歩き速度を測る
	var rg := load("res://data/guns/railgun.tres") as GunType
	_p.holder.give(GunInstance.roll(rg, 1))
	_p.holder.switch_to(1)
	_p.global_position = Vector3(0, 0.1, 10)
	Input.action_press("move_forward")
	await _wait(60)
	_note("レールガンで歩き(重さ %.1fkg)" % _p.holder.gun().weight)
	Input.action_release("move_forward")

	for l in _log:
		print("[movement] ", l)
	get_tree().quit()


func _note(label: String) -> void:
	_log.append("%s: 水平速度 %.2f m/s" % [label, Vector2(_p.velocity.x, _p.velocity.z).length()])


func _wait(frames: int) -> void:
	for _k in frames:
		await get_tree().physics_frame
