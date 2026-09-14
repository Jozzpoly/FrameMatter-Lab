extends SceneTree

const VOLUME_SIZE := Vector3i(10, 3, 3)
const CUT_CELL := Vector3i(4, 1, 1)
const ANCHOR_OWNER_CELL := Vector3i(9, 1, 1)
const MASS_PER_CELL := 1.8
const PRE_SPLIT_FRAMES := 50
const POST_SPLIT_FRAMES := 220
const LIMIT_ABS := 0.45
const MOTOR_TARGET := 1.4
const MOTOR_MAX_IMPULSE := 40.0

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	world.name = "HingeMotorLimitSuccessionWorld"
	get_root().add_child(world)

	var parent_volume := _make_parent_volume()
	var sibling_volume := CellVolume.new(Vector3i(3, 3, 3))
	sibling_volume.fill_box(Vector3i.ZERO, sibling_volume.size, 3)

	var parent_lineage := MatterLineageMap.new(VOLUME_SIZE)
	var next_token := 150001
	for cell in _occupied_cells(parent_volume):
		parent_lineage.set_lineage(cell, next_token)
		next_token += 1
	var anchor_owner_token := parent_lineage.get_lineage(ANCHOR_OWNER_CELL)
	_check(anchor_owner_token != 0, "stateful hinge anchor owner begins with retained Matter lineage")

	var assembly_transform := Transform3D(
		Basis.from_euler(Vector3(0.15, -0.41, 0.19)),
		Vector3(11.0, 5.0, -7.0)
	)
	var parent := _make_body(world, "MotorParent", parent_volume, assembly_transform)
	var sibling := _make_body(
		world,
		"MotorSibling",
		sibling_volume,
		assembly_transform * Transform3D(Basis.IDENTITY, Vector3(10.0, 0.0, 0.0))
	)
	var parent_id := parent.get_instance_id()

	var anchor_parent_local := Vector3(10.0, 1.5, 1.5)
	var hinge_local_basis := Basis.from_euler(Vector3(0.27, -0.18, 0.39)).orthonormalized()
	var hinge_parent_local := Transform3D(hinge_local_basis, anchor_parent_local)
	var hinge_world_initial: Transform3D = parent.global_transform * hinge_parent_local
	var hinge_sibling_local: Transform3D = sibling.global_transform.affine_inverse() * hinge_world_initial

	var common_anchor_velocity := Vector3(1.05, -0.12, 0.72)
	var common_angular := Vector3(0.19, -0.23, 0.28)
	_set_common_rigid_motion(parent, sibling, hinge_world_initial.origin, common_anchor_velocity, common_angular)

	var joint := HingeJoint3D.new()
	joint.name = "StatefulPersistentHinge"
	world.add_child(joint)
	joint.global_transform = hinge_world_initial
	joint.node_a = joint.get_path_to(parent)
	joint.node_b = joint.get_path_to(sibling)
	joint.exclude_nodes_from_collision = true
	var joint_id := joint.get_instance_id()

	# First prove the passive hinge starts near zero relative angle with stable axis.
	var max_pre_anchor_gap := 0.0
	var max_pre_axis_error := 0.0
	for _frame in range(PRE_SPLIT_FRAMES):
		await physics_frame
		await process_frame
		max_pre_anchor_gap = max(max_pre_anchor_gap, _hinge_anchor_gap(parent, hinge_parent_local, sibling, hinge_sibling_local))
		max_pre_axis_error = max(max_pre_axis_error, _hinge_axis_error(parent, hinge_parent_local, sibling, hinge_sibling_local))
	_check(max_pre_anchor_gap < 0.01, "passive stateful hinge anchor is stable before succession")
	_check(max_pre_axis_error < 0.01, "passive stateful hinge axis is aligned before succession")

	# Resume before the upcoming PhysicsServer step. Enable motor + symmetric limits
	# immediately before topology replacement, and reset relative rigid velocity to
	# near zero. Any substantial post-split hinge motion therefore requires the
	# stateful motor to survive endpoint reconfiguration; bounded motion requires
	# the angular limits to survive as well.
	await physics_frame
	var hinge_world_before: Transform3D = parent.global_transform * hinge_parent_local
	_set_common_rigid_motion(parent, sibling, hinge_world_before.origin, common_anchor_velocity, common_angular)
	var relative_speed_before := _relative_hinge_speed(parent, hinge_parent_local, sibling, hinge_sibling_local)
	var relative_angle_before := abs(_signed_hinge_angle(parent, hinge_parent_local, sibling, hinge_sibling_local))
	_check(relative_speed_before < 0.001, "motor-limit succession starts from essentially zero relative hinge speed")
	_check(relative_angle_before < 0.03, "motor-limit succession starts near the neutral hinge angle")

	joint.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, -LIMIT_ABS)
	joint.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, LIMIT_ABS)
	joint.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, MOTOR_TARGET)
	joint.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, MOTOR_MAX_IMPULSE)
	joint.set_flag(HingeJoint3D.FLAG_USE_LIMIT, true)
	joint.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, true)

	_check(joint.get_flag(HingeJoint3D.FLAG_USE_LIMIT), "hinge angular limit is enabled before endpoint replacement")
	_check(joint.get_flag(HingeJoint3D.FLAG_ENABLE_MOTOR), "hinge motor is enabled before endpoint replacement")
	_check(abs(joint.get_param(HingeJoint3D.PARAM_LIMIT_LOWER) + LIMIT_ABS) < 0.000001, "hinge lower limit stores intended value before endpoint replacement")
	_check(abs(joint.get_param(HingeJoint3D.PARAM_LIMIT_UPPER) - LIMIT_ABS) < 0.000001, "hinge upper limit stores intended value before endpoint replacement")
	_check(abs(joint.get_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY) - MOTOR_TARGET) < 0.000001, "hinge motor target stores intended value before endpoint replacement")

	var parent_transform: Transform3D = parent.global_transform
	var parent_linear: Vector3 = parent.linear_velocity
	var parent_angular: Vector3 = parent.angular_velocity
	var parent_com_world: Vector3 = parent.to_global(parent.matter_center_of_mass_local)
	var joint_origin_staleness := joint.global_position.distance_to(hinge_world_before.origin)
	var joint_basis_staleness := _basis_axis_error(joint.global_basis.orthonormalized(), hinge_world_before.basis.orthonormalized())

	_check(parent.volume.set_cell(CUT_CELL, CellVolume.EMPTY), "stateful hinge split removes intended bridge Matter")
	parent_lineage.clear_lineage(CUT_CELL)
	var components: Array[CellVolume] = MatterTopology.extract_connected_components(parent.volume)
	_check(components.size() == 2, "stateful hinge parent split produces two successors")
	if components.size() != 2:
		_finish()
		return

	var children: Array[ConstructBody] = []
	var child_origins: Array[Vector3i] = []
	var child_lineages: Array[MatterLineageMap] = []
	var anchor_child_index := -1
	var lineage_mismatches := 0
	var max_world_error := 0.0
	var max_velocity_error := 0.0

	for index in range(components.size()):
		var source_component: CellVolume = components[index]
		var compact_info: Dictionary = MatterTopology.compact_volume(source_component)
		var source_origin: Vector3i = compact_info["origin"]
		var compact_volume: CellVolume = compact_info["volume"]
		var child := _make_body(
			world,
			"MotorSuccessor_%d" % index,
			compact_volume,
			parent_transform * Transform3D(Basis.IDENTITY, Vector3(source_origin))
		)
		var child_com_world := child.to_global(child.matter_center_of_mass_local)
		child.linear_velocity = _velocity_at_point(parent_linear, parent_angular, parent_com_world, child_com_world)
		child.angular_velocity = parent_angular
		children.append(child)
		child_origins.append(source_origin)

		var child_lineage := MatterLineageMap.new(compact_volume.size)
		for source_cell in _occupied_cells(source_component):
			var compact_cell := source_cell - source_origin
			var token := parent_lineage.get_lineage(source_cell)
			child_lineage.set_lineage(compact_cell, token)
			if child_lineage.get_lineage(compact_cell) != token:
				lineage_mismatches += 1

			var source_world := parent_transform * (Vector3(source_cell) + Vector3(0.5, 0.5, 0.5))
			var child_world := child.to_global(Vector3(compact_cell) + Vector3(0.5, 0.5, 0.5))
			max_world_error = max(max_world_error, source_world.distance_to(child_world))
			var source_velocity := _velocity_at_point(parent_linear, parent_angular, parent_com_world, source_world)
			var child_velocity := _velocity_at_point(child.linear_velocity, child.angular_velocity, child_com_world, child_world)
			max_velocity_error = max(max_velocity_error, source_velocity.distance_to(child_velocity))
		child_lineages.append(child_lineage)

		if source_component.get_cell(ANCHOR_OWNER_CELL) != CellVolume.EMPTY:
			anchor_child_index = index

	_check(anchor_child_index >= 0, "stateful hinge owner Matter selects one successor")
	if anchor_child_index < 0:
		_finish()
		return

	var anchor_child: ConstructBody = children[anchor_child_index]
	var free_child: ConstructBody = children[1 - anchor_child_index]
	var anchor_origin: Vector3i = child_origins[anchor_child_index]
	var mapped_owner_cell := ANCHOR_OWNER_CELL - anchor_origin
	var inherited_token := child_lineages[anchor_child_index].get_lineage(mapped_owner_cell)
	var mapped_hinge_local := Transform3D(
		hinge_parent_local.basis,
		hinge_parent_local.origin - Vector3(anchor_origin)
	)
	var mapped_hinge_world := anchor_child.global_transform * mapped_hinge_local

	_check(inherited_token == anchor_owner_token, "stateful hinge endpoint follows retained owner lineage")
	_check(lineage_mismatches == 0, "stateful hinge split preserves all retained lineage")
	_check(max_world_error < 0.00001, "stateful hinge split preserves Matter world positions")
	_check(max_velocity_error < 0.00001, "stateful hinge split preserves Matter velocity field")
	_check(mapped_hinge_world.origin.distance_to(hinge_world_before.origin) < 0.00001, "stateful hinge anchor maps continuously into successor")
	_check(_basis_axis_error(mapped_hinge_world.basis.orthonormalized(), hinge_world_before.basis.orthonormalized()) < 0.00001, "stateful hinge basis maps continuously into successor")
	_check(joint_origin_staleness > 0.1 and joint_basis_staleness > 0.01, "persistent stateful hinge scene frame is materially stale before rebase")

	joint.global_transform = hinge_world_before
	joint.force_update_transform()
	var rebase_origin_error := joint.global_position.distance_to(hinge_world_before.origin)
	var rebase_basis_error := _basis_axis_error(joint.global_basis.orthonormalized(), hinge_world_before.basis.orthonormalized())
	_check(rebase_origin_error < 0.000001 and rebase_basis_error < 0.000001, "full stateful hinge frame rebases before endpoint replacement")

	joint.node_a = joint.get_path_to(anchor_child)
	_check(joint.get_instance_id() == joint_id, "stateful logical hinge identity survives endpoint replacement")
	_check(anchor_child.get_instance_id() != parent_id, "stateful hinge topology successor has new physics identity")
	# Node-side state must still be present after the host joint was reconstructed.
	_check(joint.get_flag(HingeJoint3D.FLAG_USE_LIMIT), "hinge limit flag survives endpoint reconstruction")
	_check(joint.get_flag(HingeJoint3D.FLAG_ENABLE_MOTOR), "hinge motor flag survives endpoint reconstruction")
	_check(abs(joint.get_param(HingeJoint3D.PARAM_LIMIT_LOWER) + LIMIT_ABS) < 0.000001, "hinge lower limit survives endpoint reconstruction")
	_check(abs(joint.get_param(HingeJoint3D.PARAM_LIMIT_UPPER) - LIMIT_ABS) < 0.000001, "hinge upper limit survives endpoint reconstruction")
	_check(abs(joint.get_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY) - MOTOR_TARGET) < 0.000001, "hinge motor target survives endpoint reconstruction")
	parent.free()

	await process_frame
	await physics_frame
	await process_frame

	var max_anchor_gap := 0.0
	var max_axis_error := 0.0
	var max_abs_angle := 0.0
	var max_relative_speed := 0.0
	var angle_after_30 := 0.0
	var free_child_start := free_child.global_position
	var max_free_child_separation := 0.0

	free_child.apply_central_impulse(assembly_transform.basis * Vector3(-7.0, 4.0, 11.0))

	for frame in range(POST_SPLIT_FRAMES):
		await physics_frame
		await process_frame
		var angle := abs(_signed_hinge_angle(anchor_child, mapped_hinge_local, sibling, hinge_sibling_local))
		var relative_speed := _relative_hinge_speed(anchor_child, mapped_hinge_local, sibling, hinge_sibling_local)
		max_abs_angle = max(max_abs_angle, angle)
		max_relative_speed = max(max_relative_speed, relative_speed)
		max_anchor_gap = max(max_anchor_gap, _hinge_anchor_gap(anchor_child, mapped_hinge_local, sibling, hinge_sibling_local))
		max_axis_error = max(max_axis_error, _hinge_axis_error(anchor_child, mapped_hinge_local, sibling, hinge_sibling_local))
		max_free_child_separation = max(max_free_child_separation, free_child.global_position.distance_to(free_child_start))
		if frame == 30:
			angle_after_30 = angle
		_check(_finite_body_state(anchor_child) and _finite_body_state(sibling) and _finite_body_state(free_child), "stateful hinge succession remains numerically finite")

	var final_angle := abs(_signed_hinge_angle(anchor_child, mapped_hinge_local, sibling, hinge_sibling_local))
	var final_relative_speed := _relative_hinge_speed(anchor_child, mapped_hinge_local, sibling, hinge_sibling_local)
	var final_anchor_gap := _hinge_anchor_gap(anchor_child, mapped_hinge_local, sibling, hinge_sibling_local)
	var final_axis_error := _hinge_axis_error(anchor_child, mapped_hinge_local, sibling, hinge_sibling_local)

	# The motor must create substantial new relative rotation after succession.
	# The symmetric limit must then prevent continuous spin and arrest the motor at
	# one side. Broad tolerances intentionally allow host-solver compliance without
	# mistaking an unbounded or inactive constraint for PASS.
	_check(angle_after_30 > 0.10, "inherited hinge motor creates relative rotation shortly after topology replacement")
	_check(max_abs_angle > 0.30, "inherited hinge motor reaches a material fraction of the configured angular range")
	_check(max_abs_angle < LIMIT_ABS + 0.12, "inherited angular limit prevents unbounded motor-driven rotation")
	_check(final_angle > 0.30 and final_angle < LIMIT_ABS + 0.10, "stateful hinge settles near one configured angular limit")
	_check(final_relative_speed < 0.20, "angular limit arrests sustained motor-driven relative rotation")
	_check(max_relative_speed > 0.20, "motor produces material relative angular speed before the limit arrests it")
	_check(max_anchor_gap < 0.02 and final_anchor_gap < 0.005, "stateful inherited hinge keeps a tight translational anchor")
	_check(max_axis_error < 0.02 and final_axis_error < 0.01, "stateful inherited hinge keeps its physical axes aligned")
	_check(max_free_child_separation > 0.1, "non-owning successor remains independent during stateful hinge operation")

	print(
		"MULTIFRAME_HINGE_MOTOR_LIMIT_SUCCESSION_METRIC owner_token=%d inherited_token=%d lineage_mismatches=%d world_error=%.10f velocity_error=%.10f relative_angle_before=%.10f relative_speed_before=%.10f origin_staleness=%.10f basis_staleness=%.10f rebase_origin_error=%.10f rebase_basis_error=%.10f angle_after_30=%.6f max_abs_angle=%.6f final_angle=%.6f max_relative_speed=%.6f final_relative_speed=%.6f max_anchor_gap=%.10f final_anchor_gap=%.10f max_axis_error=%.10f final_axis_error=%.10f free_child_separation=%.6f motor_target=%.6f limit_abs=%.6f joint_id=%d"
		% [
			anchor_owner_token, inherited_token, lineage_mismatches,
			max_world_error, max_velocity_error,
			relative_angle_before, relative_speed_before,
			joint_origin_staleness, joint_basis_staleness,
			rebase_origin_error, rebase_basis_error,
			angle_after_30, max_abs_angle, final_angle,
			max_relative_speed, final_relative_speed,
			max_anchor_gap, final_anchor_gap,
			max_axis_error, final_axis_error,
			max_free_child_separation, MOTOR_TARGET, LIMIT_ABS,
			joint_id,
		]
	)

	_finish()


func _make_parent_volume() -> CellVolume:
	var volume := CellVolume.new(VOLUME_SIZE)
	volume.fill_box(Vector3i(0, 0, 0), Vector3i(3, 3, 3), 2)
	volume.fill_box(Vector3i(6, 0, 0), Vector3i(10, 3, 3), 2)
	for x in range(3, 6):
		volume.set_cell(Vector3i(x, 1, 1), 2)
	return volume


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


func _set_common_rigid_motion(body_a: ConstructBody, body_b: ConstructBody, anchor_world: Vector3, anchor_velocity: Vector3, angular: Vector3) -> void:
	body_a.angular_velocity = angular
	body_b.angular_velocity = angular
	body_a.linear_velocity = _linear_velocity_for_anchor(anchor_velocity, angular, body_a.to_global(body_a.matter_center_of_mass_local), anchor_world)
	body_b.linear_velocity = _linear_velocity_for_anchor(anchor_velocity, angular, body_b.to_global(body_b.matter_center_of_mass_local), anchor_world)


func _linear_velocity_for_anchor(anchor_velocity: Vector3, angular: Vector3, com_world: Vector3, anchor_world: Vector3) -> Vector3:
	return anchor_velocity - angular.cross(anchor_world - com_world)


func _hinge_anchor_gap(body_a: ConstructBody, frame_a: Transform3D, body_b: ConstructBody, frame_b: Transform3D) -> float:
	return (body_a.global_transform * frame_a).origin.distance_to((body_b.global_transform * frame_b).origin)


func _hinge_axis(body: ConstructBody, frame: Transform3D) -> Vector3:
	return (body.global_basis * frame.basis.z).normalized()


func _hinge_axis_error(body_a: ConstructBody, frame_a: Transform3D, body_b: ConstructBody, frame_b: Transform3D) -> float:
	return _hinge_axis(body_a, frame_a).angle_to(_hinge_axis(body_b, frame_b))


func _signed_hinge_angle(body_a: ConstructBody, frame_a: Transform3D, body_b: ConstructBody, frame_b: Transform3D) -> float:
	var axis_a := _hinge_axis(body_a, frame_a)
	var axis_b := _hinge_axis(body_b, frame_b)
	var axis := (axis_a + axis_b).normalized()
	var normal_a := (body_a.global_basis * frame_a.basis.x).normalized()
	var normal_b := (body_b.global_basis * frame_b.basis.x).normalized()
	var sin_term := axis.dot(normal_a.cross(normal_b))
	var cos_term := clamp(normal_a.dot(normal_b), -1.0, 1.0)
	return atan2(sin_term, cos_term)


func _relative_hinge_speed(body_a: ConstructBody, frame_a: Transform3D, body_b: ConstructBody, frame_b: Transform3D) -> float:
	var axis_a := _hinge_axis(body_a, frame_a)
	var axis_b := _hinge_axis(body_b, frame_b)
	var axis := (axis_a + axis_b).normalized()
	return abs((body_b.angular_velocity - body_a.angular_velocity).dot(axis))


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


func _velocity_at_point(linear: Vector3, angular: Vector3, com_world: Vector3, point_world: Vector3) -> Vector3:
	return linear + angular.cross(point_world - com_world)


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
		print("MULTIFRAME_HINGE_MOTOR_LIMIT_SUCCESSION_PROBE_PASS: hinge motor and angular-limit state remained physically effective after full constraint-frame succession onto retained owner Matter.")
		quit(0)
		return
	for failure in _failures:
		push_error("MULTIFRAME_HINGE_MOTOR_LIMIT_SUCCESSION_PROBE_FAIL: " + failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
