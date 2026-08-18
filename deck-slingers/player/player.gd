class_name Player extends CharacterBody3D

@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = %Camera3D

#region movement variables
@export_group("Movement")
@export var walk_speed := 10.0
@export var ground_acceleration := 100.0
@export var air_acceleration := 20.0
@export var max_move_speed := 28.0
@export var dash_enabled := true
@export var slide_enabled := true
@export var bhop_decay := 2.0
#endregion

#region jump & gravity variables
@export_group("Jump & Gravity")
@export var gravity_up := 18.5
@export var gravity_down := 2.0 * gravity_up
@export var jump_velocity := 10.0
@export var max_fall_speed := 50.0
#endregion

#region mouse look variables
@export_group("Mouse Look")
@export var vertical_mouse_sensitivity := 0.003
@export var horizontal_mouse_sensitivity := 0.003
#endregion

#region controller look variables
@export_group("Controller Look")
@export var vertical_controller_sensitivity := 5.0
@export var horizontal_controller_sensitivity := 5.0
@export var controller_deadzone := 0.15
#endregion

#region dash movement variables
@export_group("Dash")
@export var dash_speed := 200.0
@export var dash_duration := 0.3
@export var dash_cooldown := 0.4
@export var dash_speed_curve: Curve


var _dash_hop_ready := false
var _dash_time_left := 0.0
var _dash_cooldown_left := 0.0
var _dash_direction := Vector3.ZERO
var _dash_carried_speed := 0.0
#endregion

#region slide movement variables
@export_group("Slide")
@export var slide_boost := 40.0
@export var slide_friction := 18.0
@export var stand_head_height := 1.79
@export var crouch_head_height := 0.85
@export var crouch_lerp := 12.0


var _sliding := false
#endregion

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# camera stuff
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
	#region controller looking
	var look_dir := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look_dir.length() > controller_deadzone:
		rotate_y(-look_dir.x * horizontal_controller_sensitivity * delta)
		_camera.rotate_x(-look_dir.y * vertical_controller_sensitivity * delta)
		_camera.rotation.x = clamp(_camera.rotation.x, deg_to_rad(-90), deg_to_rad(90))
	#endregion

func _physics_process(delta: float) -> void:
	%VelocityLabel.text = str(int(Vector3(velocity.x, 0.0, velocity.z).length()))
	
	#region dash ticks and cooldown
	if dash_enabled:
		if _dash_cooldown_left > 0.0:
			_dash_cooldown_left -= delta
			
		if _dash_time_left > 0.0:
			_dash_time_left -= delta
			var t := 1.0 - (_dash_time_left / dash_duration) # percentage form of how much of dash is done, to use in curve
			t = clampf(t, 0.0, 1.0)
			velocity = _dash_direction * (_dash_carried_speed + dash_speed * dash_speed_curve.sample(t))
			if _dash_time_left > 0.0:
				move_and_slide()
				return
	#endregion
	
	_apply_gravity(delta)
	
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward").normalized()
	var wish_dir := _wish_dir(input_dir)
	
	#region start dash
	if dash_enabled and Input.is_action_just_pressed("dash") and _dash_cooldown_left <= 0.0:
		var dir := Vector3.ZERO
		if is_on_floor():
			dir = wish_dir
			if dir.length_squared() < 0.001:
				dir = -global_transform.basis.z
			dir.y = 0.0
		else:
			if input_dir != Vector2.ZERO:
				dir = _camera.global_transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)
			else:
				dir = -_camera.global_transform.basis.z
		dir = dir.normalized()
		_dash_direction = dir
		_dash_carried_speed = velocity.length()
		_dash_time_left = dash_duration
		_dash_cooldown_left = dash_cooldown
		_dash_hop_ready = true
		velocity = _dash_direction * (_dash_carried_speed + dash_speed * dash_speed_curve.sample(0.0))
		move_and_slide()
		return
	#endregion
	
	#region start slide
	if slide_enabled and not _sliding and is_on_floor() and wish_dir != Vector3.ZERO \
			and Input.is_action_pressed("crouch"):
		_sliding = true
		var carried := Vector3(velocity.x, 0.0, velocity.z).length()
		velocity.x += wish_dir.x * (carried + slide_boost)
		velocity.z += wish_dir.z * (carried + slide_boost)
		
	if not slide_enabled:
		_sliding = false
	#endregion
	
	var hopped := false
	if is_on_floor() and Input.is_action_pressed("jump"):
		_sliding = false
		_dash_hop_ready = false
		var dir := wish_dir
		if dir == Vector3.ZERO:
			dir = Vector3(-global_transform.basis.z.x, 0.0, -global_transform.basis.z.z).normalized()
		var carried := Vector3(velocity.x, 0.0, velocity.z).length()
		velocity.x = dir.x * carried
		velocity.z = dir.z * carried
		velocity.y = jump_velocity
		hopped = true
		
	#region slide camera
	if slide_enabled:
		var crouched := is_on_floor() and (
			_sliding or (Input.is_action_pressed("crouch") and wish_dir == Vector3.ZERO)
		)
		_update_slide_camera(delta, crouched)
	else:
		_update_slide_camera(delta, false)
	#endregion
	
	if is_on_floor() and not hopped and not _sliding:
		_dash_hop_ready = false
		var target := wish_dir * walk_speed
		velocity.x = move_toward(velocity.x, target.x, ground_acceleration * delta)
		velocity.z = move_toward(velocity.z, target.z, ground_acceleration * delta)
	elif is_on_floor() and not hopped and _sliding:
		velocity.x = move_toward(velocity.x, 0.0, slide_friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, slide_friction * delta)
	else:
		if wish_dir != Vector3.ZERO:
			var along := velocity.dot(wish_dir)
			var add := walk_speed - along
			if add > 0.0:
				velocity += wish_dir * minf(add, air_acceleration * delta)
		var air_h := Vector3(velocity.x, 0.0, velocity.z)
		var air_speed := air_h.length()
		if air_speed > walk_speed:
			air_h = air_h.move_toward(air_h.normalized() * walk_speed, bhop_decay * delta)
			velocity.x = air_h.x
			velocity.z = air_h.z
	
	var horiz := Vector3(velocity.x, 0.0, velocity.z)
	var speed := horiz.length()
	if speed > max_move_speed:
		horiz *= max_move_speed / speed
		velocity.x = horiz.x
		velocity.z = horiz.z
	if _sliding and is_on_floor() and speed < walk_speed:
		_sliding = false
	
	move_and_slide()
	
func _update_slide_camera(delta: float, crouched: bool) -> void:
	var target_y := crouch_head_height if crouched else stand_head_height
	var pos := _head.position
	pos.y = lerpf(pos.y, target_y, 1.0 - exp(-crouch_lerp * delta))
	_head.position = pos

func _wish_dir(input_dir: Vector2) -> Vector3:
	return (global_transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized() \
		if input_dir != Vector2.ZERO else Vector3.ZERO

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		var g := gravity_down if velocity.y < 0.0 else gravity_up
		velocity.y -= g * delta
		velocity.y = maxf(velocity.y, -max_fall_speed)
