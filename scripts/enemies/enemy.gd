class_name Enemy
extends Node3D
## 試作用の敵。2Dの絵を3D空間に立てて表示する(常にカメラを向く板)。
##   射手 … 距離を取り、狙った扇状の弾を撃つ
##   重装 … 硬くて遅い。リング弾と渦巻き弾をばら撒く
## 物理ボディは持たない。弾との当たり判定は BulletManager のグリッドで行う。

signal killed(enemy: Enemy)

enum Kind { SHOOTER, HEAVY }

var kind := Kind.SHOOTER
var hit_radius := 0.8
var max_hp := 120.0
var hp := 120.0
var dead := false
## 弾幕の濃さの倍率(F3 の弾幕ショーで上げる)
var fury := 1.0

var _sprite: Sprite3D
var _label: Label3D
var _recent_dmg := 0.0
var _recent_t := 0.0
var _flash := 0.0
var _fire_t := 0.0
var _spiral := 0.0
var _anchor := Vector3.ZERO
var _t := 0.0
var _bm: BulletManager
var _rng := RandomNumberGenerator.new()

static var _textures := {}


func setup(k: Kind, pos: Vector3, fury_mult := 1.0) -> Enemy:
	kind = k
	position = pos
	fury = fury_mult
	if kind == Kind.HEAVY:
		max_hp = 600.0
		hit_radius = 1.3
	else:
		max_hp = 120.0
		hit_radius = 0.8
	hp = max_hp
	return self


func _ready() -> void:
	add_to_group("enemies")
	_rng.randomize()
	_anchor = position
	_t = _rng.randf() * 10.0
	_fire_t = _rng.randf_range(0.5, 1.5)
	_bm = get_tree().get_first_node_in_group("bullet_manager") as BulletManager

	_sprite = Sprite3D.new()
	_sprite.texture = _texture_for(kind)
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.shaded = false
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.pixel_size = hit_radius * 2.3 / 32.0
	add_child(_sprite)

	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = Vector3(0, hit_radius + 0.6, 0)
	_label.font_size = 64
	_label.outline_size = 12
	_label.modulate = Color(1, 0.95, 0.5)
	_label.no_depth_test = true
	_label.fixed_size = true
	_label.pixel_size = 0.0008
	add_child(_label)


func _process(dt: float) -> void:
	if dead:
		return
	_t += dt
	var player := get_tree().get_first_node_in_group("player") as Node3D
	# ふわふわ漂う
	var amp := 3.0 if kind == Kind.SHOOTER else 1.2
	position = _anchor + Vector3(sin(_t * 0.6) * amp, sin(_t * 1.4) * 0.4, cos(_t * 0.45) * amp)

	if player:
		_fire_t -= dt
		if _fire_t <= 0.0:
			_shoot(player.global_position + Vector3(0, 1.0, 0))

	# 被弾の白い光とダメージ表示
	_flash = maxf(0.0, _flash - dt * 8.0)
	var f := 1.0 + _flash * 3.0
	_sprite.modulate = Color(f, f, f)
	_recent_t -= dt
	if _recent_t <= 0.0:
		_recent_dmg = 0.0
		_label.text = ""
	else:
		_label.modulate.a = clampf(_recent_t / 0.3, 0.0, 1.0)


func _shoot(target: Vector3) -> void:
	var from := global_position
	var to_player := (target - from).normalized()
	match kind:
		Kind.SHOOTER:
			# 狙った扇(5方向)
			var n := 5
			for k in n:
				var a := deg_to_rad((k - (n - 1) * 0.5) * 9.0)
				var d := to_player.rotated(Vector3.UP, a)
				_bm.spawn(from, d * 13.0, BulletManager.Team.ENEMY, 6.0, 6.0, 0.55, Color(1.0, 0.3, 0.6))
			_fire_t = _rng.randf_range(1.0, 1.6) / fury
		Kind.HEAVY:
			# リング弾と渦巻き弾を交互に
			if _rng.randf() < 0.4:
				var n := int(36 * fury)
				for k in n:
					var a := TAU * k / n
					var d := Vector3(cos(a), 0.0, sin(a))
					_bm.spawn(from, d * 8.0, BulletManager.Team.ENEMY, 8.0, 8.0, 0.75, Color(0.6, 0.35, 1.0))
				_fire_t = 1.4 / fury
			else:
				for arm in 6:
					var a := _spiral + TAU * arm / 6.0
					var d := Vector3(cos(a), _rng.randf_range(-0.05, 0.08), sin(a)).normalized()
					_bm.spawn(from, d * 10.0, BulletManager.Team.ENEMY, 5.0, 8.0, 0.5, Color(0.3, 0.9, 1.0))
				_spiral += 0.22
				_fire_t = 0.09 / fury


func take_damage(amount: float) -> void:
	if dead:
		return
	hp -= amount
	_flash = 1.0
	_recent_dmg += amount
	_recent_t = 0.8
	_label.text = str(roundi(_recent_dmg))
	if hp <= 0.0:
		dead = true
		killed.emit(self)
		queue_free()


## 敵の絵(32x32)をコードで描く。本番は画像生成AIで描いた絵に差し替える。
static func _texture_for(k: Kind) -> Texture2D:
	if _textures.has(k):
		return _textures[k]
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var body := Color(0.85, 0.25, 0.35) if k == Kind.SHOOTER else Color(0.45, 0.3, 0.75)
	var dark := body.darkened(0.5)
	for y in 32:
		for x in 32:
			var dx := x - 15.5
			var dy := y - 15.5
			var d := sqrt(dx * dx + dy * dy)
			var c := Color(0, 0, 0, 0)
			if k == Kind.HEAVY:
				# 角ばった重装
				if absf(dx) < 14 and absf(dy) < 13:
					c = body if absf(dx) < 12.5 and absf(dy) < 11.5 else dark
				if absf(dy) < 2 and absf(dx) < 15:
					c = dark
			else:
				if d < 13.5:
					c = body if d < 12.0 else dark
				# 左右の羽
				if absf(dy) < 3 and absf(dx) < 15.5 and d >= 12.0:
					c = dark
			# 目
			if d < 6.0:
				c = Color(1, 1, 0.9)
			if d < 3.0:
				c = Color(0.1, 0.05, 0.1)
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	_textures[k] = tex
	return tex
