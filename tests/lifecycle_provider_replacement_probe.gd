extends SceneTree

const SIZE := Vector3i(6, 4, 3)
const MASS_PER_CELL := 1.4
const ACTIVE_FRAMES := 24
const POST_EDIT_FRAMES := 12
const STATIC_OBSERVE_FRAMES := 24

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	world.name = "LifecycleProviderReplacementWorld"
	get_root().add_child(world)

	var volume := CellVolume.new(SIZE)
	volume.fill_box(Vector3i.ZERO, SIZE, 2)
	var create_cell := Vector3i(5, 3, 2)
	volume.set_cell(create_cell, CellVolume.EMPTY)
	volume.set_cell(Vector3i(4, 1, 2), 3)
	volume.set_cell(Vector3i(2, 3, 1), 4)

	var lineage := MatterLineageMap.new(SIZE)
	var next_token := 300001
	for cell in _occupied_cells(volume):
		lineage.set_lineage(cell, next_token)
		next_token += 1

	var space := LocalMatterSpace.new()
	space.name = "PersistentLogicalSpace"
	space.mass_per_cell = MASS_PER_CELL
	space.dynamic_gravity_scale = 0.0
	space.dynamic_linear_damp = 0.0
	space.dynamic_angular_damp = 0.0
	space.dynamic_can_sleep = false
	world.add_child(space)

	var initial_transform := Transform3D(
		Basis.from_euler(Vector3(0.24, -0.38, 0.17)).orthonormalized(),
		Vector3(9.0, 5.0, -7.0)
	)
	space.initialize_static(volume, lineage, initial_transform)

	await physics_frame
	await process_frame

	var logical_space_id := space.get_instance_id()
	var initial_provider := space.get_active_provider()
	_check(initial_provider is MatterRepresentation, "I0B begins with the existing static MatterRepresentation provider")
	if not initial_provider is MatterRepresentation:
		_finish()
		return
	var initial_static := initial_provider as MatterRepresentation
	var initial_static_id := initial_static.get_instance_id()
	var initial_world_cells := _world_cell_positions(initial_static, volume)
	var initial_lineage_tokens := lineage.duplicate_tokens()
	_check(space.volume == volume and space.lineage == lineage, "logical Space owns the original authoritative Matter and lineage references")
	_check(space.get_provider_kind() == LocalMatterSpace.ProviderKind.STATIC, "initial provider authority is static")
	_check(space.get_provider_node_count() == 1, "initial logical Space has exactly one live provider")
	_check(initial_static.get_collision_shape_count() == volume.count_solid(), "initial static provider derives collision from authoritative Matter")

	var requested_linear := Vector3(1.9, 0.35, -1.15)
	var requested_angular := Vector3(0.28, -0.41, 0.33)
	_check(space.request_dynamic(requested_linear, requested_angular), "static Space accepts one queued activation request")
	_check(space.is_transition_pending(), "activation remains pending until shared pre-physics commit")
	await space.provider_transition_committed

	var dynamic_provider := space.get_active_provider()
	_check(dynamic_provider is ConstructBody, "activation replaces static provider with ConstructBody")
	if not dynamic_provider is ConstructBody:
		_finish()
		return
	var dynamic_body := dynamic_provider as ConstructBody
	var dynamic_id := dynamic_body.get_instance_id()
	var dynamic_rid := dynamic_body.get_rid()
	var activation_report := space.get_last_transition_report()
	var activation_previous_transform: Transform3D = activation_report["previous_transform"]
	var activation_current_transform: Transform3D = activation_report["current_transform"]
	var activation_pose_jump := _transform_gap(activation_previous_transform, activation_current_transform)
	var activation_world_error := _world_cell_position_error(initial_world_cells, dynamic_body, volume)
	var dynamic_commit_transform := dynamic_body.global_transform
	_check(space.get_instance_id() == logical_space_id, "logical Space identity survives static→dynamic provider replacement")
	_check(dynamic_id != initial_static_id, "dynamic provider has a different engine identity from retired static provider")
	_check(dynamic_body.volume == volume and space.volume == volume and space.lineage == lineage, "dynamic provider reuses one authoritative Matter object without cloning logical truth")
	_check(int(activation_report["provider_count_after_retire"]) == 0, "old provider is retired before successor installation")
	_check(int(activation_report["provider_count_after_install"]) == 1 and space.get_provider_node_count() == 1, "activation ends with exactly one live provider")
	_check(activation_pose_jump < 0.000001, "static→dynamic replacement preserves provider pose at commit")
	_check(activation_world_error < 0.00001, "static→dynamic replacement preserves occupied Matter world positions at commit")
	_check(dynamic_body.linear_velocity.distance_to(requested_linear) < 0.000001, "dynamic provider receives requested linear velocity before solver step")
	_check(dynamic_body.angular_velocity.distance_to(requested_angular) < 0.000001, "dynamic provider receives requested angular velocity before solver step")

	# The physics server steps before RigidBody3D's node transform is synchronized
	# back on the next PhysicsServer3D.sync(). Observe the first solver result from
	# the RID directly, then verify the node catches up at the next physics boundary.
	await process_frame
	var first_dynamic_server_transform := PhysicsServer3D.body_get_state(
		dynamic_rid,
		PhysicsServer3D.BODY_STATE_TRANSFORM
	) as Transform3D
	var first_dynamic_server_displacement := first_dynamic_server_transform.origin.distance_to(dynamic_commit_transform.origin)
	_check(first_dynamic_server_displacement > 0.005, "new dynamic provider participates in the upcoming solver tick without losing one phase")
	await physics_frame
	var first_dynamic_node_sync_gap := _transform_gap(dynamic_body.global_transform, first_dynamic_server_transform)
	_check(first_dynamic_node_sync_gap < 0.00001, "dynamic provider node synchronizes to the first solver result on the next physics boundary")
	await process_frame

	for _frame in range(ACTIVE_FRAMES):
		await physics_frame
		await process_frame
	var dynamic_translation := dynamic_body.global_position.distance_to(dynamic_commit_transform.origin)
	var dynamic_rotation := _basis_axis_error(
		dynamic_body.global_basis.orthonormalized(),
		dynamic_commit_transform.basis.orthonormalized()
	)
	_check(dynamic_translation > 0.2, "replacement-backed logical Space translates dynamically")
	_check(dynamic_rotation > 0.03, "replacement-backed logical Space rotates dynamically")

	var remove_cell := Vector3i(0, 0, 0)
	var material_change_cell := Vector3i(4, 1, 2)
	var retained_change_token := lineage.get_lineage(material_change_cell)
	var dynamic_id_before_edits := dynamic_body.get_instance_id()
	await physics_frame
	_check(space.mutate_cell(remove_cell, CellVolume.EMPTY), "shared Space mutation path removes Matter while dynamic")
	_check(space.mutate_cell(create_cell, 6, 399999), "shared Space mutation path creates Matter with fresh lineage while dynamic")
	_check(space.mutate_cell(material_change_cell, 7), "shared Space mutation path changes retained Matter material while dynamic")
	await process_frame
	_check(space.get_active_provider().get_instance_id() == dynamic_id_before_edits, "live Matter edits rebuild the active dynamic provider without replacing it")
	_check(lineage.get_lineage(remove_cell) == MatterLineageMap.NONE, "dynamic removal retires lineage")
	_check(lineage.get_lineage(create_cell) == 399999, "dynamic creation receives requested fresh lineage")
	_check(lineage.get_lineage(material_change_cell) == retained_change_token, "dynamic material change retains existing lineage")
	_check(dynamic_body.get_collision_shape_count() == volume.count_solid(), "dynamic live edit refreshes collision from authoritative Matter")
	_check(abs(dynamic_body.mass - float(volume.count_solid()) * MASS_PER_CELL) < 0.00001, "dynamic live edit refreshes mass from authoritative Matter")

	for _frame in range(POST_EDIT_FRAMES):
		await physics_frame
		await process_frame

	var post_edit_cells := volume.duplicate_cells()
	var post_edit_lineage := lineage.duplicate_tokens()
	var dynamic_id_before_static := dynamic_body.get_instance_id()
	_check(space.request_static(), "dynamic Space accepts one queued static-provider request")
	_check(space.is_transition_pending(), "static replacement remains pending until shared pre-physics commit")
	await space.provider_transition_committed

	var final_provider := space.get_active_provider()
	_check(final_provider is MatterRepresentation, "freeze-to-static replaces ConstructBody with MatterRepresentation")
	if not final_provider is MatterRepresentation:
		_finish()
		return
	var final_static := final_provider as MatterRepresentation
	var final_static_id := final_static.get_instance_id()
	var freeze_report := space.get_last_transition_report()
	var freeze_previous_transform: Transform3D = freeze_report["previous_transform"]
	var freeze_current_transform: Transform3D = freeze_report["current_transform"]
	var freeze_pose_jump := _transform_gap(freeze_previous_transform, freeze_current_transform)
	var frozen_orientation_from_identity := _basis_axis_error(
		final_static.global_basis.orthonormalized(),
		Basis.IDENTITY
	)
	_check(space.get_instance_id() == logical_space_id, "logical Space identity survives dynamic→static provider replacement")
	_check(final_static_id != dynamic_id_before_static and final_static_id != initial_static_id, "final static provider is a fresh engine representation")
	_check(space.get_provider_kind() == LocalMatterSpace.ProviderKind.STATIC, "provider authority returns to static")
	_check(int(freeze_report["provider_count_after_retire"]) == 0, "dynamic provider retires before static successor installation")
	_check(int(freeze_report["provider_count_after_install"]) == 1 and space.get_provider_node_count() == 1, "freeze replacement ends with exactly one live provider")
	_check(freeze_pose_jump < 0.000001, "dynamic→static replacement preserves arbitrary current pose")
	_check(frozen_orientation_from_identity > 0.05, "static successor retains a genuinely non-world-aligned orientation")
	_check(volume.duplicate_cells() == post_edit_cells and lineage.duplicate_tokens() == post_edit_lineage, "provider replacement preserves edited Matter and lineage truth")
	_check(final_static.get_collision_shape_count() == volume.count_solid(), "new static provider derives collision from edited Matter")

	var static_pose := final_static.global_transform
	var max_static_drift := 0.0
	for _frame in range(STATIC_OBSERVE_FRAMES):
		await physics_frame
		await process_frame
		max_static_drift = max(max_static_drift, _transform_gap(static_pose, final_static.global_transform))
	_check(max_static_drift < 0.00001, "replacement-backed static provider remains stable after dynamic motion")

	var post_static_edit_cell := Vector3i(2, 3, 1)
	var post_static_token := lineage.get_lineage(post_static_edit_cell)
	var static_id_before_edit := final_static.get_instance_id()
	_check(space.mutate_cell(post_static_edit_cell, 8), "same shared mutation path remains usable after freeze-to-static replacement")
	_check(final_static.get_instance_id() == static_id_before_edit, "post-freeze edit rebuilds static provider without replacing logical or provider identity")
	_check(lineage.get_lineage(post_static_edit_cell) == post_static_token, "post-freeze retained Matter edit preserves lineage")
	_check(final_static.get_collision_shape_count() == volume.count_solid(), "post-freeze edit keeps static collision coherent")
	_check(space.volume == volume and space.lineage == lineage, "entire I0B cycle retains one authoritative Matter + lineage pair")
	_check(space.get_instance_id() == logical_space_id, "entire I0B cycle retains one logical Space identity")

	var lineage_changes := _count_int64_mismatches(initial_lineage_tokens, lineage.duplicate_tokens())
	print(
		"LIFECYCLE_PROVIDER_REPLACEMENT_METRIC logical_space_id=%d initial_static_id=%d dynamic_id=%d final_static_id=%d activation_pose_jump=%.10f activation_world_error=%.10f first_dynamic_server_displacement=%.10f first_dynamic_node_sync_gap=%.10f dynamic_translation=%.8f dynamic_rotation=%.8f freeze_pose_jump=%.10f frozen_orientation_from_identity=%.8f max_static_drift=%.10f final_cells=%d final_shapes=%d lineage_changes=%d"
		% [
			logical_space_id,
			initial_static_id,
			dynamic_id,
			final_static_id,
			activation_pose_jump,
			activation_world_error,
			first_dynamic_server_displacement,
			first_dynamic_node_sync_gap,
			dynamic_translation,
			dynamic_rotation,
			freeze_pose_jump,
			frozen_orientation_from_identity,
			max_static_drift,
			volume.count_solid(),
			final_static.get_collision_shape_count(),
			lineage_changes,
		]
	)

	_finish()


func _world_cell_positions(provider: Node3D, volume: CellVolume) -> Dictionary:
	var result: Dictionary = {}
	for cell in _occupied_cells(volume):
		result[cell] = provider.global_transform * (Vector3(cell) + Vector3(0.5, 0.5, 0.5))
	return result


func _world_cell_position_error(snapshot: Dictionary, provider: Node3D, volume: CellVolume) -> float:
	var max_error := 0.0
	for cell_variant in snapshot.keys():
		var cell: Vector3i = cell_variant
		if volume.get_cell(cell) == CellVolume.EMPTY:
			continue
		var expected: Vector3 = snapshot[cell]
		var actual := provider.global_transform * (Vector3(cell) + Vector3(0.5, 0.5, 0.5))
		max_error = max(max_error, expected.distance_to(actual))
	return max_error


func _transform_gap(a: Transform3D, b: Transform3D) -> float:
	return max(a.origin.distance_to(b.origin), _basis_axis_error(a.basis.orthonormalized(), b.basis.orthonormalized()))


func _basis_axis_error(a: Basis, b: Basis) -> float:
	return max(a.x.distance_to(b.x), max(a.y.distance_to(b.y), a.z.distance_to(b.z)))


func _occupied_cells(volume: CellVolume) -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	for z in range(volume.size.z):
		for y in range(volume.size.y):
			for x in range(volume.size.x):
				var cell := Vector3i(x, y, z)
				if volume.get_cell(cell) != CellVolume.EMPTY:
					cells.append(cell)
	return cells


func _count_int64_mismatches(a: PackedInt64Array, b: PackedInt64Array) -> int:
	if a.size() != b.size():
		return max(a.size(), b.size())
	var mismatches := 0
	for index in range(a.size()):
		if a[index] != b[index]:
			mismatches += 1
	return mismatches


func _finish() -> void:
	if _failures.is_empty():
		print("LIFECYCLE_PROVIDER_REPLACEMENT_PROBE_PASS: one logical LocalMatterSpace preserved authoritative Matter/lineage and pose continuity through static→dynamic→static provider replacement, live motion/editing, and post-freeze editing using one shared pre-physics lifecycle path.")
		quit(0)
		return
	for failure in _failures:
		push_error("LIFECYCLE_PROVIDER_REPLACEMENT_PROBE_FAIL: " + failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)