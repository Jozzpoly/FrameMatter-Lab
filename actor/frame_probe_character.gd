class_name FrameProbeCharacter
extends Node3D

var gravity_acceleration: float = 18.0
var jump_speed: float = 6.0
var half_height: float = 0.9
var ground_probe_distance: float = 0.4
var ground_skin: float = 0.002
var ground_normal_min_y: float = 0.7
var desired_local_velocity: Vector3 = Vector3.ZERO
var jump_requested: bool = false

var grounded: bool = false
var support_body: Node3D
var support_local_center: Vector3 = Vector3.ZERO
var world_velocity: Vector3 = Vector3.ZERO

var observed_support_velocity: Vector3 = Vector3.ZERO
var observed_ground_acquisitions: int = 0
var observed_recontacts: int = 0
var observed_support_transfers: int = 0

var _previous_support_point_world: Vector3 = Vector3.ZERO
var _has_grounded_before: bool = false


func request_jump() -> void:
	jump_requested = true


func transfer_support_frame(new_support: Node3D, mapped_local_center: Vector3) -> bool:
	if not grounded:
		return false
	if new_support == null or not is_instance_valid(new_support):
		return false

	# A topology handoff is not a fresh contact acquisition. The caller owns the
	# parent→successor mapping and supplies the corresponding local support point.
	support_body = new_support
	support_local_center = mapped_local_center
	global_position = support_body.to_global(support_local_center)
	_previous_support_point_world = global_position
	world_velocity = _rigid_velocity_at_point(support_body, global_position)
	observed_support_velocity = world_velocity
	observed_support_transfers += 1
	return true


func _physics_process(delta: float) -> void:
	if grounded:
		_step_grounded(delta)
	else:
		_step_airborne(delta)
	jump_requested = false


func _step_grounded(delta: float) -> void:
	if support_body == null or not is_instance_valid(support_body):
		_detach_from_support()
		_step_airborne(delta)
		return

	var old_anchor_world: Vector3 = support_body.to_global(support_local_center)
	var support_velocity: Vector3 = Vector3.ZERO
	if delta > 0.0:
		support_velocity = (old_anchor_world - _previous_support_point_world) / delta
	observed_support_velocity = support_velocity

	# Advance to the current support-frame pose before applying actor intent.
	global_position = old_anchor_world

	if jump_requested:
		var desired_world: Vector3 = support_body.global_transform.basis * desired_local_velocity
		world_velocity = support_velocity + desired_world + Vector3.UP * jump_speed
		_detach_from_support(false)
		world_velocity.y -= gravity_acceleration * delta
		global_position += world_velocity * delta
		return

	support_local_center += desired_local_velocity * delta
	global_position = support_body.to_global(support_local_center)
	world_velocity = support_velocity + support_body.global_transform.basis * desired_local_velocity

	var hit: Dictionary = _probe_ground()
	if not _valid_ground_hit(hit):
		_previous_support_point_world = global_position
		_detach_from_support(false)
		return

	var hit_body: Node3D = hit["collider"] as Node3D
	if hit_body != support_body:
		_attach_to_hit(hit)
		return

	_snap_to_hit(hit)
	_previous_support_point_world = global_position


func _step_airborne(delta: float) -> void:
	world_velocity.y -= gravity_acceleration * delta
	global_position += world_velocity * delta

	if world_velocity.y > 0.0:
		return

	var hit: Dictionary = _probe_ground()
	if _valid_ground_hit(hit):
		_attach_to_hit(hit)


func _probe_ground() -> Dictionary:
	var ray_from: Vector3 = global_position + Vector3.UP * 0.05
	var ray_to: Vector3 = global_position - Vector3.UP * (half_height + ground_probe_distance)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_from, ray_to)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	return get_world_3d().direct_space_state.intersect_ray(query)


func _valid_ground_hit(hit: Dictionary) -> bool:
	if hit.is_empty():
		return false
	var collider: Node3D = hit["collider"] as Node3D
	if collider == null:
		return false
	var normal: Vector3 = Vector3(hit["normal"])
	return normal.y >= ground_normal_min_y


func _attach_to_hit(hit: Dictionary) -> void:
	var collider: Node3D = hit["collider"] as Node3D
	if collider == null:
		return

	support_body = collider
	grounded = true
	_snap_to_hit(hit)
	support_local_center = support_body.to_local(global_position)
	_previous_support_point_world = global_position
	world_velocity = _rigid_velocity_at_point(support_body, global_position)
	observed_support_velocity = world_velocity
	observed_ground_acquisitions += 1

	if _has_grounded_before:
		observed_recontacts += 1
	else:
		_has_grounded_before = true


func _snap_to_hit(hit: Dictionary) -> void:
	var hit_position: Vector3 = Vector3(hit["position"])
	var hit_normal: Vector3 = Vector3(hit["normal"]).normalized()
	global_position = hit_position + hit_normal * (half_height + ground_skin)
	if support_body != null and is_instance_valid(support_body):
		support_local_center = support_body.to_local(global_position)


func _detach_from_support(preserve_velocity: bool = true) -> void:
	if preserve_velocity and support_body != null and is_instance_valid(support_body):
		world_velocity = _rigid_velocity_at_point(support_body, global_position)
	grounded = false
	support_body = null
	observed_support_velocity = Vector3.ZERO


func _rigid_velocity_at_point(body: Node3D, world_point: Vector3) -> Vector3:
	if not (body is RigidBody3D):
		return Vector3.ZERO

	var rigid: RigidBody3D = body as RigidBody3D
	var center_world: Vector3 = rigid.global_position
	if body is ConstructBody:
		var construct: ConstructBody = body as ConstructBody
		center_world = construct.to_global(construct.observed_center_of_mass_local)
	return rigid.linear_velocity + rigid.angular_velocity.cross(world_point - center_world)
