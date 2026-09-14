extends SceneTree

const VOLUME_SIZE := Vector3i(10, 3, 3)
const CUT_CELL := Vector3i(4, 1, 1)
const ACTOR_LOCAL_START := Vector3(7.5, 4.15, 1.5)
const SUPPORT_SOURCE_CELL := Vector3i(7, 1, 1)
const MASS_PER_CELL := 1.7
const POST_SPLIT_RIDE_FRAMES := 90
const MAX_JUMP_FRAMES := 120

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	world.name = "RebasedSplitWorld"
	get_root().add_child(world)

	var volume := CellVolume.new(VOLUME_SIZE)
	volume.fill_box(Vector3i(0, 0, 0), Vector3i(3, 3, 3), CellVolume.SOLID)
	volume.fill_box(Vector3i(6, 0, 0), Vector3i(10, 3, 3), CellVolume.SOLID)
	for x in range(3, 6):
		volume.set_cell(Vector3i(x, 1, 1), CellVolume.SOLID)

	var parent := ConstructBody.new()
	parent.name = "ParentConstruct"
	parent.gravity_scale = 0.0
	parent.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	parent.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	parent.linear_damp = 0.0
	parent.angular_damp = 0.0
	parent.mass_per_cell = MASS_PER_CELL
	world.add_child(parent)
	parent.position = Vector3(13.0, 8.0, -11.0)
	parent.rotation = Vector3(-0.16, 0.71, 0.09)
	parent.set_volume(volume)
	parent.linear_velocity = Vector3(-1.8, 0.6, 2.7)
	parent.angular_velocity = Vector3(0.35, 0.72, -0.41)

	var actor := FrameProbeCharacter.new()
	actor.name = "Actor"
	world.add_child(actor)
	actor.global_position = parent.to_global(ACTOR_LOCAL_START)

	var acquired := false
	for _step in range(60):
		await physics_frame
		await process_frame
		if actor.grounded and actor.support_body == parent:
			acquired = true
			break
	_check(acquired, "actor acquires parent before rebased split")
	if not acquired:
		_finish()
		return

	for _step in range(45):
		await physics_frame
		await process_frame

	var parent_transform: Transform3D = parent.global_transform
	var parent_linear: Vector3 = parent.linear_velocity
	var parent_angular: Vector3 = parent.angular_velocity
	var parent_com_world: Vector3 = parent_transform * parent.observed_center_of_mass_local
	var actor_world_before: Vector3 = actor.global_position
	var actor_parent_local: Vector3 = parent.to_local(actor.global_position)

	_check(volume.set_cell(CUT_CELL, CellVolume.EMPTY), "cut removes bridge cell")
	var components: Array[CellVolume] = MatterTopology.extract_connected_components(volume)
	_check(components.size() == 2, "rebased split produces two components")

	var children: Array[ConstructBody] = []
	var component_origins: Array[Vector3i] = []
	var expected_linear: Array[Vector3] = []
	var support_index := -1
	var max_world_cell_error := 0.0
	var max_velocity_field_error := 0.0

	for index in range(components.size()):
		var source_component: CellVolume = components[index]
		var compact_info: Dictionary = MatterTopology.compact_volume(source_component)
		var origin: Vector3i = compact_info["origin"]
		var compact: CellVolume = compact_info["volume"]
		component_origins.append(origin)

		var child := ConstructBody.new()
		child.name = "RebasedChild_%d" % index
		child.gravity_scale = 0.0
		child.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
		child.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
		child.linear_damp = 0.0
		child.angular_damp = 0.0
		child.mass_per_cell = MASS_PER_CELL
		world.add_child(child)
		child.global_transform = parent_transform * Transform3D(Basis.IDENTITY, Vector3(origin))
		child.set_volume(compact)

		var child_com_local: Vector3 = MatterTopology.center_of_mass_local(compact)
		var child_com_world: Vector3 = child.global_transform * child_com_local
		var inherited_linear: Vector3 = _velocity_at_point(parent_linear, parent_angular, parent_com_world, child_com_world)
		child.linear_velocity = inherited_linear
		child.angular_velocity = parent_angular
		children.append(child)
		expected_linear.append(inherited_linear)

		if source_component.get_cell(SUPPORT_SOURCE_CELL) != CellVolume.EMPTY:
			support_index = index

		for z in range(source_component.size.z):
			for y in range(source_component.size.y):
				for x in range(source_component.size.x):
					var source_cell := Vector3i(x, y, z)
					if source_component.get_cell(source_cell) == CellVolume.EMPTY:
						continue
					var compact_cell: Vector3i = source_cell - origin
					var parent_point_world: Vector3 = parent_transform * (Vector3(source_cell) + Vector3(0.5, 0.5, 0.5))
					var child_point_world: Vector3 = child.global_transform * (Vector3(compact_cell) + Vector3(0.5, 0.5, 0.5))
					max_world_cell_error = max(max_world_cell_error, parent_point_world.distance_to(child_point_world))

					var parent_point_velocity: Vector3 = _velocity_at_point(parent_linear, parent_angular, parent_com_world, parent_point_world)
					var child_point_velocity: Vector3 = _velocity_at_point(inherited_linear, parent_angular, child_com_world, child_point_world)
					max_velocity_field_error = max(max_velocity_field_error, parent_point_velocity.distance_to(child_point_velocity))

	_check(support_index >= 0, "supporting Matter maps to one compact child")
	if support_index < 0:
		_finish()
		return

	var support_child: ConstructBody = children[support_index]
	var support_origin: Vector3i = component_origins[support_index]
	_check(support_origin.x > 0, "actor-side child actually rebases to a nonzero source origin")
	_check(support_child.volume.size.x < VOLUME_SIZE.x, "actor-side child uses a compact local volume")
	_check(max_world_cell_error < 0.00001, "rebasing preserves every retained cell world position")
	_check(max_velocity_field_error < 0.00001, "rebasing preserves every retained cell instantaneous velocity")

	var mapped_actor_local: Vector3 = actor_parent_local - Vector3(support_origin)
	var transfers_before: int = actor.observed_support_transfers
	var handoff_ok: bool = actor.transfer_support_frame(support_child, mapped_actor_local)
	var handoff_world_jump: float = actor.global_position.distance_to(actor_world_before)
	_check(handoff_ok, "actor accepts rebased successor handoff")
	_check(actor.observed_support_transfers == transfers_before + 1, "rebased handoff records one topology transfer")
	_check(handoff_world_jump < 0.0001, "rebased handoff preserves actor world position")
	parent.free()

	await physics_frame
	await process_frame

	var local_after: Vector3 = support_child.to_local(actor.global_position)
	var handoff_local_error: float = Vector2(local_after.x - mapped_actor_local.x, local_after.z - mapped_actor_local.z).length()
	_check(actor.grounded and actor.support_body == support_child, "actor remains grounded on rebased child")
	_check(handoff_local_error < 0.002, "actor enters the rebased child at the mapped local coordinate")

	var ride_local_start: Vector3 = support_child.to_local(actor.global_position)
	var max_ride_drift := 0.0
	var floor_loss := 0
	var max_linear_error := 0.0
	var max_angular_error := 0.0
	for _step in range(POST_SPLIT_RIDE_FRAMES):
		await physics_frame
		await process_frame
		var local_now: Vector3 = support_child.to_local(actor.global_position)
		max_ride_drift = max(max_ride_drift, Vector2(local_now.x - ride_local_start.x, local_now.z - ride_local_start.z).length())
		if not actor.grounded or actor.support_body != support_child:
			floor_loss += 1
		max_linear_error = max(max_linear_error, support_child.linear_velocity.distance_to(expected_linear[support_index]))
		max_angular_error = max(max_angular_error, support_child.angular_velocity.distance_to(parent_angular))

	_check(floor_loss == 0, "actor remains supported after rebased split")
	_check(max_ride_drift < 0.002, "rebased support frame remains locally stable")
	_check(max_linear_error < 0.01, "actor does not perturb rebased child linear velocity")
	_check(max_angular_error < 0.01, "actor does not perturb rebased child angular velocity")

	var recontacts_before: int = actor.observed_recontacts
	actor.request_jump()
	var saw_airborne := false
	var recontact_frame := -1
	for step in range(MAX_JUMP_FRAMES):
		await physics_frame
		await process_frame
		if not actor.grounded:
			saw_airborne = true
		elif saw_airborne:
			recontact_frame = step
			break

	_check(saw_airborne, "actor can jump after frame rebasing")
	_check(recontact_frame >= 0, "actor recontacts compact rebased child")
	_check(actor.observed_recontacts > recontacts_before, "post-rebase landing remains an ordinary contact reacquisition")
	_check(actor.support_body == support_child, "post-rebase landing resolves to compact successor")

	print(
		"TOPOLOGY_REBASED_SPLIT_METRIC support_index=%d source_origin=%s compact_size=%s world_cell_error=%.10f velocity_field_error=%.10f handoff_world_jump=%.10f handoff_local_error=%.10f ride_drift=%.10f floor_loss=%d linear_error=%.10f angular_error=%.10f recontact_frame=%d actor_parent_local=%s actor_child_local=%s"
		% [
			support_index,
			support_origin,
			support_child.volume.size,
			max_world_cell_error,
			max_velocity_field_error,
			handoff_world_jump,
			handoff_local_error,
			max_ride_drift,
			floor_loss,
			max_linear_error,
			max_angular_error,
			recontact_frame,
			actor_parent_local,
			mapped_actor_local,
		]
	)

	_finish()


func _velocity_at_point(linear: Vector3, angular: Vector3, com_world: Vector3, point_world: Vector3) -> Vector3:
	return linear + angular.cross(point_world - com_world)


func _finish() -> void:
	if _failures.is_empty():
		print("TOPOLOGY_REBASED_SPLIT_PROBE_PASS: compact child frames preserved Matter world/velocity continuity and actor support through an explicit non-identity local-coordinate mapping.")
		quit(0)
		return
	for failure in _failures:
		push_error("TOPOLOGY_REBASED_SPLIT_PROBE_FAIL: " + failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
