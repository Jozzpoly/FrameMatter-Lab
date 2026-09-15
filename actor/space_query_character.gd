class_name SpaceQueryCharacter
extends Node3D

# P1 actor challenger: volumetric collision through Godot/Jolt direct-space
# shape queries, without becoming a kinematic PhysicsBody that can inject
# implicit push authority into dynamic constructs.
#
# Current scope remains world-up / translation+yaw. Arbitrary frame-relative
# gravity and adhesion are still an explicit future semantic frontier.

@export var radius := 0.32
@export var height := 1.80
@export var gravity_acceleration := 18.0
@export var jump_speed := 5.8
@export var ground_snap_distance := 0.24
@export var ground_normal_min_y := 0.70
@export var query_margin := 0.002
@export var max_slide_iterations := 4
@export_flags_3d_physics var collision_mask := 1

var desired_local_velocity := Vector3.ZERO
var world_velocity := Vector3.ZERO
var jump_requested := false

var grounded := false
var support_body: Node3D
var support_space: LocalMatterSpace
var support_local_center := Vector3.ZERO
var observed_support_velocity := Vector3.ZERO
var observed_ground_acquisitions := 0
var observed_support_transfers := 0
var observed_wall_blocks := 0
var observed_ceiling_blocks := 0

var _shape: CapsuleShape3D
var _previous_support_point_world := Vector3.ZERO
var _has_support_sample := false
var _topology_validation_grace_steps := 0


func _ready() -> void:
	_shape = CapsuleShape3D.new()
	_shape.radius = radius
	_shape.height = max(height, radius * 2.0)


func request_jump() -> void:
	jump_requested = true


func transfer_support_frame(new_support: Node3D, mapped_local_center: Vector3) -> bool:
	if not grounded:
		return false
	var resolved_support := _resolve_support_frame(new_support)
	if resolved_support == null or not is_instance_valid(resolved_support):
		return false

	support_body = resolved_support
	support_space = _resolve_support_space(resolved_support)
	support_local_center = mapped_local_center
	global_position = resolved_support.to_global(mapped_local_center)
	_previous_support_point_world = global_position
	_has_support_sample = true
	world_velocity = _rigid_velocity_at_point(resolved_support, global_position)
	observed_support_velocity = world_velocity
	_topology_validation_grace_steps = 1
	observed_support_transfers += 1
	return true


func _physics_process(delta: float) -> void:
	if _shape == null:
		return

	if grounded:
		_step_grounded(delta)
	else:
		_step_airborne(delta)
	jump_requested = false


func _step_grounded(delta: float) -> void:
	_refresh_support_provider_from_space()
	if support_body == null or not is_instance_valid(support_body):
		_detach_from_support()
		_step_airborne(delta)
		return

	var anchor_world := support_body.to_global(support_local_center)
	var support_velocity := _support_velocity(anchor_world, delta)
	observed_support_velocity = support_velocity
	global_position = anchor_world

	var desired_world := support_body.global_transform.basis.orthonormalized() * desired_local_velocity
	desired_world.y = 0.0

	if jump_requested:
		world_velocity = support_velocity + desired_world + Vector3.UP * jump_speed
		_detach_from_support(false)
		world_velocity.y -= gravity_acceleration * delta
		_move_with_slide(world_velocity * delta)
		return

	var before := global_position
	_move_with_slide(desired_world * delta)
	var actual_motion := global_position - before
	world_velocity = support_velocity + actual_motion / max(delta, 0.000001)

	if _topology_validation_grace_steps > 0:
		_topology_validation_grace_steps -= 1

	if not _snap_and_attach_ground():
		_detach_from_support(false)
		return

	_previous_support_point_world = global_position
	_has_support_sample = true


func _step_airborne(delta: float) -> void:
	var desired_world := desired_local_velocity
	desired_world.y = 0.0
	world_velocity.x = desired_world.x
	world_velocity.z = desired_world.z
	world_velocity.y -= gravity_acceleration * delta

	var vertical_before := world_velocity.y
	_move_with_slide(world_velocity * delta)
	if vertical_before <= 0.0 and _snap_and_attach_ground():
		world_velocity = _rigid_velocity_at_point(support_body, global_position)
		return


func _move_with_slide(motion: Vector3) -> void:
	var remaining := motion
	for _iteration in range(max_slide_iterations):
		if remaining.length_squared() <= 0.0000000001:
			break

		var cast := _cast_motion(remaining)
		if cast.is_empty():
			global_position += remaining
			break

		var safe := clampf(cast[0], 0.0, 1.0)
		var unsafe := clampf(cast[1], safe, 1.0)
		if safe >= 0.999999:
			global_position += remaining
			break

		global_position += remaining * safe
		var hit := _rest_info_at_unsafe_fraction(remaining, safe, unsafe)
		var normal := Vector3.ZERO
		if not hit.is_empty():
			normal = Vector3(hit.get("normal", Vector3.ZERO)).normalized()
		if normal.is_zero_approx():
			# A blocked cast without a recoverable contact normal must fail closed.
			break

		if normal.y <= 0.25 and absf(normal.y) < 0.75:
			observed_wall_blocks += 1
		if normal.y < -0.45 and world_velocity.y > 0.0:
			world_velocity.y = 0.0
			observed_ceiling_blocks += 1
		if normal.y > ground_normal_min_y and world_velocity.y < 0.0:
			world_velocity.y = 0.0

		var leftover := remaining * (1.0 - safe)
		remaining = leftover.slide(normal)
		# Keep the query shape just outside the contacted surface instead of
		# relying on deep-overlap recovery in the next slide iteration.
		global_position += normal * query_margin


func _snap_and_attach_ground() -> bool:
	var down := Vector3.DOWN * ground_snap_distance
	var cast := _cast_motion(down)
	if cast.is_empty():
		return false
	var safe := clampf(cast[0], 0.0, 1.0)
	var unsafe := clampf(cast[1], safe, 1.0)
	if safe >= 0.999999:
		return false

	var hit := _rest_info_at_unsafe_fraction(down, safe, unsafe)
	if hit.is_empty():
		return false
	var normal := Vector3(hit.get("normal", Vector3.ZERO)).normalized()
	if normal.y < ground_normal_min_y:
		return false

	global_position += down * safe
	var collider := _collider_from_rest_info(hit)
	if collider == null:
		return false
	var resolved_support := _resolve_support_frame(collider)
	if resolved_support == null:
		return false

	var changed_support := resolved_support != support_body
	support_body = resolved_support
	support_space = _resolve_support_space(resolved_support)
	grounded = true
	support_local_center = resolved_support.to_local(global_position)
	_previous_support_point_world = global_position
	_has_support_sample = true
	observed_support_velocity = _rigid_velocity_at_point(resolved_support, global_position)
	if changed_support:
		observed_ground_acquisitions += 1
	return true


func _cast_motion(motion: Vector3) -> PackedFloat32Array:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _shape
	query.transform = global_transform
	query.motion = motion
	query.margin = query_margin
	query.collision_mask = collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false
	return get_world_3d().direct_space_state.cast_motion(query)


func _rest_info_at_unsafe_fraction(
	motion: Vector3,
	safe_fraction: float,
	unsafe_fraction: float
) -> Dictionary:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _shape
	var sample_fraction := unsafe_fraction
	if sample_fraction <= safe_fraction + 0.000001 and motion.length() > 0.000001:
		sample_fraction = min(1.0, safe_fraction + min(0.02, query_margin * 2.0 / motion.length()))
	var sample_transform := global_transform
	# global_position has already advanced by safe_fraction. Sample only the
	# remaining fraction between safe and the first unsafe position.
	sample_transform.origin += motion * max(0.0, sample_fraction - safe_fraction)
	query.transform = sample_transform
	query.margin = query_margin
	query.collision_mask = collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false
	return get_world_3d().direct_space_state.get_rest_info(query)


func _collider_from_rest_info(hit: Dictionary) -> Node3D:
	var collider_id := int(hit.get("collider_id", 0))
	if collider_id == 0:
		return null
	var object := instance_from_id(collider_id)
	return object as Node3D


func _support_velocity(anchor_world: Vector3, delta: float) -> Vector3:
	if support_body == null or not is_instance_valid(support_body):
		return Vector3.ZERO
	if _topology_validation_grace_steps > 0 or not _has_support_sample or delta <= 0.0:
		return _rigid_velocity_at_point(support_body, anchor_world)
	return (anchor_world - _previous_support_point_world) / delta


func _detach_from_support(preserve_velocity := true) -> void:
	if preserve_velocity and support_body != null and is_instance_valid(support_body):
		world_velocity = _rigid_velocity_at_point(support_body, global_position)
	grounded = false
	support_body = null
	support_space = null
	observed_support_velocity = Vector3.ZERO
	_has_support_sample = false
	_topology_validation_grace_steps = 0


func _refresh_support_provider_from_space() -> void:
	if support_space == null or not is_instance_valid(support_space):
		return
	var current_provider := support_space.get_active_provider()
	if current_provider == null or current_provider == support_body:
		return

	support_body = current_provider
	global_position = current_provider.to_global(support_local_center)
	_previous_support_point_world = global_position
	_has_support_sample = true
	world_velocity = _rigid_velocity_at_point(current_provider, global_position)
	observed_support_velocity = world_velocity
	_topology_validation_grace_steps = 1
	observed_support_transfers += 1


func _resolve_support_frame(collider: Node3D) -> Node3D:
	if collider == null:
		return null
	var first_physics_body: Node3D = null
	var current: Node = collider
	while current != null:
		if current is ConstructBody or current is MatterRepresentation:
			return current as Node3D
		if first_physics_body == null and current is PhysicsBody3D:
			first_physics_body = current as Node3D
		current = current.get_parent()
	return first_physics_body if first_physics_body != null else collider


func _resolve_support_space(frame: Node3D) -> LocalMatterSpace:
	if frame == null:
		return null
	var current: Node = frame
	while current != null:
		if current is LocalMatterSpace:
			var space := current as LocalMatterSpace
			return space if space.get_active_provider() == frame else null
		current = current.get_parent()
	return null


func _rigid_velocity_at_point(body: Node3D, world_point: Vector3) -> Vector3:
	if not (body is RigidBody3D):
		return Vector3.ZERO
	var rigid := body as RigidBody3D
	var center_world := rigid.global_position
	if body is ConstructBody:
		var construct := body as ConstructBody
		center_world = construct.to_global(construct.matter_center_of_mass_local)
	return rigid.linear_velocity + rigid.angular_velocity.cross(world_point - center_world)
