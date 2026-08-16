class_name Player extends CharacterBody3D

@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = %Camera3D

#region movement and camera settings
@export_group("Ground Movement")
@export var walk_speed := 7.0
@export var sprint_speed := 8.5
@export var jump_velocity := 6.0
@export var auto_bhop = true

@export_group("Air Physics")
@export var air_cap := 0.5 # the speed limit added per frame in the air
@export var air_accel := 800.0 # acceleration multipler in the air
@export var air_move_speed := 500.0

@export_group("Mouse Look")
@export var vertical_mouse_sensitivity := 0.003
@export var horizontal_mouse_sensitivity := 0.003

@export_group("Controller Look")
@export var vertical_controller_sensitivity := 3.0
@export var horizontal_controller_sensitivity := 3.0
@export var controller_deadzone = 0.15

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
#endregion

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED and event is InputEventMouseMotion:
		_handle_mouse_look(event.relative)
		
func _process(delta: float) -> void:
	_handle_controller_look(delta)
	
func _physics_process(delta: float) -> void:
	var wish_dir := _get_wish_dir()
	
	if is_on_floor():
		_handle_ground_physics(wish_dir)
	else:
		_handle_air_physics(wish_dir, delta)
		
	move_and_slide()
		
#region camera control funcs
func _handle_mouse_look(relative_motion: Vector2) -> void:
	rotate_y(-relative_motion.x * horizontal_mouse_sensitivity)
	_camera.rotate_x(-relative_motion.y * vertical_mouse_sensitivity)
	_camera.rotation.x = clamp(_camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))
	
func _handle_controller_look(delta: float) -> void:
	var look_dir := Input.get_vector("look_left", "look_right", "look_up", "look_down").normalized()
	
	if look_dir.length() > controller_deadzone:
		rotate_y(-look_dir.x * horizontal_controller_sensitivity * delta)
		_camera.rotate_x(look_dir.y * vertical_controller_sensitivity * delta)
		_camera.rotation.x = clamp(_camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))
#endregion
	
#region movement funcs
func _get_wish_dir() -> Vector3:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward").normalized()
	if input_dir == Vector2.ZERO:
		return Vector3.ZERO
		
	return (global_transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	
func _handle_ground_physics(wish_dir: Vector3) -> void:
	
	var target_speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed	
	
	if Input.is_action_just_pressed("jump") or (auto_bhop and Input.is_action_pressed("jump")):
		velocity.y += jump_velocity
		
		var jump_dir := wish_dir if wish_dir != Vector3.ZERO else -global_transform.basis.z
		velocity.x = jump_dir.x * target_speed
		velocity.z = jump_dir.z * target_speed
		
	else:
		velocity.x = wish_dir.x * target_speed
		velocity.z = wish_dir.z * target_speed
		
func _handle_air_physics(wish_dir: Vector3, delta: float) -> void:
	velocity.y -= gravity * delta
	if wish_dir != Vector3.ZERO:
		var cur_speed_in_wish_dir := velocity.dot(wish_dir)
		var capped_speed = min((air_move_speed * wish_dir).length(), air_cap)
		var add_speed_till_cap = capped_speed - cur_speed_in_wish_dir
		
		if add_speed_till_cap > 0.0:
			var accel_speed := air_accel * air_move_speed * delta
			accel_speed = min(accel_speed, add_speed_till_cap)
			velocity += accel_speed * wish_dir

#endregion
