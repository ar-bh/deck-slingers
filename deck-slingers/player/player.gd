class_name Player extends CharacterBody3D

#region movement + camera
@export_group("Movement and Camera")
@export var max_speed := 20.0
@export var jump_velocity := 4.5
@export var horizontal_sensitivity := 50
@export var vertical_sensitivity := 50.0
@export var steering_factor := 20.0

var mouse_is_playing := false

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity") * Vector3.DOWN

@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = %Camera3D
#endregion

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event):
	#region setting mouse mode
	if event is InputEventMouseButton:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		mouse_is_playing = true
	elif event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		mouse_is_playing = false
	#endregion

	if mouse_is_playing and event is InputEventMouseMotion:
		rotation_degrees.y -= event.relative.x * horizontal_sensitivity / 100.0
		_head.rotation_degrees.x -= event.relative.y * vertical_sensitivity / 100.0
		_head.rotation_degrees.x = clamp(
			_head.rotation_degrees.x, -90.0, 90.0
		)

func _physics_process(delta):
	if not is_on_floor():
		velocity += gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y += jump_velocity
		
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_vector.x, 0.0, input_vector.y))
	
	var desired_velocity := direction * max_speed
	var steering := desired_velocity - Vector3(velocity.x, 0.0, velocity.z)
	
	velocity.x += steering.x * steering_factor * delta
	velocity.z += steering.z * steering_factor * delta
	
	move_and_slide()
