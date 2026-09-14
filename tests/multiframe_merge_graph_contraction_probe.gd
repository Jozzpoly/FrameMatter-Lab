extends SceneTree

const LEFT_SIZE := Vector3i(4, 3, 3)
const RIGHT_SIZE := Vector3i(4, 3, 3)
const MERGED_SIZE := Vector3i(8, 3, 3)
const RIGHT_ORIGIN := Vector3i(4, 0, 0)
const MASS_PER_CELL := 1.7
const PRE_BIND_FRAMES := 60
const POST_BIND_FRAMES := 180
const LEFT_OWNER_CELL := Vector3i(0, 1, 1)
const RIGHT_OWNER_CELL := Vector3i(3, 1, 1)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	world.name = "MechanicalMergeGraphContractionWorld"
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
	var next_token := 120001
	for cell in _occupied_cells(left_volume):
		left_lineage.set_lineage(cell, next_token)
		next_token += 1
	for cell in _occupied_cells(right_volume):
		right_lineage.set_lineage(cell, next_token)
		next_token += 1
	var left_owner_token := left_lineage.get_lineage(LEFT_OWNER_CELL)
	var right_owner_token := right_lineage.get_lineage(RIGHT_OWNER_CELL)
	_check(left_owner_token != 0 and right_owner_token != 0 and left_owner_token != right_owner_token, "external mechanical anchors begin with distinct retained Matter lineage")

	var assembly_transform := Transform3D(
		Basis.from_euler(Vector3(0.0, 0.41, 0.0)),
		Vector3(12.0, 7.0, -8.0)
	)
	var left := _make_source_body(world, "MergeLeft", left_volume, assembly_transform)
	var right := _make_source_body(
		world,
		"MergeRight",
		right_volume,
		assembly_transform * Transform3D(Basis.IDENTITY, Vector3(RIGHT_ORIGIN))
	)
	var left_external := _make_source_box(
		world,
		"LeftExternal",
		Vector3i(3, 3, 3),
		4,
		assembly_transform * Transform3D(Basis.IDENTITY, Vector3(-3.0, 0.0, 0.0))
	)
	var right_external := _make_source_box(
		world,
		"RightExternal",
		Vector3i(3, 3, 3),
		5,
		assembly_transform * Transform3D(Basis.IDENTITY, Vector3(8.0, 0.0, 0.0))
	)
	var left_id := left.get_instance_id()
	var right_id := right.get_instance_id()
	var left_external_id := left_external.get_instance_id()
	var right_external_id := right_external.get_instance_id()

	var left_external_anchor_local := Vector3(0.0, 1.5, 1.5)
	var seam_left_local := Vector3(4.0, 1.5, 1.5)
	var seam_right_local := Vector3(0.0, 1.5, 1.5)
	var right_external_anchor_local := Vector3(4.0, 1.5, 1.5)
	var left_anchor_world := left.to_global(left_external_anchor_local)
	var seam_world := left.to_global(seam_left_local)
	var right_anchor_world := right.to_global(right_external_anchor_local)
	var left_external_local := left_external.to_local(left_anchor_world)
	var right_external_local := right_external.to_local(right_anchor_world)

	# Start the four bodies with one translational motion and locked source
	# rotation so the two source lattices remain aligned before explicit bind.
	var common_linear := Vector3(1.25, 0.0, -0.65)
	for body in [left, right, left_external, right_external]:
		body.linear_velocity = common_linear

	var left_joint := _make_pin_joint(world, "LeftExternalLink", left_anchor_world, left, left_external)
	var internal_joint := _make_pin_joint(world, "InternalSourceLink", seam_world, left, right)
	var right_joint := _make_pin_joint(world, "RightExternalLink", right_anchor_world, right, right_external)
	var left_joint_id := left_joint.get_instance_id()
	var internal_joint_id := internal_joint.get_instance_id()
	var right_joint_id := right_joint.get_instance_id()

	var max_pre_left_gap := 0.0
	var max_pre_internal_gap := 0.0
	var max_pre_right_gap := 0.0
	for _frame in range(PRE_BIND_FRAMES):
		await physics_frame
		await process_frame
		max_pre_left_gap = max(max_pre_left_gap, left.to_global(left_external_anchor_local).distance_to(left_external.to_global(left_external_local)))
		max_pre_internal_gap = max(max_pre_internal_gap, left.to_global(seam_left_local).distance_to(right.to_global(seam_right_local)))
		max_pre_right_gap = max(max_pre_right_gap, right.to_global(right_external_anchor_local).distance_to(right_external.to_global(right_external_local)))
	_check(max_pre_left_gap < 0.01 and max_pre_internal_gap < 0.01 and max_pre_right_gap < 0.01, "three-link source graph is stable before rigid contraction")

	# Commit graph contraction before the upcoming PhysicsServer step.
	await physics_frame
	var merge_transform := left.global_transform
	var expected_right_transform := merge_transform * Transform3D(Basis.IDENTITY, Vector3(RIGHT_ORIGIN))
	var source_alignment_error := right.global_transform.origin.distance_to(expected_right_transform.origin)
	var source_orientation_error := _basis_axis_error(right.global_transform.basis.orthonormalized(), expected_right_transform.basis.orthonormalized())
	_check(source_alignment_error < 0.002, "jointed source lattices remain position-compatible for explicit rigid bind")
	_check(source_orientation_error < 0.00001, "locked source lattices remain orientation-compatible for explicit rigid bind")

	var left_anchor_now := left.to_global(left_external_anchor_local)
	var right_anchor_now := right.to_global(right_external_anchor_local)
	var left_joint_staleness := left_joint.global_position.distance_to(left_anchor_now)
	var right_joint_staleness := right_joint.global_position.distance_to(right_anchor_now)

	# Enter a genuinely incompatible source velocity state at the transaction
	# boundary. The old internal pin never sees this state: A+B are replaced by
	# one inelastic rigid successor before the solver step.
	var left_linear := Vector3(2.4, 0.0, 0.8)
	var right_linear := Vector3(-0.9, 0.0, 2.0)
	var left_angular := Vector3.ZERO
	var right_angular := Vector3.ZERO
	left.linear_velocity = left_linear
	right.linear_velocity = right_linear
	left.angular_velocity = left_angular
	right.angular_velocity = right_angular

	var left_props := MatterMassProperties.calculate(left_volume, MASS_PER_CELL)
	var right_props := MatterMassProperties.calculate(right_volume, MASS_PER_CELL)
	var merged_props := MatterMassProperties.calculate(merged_volume, MASS_PER_CELL)
	var rotation := merge_transform.basis.orthonormalized()
	var left_mass: float = left_props["mass"]
	var right_mass: float = right_props["mass"]
	var merged_mass: float = merged_props["mass"]
	var left_com_world := left.global_transform * Vector3(left_props["center_of_mass_local"])
	var right_com_world := right.global_transform * Vector3(right_props["center_of_mass_local"])
	var merged_com_world := merge_transform * Vector3(merged_props["center_of_mass_local"])
	var left_inertia_world := MatterMassProperties.world_inertia(left_props["inertia_tensor_local"], rotation)
	var right_inertia_world := MatterMassProperties.world_inertia(right_props["inertia_tensor_local"], rotation)
	var merged_inertia_world := MatterMassProperties.world_inertia(merged_props["inertia_tensor_local"], rotation)

	var total_p := left_linear * left_mass + right_linear * right_mass
	var total_l := (
		left_inertia_world * left_angular
		+ (left_com_world - merged_com_world).cross(left_linear * left_mass)
		+ right_inertia_world * right_angular
		+ (right_com_world - merged_com_world).cross(right_linear * right_mass)
	)
	var merged_linear := total_p / merged_mass
	var merged_angular := merged_inertia_world.inverse() * total_l
	var linear_momentum_error := (merged_linear * merged_mass).distance_to(total_p)
	var angular_momentum_error := (merged_inertia_world * merged_angular).distance_to(total_l)
	var energy_before := (
		0.5 * left_mass * left_linear.length_squared()
		+ 0.5 * right_mass * right_linear.length_squared()
	)
	var energy_after := (
		0.5 * merged_mass * merged_linear.length_squared()
		+ 0.5 * merged_angular.dot(merged_inertia_world * merged_angular)
	)
	var energy_loss := energy_before - energy_after
	_check(linear_momentum_error < 0.0001, "graph contraction successor preserves source linear momentum")
	_check(angular_momentum_error < 0.001, "graph contraction successor preserves source angular momentum")
	_check(energy_loss > 0.1 and energy_after <= energy_before + 0.0001, "incompatible rigid contraction dissipates rather than creates kinetic energy")

	var merged_lineage := MatterLineageMap.new(MERGED_SIZE)
	var lineage_mismatches := 0
	for cell in _occupied_cells(left_volume):
		var token := left_lineage.get_lineage(cell)
		merged_lineage.set_lineage(cell, token)
		if merged_lineage.get_lineage(cell) != token:
			lineage_mismatches += 1
	for cell in _occupied_cells(right_volume):
		var merged_cell := cell + RIGHT_ORIGIN
		var token := right_lineage.get_lineage(cell)
		merged_lineage.set_lineage(merged_cell, token)
		if merged_lineage.get_lineage(merged_cell) != token:
			lineage_mismatches += 1
	var inherited_left_token := merged_lineage.get_lineage(LEFT_OWNER_CELL)
	var inherited_right_token := merged_lineage.get_lineage(RIGHT_OWNER_CELL + RIGHT_ORIGIN)
	_check(lineage_mismatches == 0, "rigid graph contraction preserves all retained source lineage")
	_check(inherited_left_token == left_owner_token and inherited_right_token == right_owner_token, "both external mechanical owners survive into merged Matter")

	var successor := _make_successor_body(world, "MergedMechanicalSuccessor", merged_volume, merge_transform)
	successor.linear_velocity = merged_linear
	successor.angular_velocity = merged_angular
	var successor_id := successor.get_instance_id()
	_check(successor_id != left_id and successor_id != right_id, "rigid contraction replaces both source physics identities")

	# External links survive and converge onto the same successor. Their host
	# Joint3D frames must be rebased before endpoint reconfiguration.
	left_joint.global_position = left_anchor_now
	left_joint.force_update_transform()
	right_joint.global_position = right_anchor_now
	right_joint.force_update_transform()
	var left_rebase_error := left_joint.global_position.distance_to(left_anchor_now)
	var right_rebase_error := right_joint.global_position.distance_to(right_anchor_now)
	left_joint.node_a = left_joint.get_path_to(successor)
	right_joint.node_a = right_joint.get_path_to(successor)

	# The A<->B relation is now internal to one rigid frame. Keeping it would
	# produce a meaningless self-constraint, so graph contraction retires it.
	internal_joint.free()
	_check(not is_instance_valid(internal_joint), "internal source joint is retired when both endpoints collapse into one rigid successor")
	_check(left_joint.get_instance_id() == left_joint_id and right_joint.get_instance_id() == right_joint_id, "both external logical link identities survive many-to-one contraction")
	_check(left_rebase_error < 0.000001 and right_rebase_error < 0.000001, "both surviving constraint frames rebase exactly before endpoint contraction")
	_check(left_external.get_instance_id() == left_external_id and right_external.get_instance_id() == right_external_id, "external endpoint frame identities survive rigid contraction")
	_check(internal_joint_id != left_joint_id and internal_joint_id != right_joint_id, "retired internal relation had its own distinct logical identity")
	left.free()
	right.free()

	await process_frame
	await physics_frame
	await process_frame

	_check(_count_pin_joints(world) == 2, "graph contraction leaves only the two external mechanical links")
	_check(left_joint.node_a == left_joint.get_path_to(successor) and right_joint.node_a == right_joint.get_path_to(successor), "both external links now resolve to the same merged successor")

	var merged_left_anchor_local := left_external_anchor_local
	var merged_right_anchor_local := Vector3(RIGHT_ORIGIN) + right_external_anchor_local
	var max_left_gap := 0.0
	var max_right_gap := 0.0
	var successor_linear_before := successor.linear_velocity
	var successor_angular_before := successor.angular_velocity

	# Drive both persistent external endpoints after contraction. The common
	# successor must receive both mechanical reactions without recreating the
	# retired internal relation.
	left_external.apply_central_impulse(assembly_transform.basis * Vector3(-11.0, 0.0, 6.0))
	right_external.apply_central_impulse(assembly_transform.basis * Vector3(13.0, 0.0, -7.0))

	for _frame in range(POST_BIND_FRAMES):
		await physics_frame
		await process_frame
		max_left_gap = max(max_left_gap, successor.to_global(merged_left_anchor_local).distance_to(left_external.to_global(left_external_local)))
		max_right_gap = max(max_right_gap, successor.to_global(merged_right_anchor_local).distance_to(right_external.to_global(right_external_local)))
		_check(_count_pin_joints(world) == 2, "retired internal self-relation never reappears after graph contraction")
		_check(_finite_body_state(successor) and _finite_body_state(left_external) and _finite_body_state(right_external), "contracted mechanical graph remains numerically finite")

	var final_left_gap := successor.to_global(merged_left_anchor_local).distance_to(left_external.to_global(left_external_local))
	var final_right_gap := successor.to_global(merged_right_anchor_local).distance_to(right_external.to_global(right_external_local))
	var successor_linear_change := successor.linear_velocity.distance_to(successor_linear_before)
	var successor_angular_change := successor.angular_velocity.distance_to(successor_angular_before)

	_check(max_left_gap < 0.02 and max_right_gap < 0.02, "both external inherited links remain bounded after rigid graph contraction")
	_check(final_left_gap < 0.005 and final_right_gap < 0.005, "both external inherited links finish with tight anchors")
	_check(successor_linear_change > 0.01 or successor_angular_change > 0.01, "merged successor receives post-contraction mechanical reaction from external graph")
	_check(_count_pin_joints(world) == 2, "final graph contains no self-constraint")

	print(
		"MULTIFRAME_MERGE_GRAPH_CONTRACTION_METRIC left_token=%d inherited_left=%d right_token=%d inherited_right=%d lineage_mismatches=%d source_alignment_error=%.10f source_orientation_error=%.10f linear_momentum_error=%.10f angular_momentum_error=%.10f energy_loss=%.6f left_staleness=%.10f right_staleness=%.10f left_rebase_error=%.10f right_rebase_error=%.10f max_left_gap=%.10f final_left_gap=%.10f max_right_gap=%.10f final_right_gap=%.10f successor_linear_change=%.6f successor_angular_change=%.6f final_pin_joints=%d left_id=%d right_id=%d successor_id=%d internal_joint_id=%d"
		% [
			left_owner_token, inherited_left_token, right_owner_token, inherited_right_token,
			lineage_mismatches,
			source_alignment_error, source_orientation_error,
			linear_momentum_error, angular_momentum_error, energy_loss,
			left_joint_staleness, right_joint_staleness, left_rebase_error, right_rebase_error,
			max_left_gap, final_left_gap, max_right_gap, final_right_gap,
			successor_linear_change, successor_angular_change,
			_count_pin_joints(world), left_id, right_id, successor_id, internal_joint_id,
		]
	)

	_finish()


func _make_source_box(world: Node3D, body_name: String, size: Vector3i, material_id: int, transform: Transform3D) -> ConstructBody:
	var volume := CellVolume.new(size)
	volume.fill_box(Vector3i.ZERO, size, material_id)
	return _make_source_body(world, body_name, volume, transform)


func _make_source_body(world: Node3D, body_name: String, volume: CellVolume, transform: Transform3D) -> ConstructBody:
	var body := _base_body(world, body_name, transform)
	body.axis_lock_angular_x = true
	body.axis_lock_angular_y = true
	body.axis_lock_angular_z = true
	body.set_volume(volume)
	return body


func _make_successor_body(world: Node3D, body_name: String, volume: CellVolume, transform: Transform3D) -> ConstructBody:
	var body := _base_body(world, body_name, transform)
	body.set_volume(volume)
	return body


func _base_body(world: Node3D, body_name: String, transform: Transform3D) -> ConstructBody:
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
	return body


func _make_pin_joint(world: Node3D, joint_name: String, anchor_world: Vector3, body_a: ConstructBody, body_b: ConstructBody) -> PinJoint3D:
	var joint := PinJoint3D.new()
	joint.name = joint_name
	world.add_child(joint)
	joint.global_position = anchor_world
	joint.node_a = joint.get_path_to(body_a)
	joint.node_b = joint.get_path_to(body_b)
	joint.exclude_nodes_from_collision = true
	return joint


func _copy_volume(source: CellVolume, target_origin: Vector3i, target: CellVolume) -> void:
	for cell in _occupied_cells(source):
		target.set_cell(cell + target_origin, source.get_cell(cell))


func _occupied_cells(volume: CellVolume) -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	for z in range(volume.size.z):
		for y in range(volume.size.y):
			for x in range(volume.size.x):
				var cell := Vector3i(x, y, z)
				if volume.get_cell(cell) != CellVolume.EMPTY:
					cells.append(cell)
	return cells


func _basis_axis_error(a: Basis, b: Basis) -> float:
	return max(a.x.distance_to(b.x), max(a.y.distance_to(b.y), a.z.distance_to(b.z)))


func _count_pin_joints(world: Node) -> int:
	var count := 0
	for child in world.get_children():
		if child is PinJoint3D:
			count += 1
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
		print("MULTIFRAME_MERGE_GRAPH_CONTRACTION_PROBE_PASS: two constrained source frames rigidly contracted into one momentum-derived successor; external links converged onto it while the now-internal source relation was retired.")
		quit(0)
		return
	for failure in _failures:
		push_error("MULTIFRAME_MERGE_GRAPH_CONTRACTION_PROBE_FAIL: " + failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
