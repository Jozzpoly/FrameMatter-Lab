class_name SpaceQueryCharacter
extends Node3D

const SCALE_PROBE_BASE_RADIUS := 0.32
const SCALE_PROBE_BASE_HEIGHT := 1.80
const SCALE_PROBE_BASE_GRAVITY := 18.0
const SCALE_PROBE_BASE_JUMP_SPEED := 5.8
const SCALE_PROBE_BASE_GROUND_SNAP := 0.24
const SCALE_PROBE_BASE_QUERY_MARGIN := 0.002
const SCALE_PROBE_BASE_FACING_POSITION := Vector3(0.0, 0.1, -0.42)
const SCALE_PROBE_BASE_FACING_SIZE := Vector3(0.16, 0.16, 0.42)

# P1 actor challenger: volumetric collision through Godot/Jolt direct-space
# shape queries, without becoming a kinematic PhysicsBody that can inject
# implicit push authority into dynamic constructs.
#
# Current scope remains world-up / translation+yaw. Arbitrary frame-relative
# gravity and adhesion are still an explicit future semantic frontier.

@export var radius: float = 0.32
@export var height: float = 1.80
@export var gravity_acceleration: float = 18.0
@export var jump_speed: float = 5.8
@export var ground_snap_distance: float = 0.24
@export var ground_normal_min_y: float = 0.70
@export var query_margin: float = 0.002
@export var max_slide_iterations: int = 4
@export_flags_3d_physics var collision_mask := 1

# Bounded post-C7 challenger. This does not turn the query actor into a solver
# body. It gives contacts with dynamic rigid Matter a finite effective actor
# mass so momentum exchange can be tested without restoring CharacterBody-style
# infinite kinematic push authority.
@export var reciprocal_dynamic_contact_enabled := false
@export var reciprocal_actor_mass := 4.0
@export_range(0.0, 1.0, 0.01) var reciprocal_contact_coupling := 0.72
@export var reciprocal_max_impulse := 8.0
@export var reciprocal_min_closing_speed := 0.05
@export var reciprocal_external_velocity_decay := 9.0

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
var observed_support_rebases := 0
var observed_wall_blocks := 0
var observed_ceiling_blocks := 0
var observed_reciprocal_contacts := 0
var observed_reciprocal_impulse_total := 0.0
var observed_reciprocal_max_impulse := 0.0
var observed_reciprocal_last_body_mass := 0.0
var observed_reciprocal_last_impulse := 0.0
var reciprocal_external_velocity := Vector3.ZERO

var _shape: CapsuleShape3D
var _reciprocal_contact_shape: CapsuleShape3D
var _reciprocal_contact_bodies_this_step: Dictionary = {}
var _reciprocal_recoil_exclude_rids: Array[RID] = []
var _previous_support_point_world := Vector3.ZERO
var _has_support_sample := false
var _topology_validation_grace_steps := 0
var _support_contact_local_point := Vector3.ZERO
var _support_contact_local_normal := Vector3.ZERO
var _has_support_contact_witness := false


func _ready() -> void:
	_shape = CapsuleShape3D.new()
	_shape.radius = radius
	_shape.height = maxf(height, radius * 2.0)
	_reciprocal_contact_shape = CapsuleShape3D.new()
	_refresh_reciprocal_contact_shape()


# C1-only relative-scale proxy. It deliberately changes the embodied actor's
# size relative to unchanged 1-cell Matter; it is not a representation change.
func apply_scale_probe(length_scale: float) -> void:
	var scale_factor := maxf(1.0, length_scale)
	radius = SCALE_PROBE_BASE_RADIUS * scale_factor
	height = SCALE_PROBE_BASE_HEIGHT * scale_factor
	gravity_acceleration = SCALE_PROBE_BASE_GRAVITY * scale_factor
	jump_speed = SCALE_PROBE_BASE_JUMP_SPEED * scale_factor
	ground_snap_distance = SCALE_PROBE_BASE_GROUND_SNAP * scale_factor
	query_margin = SCALE_PROBE_BASE_QUERY_MARGIN * scale_factor
	if _shape != null:
		_shape.radius = radius
		_shape.height = maxf(height, radius * 2.0)
	_refresh_reciprocal_contact_shape()

	var body := get_node_or_null("Body") as MeshInstance3D
	if body != null and body.mesh is CapsuleMesh:
		var capsule := body.mesh as CapsuleMesh
		capsule.radius = radius
		capsule.height = height
	var facing := get_node_or_null("FacingMarker") as MeshInstance3D
	if facing != null:
		facing.position = SCALE_PROBE_BASE_FACING_POSITION * scale_factor
		if facing.mesh is BoxMesh:
			(facing.mesh as BoxMesh).size = SCALE_PROBE_BASE_FACING_SIZE * scale_factor


func request_jump() -> void:
	jump_requested = true


func clear_support_for_world_reset() -> void:
	# Explicit world-rebuild boundary: no typed reference to the retiring support
	# Space/body may survive into registry/presentation callbacks.
	_detach_from_support(false)
	desired_local_velocity = Vector3.ZERO
	world_velocity = Vector3.ZERO
	reciprocal_external_velocity = Vector3.ZERO
	_reciprocal_recoil_exclude_rids.clear()
	jump_requested = false


func get_support_contact_witness() -> Dictionary:
	var invalid := {"valid": false}
	if (
		not grounded
		or not _has_support_contact_witness
		or support_body == null
		or not is_instance_valid(support_body)
		or support_space == null
		or not is_instance_valid(support_space)
		or support_space.get_active_provider() != support_body
		or support_space.volume == null
	):
		return invalid

	var local_normal: Vector3 = _support_contact_local_normal.normalized()
	if local_normal.is_zero_approx():
		return invalid
	# get_rest_info() reports a point on the contacted surface. Move a tiny
	# amount into the support material before flooring to a logical cell so a
	# top-face contact at y=N resolves to the occupied cell below rather than
	# the empty cell above. Ambiguous/empty results fail closed.
	var inset: float = maxf(query_margin * 2.0, 0.002)
	var sample_local: Vector3 = _support_contact_local_point - local_normal * inset
	var cell := Vector3i(
		floori(sample_local.x),
		floori(sample_local.y),
		floori(sample_local.z)
	)
	if not support_space.volume.in_bounds(cell):
		return invalid
	if support_space.volume.get_cell(cell) == CellVolume.EMPTY:
		return invalid

	return {
		"valid": true,
		"cell": cell,
		"world_point": support_body.to_global(_support_contact_local_point),
		"world_normal": (support_body.global_transform.basis * local_normal).normalized(),
		"local_point": _support_contact_local_point,
		"local_normal": local_normal,
		"space_id": support_space.get_instance_id(),
		"provider_id": support_body.get_instance_id(),
	}


func transfer_support_frame(new_support: Node3D, mapped_local_center: Vector3) -> bool:
	if not grounded:
		return false
	var resolved_support: Node3D = _resolve_support_frame(new_support)
	if resolved_support == null or not is_instance_valid(resolved_support):
		return false

	var witness_world_point := Vector3.ZERO
	var witness_world_normal := Vector3.ZERO
	var preserve_witness := _has_support_contact_witness and support_body != null and is_instance_valid(support_body)
	if preserve_witness:
		witness_world_point = support_body.to_global(_support_contact_local_point)
		witness_world_normal = (support_body.global_transform.basis * _support_contact_local_normal).normalized()

	support_body = resolved_support
	support_space = _resolve_support_space(resolved_support)
	support_local_center = mapped_local_center
	global_position = resolved_support.to_global(mapped_local_center)
	if preserve_witness:
		_support_contact_local_point = resolved_support.to_local(witness_world_point)
		_support_contact_local_normal = (
			resolved_support.global_transform.basis.inverse() * witness_world_normal
		).normalized()
		_has_support_contact_witness = not _support_contact_local_normal.is_zero_approx()
	else:
		_clear_support_contact_witness()
	_previous_support_point_world = global_position
	_has_support_sample = true
	world_velocity = _rigid_velocity_at_point(resolved_support, global_position)
	observed_support_velocity = world_velocity
	_topology_validation_grace_steps = 1
	observed_support_transfers += 1
	return true


func transfer_support_frame_with_contact_witness(
	new_support: Node3D,
	mapped_local_center: Vector3,
	mapped_contact_local_point: Vector3,
	mapped_contact_local_normal: Vector3
) -> bool:
	# Topology succession can retire the old provider before the consumer receives
	# the split result. In that case transfer_support_frame() cannot reconstruct
	# the contact from the old body, so the transaction supplies the already
	# captured source-local witness mapped into the exact successor frame.
	if not transfer_support_frame(new_support, mapped_local_center):
		return false
	var local_normal := mapped_contact_local_normal.normalized()
	if support_space == null or not is_instance_valid(support_space) or local_normal.is_zero_approx():
		_clear_support_contact_witness()
		return true
	_support_contact_local_point = mapped_contact_local_point
	_support_contact_local_normal = local_normal
	_has_support_contact_witness = true
	return true


func rebase_support_local_coordinates(local_shift: Vector3) -> bool:
	# Storage-frame rebasing changes only the provider-local coordinate system.
	# The logical support relation and the actor's world point must stay intact.
	if not grounded or support_body == null or not is_instance_valid(support_body):
		return false
	if support_space == null or not is_instance_valid(support_space):
		return false
	if support_space.get_active_provider() != support_body:
		return false

	support_local_center += local_shift
	if _has_support_contact_witness:
		_support_contact_local_point += local_shift
	global_position = support_body.to_global(support_local_center)
	_previous_support_point_world = global_position
	_has_support_sample = true
	world_velocity = _rigid_velocity_at_point(support_body, global_position)
	observed_support_velocity = world_velocity
	_topology_validation_grace_steps = 1
	observed_support_rebases += 1
	return true


func _physics_process(delta: float) -> void:
	if _shape == null:
		return

	_reciprocal_contact_bodies_this_step.clear()
	if reciprocal_dynamic_contact_enabled:
		_resolve_incoming_reciprocal_contact()

	if grounded:
		_step_grounded(delta)
	else:
		_step_airborne(delta)
	if reciprocal_dynamic_contact_enabled:
		reciprocal_external_velocity = reciprocal_external_velocity.move_toward(
			Vector3.ZERO,
			reciprocal_external_velocity_decay * delta
		)
	jump_requested = false


func _step_grounded(delta: float) -> void:
	_refresh_support_provider_from_space()
	if support_body == null or not is_instance_valid(support_body):
		_detach_from_support()
		_step_airborne(delta)
		return

	var anchor_world: Vector3 = support_body.to_global(support_local_center)
	var support_velocity: Vector3 = _support_velocity(anchor_world, delta)
	observed_support_velocity = support_velocity
	global_position = anchor_world

	var desired_world: Vector3 = support_body.global_transform.basis.orthonormalized() * desired_local_velocity
	desired_world.y = 0.0
	if reciprocal_dynamic_contact_enabled:
		_apply_reciprocal_recoil_motion(delta)

	if jump_requested:
		world_velocity = support_velocity + desired_world + Vector3.UP * jump_speed
		_detach_from_support(false)
		world_velocity.y -= gravity_acceleration * delta
		_move_with_slide(world_velocity * delta)
		return

	var before: Vector3 = global_position
	_move_with_slide(desired_world * delta)
	var actual_motion: Vector3 = global_position - before
	world_velocity = support_velocity + actual_motion / maxf(delta, 0.000001)

	# A provider installed at SceneTree.physics_frame is authoritative before the
	# upcoming solver step, but direct-space queries in this same host phase may
	# not see its fresh collision yet. Explicit frame handoff/rebase already
	# proves the logical support relation, so preserve it for one step instead of
	# fabricating detach+reacquire from a transient PhysicsServer visibility gap.
	if _topology_validation_grace_steps > 0:
		_topology_validation_grace_steps -= 1
		support_local_center = support_body.to_local(global_position)
		if actual_motion.length_squared() > 0.0000000001:
			# We moved without a fresh collision query, so the old exact contact point
			# can no longer certify which Matter cell is directly under the actor.
			_has_support_contact_witness = false
		_previous_support_point_world = global_position
		_has_support_sample = true
		return

	if not _snap_and_attach_ground():
		_detach_from_support(false)
		return

	_previous_support_point_world = global_position
	_has_support_sample = true


func _step_airborne(delta: float) -> void:
	var desired_world: Vector3 = desired_local_velocity
	desired_world.y = 0.0
	if reciprocal_dynamic_contact_enabled:
		_apply_reciprocal_recoil_motion(delta)
	world_velocity.x = desired_world.x
	world_velocity.z = desired_world.z
	world_velocity.y -= gravity_acceleration * delta

	var vertical_before: float = world_velocity.y
	_move_with_slide(world_velocity * delta)
	if vertical_before <= 0.0 and _snap_and_attach_ground():
		world_velocity = _rigid_velocity_at_point(support_body, global_position)
		return


func _move_with_slide(motion: Vector3) -> void:
	var remaining: Vector3 = motion
	for _iteration in range(max_slide_iterations):
		if remaining.length_squared() <= 0.0000000001:
			break

		var cast: PackedFloat32Array = _cast_motion(remaining)
		if cast.is_empty():
			global_position += remaining
			break

		var safe: float = clampf(cast[0], 0.0, 1.0)
		var unsafe: float = clampf(cast[1], safe, 1.0)
		if safe >= 0.999999:
			global_position += remaining
			break

		global_position += remaining * safe
		var hit: Dictionary = _rest_info_at_unsafe_fraction(remaining, safe, unsafe)
		var normal := Vector3.ZERO
		if not hit.is_empty():
			normal = Vector3(hit.get("normal", Vector3.ZERO)).normalized()
		if normal.is_zero_approx():
			# A blocked cast without a recoverable contact normal must fail closed.
			break

		if normal.y <= 0.25 and absf(normal.y) < 0.75:
			observed_wall_blocks += 1
			if reciprocal_dynamic_contact_enabled and not hit.is_empty():
				var motion_seconds := maxf(get_physics_process_delta_time(), 0.000001)
				_apply_reciprocal_dynamic_contact(
					hit,
					normal,
					remaining / motion_seconds
				)
		if normal.y < -0.45 and world_velocity.y > 0.0:
			world_velocity.y = 0.0
			observed_ceiling_blocks += 1
		if normal.y > ground_normal_min_y and world_velocity.y < 0.0:
			world_velocity.y = 0.0

		var leftover: Vector3 = remaining * (1.0 - safe)
		remaining = leftover.slide(normal)
		# Keep the query shape just outside the contacted surface instead of
		# relying on deep-overlap recovery in the next slide iteration.
		global_position += normal * query_margin


func _refresh_reciprocal_contact_shape() -> void:
	if _reciprocal_contact_shape == null:
		return
	_reciprocal_contact_shape.radius = maxf(0.01, radius * 0.96)
	# Deliberately keep the reciprocal probe away from the floor/ceiling so an
	# ordinary support contact does not masquerade as a side impact.
	_reciprocal_contact_shape.height = maxf(
		_reciprocal_contact_shape.radius * 2.0,
		height * 0.58
	)


func _resolve_incoming_reciprocal_contact() -> void:
	if _reciprocal_contact_shape == null:
		return
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _reciprocal_contact_shape
	query.transform = global_transform
	query.margin = maxf(query_margin, 0.004)
	query.collision_mask = collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false

	# Query actors are invisible to the rigid solver. For an incoming body we
	# therefore cannot wait for actor-authored cast_motion to discover contact.
	# Inspect current side-volume overlaps explicitly and feed the exact same
	# finite-mass impulse law used by actor-authored contact.
	var overlaps: Array[Dictionary] = get_world_3d().direct_space_state.intersect_shape(query, 8)
	if overlaps.is_empty():
		return

	var actor_velocity := reciprocal_external_velocity
	if grounded and support_body != null and is_instance_valid(support_body):
		actor_velocity += _support_velocity(global_position, maxf(get_physics_process_delta_time(), 0.000001))
		actor_velocity += support_body.global_transform.basis.orthonormalized() * desired_local_velocity
	else:
		actor_velocity += Vector3(desired_local_velocity.x, world_velocity.y, desired_local_velocity.z)

	for overlap in overlaps:
		var collider := overlap.get("collider") as Node3D
		if collider == null:
			continue
		var frame := _resolve_support_frame(collider)
		if not (frame is RigidBody3D):
			continue
		var body := frame as RigidBody3D
		if body == support_body:
			continue
		var normal := global_position - body.global_position
		normal.y = 0.0
		normal = normal.normalized()
		if normal.is_zero_approx():
			continue
		var contact_world := global_position - normal * radius
		_apply_reciprocal_body_contact(body, normal, actor_velocity, contact_world)


func _apply_reciprocal_dynamic_contact(
	hit: Dictionary,
	normal: Vector3,
	actor_contact_velocity: Vector3
) -> void:
	var collider := _collider_from_rest_info(hit)
	if collider == null:
		return
	var frame := _resolve_support_frame(collider)
	if not (frame is RigidBody3D):
		return
	var contact_world: Vector3 = Vector3(hit.get("point", global_position))
	_apply_reciprocal_body_contact(
		frame as RigidBody3D,
		normal,
		actor_contact_velocity,
		contact_world
	)


func _apply_reciprocal_body_contact(
	body: RigidBody3D,
	normal: Vector3,
	actor_contact_velocity: Vector3,
	contact_world: Vector3
) -> void:
	if not is_instance_valid(body) or body == support_body or normal.is_zero_approx():
		return
	var body_id := body.get_instance_id()
	if _reciprocal_contact_bodies_this_step.has(body_id):
		return
	var actor_mass := maxf(reciprocal_actor_mass, 0.001)
	var body_mass := maxf(body.mass, 0.001)
	var body_velocity := _rigid_velocity_at_point(body, contact_world)
	var relative_normal_speed := (actor_contact_velocity - body_velocity).dot(normal)
	var closing_speed := -relative_normal_speed
	if closing_speed <= reciprocal_min_closing_speed:
		return

	var effective_inverse_mass := 1.0 / actor_mass + 1.0 / body_mass
	var impulse_magnitude := closing_speed / maxf(effective_inverse_mass, 0.000001)
	impulse_magnitude *= clampf(reciprocal_contact_coupling, 0.0, 1.0)
	impulse_magnitude = minf(impulse_magnitude, maxf(reciprocal_max_impulse, 0.0))
	if impulse_magnitude <= 0.0:
		return

	_reciprocal_contact_bodies_this_step[body_id] = true
	var body_rid := body.get_rid()
	if not _reciprocal_recoil_exclude_rids.has(body_rid):
		_reciprocal_recoil_exclude_rids.append(body_rid)
	var impulse_on_body := -normal * impulse_magnitude
	body.apply_central_impulse(impulse_on_body)

	# The query actor is not a PhysicsServer body, so explicitly retain its
	# equal-and-opposite velocity change as a transient external channel. Player
	# intent remains responsive and will overcome it over time rather than being
	# replaced by solver-owned locomotion in this bounded challenger.
	reciprocal_external_velocity += normal * (impulse_magnitude / actor_mass)

	observed_reciprocal_contacts += 1
	observed_reciprocal_impulse_total += impulse_magnitude
	observed_reciprocal_max_impulse = maxf(observed_reciprocal_max_impulse, impulse_magnitude)
	observed_reciprocal_last_body_mass = body_mass
	observed_reciprocal_last_impulse = impulse_magnitude


func _apply_reciprocal_recoil_motion(delta: float) -> void:
	if reciprocal_external_velocity.length_squared() <= 0.0000000001 or delta <= 0.0:
		_reciprocal_recoil_exclude_rids.clear()
		return
	var motion := reciprocal_external_velocity * delta
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _shape
	query.transform = global_transform
	query.motion = motion
	query.margin = query_margin
	query.collision_mask = collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = _reciprocal_recoil_exclude_rids.duplicate()
	var cast: PackedFloat32Array = get_world_3d().direct_space_state.cast_motion(query)
	if cast.is_empty():
		global_position += motion
	else:
		var safe := clampf(cast[0], 0.0, 1.0)
		global_position += motion * safe
	_reciprocal_recoil_exclude_rids.clear()


func _snap_and_attach_ground() -> bool:
	var down: Vector3 = Vector3.DOWN * ground_snap_distance
	var cast: PackedFloat32Array = _cast_motion(down)
	if cast.is_empty():
		return _attach_from_current_ground_overlap()
	var safe: float = clampf(cast[0], 0.0, 1.0)
	var unsafe: float = clampf(cast[1], safe, 1.0)
	if safe >= 0.999999:
		# cast_motion intentionally ignores shapes the capsule already overlaps.
		# A ground-like current intersection is therefore a second, complementary
		# contact state rather than evidence that the floor disappeared.
		return _attach_from_current_ground_overlap()

	# `_rest_info_at_unsafe_fraction()` samples relative to the already-reached
	# safe position (the same contract used by `_move_with_slide`). Ground snap
	# must therefore advance temporarily before asking for the overlap normal.
	var start_position: Vector3 = global_position
	global_position += down * safe
	var hit: Dictionary = _rest_info_at_unsafe_fraction(down, safe, unsafe)
	if not _attach_from_ground_hit(hit):
		global_position = start_position
		return false
	return true


func _attach_from_current_ground_overlap() -> bool:
	var hit: Dictionary = _rest_info_at_current_pose()
	return _attach_from_ground_hit(hit)


func _attach_from_ground_hit(hit: Dictionary) -> bool:
	if hit.is_empty():
		return false
	var normal: Vector3 = Vector3(hit.get("normal", Vector3.ZERO)).normalized()
	if normal.y < ground_normal_min_y:
		return false

	var collider: Node3D = _collider_from_rest_info(hit)
	if collider == null:
		return false
	var resolved_support: Node3D = _resolve_support_frame(collider)
	if resolved_support == null:
		return false

	var changed_support: bool = resolved_support != support_body
	support_body = resolved_support
	support_space = _resolve_support_space(resolved_support)
	grounded = true
	support_local_center = resolved_support.to_local(global_position)
	var contact_world: Vector3 = Vector3(hit.get("point", global_position))
	_support_contact_local_point = resolved_support.to_local(contact_world)
	_support_contact_local_normal = (
		resolved_support.global_transform.basis.inverse() * normal
	).normalized()
	_has_support_contact_witness = (
		support_space != null
		and is_instance_valid(support_space)
		and not _support_contact_local_normal.is_zero_approx()
	)
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


func _rest_info_at_current_pose() -> Dictionary:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _shape
	query.transform = global_transform
	query.margin = query_margin
	query.collision_mask = collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false
	return get_world_3d().direct_space_state.get_rest_info(query)


func _rest_info_at_unsafe_fraction(
	motion: Vector3,
	safe_fraction: float,
	unsafe_fraction: float
) -> Dictionary:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _shape
	var sample_fraction: float = unsafe_fraction
	if sample_fraction <= safe_fraction + 0.000001 and motion.length() > 0.000001:
		sample_fraction = minf(1.0, safe_fraction + minf(0.02, query_margin * 2.0 / motion.length()))
	var sample_transform: Transform3D = global_transform
	# global_position has already advanced by safe_fraction. Sample only the
	# remaining fraction between safe and the first unsafe position.
	sample_transform.origin += motion * maxf(0.0, sample_fraction - safe_fraction)
	query.transform = sample_transform
	query.margin = query_margin
	query.collision_mask = collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false
	return get_world_3d().direct_space_state.get_rest_info(query)


func _collider_from_rest_info(hit: Dictionary) -> Node3D:
	var collider_id: int = int(hit.get("collider_id", 0))
	if collider_id == 0:
		return null
	var object: Object = instance_from_id(collider_id)
	return object as Node3D


func _support_velocity(anchor_world: Vector3, delta: float) -> Vector3:
	if support_body == null or not is_instance_valid(support_body):
		return Vector3.ZERO
	if _topology_validation_grace_steps > 0 or not _has_support_sample or delta <= 0.0:
		return _rigid_velocity_at_point(support_body, anchor_world)
	return (anchor_world - _previous_support_point_world) / delta


func _detach_from_support(preserve_velocity: bool = true) -> void:
	if preserve_velocity and support_body != null and is_instance_valid(support_body):
		world_velocity = _rigid_velocity_at_point(support_body, global_position)
	grounded = false
	support_body = null
	support_space = null
	observed_support_velocity = Vector3.ZERO
	_has_support_sample = false
	_clear_support_contact_witness()
	_topology_validation_grace_steps = 0


func _clear_support_contact_witness() -> void:
	_has_support_contact_witness = false
	_support_contact_local_point = Vector3.ZERO
	_support_contact_local_normal = Vector3.ZERO


func _refresh_support_provider_from_space() -> void:
	if support_space == null or not is_instance_valid(support_space):
		return
	var current_provider: Node3D = support_space.get_active_provider()
	if current_provider == null or current_provider == support_body:
		return

	var witness_world_point := Vector3.ZERO
	var witness_world_normal := Vector3.ZERO
	var preserve_witness := _has_support_contact_witness and support_body != null and is_instance_valid(support_body)
	if preserve_witness:
		witness_world_point = support_body.to_global(_support_contact_local_point)
		witness_world_normal = (support_body.global_transform.basis * _support_contact_local_normal).normalized()

	support_body = current_provider
	global_position = current_provider.to_global(support_local_center)
	if preserve_witness:
		_support_contact_local_point = current_provider.to_local(witness_world_point)
		_support_contact_local_normal = (
			current_provider.global_transform.basis.inverse() * witness_world_normal
		).normalized()
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
	var center_world: Vector3 = rigid.global_position
	if body is ConstructBody:
		var construct := body as ConstructBody
		center_world = construct.to_global(construct.matter_center_of_mass_local)
	return rigid.linear_velocity + rigid.angular_velocity.cross(world_point - center_world)
