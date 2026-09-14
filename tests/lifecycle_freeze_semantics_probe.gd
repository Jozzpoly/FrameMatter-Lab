extends SceneTree

const SIZE := Vector3i(5, 4, 3)
const MASS_PER_CELL := 1.35
const DYNAMIC_WARMUP_FRAMES := 18
const FROZEN_OBSERVE_FRAMES := 30
const RESUME_DRIVE_FRAMES := 24
const FINAL_FROZEN_FRAMES := 24

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	world.name = "LifecycleFreezeSemanticsWorld"
	get_root().add_child(world)

	var volume := CellVolume.new(SIZE)
	volume.fill_box(Vector3i(0, 0, 0), Vector3i(4, 3, 2), 2)
	volume.set_cell(Vector3i(3, 3, 1), 3)
	volume.set_cell(Vector3i(1, 1, 2), 4)

	var lineage := MatterLineageMap.new(SIZE)
	var next_token := 200001
	for cell in _occupied_cells(volume):
		lineage.set_lineage(cell, next_token)
		next_token += 1

	var body := ConstructBody.new()
	body.name = "LifecycleFreezeBody"
	body.gravity_scale = 0.0
	body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.linear_damp = 0.0
	body.angular_damp = 0.0
	body.can_sleep = false
	body.collision_layer = 0
	body.collision_mask = 0
	body.mass_per_cell = MASS_PER_CELL
	world.add_child(body)
	body.global_transform = Transform3D(
		Basis.from_euler(Vector3(0.19, -0.43, 0.27)).orthonormalized(),
		Vector3(-8.0, 6.5, 11.0)
	)
	body.set_volume(volume)

	await physics_frame
	await process_frame

	var instance_id := body.get_instance_id()
	var rid := body.get_rid()
	var initial_cells := volume.duplicate_cells()
	var initial_lineage := lineage.duplicate_tokens()
	var initial_transform := body.global_transform
	var initial_mass := body.mass
	var initial_shape_count := body.get_collision_shape_count()

	_check(initial_shape_count == volume.count_solid(), "initial collision representation matches Matter occupancy")
	_check(abs(initial_mass - float(volume.count_solid()) * MASS_PER_CELL) < 0.00001, "initial mass matches occupied Matter")

	body.linear_velocity = Vector3(2.3, 0.4, -1.1)
	body.angular_velocity = Vector3(0.31, -0.47, 0.22)
	for _frame in range(DYNAMIC_WARMUP_FRAMES):
		await physics_frame
		await process_frame

	var pre_freeze_transform := body.global_transform
	var pre_freeze_linear := body.linear_velocity
	var pre_freeze_angular := body.angular_velocity
	var dynamic_translation := pre_freeze_transform.origin.distance_to(initial_transform.origin)
	var dynamic_rotation := _basis_axis_error(
		pre_freeze_transform.basis.orthonormalized(),
		initial_transform.basis.orthonormalized()
	)
	_check(dynamic_translation > 0.1, "same-body control is genuinely dynamic before first freeze")
	_check(dynamic_rotation > 0.02, "same-body control genuinely rotates before first freeze")

	# First transition is committed at the physics-frame boundary. Separate the
	# final legal dynamic phase advance from the synchronous effect of the toggle.
	# Velocity behavior remains telemetry: FrameMatter has not chosen a restore policy.
	await physics_frame
	var freeze_boundary_transform := body.global_transform
	var freeze_phase_advance := _transform_gap(pre_freeze_transform, freeze_boundary_transform)
	var freeze_world_before := _world_cell_positions(body, volume)
	body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	body.freeze = true
	var freeze_toggle_transform := body.global_transform
	var freeze_toggle_jump := _transform_gap(freeze_boundary_transform, freeze_toggle_transform)
	var linear_immediate_frozen := body.linear_velocity
	var angular_immediate_frozen := body.angular_velocity
	_check(body.freeze, "body reports frozen state immediately after static freeze transition")
	_check(body.get_instance_id() == instance_id and body.get_rid() == rid, "freeze transition keeps engine instance and RID identity")
	_check(freeze_toggle_jump < 0.000001, "freeze toggle does not synchronously jump body pose")

	var max_frozen_pose_drift := 0.0
	for _frame in range(FROZEN_OBSERVE_FRAMES):
		await physics_frame
		await process_frame
		max_frozen_pose_drift = max(max_frozen_pose_drift, _transform_gap(freeze_toggle_transform, body.global_transform))
	var linear_after_frozen_window := body.linear_velocity
	var angular_after_frozen_window := body.angular_velocity
	_check(max_frozen_pose_drift < 0.00001, "FREEZE_MODE_STATIC keeps arbitrary pose stable across frozen solver frames")
	_check(_world_cell_position_error(freeze_world_before, body, volume) < 0.00001, "frozen local Matter remains at the same world-space cell centers")

	# Mutate authoritative Matter and lineage while the same body remains frozen.
	var remove_a := Vector3i(0, 0, 0)
	var remove_b := Vector3i(3, 2, 1)
	var create_c := Vector3i(4, 2, 2)
	var retired_a := lineage.get_lineage(remove_a)
	var retired_b := lineage.get_lineage(remove_b)
	_check(retired_a != MatterLineageMap.NONE and retired_b != MatterLineageMap.NONE, "frozen-edit removal cells begin with lineage")
	volume.set_cell(remove_a, CellVolume.EMPTY)
	volume.set_cell(remove_b, CellVolume.EMPTY)
	lineage.clear_lineage(remove_a)
	lineage.clear_lineage(remove_b)
	volume.set_cell(create_c, 5)
	lineage.set_lineage(create_c, 299999)

	var frozen_pose_before_rebuild := body.global_transform
	body.rebuild_derived()
	var frozen_rebuild_pose_jump := _transform_gap(frozen_pose_before_rebuild, body.global_transform)
	var expected_mass := float(volume.count_solid()) * MASS_PER_CELL
	_check(body.freeze, "live Matter rebuild does not implicitly unfreeze the body")
	_check(frozen_rebuild_pose_jump < 0.000001, "live Matter rebuild while frozen does not move the host pose")
	_check(body.get_instance_id() == instance_id and body.get_rid() == rid, "frozen live rebuild keeps instance and RID identity")
	_check(body.get_collision_shape_count() == volume.count_solid(), "frozen live rebuild updates collision shape count from Matter")
	_check(abs(body.mass - expected_mass) < 0.00001, "frozen live rebuild refreshes mass from Matter")
	_check(lineage.get_lineage(remove_a) == MatterLineageMap.NONE and lineage.get_lineage(remove_b) == MatterLineageMap.NONE, "destroyed frozen Matter retires its sidecar lineage in the experiment")
	_check(lineage.get_lineage(create_c) == 299999, "created frozen Matter receives fresh lineage in the experiment")

	var post_mutation_cells := volume.duplicate_cells()
	var post_mutation_lineage := lineage.duplicate_tokens()
	var frozen_pose_after_edit := body.global_transform
	for _frame in range(6):
		await physics_frame
		await process_frame
	_check(_transform_gap(frozen_pose_after_edit, body.global_transform) < 0.00001, "edited frozen body remains spatially stable")

	# Observe host unfreeze semantics without restoring velocity ourselves.
	await physics_frame
	var unfreeze_world_before := _world_cell_positions(body, volume)
	var unfreeze_pose_before := body.global_transform
	var linear_before_unfreeze := body.linear_velocity
	var angular_before_unfreeze := body.angular_velocity
	body.freeze = false
	var unfreeze_toggle_jump := _transform_gap(unfreeze_pose_before, body.global_transform)
	var linear_immediate_unfrozen := body.linear_velocity
	var angular_immediate_unfrozen := body.angular_velocity
	_check(not body.freeze, "body reports dynamic state immediately after unfreeze")
	_check(body.get_instance_id() == instance_id and body.get_rid() == rid, "unfreeze keeps engine instance and RID identity")
	_check(unfreeze_toggle_jump < 0.000001, "unfreeze toggle does not synchronously jump body pose")
	_check(_world_cell_position_error(unfreeze_world_before, body, volume) < 0.000001, "unfreeze does not synchronously jump world-space Matter")

	await process_frame
	var first_unfreeze_server_step_transform := PhysicsServer3D.body_get_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM) as Transform3D
	var first_unfreeze_server_displacement := first_unfreeze_server_step_transform.origin.distance_to(unfreeze_pose_before.origin)
	await physics_frame
	var first_unfreeze_node_sync_gap := body.global_transform.origin.distance_to(first_unfreeze_server_step_transform.origin)
	await process_frame
	var linear_after_first_unfreeze_step := body.linear_velocity
	var angular_after_first_unfreeze_step := body.angular_velocity

	# Regardless of what freeze/unfreeze did to prior velocity, prove that the same
	# host body can return to active rigid motion and preserve the edited Matter.
	await physics_frame
	var commanded_start_transform := body.global_transform
	body.linear_velocity = Vector3(-1.6, 0.25, 2.05)
	body.angular_velocity = Vector3(-0.24, 0.39, 0.33)
	for _frame in range(RESUME_DRIVE_FRAMES):
		await physics_frame
		await process_frame
	var commanded_end_transform := body.global_transform
	var resumed_translation := commanded_end_transform.origin.distance_to(commanded_start_transform.origin)
	var resumed_rotation := _basis_axis_error(
		commanded_end_transform.basis.orthonormalized(),
		commanded_start_transform.basis.orthonormalized()
	)
	_check(resumed_translation > 0.1, "same host resumes commanded rigid translation after unfreeze")
	_check(resumed_rotation > 0.02, "same host resumes commanded rigid rotation after unfreeze")
	_check(volume.duplicate_cells() == post_mutation_cells, "dynamic resume preserves edited Matter storage")
	_check(lineage.duplicate_tokens() == post_mutation_lineage, "dynamic resume preserves edited lineage sidecar")
	_check(body.get_collision_shape_count() == volume.count_solid(), "dynamic resume retains rebuilt collision representation")
	_check(abs(body.mass - expected_mass) < 0.00001, "dynamic resume retains rebuilt mass")

	# Freeze again at the arbitrary orientation reached through active simulation.
	await physics_frame
	var second_freeze_transform := body.global_transform
	body.freeze = true
	var second_freeze_toggle_jump := _transform_gap(second_freeze_transform, body.global_transform)
	var max_second_frozen_drift := 0.0
	for _frame in range(FINAL_FROZEN_FRAMES):
		await physics_frame
		await process_frame
		max_second_frozen_drift = max(max_second_frozen_drift, _transform_gap(second_freeze_transform, body.global_transform))
	_check(second_freeze_toggle_jump < 0.000001, "second freeze does not synchronously jump arbitrary dynamic pose")
	_check(max_second_frozen_drift < 0.00001, "second freeze preserves arbitrary post-motion orientation and position")
	_check(body.get_instance_id() == instance_id and body.get_rid() == rid, "entire I0A cycle uses one engine instance and RID")
	_check(volume.duplicate_cells() == post_mutation_cells, "entire I0A cycle preserves final authoritative Matter")
	_check(lineage.duplicate_tokens() == post_mutation_lineage, "entire I0A cycle preserves final lineage state")
	_check(_finite_body_state(body), "same-body lifecycle remains numerically finite")

	var material_changes_from_initial := _count_int32_mismatches(initial_cells, volume.duplicate_cells())
	var lineage_changes_from_initial := _count_int64_mismatches(initial_lineage, lineage.duplicate_tokens())
	print(
		"LIFECYCLE_FREEZE_SEMANTICS_METRIC instance_id=%d rid_id=%d dynamic_translation=%.8f dynamic_rotation=%.8f freeze_phase_advance=%.10f freeze_toggle_jump=%.10f max_frozen_pose_drift=%.10f frozen_rebuild_pose_jump=%.10f unfreeze_toggle_jump=%.10f first_unfreeze_server_displacement=%.10f first_unfreeze_node_sync_gap=%.10f resumed_translation=%.8f resumed_rotation=%.8f second_freeze_toggle_jump=%.10f max_second_frozen_drift=%.10f linear_pre_freeze=%s angular_pre_freeze=%s linear_immediate_frozen=%s angular_immediate_frozen=%s linear_after_frozen_window=%s angular_after_frozen_window=%s linear_before_unfreeze=%s angular_before_unfreeze=%s linear_immediate_unfrozen=%s angular_immediate_unfrozen=%s linear_after_first_unfreeze_step=%s angular_after_first_unfreeze_step=%s initial_mass=%.6f final_mass=%.6f initial_shapes=%d final_shapes=%d material_changes=%d lineage_changes=%d retired_a=%d retired_b=%d created_token=%d"
		% [
			instance_id,
			rid.get_id(),
			dynamic_translation,
			dynamic_rotation,
			freeze_phase_advance,
			freeze_toggle_jump,
			max_frozen_pose_drift,
			frozen_rebuild_pose_jump,
			unfreeze_toggle_jump,
			first_unfreeze_server_displacement,
			first_unfreeze_node_sync_gap,
			resumed_translation,
			resumed_rotation,
			second_freeze_toggle_jump,
			max_second_frozen_drift,
			pre_freeze_linear,
			pre_freeze_angular,
			linear_immediate_frozen,
			angular_immediate_frozen,
			linear_after_frozen_window,
			angular_after_frozen_window,
			linear_before_unfreeze,
			angular_before_unfreeze,
			linear_immediate_unfrozen,
			angular_immediate_unfrozen,
			linear_after_first_unfreeze_step,
			angular_after_first_unfreeze_step,
			initial_mass,
			body.mass,
			initial_shape_count,
			body.get_collision_shape_count(),
			material_changes_from_initial,
			lineage_changes_from_initial,
			retired_a,
			retired_b,
			lineage.get_lineage(create_c),
		]
	)

	_finish()


func _world_cell_positions(body: Node3D, volume: CellVolume) -> Dictionary:
	var result: Dictionary = {}
	for cell in _occupied_cells(volume):
		result[cell] = body.global_transform * (Vector3(cell) + Vector3(0.5, 0.5, 0.5))
	return result


func _world_cell_position_error(snapshot: Dictionary, body: Node3D, volume: CellVolume) -> float:
	var max_error := 0.0
	for cell_variant in snapshot.keys():
		var cell: Vector3i = cell_variant
		if volume.get_cell(cell) == CellVolume.EMPTY:
			continue
		var expected: Vector3 = snapshot[cell]
		var actual := body.global_transform * (Vector3(cell) + Vector3(0.5, 0.5, 0.5))
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


func _count_int32_mismatches(a: PackedInt32Array, b: PackedInt32Array) -> int:
	if a.size() != b.size():
		return max(a.size(), b.size())
	var mismatches := 0
	for index in range(a.size()):
		if a[index] != b[index]:
			mismatches += 1
	return mismatches


func _count_int64_mismatches(a: PackedInt64Array, b: PackedInt64Array) -> int:
	if a.size() != b.size():
		return max(a.size(), b.size())
	var mismatches := 0
	for index in range(a.size()):
		if a[index] != b[index]:
			mismatches += 1
	return mismatches


func _finite_body_state(body: ConstructBody) -> bool:
	return (
		body.global_position.is_finite()
		and body.linear_velocity.is_finite()
		and body.angular_velocity.is_finite()
		and body.matter_center_of_mass_local.is_finite()
		and is_finite(body.mass)
	)


func _finish() -> void:
	if _failures.is_empty():
		print("LIFECYCLE_FREEZE_SEMANTICS_PROBE_PASS: one ConstructBody/RID survived dynamic→static-freeze→frozen live edit→dynamic→static-freeze while preserving Matter/lineage/derived-state coherence; host velocity semantics are reported as telemetry.")
		quit(0)
		return
	for failure in _failures:
		push_error("LIFECYCLE_FREEZE_SEMANTICS_PROBE_FAIL: " + failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)