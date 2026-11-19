class_name Player
extends CharacterBody3D
## プレイヤーの移動。軽やかに動き回って弾を避けることを優先した数値にしている。
##   ダッシュ     … Shift を押している間は走る(走りながら撃てる)
##   二段ジャンプ … 空中でもう1回跳べる。跳んだ瞬間に入力方向へ向きを変えられる
##   スライディング … 走っている最中に Ctrl / C。坂を下ると加速する。滑りながら撃てる
##   回避         … Q / Alt。入力方向へ短く飛ぶ。0.3秒無敵、再使用まで2秒
## 持っている銃が重いほど、速度・回避距離が落ちる(speed_mult、GunHolder が設定)。

signal damaged(amount: float)
signal died

const WALK_SPEED := 7.5
const DASH_SPEED := 11.5
const GROUND_ACCEL := 70.0
const AIR_ACCEL := 25.0
const GRAVITY := 22.0
const JUMP_VELOCITY := 7.2
const MAX_AIR_JUMPS := 1
const COYOTE_TIME := 0.12

const SLIDE_BOOST := 14.0
const SLIDE_FRICTION := 5.0
const SLIDE_MIN_SPEED := 6.0
const SLIDE_STEER := 2.5

const DODGE_SPEED := 22.0
const DODGE_TIME := 0.15
const DODGE_IFRAMES := 0.3
const DODGE_COOLDOWN := 2.0

const STAND_EYE := 1.6
const SLIDE_EYE := 0.9
const BASE_FOV := 85.0

enum State { NORMAL, SLIDE, DODGE }

@export var max_hp := 100.0

var hp := 100.0
var hit_radius := 0.5
var speed_mult := 1.0
var state := State.NORMAL
var dodge_cooldown := 0.0
var invuln := 0.0
var deaths := 0

var _air_jumps := MAX_AIR_JUMPS
var _coyote := 0.0
var _state_t := 0.0
var _dodge_dir := Vector3.ZERO
var _recoil_pitch := 0.0
var _spawn_pos := Vector3.ZERO

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var holder: GunHolder = $Head/Camera3D/GunHolder


func _ready() -> void:
	hp = max_hp
	_spawn_pos = global_position
	collision_layer = 2
	collision_mask = 1
	floor_max_angle = deg_to_rad(50)
	floor_snap_length = 0.4
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var bm := get_tree().get_first_node_in_group("bullet_manager") as BulletManager
	if bm:
		bm.register_target(self)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens: float = Game.mouse_sensitivity * (0.6 if holder.aiming else 1.0)
		rotate_y(-event.relative.x * sens)
		head.rotation.x = clampf(head.rotation.x - event.relative.y * sens, deg_to_rad(-89), deg_to_rad(89))
	elif event.is_action_pressed("ui_release_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()


func _physics_process(dt: float) -> void:
	dodge_cooldown = maxf(0.0, dodge_cooldown - dt)
	invuln = maxf(0.0, invuln - dt)
	_state_t += dt

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish := (global_basis * Vector3(input.x, 0, input.y))
	wish.y = 0
	wish = wish.normalized()
	var h_vel := Vector3(velocity.x, 0, velocity.z)
	var on_floor := is_on_floor()

	if on_floor:
		_coyote = COYOTE_TIME
		_air_jumps = MAX_AIR_JUMPS
	else:
		_coyote -= dt

	# --- 回避 ---
	if Input.is_action_just_pressed("dodge") and dodge_cooldown <= 0.0 and state != State.DODGE:
		_dodge_dir = wish if wish != Vector3.ZERO else -global_basis.z
		_dodge_dir.y = 0
		_dodge_dir = _dodge_dir.normalized()
		state = State.DODGE
		_state_t = 0.0
		invuln = DODGE_IFRAMES
		dodge_cooldown = DODGE_COOLDOWN

	match state:
		State.DODGE:
			velocity = _dodge_dir * DODGE_SPEED * speed_mult
			velocity.y = 0.0
			if _state_t >= DODGE_TIME:
				state = State.NORMAL
				velocity = _dodge_dir * DASH_SPEED * speed_mult
		State.SLIDE:
			_slide(dt, wish, on_floor)
		State.NORMAL:
			var dashing := Input.is_action_pressed("dash") and input.y < 0.3
			var target_speed := (DASH_SPEED if dashing else WALK_SPEED) * speed_mult
			var accel := GROUND_ACCEL if on_floor else AIR_ACCEL
			# 地上で今の速度が目標より速い場合(スライディング直後など)はゆっくり落とす
			if on_floor and h_vel.length() > target_speed + 0.5 and wish != Vector3.ZERO:
				accel = 12.0
			h_vel = h_vel.move_toward(wish * target_speed, accel * dt)
			velocity.x = h_vel.x
			velocity.z = h_vel.z
			if Input.is_action_just_pressed("crouch") and on_floor and h_vel.length() > WALK_SPEED * 0.9:
				state = State.SLIDE
				_state_t = 0.0
				var dir := h_vel.normalized()
				var speed := maxf(h_vel.length(), SLIDE_BOOST * speed_mult)
				velocity.x = dir.x * speed
				velocity.z = dir.z * speed

	# --- ジャンプ(二段まで) ---
	if Input.is_action_just_pressed("jump") and state != State.DODGE:
		if _coyote > 0.0:
			velocity.y = JUMP_VELOCITY
			_coyote = 0.0
			if state == State.SLIDE:
				state = State.NORMAL  # スライディングジャンプは勢いを保つ
		elif _air_jumps > 0:
			_air_jumps -= 1
			velocity.y = JUMP_VELOCITY * 0.95
			# 空中で向きを変える: 今の水平速度を入力方向へ振り向ける
			if wish != Vector3.ZERO:
				var hs := maxf(Vector2(velocity.x, velocity.z).length(), WALK_SPEED * speed_mult)
				velocity.x = wish.x * hs
				velocity.z = wish.z * hs

	if not is_on_floor() and state != State.DODGE:
		velocity.y -= GRAVITY * dt

	move_and_slide()
	_update_camera(dt)

	if global_position.y < -20.0:
		_respawn()


func _slide(dt: float, wish: Vector3, on_floor: bool) -> void:
	var h := Vector3(velocity.x, 0, velocity.z)
	var speed := h.length()
	var dir := h / maxf(speed, 0.001)
	# 少しだけ曲がれる
	if wish != Vector3.ZERO:
		dir = dir.slerp(wish, clampf(SLIDE_STEER * dt, 0.0, 1.0)).normalized()
	speed -= SLIDE_FRICTION * dt
	# 坂: 重力の斜面方向の成分で加速 / 減速
	if on_floor:
		var n := get_floor_normal()
		var g_along := Vector3(0, -GRAVITY, 0) - n * Vector3(0, -GRAVITY, 0).dot(n)
		g_along.y = 0
		speed += g_along.dot(dir) * dt * 1.4
	speed = minf(speed, 24.0)
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	if speed < SLIDE_MIN_SPEED * speed_mult or not Input.is_action_pressed("crouch"):
		state = State.NORMAL


func _update_camera(dt: float) -> void:
	var eye := SLIDE_EYE if state == State.SLIDE else STAND_EYE
	head.position.y = lerpf(head.position.y, eye, clampf(dt * 14.0, 0, 1))
	var hs := Vector2(velocity.x, velocity.z).length()
	var fov := BASE_FOV + clampf((hs - WALK_SPEED) * 0.9, 0.0, 14.0)
	if holder.aiming:
		fov -= 25.0
	camera.fov = lerpf(camera.fov, fov, clampf(dt * 10.0, 0, 1))
	var tilt := deg_to_rad(-6.0) if state == State.SLIDE else 0.0
	camera.rotation.z = lerpf(camera.rotation.z, tilt, clampf(dt * 10.0, 0, 1))
	# 反動の戻り
	if _recoil_pitch > 0.0:
		var back := minf(_recoil_pitch, dt * 10.0 * maxf(_recoil_pitch, 0.02))
		_recoil_pitch -= back
		head.rotation.x -= back


## 撃つたびに GunHolder から呼ばれる。視点を跳ね上げ、少しずつ戻す
func add_recoil(deg: float) -> void:
	var r := deg_to_rad(deg)
	head.rotation.x = clampf(head.rotation.x + r, deg_to_rad(-89), deg_to_rad(89))
	# 跳ね上がりの 85% は自動で戻る(残りはプレイヤーが押さえる)
	_recoil_pitch += r * 0.85
	rotate_y(deg_to_rad(randf_range(-0.25, 0.25) * deg))


func take_bullet_hit(amount: float) -> void:
	if invuln > 0.0 or hp <= 0.0:
		return
	hp -= amount
	damaged.emit(amount)
	if hp <= 0.0:
		deaths += 1
		died.emit()
		_respawn()


func _respawn() -> void:
	hp = max_hp
	global_position = _spawn_pos
	velocity = Vector3.ZERO
	state = State.NORMAL
	invuln = 1.5
