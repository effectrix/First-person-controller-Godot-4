class_name Player
extends CharacterBody3D

signal state_changed(new_state)

enum States{
	IDLE, WALK, RUN, CROUCH, CROUCHWALK, IN_AIR, IN_WATER,
}

enum BodyCollisionType{
	STAND, CROUCH,
}

const GRAVITY: float = 9.8
const GRAVITY_IN_WATER: float = 3.3

const WALK_FORWARD_SPEED: float = 2.0
const WALK_FORWARD_SLOW_SPEED: float = 1.4
const WALK_BACKWARD_SPEED: float = 1.5
const WALK_STRAFE_SPEED: float = 1.75

const RUN_FORWARD_SPEED: float = 4.0
const RUN_BACKWARD_SPEED: float = 3.0
const RUN_STRAFE_SPEED: float = 3.5

const CROUCHWALK_FORWARD_SPEED: float = 1.2
const CROUCHWALK_BACKWARD_SPEED: float = 1.0
const CROUCHWALK_STRAFE_SPEED: float = 0.75

const IN_AIR_SPEED: int = 3

const IN_WATER_SPEED: float = 2.0
const IN_WATER_FAST_SPEED: float = 4.0 

const ACCEL_ON_GROUND: int = 14
const ACCEL_IN_AIR: int = 1
const ACCEL_IN_WATER: int = 4

const JUMP_COOLDOWN: float = 0.5

const CAMERA_CROUCH_Y_OFFSET: float = 0.5
const CAMERA_CROUCH_TWEEN_DURATION: float = 0.5

const MAX_STATE_HISTORY_SIZE: int = 3

var is_input_locked: bool = false
var is_gravity_active: bool = true

var is_moving: bool = false 
var is_moving_forward: bool = false
var is_moving_backward: bool = false
var is_moving_strafe: bool = false
var is_running: bool = false
var is_crouching: bool = false
var is_slow_walking: bool = false
var is_in_air: bool = false
var is_jumping: bool = false
var has_jumped: bool = false
var is_in_water: bool = false
var is_underwater: bool = false

var active_state: int = States.IDLE
var state_history: Array = []

var h_rot: float = 0.0
var z_input: float = 0.0
var x_input: float = 0.0
var y_input: float = 0.0
var mouse_rot_x: float = 0.0
var mouse_rot_y: float = 0.0
var mouse_sensitivity: float = 0.1
var mouse_rotation: Vector2

var v_min_camera_rot: float = -1.5708 #-PI/2
var v_max_camera_rot: float = 1.5708 #PI/2

var acceleration: int = 0
var speed: float = 0
var jump_amount: int = 5
#var snap: Vector3 = Vector3.ZERO
var direction: Vector3 = Vector3.ZERO
var _velocity: Vector3 = Vector3.ZERO
var gravity_vec: Vector3 = Vector3.ZERO
var movement: Vector3 = Vector3.ZERO

@onready var body: Node3D = $Body as Node3D
@onready var head: Node3D = $Body/Head as Node3D
@onready var camera: Node3D = $Body/Head/Camera3D as Camera3D
@onready var collision_stand: CollisionShape3D = $CollisionStand as CollisionShape3D
@onready var collision_crouch: CollisionShape3D = $CollisionCrouch as CollisionShape3D
@onready var jump_timer: Timer = $JumpCooldown as Timer



func _init() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	_get_input()
	match active_state:
		States.IDLE:
			idle_state(delta)
		States.WALK:
			walk_state(delta)
		States.RUN:
			run_state(delta)
		States.CROUCH:
			crouch_state(delta)
		States.CROUCHWALK:
			crouchwalk_state(delta)
		States.IN_AIR:
			in_air_state(delta)
		States.IN_WATER:
			in_water_state(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		mouse_rot_x = -(event as InputEventMouseMotion).relative.x * mouse_sensitivity
		mouse_rot_y = -(event as InputEventMouseMotion).relative.y * mouse_sensitivity
		mouse_rotation = Vector2(-event.relative.x, -event.relative.y)
		body.rotate_y(deg_to_rad(mouse_rot_x))
		head.rotate_x(deg_to_rad(mouse_rot_y))
		head.rotation.x = clamp(head.rotation.x, v_min_camera_rot, v_max_camera_rot)
	if event is InputEventKey:
		if event.is_action_pressed("ui_cancel"):
			is_input_locked = false if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE else true
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE else Input.MOUSE_MODE_VISIBLE


func _get_input() -> void:
	if is_input_locked:
		return
	h_rot = body.global_transform.basis.get_euler().y
	z_input = Input.get_action_strength("move_backward") - Input.get_action_strength("move_forward")
	x_input = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	y_input = camera.global_transform.basis.z.dot(Vector3.UP) * z_input
	direction = Vector3.ZERO
	if z_input > 0.0:
		is_moving_backward = true
		is_moving = true
	elif x_input != 0.0:
		is_moving_strafe = true
		is_moving = true
	elif z_input < 0.0:
		is_moving_forward = true
		is_moving = true
	else:
		is_moving_backward = false
		is_moving_strafe = false
		is_moving_forward = false
		is_moving = false
	is_running = true if Input.is_action_pressed("run") else false
	is_crouching = true if Input.is_action_pressed("crouch") else false
	is_jumping = true if Input.is_action_just_pressed("jump") else false
	is_slow_walking = true if Input.is_action_pressed("walk") else false


func apply_jump_walk() -> void:
#	snap = Vector3.ZERO
	gravity_vec = _velocity.normalized() * 0.1 * Vector3.UP
	gravity_vec *= speed * 1.7


func apply_jump() -> void:
	has_jumped = true
#	snap = Vector3.ZERO
	gravity_vec = Vector3.UP
	gravity_vec *= jump_amount
	jump_timer.start(JUMP_COOLDOWN)


func apply_gravity(delta: float, new_accel: int, gravity_scale: float = 1.0) -> void:
#	snap = Vector3.ZERO
	if is_gravity_active:
		acceleration = new_accel
		if active_state == States.IN_AIR:
			gravity_vec += Vector3.DOWN * GRAVITY * gravity_scale * delta
		else:
			gravity_vec += Vector3.DOWN * GRAVITY_IN_WATER * gravity_scale * delta


func disable_gravity(new_accel: int) -> void:
#	snap = -get_floor_normal()
	acceleration = new_accel
	gravity_vec = Vector3.ZERO


func set_body_collision_type(new_type: int) -> void:
	var is_stand_active: bool = true if new_type == BodyCollisionType.STAND else false
	collision_stand.set_deferred("disabled", is_stand_active)
	collision_crouch.set_deferred("disabled", is_stand_active)


func get_body_collision_type() -> int:
	return BodyCollisionType.CROUCH if collision_stand.disabled else BodyCollisionType.STAND


func apply_move_and_slide(delta: float) -> void:
	_velocity = _velocity.lerp(direction * speed, acceleration * delta)
	movement = _velocity + gravity_vec
	velocity = movement
	move_and_slide()


func update_state(new_state: int) -> void:
	exit_state(active_state, new_state)
	enter_state(new_state)
	if state_history.size() > MAX_STATE_HISTORY_SIZE:
		state_history.pop_front()
	state_history.append(active_state)
	active_state = new_state
	emit_signal("state_changed", str(States.keys()[active_state]))


func get_previous_state() -> int:
	return state_history.back()


func enter_state(new_state: int) -> void:
	match new_state:
		States.IDLE:
			acceleration = ACCEL_ON_GROUND
		States.WALK:
			acceleration = ACCEL_ON_GROUND
		States.RUN:
			acceleration = ACCEL_ON_GROUND
		States.CROUCH:
			acceleration = ACCEL_ON_GROUND
			play_camera_crouch_anim(true)
		States.CROUCHWALK:
			acceleration = ACCEL_ON_GROUND
			play_camera_crouch_anim(true)
		States.IN_AIR:
			acceleration = ACCEL_IN_AIR
		States.IN_WATER:
			acceleration = ACCEL_IN_WATER


func exit_state(prev_state: int, new_state: int) -> void:
	match new_state:
		States.IDLE:
			if prev_state == States.CROUCH or prev_state == States.CROUCHWALK:
				play_camera_crouch_anim(false)
		States.WALK:
			if prev_state == States.CROUCH or prev_state == States.CROUCHWALK:
				play_camera_crouch_anim(false)
		States.RUN:
			if prev_state == States.CROUCH or prev_state == States.CROUCHWALK:
				play_camera_crouch_anim(false)
		States.CROUCH:
			pass
		States.CROUCHWALK:
			pass
		States.IN_AIR:
			pass
		States.IN_WATER:
			pass
	


func idle_state(delta: float) -> void:
	direction = Vector3(x_input, 0.0, z_input).rotated(Vector3.UP, h_rot).normalized()
#	direction = Vector3.ZERO
	if !is_on_floor():
		update_state(States.IN_AIR)
	elif is_in_water:
		update_state(States.IN_WATER)
	elif is_crouching:
		set_body_collision_type(BodyCollisionType.CROUCH)
		update_state(States.CROUCH)
	elif is_jumping and !has_jumped:
		apply_jump()
		update_state(States.IN_AIR)
	elif is_moving:
		if is_crouching:
			set_body_collision_type(BodyCollisionType.CROUCH)
			update_state(States.CROUCHWALK)
		elif is_running:
			update_state(States.RUN)
		elif is_jumping and !has_jumped:
			apply_jump()
			update_state(States.IN_AIR)
		else:
			update_state(States.WALK)
	apply_move_and_slide(delta)


func walk_state(delta: float) -> void:
	direction = Vector3(x_input, 0.0, z_input).rotated(Vector3.UP, h_rot).normalized()
	if is_slow_walking:
		speed = WALK_FORWARD_SLOW_SPEED
	elif is_moving_forward:
		speed = WALK_FORWARD_SPEED
	elif is_moving_strafe:
		speed = WALK_STRAFE_SPEED
	elif is_moving_backward:
		speed = WALK_BACKWARD_SPEED
	if !is_on_floor():
		update_state(States.IN_AIR)
	elif is_in_water:
		update_state(States.IN_WATER)
	elif !is_moving:
		update_state(States.IDLE)
	elif is_crouching:
		set_body_collision_type(BodyCollisionType.CROUCH)
		update_state(States.CROUCHWALK)
	elif is_running:
		update_state(States.RUN)
	elif is_jumping and !has_jumped:
		apply_jump()
		update_state(States.IN_AIR)
	apply_move_and_slide(delta)


func run_state(delta: float) -> void:
	direction = Vector3(x_input, 0.0, z_input).rotated(Vector3.UP, h_rot).normalized()
	if is_moving_forward:
		speed = RUN_FORWARD_SPEED
	elif is_moving_strafe:
		speed = RUN_STRAFE_SPEED
	elif is_moving_backward:
		speed = RUN_BACKWARD_SPEED
	if !is_on_floor():
		update_state(States.IN_AIR)
	elif is_in_water:
		update_state(States.IN_WATER)
	elif is_jumping:
		apply_jump()
		update_state(States.IN_AIR)
	elif !is_running:
		update_state(States.WALK)
	elif !is_moving:
		update_state(States.IDLE)
	apply_move_and_slide(delta)


func crouch_state(delta: float) -> void:
	direction = Vector3(x_input, 0.0, z_input).rotated(Vector3.UP, h_rot).normalized()
	if !is_on_floor():
		update_state(States.IN_AIR)
	elif is_in_water:
		update_state(States.IN_WATER)
	elif is_moving:
		update_state(States.CROUCHWALK)
	elif !is_crouching:
		if !is_moving:
			update_state(States.IDLE)
		elif is_moving:
			update_state(States.WALK)
	apply_move_and_slide(delta)


func crouchwalk_state(delta: float) -> void:
	direction = Vector3(x_input, 0.0, z_input).rotated(Vector3.UP, h_rot).normalized()
	if is_moving_strafe:
		speed = CROUCHWALK_STRAFE_SPEED
	elif is_moving_backward:
		speed = CROUCHWALK_BACKWARD_SPEED
	elif is_moving_forward:
		speed = CROUCHWALK_FORWARD_SPEED
	if !is_on_floor():
		update_state(States.IN_AIR)
	elif is_in_water:
		update_state(States.IN_WATER)
	elif !is_moving:
		update_state(States.CROUCH)
	elif !is_crouching:
		if is_moving:
			update_state(States.WALK)
		else:
			update_state(States.IDLE)
	apply_move_and_slide(delta)


func in_air_state(delta: float) -> void:
	direction = Vector3(x_input, 0.0, z_input).rotated(Vector3.UP, h_rot).normalized()
	if is_on_floor():
		if is_moving:
			if is_crouching:
				set_body_collision_type(BodyCollisionType.CROUCH)
				update_state(States.CROUCH)
			else:
				update_state(get_previous_state())
		elif !is_moving:
			if is_crouching:
				set_body_collision_type(BodyCollisionType.CROUCH)
				update_state(States.CROUCH)
			else:
				update_state(States.IDLE)
	elif is_in_water:
		update_state(States.IN_WATER)
	else:
		apply_gravity(delta, ACCEL_IN_AIR)
	apply_move_and_slide(delta)


func in_water_state(delta: float) -> void:
	if is_jumping:
		y_input = 1.0
	elif is_crouching:
		y_input = -1.0
	direction = Vector3(x_input, y_input, z_input).rotated(Vector3.UP, h_rot).normalized()
	if !is_in_water and is_on_floor():
		if is_moving:
			update_state(States.WALK)
		elif !is_moving:
			update_state(States.IDLE)
		else:
			update_state(States.IN_AIR)
	if is_running:
		speed = IN_WATER_FAST_SPEED
	else:
		speed = IN_WATER_SPEED
	apply_move_and_slide(delta)


func play_camera_crouch_anim(to_crouch: bool) -> void:
	var tween: Tween = create_tween().bind_node(camera)
	var y_pos: float = 0.0
	if to_crouch:
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		y_pos = -CAMERA_CROUCH_Y_OFFSET
	else:
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(tween.TRANS_CUBIC)
		y_pos += CAMERA_CROUCH_Y_OFFSET
	tween.tween_property(camera, "position:y", y_pos, CAMERA_CROUCH_TWEEN_DURATION)


func _on_jump_cooldown_timeout() -> void:
	has_jumped = false
