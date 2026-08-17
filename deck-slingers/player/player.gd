class_name Player extends CharacterBody3D

@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = %Camera3D

#region movement and camera
@export_group("Movement")
@export var walk_speed := 7.0
@export var sprint_speed := 8.5
@export var jump_velocity := 6.0

@export_group("Mouse Look")
@export var vertical_mouse_sensitivity := 0.003
@export var horizontal_mouse_sensitivity := 0.003

@export_group("Controller Look")
@export var vertical_controller_sensitivity := 3.0
@export var horizontal_controller_sensitivity := 3.0
@export var controller_deadzone := 0.15

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
	if not is_on_floor():
		velocity.y -= gravity * delta
		
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward").normalized()
	var wish_dir := (global_transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()\
		if input_dir != Vector2.ZERO else Vector3.ZERO
	var current_speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y += jump_velocity
		
	velocity.x = wish_dir.x * current_speed
	velocity.z = wish_dir.z * current_speed
	
	move_and_slide()
	
