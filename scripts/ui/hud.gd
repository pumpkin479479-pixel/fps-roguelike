extends CanvasLayer
## 画面表示: 照準、体力、回避の再使用、弾数、銃の性能、負荷(FPS / 弾数 / 更新時間)、操作説明

const HELP := """[操作]  F1 で表示切替
WASD 移動 / Shift ダッシュ / Space ジャンプ(空中でもう1回)
Ctrl か C  スライディング(走りながら) / Q か Alt  回避
左クリック 射撃 / 右クリック 構える / R リロード
1・2・ホイール 持ち替え / E 銃を拾う(2丁まで、3丁目は入れ替え)
F3 弾幕ショー / F4 銃を1丁落とす / Esc マウス解放"""

var _player: Player
var _bm: BulletManager
var _range: Node

var _perf: Label
var _gun: Label
var _status: Label
var _help: Label
var _pickup: Label
var _cross: Control
var _hurt: ColorRect
var _hurt_a := 0.0


func setup(p: Player, bm: BulletManager, range_node: Node) -> void:
	_player = p
	_bm = bm
	_range = range_node


func _ready() -> void:
	_perf = _label(Vector2(16, 12), 18)
	_help = _label(Vector2(16, 120), 17)
	_help.text = HELP
	_status = _label(Vector2.ZERO, 22)
	_gun = _label(Vector2.ZERO, 19)
	_gun.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_pickup = _label(Vector2.ZERO, 18)

	_hurt = ColorRect.new()
	_hurt.color = Color(1, 0, 0, 0)
	_hurt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hurt.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_hurt)
	move_child(_hurt, 0)

	_cross = Crosshair.new()
	add_child(_cross)

	_player.damaged.connect(func(_a): _hurt_a = 0.35)


func _label(pos: Vector2, size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_help"):
		_help.visible = not _help.visible


func _process(dt: float) -> void:
	_perf.text = "FPS %d  (%.1f ms)\n弾 %d 発   弾の更新 %.2f ms   地形判定 %d 回\n敵 %d 体%s" % [
		Engine.get_frames_per_second(), dt * 1000.0, _bm.count, _bm.last_update_usec / 1000.0,
		_bm.last_ray_count, get_tree().get_nodes_in_group("enemies").size(),
		"   [弾幕ショー中]" if _range.get("storm") else ""]

	var dodge := "回避 OK" if _player.dodge_cooldown <= 0.0 else "回避 %.1f" % _player.dodge_cooldown
	var state := ["", "  スライディング", "  回避中"][_player.state] as String
	_status.text = "体力 %d / %d   %s   速度 %.1f m/s (重さ補正 %+d%%)%s%s" % [
		ceili(_player.hp), _player.max_hp, dodge,
		Vector2(_player.velocity.x, _player.velocity.z).length(),
		roundi((_player.speed_mult - 1.0) * 100.0), state,
		"   無敵" if _player.invuln > 0.0 else ""]

	var h := _player.holder
	var g := h.gun()
	if g:
		var ammo := "リロード中…" if h.reloading else "%d / %d" % [g.ammo, g.magazine]
		var slots := ""
		for k in h.slots.size():
			slots += ("[%d] %s   " if k == h.current else " %d  %s   ") % [k + 1, h.slots[k].display_name()]
		var charge := ""
		if g.type.fire_mode == GunType.FireMode.CHARGE:
			charge = "\nチャージ " + "|".repeat(roundi(h.charge * 20)) + ".".repeat(20 - roundi(h.charge * 20))
		_gun.text = "%s\n%s  %s%s\n%s" % [slots, g.display_name(), ammo, charge, "\n".join(g.stat_lines())]
		_gun.modulate = Color.WHITE

	var p: GunPickup = _range.call("looked_pickup")
	if p:
		var lines := p.gun.stat_lines()
		_pickup.text = "[E] 拾う: %s\n%s" % [p.gun.display_name(), "\n".join(lines)]
		_pickup.modulate = GunInstance.RARITY_COLORS[p.gun.rarity]
	else:
		_pickup.text = ""

	# 画面サイズに合わせて配置(ラベルは文字量で大きさが変わるので毎フレーム置き直す)
	var vp := get_viewport().get_visible_rect().size
	_status.reset_size()
	_status.position = Vector2(16, vp.y - _status.size.y - 16)
	_gun.reset_size()
	_gun.position = vp - _gun.size - Vector2(16, 16)
	_pickup.position = vp * 0.5 + Vector2(40, 30)
	_cross.position = vp * 0.5

	_hurt_a = maxf(0.0, _hurt_a - dt)
	_hurt.color.a = _hurt_a
	(_cross as Crosshair).spread = g.spread_deg * (0.4 if h.aiming else 1.0) if g else 1.0
	_cross.queue_redraw()


class Crosshair extends Control:
	var spread := 2.0

	func _draw() -> void:
		var gap := 6.0 + spread * 5.0
		var c := Color(1, 1, 1, 0.9)
		for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			draw_line(d * gap, d * (gap + 10.0), Color.BLACK, 4.0)
			draw_line(d * gap, d * (gap + 10.0), c, 2.0)
		draw_circle(Vector2.ZERO, 2.0, c)
