class_name Player extends CharacterBody3D

@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = %Camera3D

#region movement and camera
@export_group("Movement")
@export var walk_speed := 7.0
@export var jump_velocity := 6.0
@export var dash_speed := 75.0
@export var dash_duration := 0.15
@export var dash_cooldown := 0.4
@export var dash_speed_curve: Curve

@export_group("Mouse Look")
@export var vertical_mouse_sensitivity := 0.003
@export var horizontal_mouse_sensitivity := 0.003

@export_group("Controller Look")
@export var vertical_controller_sensitivity := 3.0
@export var horizontal_controller_sensitivity := 3.0
@export var controller_deadzone := 0.15

var gravity: float = 12.5
var _dash_time_left := 0.0
var _dash_cooldown_left := 0.0
var _dash_direction := Vector3.ZERO
#endregion

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED and event is InputEventMouseMotion:
		rotate_y(-event.relative.x * horizontal_mouse_sensitivity)
		_camera.rotate_x(-event.relative.y * vertical_mouse_sensitivity)
		_camera.rotation.x = clamp(_camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))
		
func _process(delta: float) -> void:
	#region controller support
	var look_dir := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look_dir.length() > controller_deadzone:
		rotate_y(-look_dir.x * horizontal_controller_sensitivity * delta)
		_camera.rotate_x(-look_dir.y * vertical_controller_sensitivity * delta)
		_camera.rotation.x = clamp(_camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))
	#endregion
	
func _physics_process(delta: float) -> void:
	if _dash_cooldown_left > 0.0:
		_dash_cooldown_left -= delta
	
	if _dash_time_left > 0.0:
		_dash_time_left -= delta
		# this makes t a percent basically from 0% to 100% in terms of how much dash is completed,
		# to match with the curve
		var t := 1.0 - (_dash_time_left / dash_duration)
		t = clampf(t, 0.0, 1.0)
		velocity = _dash_direction * dash_speed * dash_speed_curve.sample(t)
		if _dash_time_left > 0.0:
			move_and_slide()
			return
		
	if not is_on_floor():
		velocity.y -= gravity * delta
		
	# dash is starting
	if Input.is_action_just_pressed("dash") and _dash_cooldown_left <= 0.0:
		var dir := -_camera.global_transform.basis.z
		if is_on_floor():
			dir.y = 0.0
		if dir.length_squared() < 0.0001:
			dir = -global_transform.basis.z
			dir.y = 0.0
		dir = dir.normalized()
		_dash_direction = dir
		_dash_time_left = dash_duration
		_dash_cooldown_left = dash_cooldown
		velocity = _dash_direction * dash_speed * dash_speed_curve.sample(0.0)
		move_and_slide()
		return
		
		
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward").normalized()
	var wish_dir := (global_transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()\
		if input_dir != Vector2.ZERO else Vector3.ZERO
	var current_speed := walk_speed
	
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y += jump_velocity
		
	velocity.x = wish_dir.x * current_speed
	velocity.z = wish_dir.z * current_speed
	
	move_and_slide()
	
