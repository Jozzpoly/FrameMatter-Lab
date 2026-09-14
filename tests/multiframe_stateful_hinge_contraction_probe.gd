extends SceneTree

const LEFT_SIZE := Vector3i(4, 3, 3)
const RIGHT_SIZE := Vector3i(4, 3, 3)
const MERGED_SIZE := Vector3i(8, 3, 3)
const RIGHT_ORIGIN := Vector3i(4, 0, 0)
const MASS_PER_CELL := 1.7
const PRE_BIND_FRAMES := 50
const POST_BIND_FRAMES := 240
const LEFT_OWNER_CELL := Vector3i(0, 1, 1)
const RIGHT_OWNER_CELL := Vector3i(3, 1, 1)
const LEFT_LIMIT := 0.40
const RIGHT_LIMIT := 0.55
const LEFT_MOTOR_TARGET := 1.10
const RIGHT_MOTOR_TARGET := -1.30
const MOTOR_MAX_IMPULSE := 40.0

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	world.name = "StatefulHingeContractionWorld"
	get_root().add_child(world)

	var left_volume := CellVolume.new(LEFT_SIZE)
	left_volume.fill_box(Vector3i.ZERO, LEFT_SIZE, 2)
	var right_volume := CellVolume.new(RIGHT_SIZE)
	right_volume.fill_box(Vector3i.ZERO, RIGHT_SIZE, 3)
	var merged_volume := CellVolume.new(MERGED_SIZE)
	_copy_volume(left_volume, Vector3i.ZERO, merged_volume)
	_copy_volume(right_volume, RIGHT_ORIGIN, merged_volume)

	var left_lineage := MatterLineageMap.new(LEFT_SIZE)
	var right_lineage := MatterLineageMap.new(RIGHT_SIZE)
	var next_token := 170001
	for cell in _occupied_cells(left_volume):
		left_lineage.set_lineage(cell, next_token)
		next_token += 1
	for cell in _occupied_cells(right_volume):
		right_lineage.set_lineage(cell, next_token)
		next_token += 1
	var left_owner_token: int = left_lineage.get_lineage(LEFT_OWNER_CELL)
	var right_owner_token: int = right_lineage.get_lineage(RIGHT_OWNER_CELL)
	_check(left_owner_token != 0 and right_owner_token != 0 and left_owner_token != right_owner_token, "stateful external hinges start with distinct retained Matter lineage")

	var assembly_transform := Transform3D(
		Basis.from_euler(Vector3(0.10, -0.37, 0.16)),
		Vector3(14.0, 7.0, -9.0)
	)
	var left := _make_body(world, "StatefulContractionLeft", left_volume, assembly_transform)
	var right := _make_body(
		world,
		"StatefulContractionRight",
		right_volume,
		assembly_transform * Transform3D(Basis.IDENTITY, Vector3(RIGHT_ORIGIN))
	)
	var left_external := _make_box_body(
		world,
		"StatefulContractionExternalLeft",
		Vector3i(3, 3, 3),
		4,
		assembly_transform * Transform3D(Basis.IDENTITY, Vector3(-3.0, 0.0, 0.0))
	)
	var right_external := _make_box_body(
		world,
		"StatefulContractionExternalRight",
		Vector3i(3, 3, 3),
		5,
		assembly_transform * Transform3D(Basis.IDENTITY, Vector3(8.0, 0.0, 0.0))
	)
	var left_id := left.get_instance_id()
	var right_id := right.get_instance_id()
	var left_external_id := left_external.get_instance_id()
	var right_external_id := right_external.get_instance_id()

	var left_source_frame := Transform3D(
		Basis.from_euler(Vector3(0.28, -0.16, 0.34)).orthonormalized(),
		Vector3(0.0, 1.5, 1.5)
	)
	var right_source_frame := Transform3D(
		Basis.from_euler(Vector3(-0.21, 0.24, -0.31)).orthonormalized(),
		Vector3(4.0, 1.5, 1.5)
	)
	var seam_left_local := Vector3(4.0, 1.5, 1.5)
	var seam_right_local := Vector3(0.0, 1.5, 1.5)

	var left_world_initial: Transform3D = left.global_transform * left_source_frame
	var right_world_initial: Transform3D = right.global_transform * right_source_frame
	var seam_world: Vector3 = left.to_global(seam_left_local)
	var left_external_frame: Transform3D = left_external.global_transform.affine_inverse() * left_world_initial
	var right_external_frame: Transform3D = right_external.global_transform.affine_inverse() * right_world_initial

	var common_linear := Vector3(1.20, 0.08, -0.70)
	for body in [left, right, left_external, right_external]:
		body.linear_velocity = common_linear
		body.angular_velocity = Vector3.ZERO

	var left_joint := _make_hinge(world, "LeftExternalStatefulHinge", left_world_initial, left, left_external)
	var internal_joint := _make_pin_joint(world, "InternalContractionRelation", seam_world, left, right)
	var right_joint := _make_hinge(world, "RightExternalStatefulHinge", right_world_initial, right, right_external)
	var left_joint_id := left_joint.get_instance_id()
	var internal_joint_id := internal_joint.get_instance_id()
	var right_joint_id := right_joint.get_instance_id()

	var max_pre_left_gap := 0.0
	var max_pre_right_gap := 0.0
	var max_pre_left_axis_error := 0.0
	var max_pre_right_axis_error := 0.0
	for _frame in range(PRE_BIND_FRAMES):
		await physics_frame
		await process_frame
		max_pre_left_gap = max(max_pre_left_gap, _hinge_anchor_gap(left, left_source_frame, left_external, left_external_frame))
		max_pre_right_gap = max(max_pre_right_gap, _hinge_anchor_gap(right, right_source_frame, right_external, right_external_frame))
		max_pre_left_axis_error = max(max_pre_left_axis_error, _hinge_axis_error(left, left_source_frame, left_external, left_external_frame))
		max_pre_right_axis_error = max(max_pre_right_axis_error, _hinge_axis_error(right, right_source_frame, right_external, right_external_frame))
	_check(max_pre_left_gap < 0.01 and max_pre_right_gap < 0.01, "both passive external hinge anchors are stable before contraction")
	_check(max_pre_left_axis_error < 0.01 and max_pre_right_axis_error < 0.01, "both passive external hinge axes are aligned before contraction")

	await physics_frame
	var merge_transform: Transform3D = left.global_transform
	var expected_right_transform := merge_transform * Transform3D(Basis.IDENTITY, Vector3(RIGHT_ORIGIN))
	var source_alignment_error := right.global_transform.origin.distance_to(expected_right_transform.origin)
	var source_orientation_error := _basis_axis_error(right.global_transform.basis.orthonormalized(), expected_right_transform.basis.orthonormalized())
	_check(source_alignment_error < 0.002, "stateful contraction source lattices remain position-compatible at explicit bind instant")
	_check(source_orientation_error < 0.00001, "stateful contraction source lattices remain orientation-compatible at explicit bind instant")

	var left_world_before: Transform3D = left.global_transform * left_source_frame
	var right_world_before: Transform3D = right.global_transform * right_source_frame
	var left_angle_before: float = abs(_signed_hinge_angle(left, left_source_frame, left_external, left_external_frame))
	var right_angle_before: float = abs(_signed_hinge_angle(right, right_source_frame, right_external, right_external_frame))
	var left_speed_before: float = _relative_hinge_speed(left, left_source_frame, left_external, left_external_frame)
	var right_speed_before: float = _relative_hinge_speed(right, right_source_frame, right_external, right_external_frame)
	_check(left_angle_before < 0.04 and right_angle_before < 0.04, "both external hinges begin contraction near neutral angle")
	_check(left_speed_before < 0.001 and right_speed_before < 0.001, "both external hinges begin contraction with essentially zero relative angular speed")

	_configure_stateful_hinge(left_joint, LEFT_LIMIT, LEFT_MOTOR_TARGET)
	_configure_stateful_hinge(right_joint, RIGHT_LIMIT, RIGHT_MOTOR_TARGET)
	_check(_state_matches(left_joint, LEFT_LIMIT, LEFT_MOTOR_TARGET), "left external motor/limit state is configured before contraction")
	_check(_state_matches(right_joint, RIGHT_LIMIT, RIGHT_MOTOR_TARGET), "right external motor/limit state is configured before contraction")

	var left_origin_staleness := left_joint.global_position.distance_to(left_world_before.origin)
	var right_origin_staleness := right_joint.global_position.distance_to(right_world_before.origin)
	_check(left_origin_staleness > 0.1 and right_origin_staleness > 0.1, "both persistent external hinge origins are materially stale before contraction")

	var left_linear := Vector3(2.4, 0.15, 0.8)
	var right_linear := Vector3(-0.9, -0.05, 2.0)
	var left_angular := Vector3.ZERO
	var right_angular := Vector3.ZERO
	left.linear_velocity = left_linear
	right.linear_velocity = right_linear
	left.angular_velocity = left_angular
	right.angular_velocity = right_angular

	var left_props: Dictionary = MatterMassProperties.calculate(left_volume, MASS_PER_CELL)
	var right_props: Dictionary = MatterMassProperties.calculate(right_volume, MASS_PER_CELL)
	var merged_props: Dictionary = MatterMassProperties.calculate(merged_volume, MASS_PER_CELL)
	var rotation: Basis = merge_transform.basis.orthonormalized()
	var left_mass: float = float(left_props["mass"])
	var right_mass: float = float(right_props["mass"])
	var merged_mass: float = float(merged_props["mass"])
	var left_com_world: Vector3 = left.global_transform * Vector3(left_props["center_of_mass_local"])
	var right_com_world: Vector3 = right.global_transform * Vector3(right_props["center_of_mass_local"])
	var merged_com_world: Vector3 = merge_transform * Vector3(merged_props["center_of_mass_local"])
	var left_inertia_world: Basis = MatterMassProperties.world_inertia(Basis(left_props["inertia_tensor_local"]), rotation)
	var right_inertia_world: Basis = MatterMassProperties.world_inertia(Basis(right_props["inertia_tensor_local"]), rotation)
	var merged_inertia_world: Basis = MatterMassProperties.world_inertia(Basis(merged_props["inertia_tensor_local"]), rotation)

	var total_p: Vector3 = left_linear * left_mass + right_linear * right_mass
	var total_l: Vector3 = (
		left_inertia_world * left_angular
		+ (left_com_world - merged_com_world).cross(left_linear * left_mass)
		+ right_inertia_world * right_angular
		+ (right_com_world - merged_com_world).cross(right_linear * right_mass)
	)
	var merged_linear: Vector3 = total_p / merged_mass
	var merged_angular: Vector3 = merged_inertia_world.inverse() * total_l
	var linear_momentum_error := (merged_linear * merged_mass).distance_to(total_p)
	var angular_momentum_error := (merged_inertia_world * merged_angular).distance_to(total_l)
	var energy_before := 0.5 * left_mass * left_linear.length_squared() + 0.5 * right_mass * right_linear.length_squared()
	var energy_after := 0.5 * merged_mass * merged_linear.length_squared() + 0.5 * merged_angular.dot(merged_inertia_world * merged_angular)
	var energy_loss := energy_before - energy_after
	_check(linear_momentum_error < 0.0001, "stateful contraction successor preserves source linear momentum")
	_check(angular_momentum_error < 0.001, "stateful contraction successor preserves source angular momentum")
	_check(energy_loss > 0.1 and energy_after <= energy_before + 0.0001, "stateful incompatible contraction dissipates rather than creates kinetic energy")

	var merged_lineage := MatterLineageMap.new(MERGED_SIZE)
	var lineage_mismatches := 0
	for cell in _occupied_cells(left_volume):
		var left_token: int = left_lineage.get_lineage(cell)
		merged_lineage.set_lineage(cell, left_token)
		if merged_lineage.get_lineage(cell) != left_token:
			lineage_mismatches += 1
	for cell in _occupied_cells(right_volume):
		var merged_cell := cell + RIGHT_ORIGIN
		var right_token: int = right_lineage.get_lineage(cell)
		merged_lineage.set_lineage(merged_cell, right_token)
		if merged_lineage.get_lineage(merged_cell) != right_token:
			lineage_mismatches += 1
	var inherited_left_token: int = merged_lineage.get_lineage(LEFT_OWNER_CELL)
	var inherited_right_token: int = merged_lineage.get_lineage(RIGHT_OWNER_CELL + RIGHT_ORIGIN)
	_check(lineage_mismatches == 0, "stateful contraction preserves all retained source lineage")
	_check(inherited_left_token == left_owner_token and inherited_right_token == right_owner_token, "both external stateful hinge owners survive into merged Matter")

	var successor := _make_body(world, "StatefulContractionSuccessor", merged_volume, merge_transform)
	successor.linear_velocity = merged_linear
	successor.angular_velocity = merged_angular
	var successor_id := successor.get_instance_id()
	_check(successor_id != left_id and successor_id != right_id, "stateful contraction replaces both source physics identities")

	var merged_left_frame := left_source_frame
	var merged_right_frame := Transform3D(right_source_frame.basis, Vector3(RIGHT_ORIGIN) + right_source_frame.origin)

	for body in [left_external, right_external]:
		var body_com_world: Vector3 = body.to_global(body.matter_center_of_mass_local)
		body.linear_velocity = _velocity_at_point(merged_linear, merged_angular, merged_com_world, body_com_world)
		body.angular_velocity = merged_angular

	left_joint.global_transform = left_world_before
	left_joint.force_update_transform()
	right_joint.global_transform = right_world_before
	right_joint.force_update_transform()
	var left_rebase_origin_error := left_joint.global_position.distance_to(left_world_before.origin)
	var right_rebase_origin_error := right_joint.global_position.distance_to(right_world_before.origin)
	var left_rebase_basis_error := _basis_axis_error(left_joint.global_basis.orthonormalized(), left_world_before.basis.orthonormalized())
	var right_rebase_basis_error := _basis_axis_error(right_joint.global_basis.orthonormalized(), right_world_before.basis.orthonormalized())
	left_joint.node_a = left_joint.get_path_to(successor)
	right_joint.node_a = right_joint.get_path_to(successor)

	# Measure inherited relative motion before the first successor solver step.
	# After that step the enabled motors are allowed to create relative speed.
	var pre_solver_left_speed: float = _relative_hinge_speed(successor, merged_left_frame, left_external, left_external_frame)
	var pre_solver_right_speed: float = _relative_hinge_speed(successor, merged_right_frame, right_external, right_external_frame)
	_check(pre_solver_left_speed < 0.001 and pre_solver_right_speed < 0.001, "both external hinges enter the successor solver phase with near-zero inherited relative speed")

	internal_joint.free()
	_check(not is_instance_valid(internal_joint), "internal relation retires when A and B collapse into one rigid successor")
	_check(left_joint.get_instance_id() == left_joint_id and right_joint.get_instance_id() == right_joint_id, "both external stateful edge identities survive many-to-one contraction")
	_check(internal_joint_id != left_joint_id and internal_joint_id != right_joint_id, "retired internal relation had distinct identity")
	_check(left_external.get_instance_id() == left_external_id and right_external.get_instance_id() == right_external_id, "unaffected external endpoint body identities survive contraction")
	_check(left_rebase_origin_error < 0.000001 and right_rebase_origin_error < 0.000001, "both external hinge origins rebase exactly before endpoint contraction")
	_check(left_rebase_basis_error < 0.000001 and right_rebase_basis_error < 0.000001, "both external hinge bases rebase exactly before endpoint contraction")
	_check(_state_matches(left_joint, LEFT_LIMIT, LEFT_MOTOR_TARGET), "left motor/limit state survives endpoint contraction")
	_check(_state_matches(right_joint, RIGHT_LIMIT, RIGHT_MOTOR_TARGET), "right motor/limit state survives endpoint contraction")
	left.free()
	right.free()

	await process_frame
	await physics_frame
	await process_frame

	_check(_count_hinges(world) == 2, "stateful graph contraction leaves only the two external hinges")
	_check(left_joint.node_a == left_joint.get_path_to(successor) and right_joint.node_a == right_joint.get_path_to(successor), "both stateful external edges converge onto the same merged successor")

	var first_step_left_speed: float = _relative_hinge_speed(successor, merged_left_frame, left_external, left_external_frame)
	var first_step_right_speed: float = _relative_hinge_speed(successor, merged_right_frame, right_external, right_external_frame)

	var max_left_gap := 0.0
	var max_right_gap := 0.0
	var max_left_axis_error := 0.0
	var max_right_axis_error := 0.0
	var max_left_angle := 0.0
	var max_right_angle := 0.0
	var max_left_speed := 0.0
	var max_right_speed := 0.0
	var left_angle_after_30 := 0.0
	var right_angle_after_30 := 0.0

	for frame in range(POST_BIND_FRAMES):
		await physics_frame
		await process_frame
		var left_angle: float = abs(_signed_hinge_angle(successor, merged_left_frame, left_external, left_external_frame))
		var right_angle: float = abs(_signed_hinge_angle(successor, merged_right_frame, right_external, right_external_frame))
		var left_speed: float = _relative_hinge_speed(successor, merged_left_frame, left_external, left_external_frame)
		var right_speed: float = _relative_hinge_speed(successor, merged_right_frame, right_external, right_external_frame)
		max_left_angle = max(max_left_angle, left_angle)
		max_right_angle = max(max_right_angle, right_angle)
		max_left_speed = max(max_left_speed, left_speed)
		max_right_speed = max(max_right_speed, right_speed)
		max_left_gap = max(max_left_gap, _hinge_anchor_gap(successor, merged_left_frame, left_external, left_external_frame))
		max_right_gap = max(max_right_gap, _hinge_anchor_gap(successor, merged_right_frame, right_external, right_external_frame))
		max_left_axis_error = max(max_left_axis_error, _hinge_axis_error(successor, merged_left_frame, left_external, left_external_frame))
		max_right_axis_error = max(max_right_axis_error, _hinge_axis_error(successor, merged_right_frame, right_external, right_external_frame))
		if frame == 29:
			left_angle_after_30 = left_angle
			right_angle_after_30 = right_angle
		_check(_count_hinges(world) == 2, "retired internal relation never reappears during stateful contraction")
		_check(_finite_body_state(successor) and _finite_body_state(left_external) and _finite_body_state(right_external), "stateful contracted graph remains numerically finite")

	var final_left_angle: float = abs(_signed_hinge_angle(successor, merged_left_frame, left_external, left_external_frame))
	var final_right_angle: float = abs(_signed_hinge_angle(successor, merged_right_frame, right_external, right_external_frame))
	var final_left_speed: float = _relative_hinge_speed(successor, merged_left_frame, left_external, left_external_frame)
	var final_right_speed: float = _relative_hinge_speed(successor, merged_right_frame, right_external, right_external_frame)
	var final_left_gap: float = _hinge_anchor_gap(successor, merged_left_frame, left_external, left_external_frame)
	var final_right_gap: float = _hinge_anchor_gap(successor, merged_right_frame, right_external, right_external_frame)
	var final_left_axis_error: float = _hinge_axis_error(successor, merged_left_frame, left_external, left_external_frame)
	var final_right_axis_error: float = _hinge_axis_error(successor, merged_right_frame, right_external, right_external_frame)

	_check(left_angle_after_30 > 0.06 and right_angle_after_30 > 0.06, "both inherited motors create early post-contraction relative rotation")
	_check(max_left_speed > 0.35 and max_right_speed > 0.35, "both inherited motors produce material relative angular speed on the common successor")
	_check(max_left_angle > 0.22 and max_left_angle < LEFT_LIMIT + 0.16, "left inherited hinge reaches but does not escape its configured angular range")
	_check(max_right_angle > 0.30 and max_right_angle < RIGHT_LIMIT + 0.16, "right inherited hinge reaches but does not escape its configured angular range")
	_check(final_left_angle > 0.20 and final_left_angle < LEFT_LIMIT + 0.12, "left stateful hinge settles near its configured limit after contraction")
	_check(final_right_angle > 0.28 and final_right_angle < RIGHT_LIMIT + 0.12, "right stateful hinge settles near its configured limit after contraction")
	_check(final_left_speed < 0.30 and final_right_speed < 0.30, "both inherited angular limits arrest sustained motor-driven rotation")
	_check(max_left_gap < 0.03 and max_right_gap < 0.03 and final_left_gap < 0.008 and final_right_gap < 0.008, "both inherited stateful hinges keep bounded translational anchors on the common successor")
	_check(max_left_axis_error < 0.03 and max_right_axis_error < 0.03 and final_left_axis_error < 0.015 and final_right_axis_error < 0.015, "both inherited stateful hinges preserve their physical axes on the common successor")
	_check(_state_matches(left_joint, LEFT_LIMIT, LEFT_MOTOR_TARGET) and _state_matches(right_joint, RIGHT_LIMIT, RIGHT_MOTOR_TARGET), "both external edges retain distinct state through the complete contraction run")
	_check(_count_hinges(world) == 2, "final contracted graph contains no internal self-edge")

	print(
		"MULTIFRAME_STATEFUL_HINGE_CONTRACTION_METRIC left_token=%d inherited_left=%d right_token=%d inherited_right=%d lineage_mismatches=%d source_alignment_error=%.10f source_orientation_error=%.10f linear_momentum_error=%.10f angular_momentum_error=%.10f energy_loss=%.6f left_angle_before=%.10f right_angle_before=%.10f left_speed_before=%.10f right_speed_before=%.10f left_origin_staleness=%.10f right_origin_staleness=%.10f left_rebase_origin_error=%.10f right_rebase_origin_error=%.10f left_rebase_basis_error=%.10f right_rebase_basis_error=%.10f pre_solver_left_speed=%.6f pre_solver_right_speed=%.6f first_step_left_speed=%.6f first_step_right_speed=%.6f left_angle_after_30=%.6f right_angle_after_30=%.6f max_left_angle=%.6f max_right_angle=%.6f final_left_angle=%.6f final_right_angle=%.6f max_left_speed=%.6f max_right_speed=%.6f final_left_speed=%.6f final_right_speed=%.6f max_left_gap=%.10f max_right_gap=%.10f final_left_gap=%.10f final_right_gap=%.10f max_left_axis_error=%.10f max_right_axis_error=%.10f final_left_axis_error=%.10f final_right_axis_error=%.10f left_joint_id=%d right_joint_id=%d internal_joint_id=%d successor_id=%d"
		% [
			left_owner_token, inherited_left_token, right_owner_token, inherited_right_token,
			lineage_mismatches,
			source_alignment_error, source_orientation_error,
			linear_momentum_error, angular_momentum_error, energy_loss,
			left_angle_before, right_angle_before, left_speed_before, right_speed_before,
			left_origin_staleness, right_origin_staleness,
			left_rebase_origin_error, right_rebase_origin_error, left_rebase_basis_error, right_rebase_basis_error,
			pre_solver_left_speed, pre_solver_right_speed, first_step_left_speed, first_step_right_speed,
			left_angle_after_30, right_angle_after_30,
			max_left_angle, max_right_angle, final_left_angle, final_right_angle,
			max_left_speed, max_right_speed, final_left_speed, final_right_speed,
			max_left_gap, max_right_gap, final_left_gap, final_right_gap,
			max_left_axis_error, max_right_axis_error, final_left_axis_error, final_right_axis_error,
			left_joint_id, right_joint_id, internal_joint_id, successor_id,
		]
	)

	_finish()


func _copy_volume(source: CellVolume, offset: Vector3i, target: CellVolume) -> void:
	for cell in _occupied_cells(source):
		target.set_cell(cell + offset, source.get_cell(cell))


func _make_box_body(world: Node3D, body_name: String, size: Vector3i, material: int, transform: Transform3D) -> ConstructBody:
	var volume := CellVolume.new(size)
	volume.fill_box(Vector3i.ZERO, size, material)
	return _make_body(world, body_name, volume, transform)


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


func _make_hinge(world: Node3D, joint_name: String, world_frame: Transform3D, body_a: ConstructBody, body_b: ConstructBody) -> HingeJoint3D:
	var joint := HingeJoint3D.new()
	joint.name = joint_name
	world.add_child(joint)
	joint.global_transform = world_frame
	joint.node_a = joint.get_path_to(body_a)
	joint.node_b = joint.get_path_to(body_b)
	joint.exclude_nodes_from_collision = true
	return joint


func _make_pin_joint(world: Node3D, joint_name: String, anchor_world: Vector3, body_a: ConstructBody, body_b: ConstructBody) -> PinJoint3D:
	var joint := PinJoint3D.new()
	joint.name = joint_name
	world.add_child(joint)
	joint.global_position = anchor_world
	joint.node_a = joint.get_path_to(body_a)
	joint.node_b = joint.get_path_to(body_b)
	joint.exclude_nodes_from_collision = true
	return joint


func _configure_stateful_hinge(joint: HingeJoint3D, limit_abs: float, motor_target: float) -> void:
	joint.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, -limit_abs)
	joint.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, limit_abs)
	joint.set_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY, motor_target)
	joint.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, MOTOR_MAX_IMPULSE)
	joint.set_flag(HingeJoint3D.FLAG_USE_LIMIT, true)
	joint.set_flag(HingeJoint3D.FLAG_ENABLE_MOTOR, true)


func _state_matches(joint: HingeJoint3D, limit_abs: float, motor_target: float) -> bool:
	return (
		joint.get_flag(HingeJoint3D.FLAG_USE_LIMIT)
		and joint.get_flag(HingeJoint3D.FLAG_ENABLE_MOTOR)
		and abs(joint.get_param(HingeJoint3D.PARAM_LIMIT_LOWER) + limit_abs) < 0.000001
		and abs(joint.get_param(HingeJoint3D.PARAM_LIMIT_UPPER) - limit_abs) < 0.000001
		and abs(joint.get_param(HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY) - motor_target) < 0.000001
	)


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
	var cos_term: float = clampf(normal_a.dot(normal_b), -1.0, 1.0)
	return atan2(sin_term, cos_term)


func _relative_hinge_speed(body_a: ConstructBody, frame_a: Transform3D, body_b: ConstructBody, frame_b: Transform3D) -> float:
	var axis_a := _hinge_axis(body_a, frame_a)
	var axis_b := _hinge_axis(body_b, frame_b)
	var axis := (axis_a + axis_b).normalized()
	return abs((body_b.angular_velocity - body_a.angular_velocity).dot(axis))


func _velocity_at_point(linear: Vector3, angular: Vector3, com_world: Vector3, point_world: Vector3) -> Vector3:
	return linear + angular.cross(point_world - com_world)


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


func _count_hinges(node: Node) -> int:
	var count := 0
	for child in node.get_children():
		if child is HingeJoint3D:
			count += 1
		count += _count_hinges(child)
	return count


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
		print("MULTIFRAME_STATEFUL_HINGE_CONTRACTION_PROBE_PASS: many-to-one rigid contraction preserved two distinct external motor/limit hinge relations on one merged successor while retiring the internal source relation.")
		quit(0)
		return
	for failure in _failures:
		push_error("MULTIFRAME_STATEFUL_HINGE_CONTRACTION_PROBE_FAIL: " + failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
