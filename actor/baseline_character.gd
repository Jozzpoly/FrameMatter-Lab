class_name BaselineCharacter
extends CharacterBody3D

var gravity_acceleration: float = 18.0
var desired_horizontal_velocity: Vector3 = Vector3.ZERO
var jump_speed: float = 6.0
var jump_requested: bool = false

var observed_on_floor: bool = false
var observed_platform_velocity: Vector3 = Vector3.ZERO
var observed_platform_angular_velocity: Vector3 = Vector3.ZERO
var observed_real_velocity: Vector3 = Vector3.ZERO


func configure_default_shape() -> void:
	for child in get_children():
		if child is CollisionShape3D:
			return
	var collision_shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.6, 1.8, 0.6)
	collision_shape.shape = box
	add_child(collision_shape)


func request_jump() -> void:
	jump_requested = true


func _physics_process(delta: float) -> void:
	velocity.x = desired_horizontal_velocity.x
	velocity.z = desired_horizontal_velocity.z

	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = 0.0
		if jump_requested:
			velocity.y = jump_speed
	else:
		velocity.y -= gravity_acceleration * delta

	move_and_slide()

	observed_on_floor = is_on_floor()
	observed_platform_velocity = get_platform_velocity()
	observed_platform_angular_velocity = get_platform_angular_velocity()
	observed_real_velocity = get_real_velocity()
	jump_requested = false
