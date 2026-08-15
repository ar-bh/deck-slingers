class_name Player extends CharacterBody3D

@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = %Camera3D

@export var vertical_look_sensitivity: float = 0.006
@export var horizontal_look_sensitivity: float = 0.006
@export var vertical_controller_look_sensitivity: float = 0.03
@export var horizontal_controller_look_sensitivity: float = 0.03


@export var jump_velocity := 6.0
@export var auto_bhop := true
@export var walk_speed := 7.0
@export var sprint_speed := 8.5

@export_group("Headbob")
@export var headbob_enabled := false
@export var headbob_move_amount: = 0.06
@export var headbob_frequency := 2.4
@export var headbob_time := 0.0

var wish_dir := Vector3.ZERO

func get_move_speed() -> float:
	return sprint_speed if Input.is_action_pressed("sprint") else walk_speed

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event) -> void:
	if event is InputEventMouseButton:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			rotate_y(-event.relative.x * horizontal_look_sensitivity)
			_camera.rotate_x(-event.relative.y * vertical_look_sensitivity)
			_camera.rotation.x = clamp(_camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))

func _headbob_effect(delta: float) -> void:
	headbob_time += delta * velocity.length()
	_camera.transform.origin = Vector3(
		cos(headbob_time * headbob_frequency * 0.5) * headbob_move_amount,
		sin(headbob_time * headbob_frequency) * headbob_move_amount,
		0
	)

var _cur_controller_look := Vector2()
func _handle_controller_look_input(delta: float) -> void:
	var target_look := Input.get_vector("look_left", "look_right", "look_down", "look_up").normalized()
	_cur_controller_look = target_look
	
	rotate_y(-_cur_controller_look.x * horizontal_controller_look_sensitivity)
	_camera.rotate_x(_cur_controller_look.y * vertical_controller_look_sensitivity)
	_camera.rotation.x = clamp(_camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))

func _process(delta: float) -> void:
	_handle_controller_look_input(delta)

func _handle_air_physics(delta: float) -> void:
	velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
	
func _handle_ground_physics(delta: float) -> void:
	velocity.x = wish_dir.x * get_move_speed()
	velocity.z = wish_dir.z * get_move_speed()
	
	if headbob_enabled:
		_headbob_effect(delta)

func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward").normalized()
	wish_dir = global_transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)
	
	if is_on_floor():
		if Input.is_action_just_pressed("jump") or (auto_bhop and Input.is_action_pressed("jump")):
			velocity.y = jump_velocity
		_handle_ground_physics(delta)
	else:
		_handle_air_physics(delta)
		
	move_and_slide()
