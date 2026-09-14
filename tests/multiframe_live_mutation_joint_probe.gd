extends SceneTree

const MASS_PER_CELL := 2.25
const SETTLE_FRAMES := 30
const DRIVE_FRAMES := 90
const MUTATION_SETTLE_FRAMES := 3

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	world.name = "MultiFrameLiveMutationJointWorld"
	get_root().add_child(world)

	var edited_volume := CellVolume.new(Vector3i(6, 3, 4))
	edited_volume.fill_box(Vector3i.ZERO, edited_volume.size, 2)
	var sibling_volume := CellVolume.new(Vector3i(4, 3, 4))
	sibling_volume.fill_box(Vector3i.ZERO, sibling_volume.size, 3)

	var sibling_snapshot := sibling_volume.duplicate_cells()
	var initial_edited_snapshot := edited_volume.duplicate_cells()

	var assembly_transform := Transform3D(
		Basis.from_euler(Vector3(0.17, -0.42, 0.24)),
		Vector3(9.0, 6.0, -5.0)
	)
	var edited := _make_body(world, "EditedFrame", edited_volume, assembly_transform)
	var sibling := _make_body(
		world,
		"SiblingFrame",
		sibling_volume,
		assembly_transform * Transform3D(Basis.IDENTITY, Vector3(6.0, 0.0, 0.0))
	)
	var edited_id := edited.get_instance_id()
	var sibling_id := sibling.get_instance_id()

	var anchor_world: Vector3 = assembly_transform * Vector3(6.0, 1.5, 2.0)
	var edited_anchor_local: Vector3 = edited.to_local(anchor_world)
	var sibling_anchor_local: Vector3 = sibling.to_local(anchor_world)
	var common_linear_at_anchor := Vector3(1.1, -0.3, 0.7)
	var common_angular := Vector3(0.24, -0.36, 0.29)
	edited.linear_velocity = _velocity_at_point(
		common_linear_at_anchor,
		common_angular,
		anchor_world,
		edited.to_global(edited.matter_center_of_mass_local)
	)
	sibling.linear_velocity = _velocity_at_point(
		common_linear_at_anchor,
		common_angular,
		anchor_world,
		sibling.to_global(sibling.matter_center_of_mass_local)
	)
	edited.angular_velocity = common_angular
	sibling.angular_velocity = common_angular

	var joint := PinJoint3D.new()
	joint.name = "LiveMutationMechanicalLink"
	world.add_child(joint)
	joint.global_position = anchor_world
	joint.node_a = joint.get_path_to(edited)
	joint.node_b = joint.get_path_to(sibling)
	joint.exclude_nodes_from_collision = true

	var max_anchor_gap := 0.0
	for _frame in range(SETTLE_FRAMES):
		await physics_frame
		await process_frame
		max_anchor_gap = max(max_anchor_gap, _anchor_gap(edited, sibling, edited_anchor_local, sibling_anchor_local))

	# Put the coupled system into non-trivial relative motion before edits begin.
	sibling.apply_torque_impulse(assembly_transform.basis * Vector3(11.0, 19.0, -7.0))
	for _frame in range(DRIVE_FRAMES):
		await physics_frame
		await process_frame
		max_anchor_gap = max(max_anchor_gap, _anchor_gap(edited, sibling, edited_anchor_local, sibling_anchor_local))

	var initial_mass := edited.mass
	var initial_com := edited.matter_center_of_mass_local
	var mutation_cells: Array[Vector3i] = [
		Vector3i(0, 0, 0),
		Vector3i(0, 0, 1),
		Vector3i(0, 1, 0),
		Vector3i(1, 0, 0),
		Vector3i(0, 2, 3),
		Vector3i(1, 2, 3),
		Vector3i(0, 2, 2),
		Vector3i(1, 2, 2),
	]

	var max_com_shift := 0.0
	var max_mass_error := 0.0
	var max_shape_error := 0
	var max_rebuild_usec := 0
	var max_linear_speed := 0.0
	var max_angular_speed := 0.0
	var mutation_count := 0

	# Remove an asymmetric set and then restore it. Each operation rebuilds the
	# derived mesh/colliders/mass properties on the SAME RigidBody3D while the
	# joint stays alive and the sibling remains a separate frame.
	for material_id in [CellVolume.EMPTY, 2]:
		var cells: Array[Vector3i] = mutation_cells
		if material_id != CellVolume.EMPTY:
			cells = mutation_cells.duplicate()
			cells.reverse()
		for cell in cells:
			var changed := edited.volume.set_cell(cell, material_id)
			_check(changed, "deterministic live mutation changes the intended Matter cell")
			if not changed:
				continue
			edited.rebuild_derived()
			mutation_count += 1

			var expected_mass := float(edited.volume.count_solid()) * MASS_PER_CELL
			var expected_com := MatterTopology.center_of_mass_local(edited.volume)
			var expected_shapes := CellCollisionBoxer.build_boxes(edited.volume, edited.collision_mode).size()
			max_mass_error = max(max_mass_error, abs(edited.mass - expected_mass))
			max_shape_error = max(max_shape_error, abs(edited.get_collision_shape_count() - expected_shapes))
			max_com_shift = max(max_com_shift, edited.matter_center_of_mass_local.distance_to(initial_com))
			max_rebuild_usec = max(max_rebuild_usec, edited.last_rebuild_usec)
			_check(edited.matter_center_of_mass_local.distance_to(expected_com) < 0.000001, "live-mutated frame publishes synchronous Matter COM")
			_check(edited.get_instance_id() == edited_id, "live mutation preserves edited physics-body identity")
			_check(sibling.get_instance_id() == sibling_id, "live mutation preserves sibling physics-body identity")

			for _frame in range(MUTATION_SETTLE_FRAMES):
				await physics_frame
				await process_frame
				max_anchor_gap = max(max_anchor_gap, _anchor_gap(edited, sibling, edited_anchor_local, sibling_anchor_local))
				max_linear_speed = max(max_linear_speed, max(edited.linear_velocity.length(), sibling.linear_velocity.length()))
				max_angular_speed = max(max_angular_speed, max(edited.angular_velocity.length(), sibling.angular_velocity.length()))
				_check(_finite_body_state(edited) and _finite_body_state(sibling), "constraint-linked bodies remain numerically finite during live mutation")

	var final_anchor_gap := _anchor_gap(edited, sibling, edited_anchor_local, sibling_anchor_local)
	var edited_storage_mismatch := _count_mismatches(initial_edited_snapshot, edited.volume.duplicate_cells())
	var sibling_storage_mismatch := _count_mismatches(sibling_snapshot, sibling.volume.duplicate_cells())

	_check(mutation_count == mutation_cells.size() * 2, "campaign executes every planned remove/add mutation")
	_check(max_com_shift > 0.05, "asymmetric edits materially move the edited frame COM")
	_check(max_mass_error < 0.00001, "edited frame mass stays coherent with current Matter")
	_check(max_shape_error == 0, "edited frame collision-shape count stays coherent with active collision compiler output")
	_check(abs(edited.mass - initial_mass) < 0.00001, "restoring the removed Matter restores initial total mass")
	_check(edited_storage_mismatch == 0, "remove/add cycle restores edited Matter exactly")
	_check(sibling_storage_mismatch == 0, "editing one constrained frame never mutates sibling Matter")
	_check(max_anchor_gap < 0.02, "joint remains bounded while endpoint geometry/mass/COM are rebuilt")
	_check(final_anchor_gap < 0.005, "joint closes back to a tight anchor after all live mutations")
	_check(max_linear_speed < 100.0 and max_angular_speed < 100.0, "live-mutation campaign does not produce solver explosion")
	_check(edited.get_parent() == world and sibling.get_parent() == world, "constraint-linked frames remain separate scene siblings")
	_check(edited.get_instance_id() != sibling.get_instance_id(), "constraint-linked frames remain separate physics identities")

	print(
		"MULTIFRAME_LIVE_MUTATION_JOINT_METRIC mutations=%d initial_cells=%d final_cells=%d initial_mass=%.6f final_mass=%.6f max_com_shift=%.10f max_mass_error=%.10f max_shape_error=%d max_rebuild_usec=%d max_anchor_gap=%.10f final_anchor_gap=%.10f max_linear_speed=%.6f max_angular_speed=%.6f edited_storage_mismatch=%d sibling_storage_mismatch=%d edited_id=%d sibling_id=%d"
		% [
			mutation_count,
			initial_edited_snapshot.size(),
			edited.volume.count_solid(),
			initial_mass,
			edited.mass,
			max_com_shift,
			max_mass_error,
			max_shape_error,
			max_rebuild_usec,
			max_anchor_gap,
			final_anchor_gap,
			max_linear_speed,
			max_angular_speed,
			edited_storage_mismatch,
			sibling_storage_mismatch,
			edited_id,
			sibling_id,
		]
	)

	_finish()


func _make_body(world: Node3D, body_name: String, volume: CellVolume, transform: Transform3D) -> ConstructBody:
	var body := ConstructBody.new()
	body.name = body_name
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
	body.global_transform = transform
	body.set_volume(volume)
	return body


func _anchor_gap(a: ConstructBody, b: ConstructBody, a_local: Vector3, b_local: Vector3) -> float:
	return a.to_global(a_local).distance_to(b.to_global(b_local))


func _velocity_at_point(linear_at_anchor: Vector3, angular: Vector3, anchor_world: Vector3, point_world: Vector3) -> Vector3:
	return linear_at_anchor + angular.cross(point_world - anchor_world)


func _finite_body_state(body: ConstructBody) -> bool:
	return (
		body.global_position.is_finite()
		and body.linear_velocity.is_finite()
		and body.angular_velocity.is_finite()
		and is_finite(body.mass)
		and body.matter_center_of_mass_local.is_finite()
	)


func _count_mismatches(expected: PackedInt32Array, actual: PackedInt32Array) -> int:
	if expected.size() != actual.size():
		return max(expected.size(), actual.size())
	var mismatches := 0
	for index in range(expected.size()):
		if expected[index] != actual[index]:
			mismatches += 1
	return mismatches


func _finish() -> void:
	if _failures.is_empty():
		print("MULTIFRAME_LIVE_MUTATION_JOINT_PROBE_PASS: one mechanically constrained Matter frame survived repeated live geometry/collision/mass/COM rebuilds without frame replacement, sibling mutation or joint loss.")
		quit(0)
		return
	for failure in _failures:
		push_error("MULTIFRAME_LIVE_MUTATION_JOINT_PROBE_FAIL: " + failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
