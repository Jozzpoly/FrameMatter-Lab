extends SceneTree

const VOLUME_SIZE := Vector3i(10, 3, 3)
const CUT_CELL := Vector3i(4, 1, 1)
const ANCHOR_OWNER_CELL := Vector3i(9, 1, 1)
const MASS_PER_CELL := 1.8
const PRE_SPLIT_FRAMES := 60
const POST_SPLIT_FRAMES := 180

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	world.name = "HingeSplitSuccessionWorld"
	get_root().add_child(world)

	var parent_volume := _make_parent_volume()
	var sibling_volume := CellVolume.new(Vector3i(3, 3, 3))
	sibling_volume.fill_box(Vector3i.ZERO, sibling_volume.size, 3)

	var parent_lineage := MatterLineageMap.new(VOLUME_SIZE)
	var next_token := 140001
	for cell in _occupied_cells(parent_volume):
		parent_lineage.set_lineage(cell, next_token)
		next_token += 1
	var anchor_owner_token := parent_lineage.get_lineage(ANCHOR_OWNER_CELL)
	_check(anchor_owner_token != 0, "hinge anchor owner begins with retained Matter lineage")

	var assembly_transform := Transform3D(
		Basis.from_euler(Vector3(0.17, -0.46, 0.23)),
		Vector3(13.0, 6.0, -8.0)
	)
	var parent := _make_body(world, "HingeParent", parent_volume, assembly_transform)
	var sibling := _make_body(
		world,
		"HingeSibling",
		sibling_volume,
		assembly_transform * Transform3D(Basis.IDENTITY, Vector3(10.0, 0.0, 0.0))
	)
	var parent_id := parent.get_instance_id()
	var sibling_id := sibling.get_instance_id()

	var anchor_parent_local := Vector3(10.0, 1.5, 1.5)
	var hinge_local_basis := Basis.from_euler(Vector3(0.31, -0.22, 0.47)).orthonormalized()
	var hinge_parent_local := Transform3D(hinge_local_basis, anchor_parent_local)
	var hinge_world_initial: Transform3D = parent.global_transform * hinge_parent_local
	var hinge_sibling_local: Transform3D = sibling.global_transform.affine_inverse() * hinge_world_initial

	var common_linear_at_anchor := Vector3(1.2, -0.15, 0.85)
	var common_angular := Vector3(0.24, -0.29, 0.33)
	var anchor_world := hinge_world_initial.origin
	parent.linear_velocity = _velocity_at_point(
		common_linear_at_anchor,
		common_angular,
		anchor_world,
		parent.to_global(parent.matter_center_of_mass_local)
	)
	sibling.linear_velocity = _velocity_at_point(
		common_linear_at_anchor,
		common_angular,
		anchor_world,
		sibling.to_global(sibling.matter_center_of_mass_local)
	)
	parent.angular_velocity = common_angular
	sibling.angular_velocity = common_angular

	var joint := HingeJoint3D.new()
	joint.name = "PersistentHingeLink"
	world.add_child(joint)
	joint.global_transform = hinge_world_initial
	joint.node_a = joint.get_path_to(parent)
	joint.node_b = joint.get_path_to(sibling)
	joint.exclude_nodes_from_collision = true
	var joint_id := joint.get_instance_id()

	var max_pre_anchor_gap := 0.0
	var max_pre_axis_error := 0.0
	for _frame in range(PRE_SPLIT_FRAMES):
		await physics_frame
		await process_frame
		max_pre_anchor_gap = max(max_pre_anchor_gap, _hinge_anchor_gap(parent, hinge_parent_local, sibling, hinge_sibling_local))
		max_pre_axis_error = max(max_pre_axis_error, _hinge_axis_error(parent, hinge_parent_local, sibling, hinge_sibling_local))
	_check(max_pre_anchor_gap < 0.01, "hinge anchor is stable before topology split")
	_check(max_pre_axis_error < 0.01, "hinge axis remains aligned before topology split")

	# Commit topology replacement before the upcoming PhysicsServer step.
	await physics_frame
	var parent_transform: Transform3D = parent.global_transform
	var parent_linear: Vector3 = parent.linear_velocity
	var parent_angular: Vector3 = parent.angular_velocity
	var parent_com_world: Vector3 = parent.to_global(parent.matter_center_of_mass_local)
	var hinge_world_before: Transform3D = parent_transform * hinge_parent_local
	var joint_origin_staleness := joint.global_position.distance_to(hinge_world_before.origin)
	var joint_basis_staleness := _basis_axis_error(joint.global_basis.orthonormalized(), hinge_world_before.basis.orthonormalized())

	_check(parent.volume.set_cell(CUT_CELL, CellVolume.EMPTY), "hinge split removes intended bridge Matter")
	parent_lineage.clear_lineage(CUT_CELL)
	var components: Array[CellVolume] = MatterTopology.extract_connected_components(parent.volume)
	_check(components.size() == 2, "hinge parent split produces exactly two successor components")
	if components.size() != 2:
		_finish()
		return

	var children: Array[ConstructBody] = []
	var child_origins: Array[Vector3i] = []
	var child_lineages: Array[MatterLineageMap] = []
	var anchor_child_index := -1
	var max_split_world_error := 0.0
	var max_split_velocity_error := 0.0
	var lineage_mismatches := 0

	for index in range(components.size()):
		var source_component: CellVolume = components[index]
		var compact_info: Dictionary = MatterTopology.compact_volume(source_component)
		var source_origin: Vector3i = compact_info["origin"]
		var compact_volume: CellVolume = compact_info["volume"]
		var child := _make_body(
			world,
			"HingeSuccessor_%d" % index,
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

			var parent_point_world := parent_transform * (Vector3(source_cell) + Vector3(0.5, 0.5, 0.5))
			var child_point_world := child.to_global(Vector3(compact_cell) + Vector3(0.5, 0.5, 0.5))
			max_split_world_error = max(max_split_world_error, parent_point_world.distance_to(child_point_world))
			var parent_point_velocity := _velocity_at_point(parent_linear, parent_angular, parent_com_world, parent_point_world)
			var child_point_velocity := _velocity_at_point(child.linear_velocity, child.angular_velocity, child_com_world, child_point_world)
			max_split_velocity_error = max(max_split_velocity_error, parent_point_velocity.distance_to(child_point_velocity))
		child_lineages.append(child_lineage)

		if source_component.get_cell(ANCHOR_OWNER_CELL) != CellVolume.EMPTY:
			anchor_child_index = index

	_check(anchor_child_index >= 0, "one successor retains hinge anchor-owner Matter")
	if anchor_child_index < 0:
		_finish()
		return

	var anchor_child: ConstructBody = children[anchor_child_index]
	var free_child: ConstructBody = children[1 - anchor_child_index]
	var anchor_origin: Vector3i = child_origins[anchor_child_index]
	var mapped_owner_cell := ANCHOR_OWNER_CELL - anchor_origin
	var inherited_anchor_token := child_lineages[anchor_child_index].get_lineage(mapped_owner_cell)
	var mapped_hinge_local := Transform3D(
		hinge_parent_local.basis,
		hinge_parent_local.origin - Vector3(anchor_origin)
	)
	var mapped_hinge_world: Transform3D = anchor_child.global_transform * mapped_hinge_local

	_check(inherited_anchor_token == anchor_owner_token, "hinge endpoint successor is selected by retained owner lineage")
	_check(lineage_mismatches == 0, "hinge split preserves every retained Matter lineage")
	_check(max_split_world_error < 0.00001, "hinge split preserves retained Matter world positions")
	_check(max_split_velocity_error < 0.00001, "hinge split preserves retained Matter velocity field")
	_check(mapped_hinge_world.origin.distance_to(hinge_world_before.origin) < 0.00001, "hinge anchor maps continuously into compact successor")
	_check(_basis_axis_error(mapped_hinge_world.basis.orthonormalized(), hinge_world_before.basis.orthonormalized()) < 0.00001, "hinge orientation maps continuously into compact successor")

	# HingeJoint3D configures a full body-local frame from Joint3D.global_transform.
	# Rebase both origin and basis before swapping the endpoint. Position-only
	# rebasing would preserve a point but can silently change the hinge axis.
	_check(joint_origin_staleness > 0.1, "moving assembly makes hinge scene origin materially stale before succession")
	_check(joint_basis_staleness > 0.01, "moving assembly makes hinge scene orientation materially stale before succession")
	joint.global_transform = hinge_world_before
	joint.force_update_transform()
	var rebase_origin_error := joint.global_position.distance_to(hinge_world_before.origin)
	var rebase_basis_error := _basis_axis_error(joint.global_basis.orthonormalized(), hinge_world_before.basis.orthonormalized())
	_check(rebase_origin_error < 0.000001, "hinge scene origin rebases exactly before endpoint replacement")
	_check(rebase_basis_error < 0.000001, "hinge scene orientation rebases exactly before endpoint replacement")

	joint.node_a = joint.get_path_to(anchor_child)
	_check(joint.get_instance_id() == joint_id, "logical hinge identity survives endpoint succession")
	_check(sibling.get_instance_id() == sibling_id, "persistent hinge sibling identity survives topology replacement")
	_check(anchor_child.get_instance_id() != parent_id, "hinge successor has a new physics-body identity")
	parent.free()

	await process_frame
	await physics_frame
	await process_frame

	var max_post_anchor_gap := 0.0
	var max_post_axis_error := 0.0
	var max_relative_normal_angle := 0.0
	var free_child_start := free_child.global_position
	var max_free_child_separation := 0.0
	var anchor_child_linear_before := anchor_child.linear_velocity
	var anchor_child_angular_before := anchor_child.angular_velocity

	# Drive relative rotation around the intended hinge axis while independently
	# kicking the non-owning topology successor away from the mechanical island.
	var hinge_axis_world := (anchor_child.global_basis * mapped_hinge_local.basis.z).normalized()
	sibling.apply_torque_impulse(hinge_axis_world * 18.0)
	free_child.apply_central_impulse(assembly_transform.basis * Vector3(-8.0, 5.0, 12.0))

	for _frame in range(POST_SPLIT_FRAMES):
		await physics_frame
		await process_frame
		max_post_anchor_gap = max(max_post_anchor_gap, _hinge_anchor_gap(anchor_child, mapped_hinge_local, sibling, hinge_sibling_local))
		max_post_axis_error = max(max_post_axis_error, _hinge_axis_error(anchor_child, mapped_hinge_local, sibling, hinge_sibling_local))
		max_relative_normal_angle = max(max_relative_normal_angle, _hinge_normal_angle(anchor_child, mapped_hinge_local, sibling, hinge_sibling_local))
		max_free_child_separation = max(max_free_child_separation, free_child.global_position.distance_to(free_child_start))
		_check(_finite_body_state(anchor_child) and _finite_body_state(free_child) and _finite_body_state(sibling), "hinge succession remains numerically finite")

	var final_anchor_gap := _hinge_anchor_gap(anchor_child, mapped_hinge_local, sibling, hinge_sibling_local)
	var final_axis_error := _hinge_axis_error(anchor_child, mapped_hinge_local, sibling, hinge_sibling_local)
	var anchor_child_linear_change := anchor_child.linear_velocity.distance_to(anchor_child_linear_before)
	var anchor_child_angular_change := anchor_child.angular_velocity.distance_to(anchor_child_angular_before)

	_check(max_post_anchor_gap < 0.02, "inherited hinge anchor remains bounded after topology replacement")
	_check(final_anchor_gap < 0.005, "inherited hinge finishes with a tight anchor")
	_check(max_post_axis_error < 0.02 and final_axis_error < 0.01, "inherited hinge preserves aligned physical hinge axes")
	_check(max_relative_normal_angle > 0.1, "inherited hinge still permits material relative rotation around its preserved axis")
	_check(max_free_child_separation > 0.1, "non-owning successor remains mechanically independent from inherited hinge")
	_check(anchor_child_linear_change > 0.01 or anchor_child_angular_change > 0.01, "hinge successor receives mechanical reaction through inherited constraint")
	_check(joint.node_a == joint.get_path_to(anchor_child) and joint.node_b == joint.get_path_to(sibling), "hinge endpoints remain explicitly mapped after succession")

	print(
		"MULTIFRAME_HINGE_SPLIT_SUCCESSION_METRIC components=%d anchor_child_index=%d anchor_origin=%s owner_token=%d inherited_token=%d lineage_mismatches=%d split_world_error=%.10f split_velocity_error=%.10f pre_anchor_gap=%.10f pre_axis_error=%.10f origin_staleness=%.10f basis_staleness=%.10f rebase_origin_error=%.10f rebase_basis_error=%.10f max_anchor_gap=%.10f final_anchor_gap=%.10f max_axis_error=%.10f final_axis_error=%.10f max_relative_normal_angle=%.6f free_child_separation=%.6f successor_linear_change=%.6f successor_angular_change=%.6f joint_id=%d"
		% [
			components.size(), anchor_child_index, anchor_origin,
			anchor_owner_token, inherited_anchor_token, lineage_mismatches,
			max_split_world_error, max_split_velocity_error,
			max_pre_anchor_gap, max_pre_axis_error,
			joint_origin_staleness, joint_basis_staleness,
			rebase_origin_error, rebase_basis_error,
			max_post_anchor_gap, final_anchor_gap,
			max_post_axis_error, final_axis_error,
			max_relative_normal_angle, max_free_child_separation,
			anchor_child_linear_change, anchor_child_angular_change,
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


func _hinge_anchor_gap(body_a: ConstructBody, frame_a: Transform3D, body_b: ConstructBody, frame_b: Transform3D) -> float:
	return (body_a.global_transform * frame_a).origin.distance_to((body_b.global_transform * frame_b).origin)


func _hinge_axis_error(body_a: ConstructBody, frame_a: Transform3D, body_b: ConstructBody, frame_b: Transform3D) -> float:
	var axis_a := (body_a.global_basis * frame_a.basis.z).normalized()
	var axis_b := (body_b.global_basis * frame_b.basis.z).normalized()
	return axis_a.angle_to(axis_b)


func _hinge_normal_angle(body_a: ConstructBody, frame_a: Transform3D, body_b: ConstructBody, frame_b: Transform3D) -> float:
	var normal_a := (body_a.global_basis * frame_a.basis.x).normalized()
	var normal_b := (body_b.global_basis * frame_b.basis.x).normalized()
	return normal_a.angle_to(normal_b)


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
		print("MULTIFRAME_HINGE_SPLIT_SUCCESSION_PROBE_PASS: a full position+orientation hinge frame followed retained owner Matter through compact topology split while preserving hinge-axis behavior and logical joint identity.")
		quit(0)
		return
	for failure in _failures:
		push_error("MULTIFRAME_HINGE_SPLIT_SUCCESSION_PROBE_FAIL: " + failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
