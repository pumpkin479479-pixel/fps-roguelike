extends Node
## 起動時の共通設定。入力の割り当てをコードで登録する(エディタ操作なしで変更できるように)。

const PHYS_WORLD := 1      # 地形
const PHYS_PLAYER := 2     # プレイヤー
const PHYS_ENEMY := 4      # 敵
const PHYS_PICKUP := 8     # 落ちている銃

## 入力名 → キー/ボタンの一覧。InputEventKey は physical_keycode で登録する。
const ACTIONS := {
	"move_forward": [KEY_W],
	"move_back": [KEY_S],
	"move_left": [KEY_A],
	"move_right": [KEY_D],
	"jump": [KEY_SPACE],
	"dash": [KEY_SHIFT],
	"crouch": [KEY_CTRL, KEY_C],
	"dodge": [KEY_Q, KEY_ALT],
	"reload": [KEY_R],
	"interact": [KEY_E],
	"weapon_1": [KEY_1],
	"weapon_2": [KEY_2],
	"fire": [MOUSE_BUTTON_LEFT],
	"aim": [MOUSE_BUTTON_RIGHT],
	"weapon_next": [MOUSE_BUTTON_WHEEL_DOWN],
	"weapon_prev": [MOUSE_BUTTON_WHEEL_UP],
	"toggle_help": [KEY_F1],
	"bullet_storm": [KEY_F3],
	"spawn_gun": [KEY_F4],
	"gun_viewer": [KEY_F5],
	"ui_release_mouse": [KEY_ESCAPE],
}

var mouse_sensitivity := 0.0025


func _ready() -> void:
	for action: String in ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for code: int in ACTIONS[action]:
			var ev: InputEvent
			if code <= MOUSE_BUTTON_XBUTTON2:
				var mb := InputEventMouseButton.new()
				mb.button_index = code
				ev = mb
			else:
				var k := InputEventKey.new()
				k.physical_keycode = code
				ev = k
			InputMap.action_add_event(action, ev)
	_setup_screenshot()


## 開発用: `-- --screenshot=out.png --shot-frames=120` で、指定フレーム後に画面を保存して終了する。
## AI が見た目を確認するために使う(フレーム数に加えて最低 2 秒待つ)。--fire で射撃、--aim で構えを押しっぱなしにする。
func _setup_screenshot() -> void:
	var path := ""
	var frames := 120
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--screenshot="):
			path = a.trim_prefix("--screenshot=")
		elif a.begins_with("--shot-frames="):
			frames = int(a.trim_prefix("--shot-frames="))
		elif a == "--fire":
			Input.action_press.call_deferred("fire")
		elif a == "--aim":
			Input.action_press.call_deferred("aim")
	if path == "":
		return
	# 速いPCでは 120 フレームが一瞬で終わり構えの動きが途中になるので、最低 2 秒は待つ
	var start := Time.get_ticks_msec()
	var k := 0
	while k < frames or Time.get_ticks_msec() - start < 2000:
		await get_tree().process_frame
		k += 1
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("[screenshot] ", path)
	get_tree().quit()
