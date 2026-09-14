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
	world.name = "JointSplitSuccessionWorld"
	get_root().add_child(world)

	var parent_volume := _make_parent_volume()
	var sibling_volume := CellVolume.new(Vector3i(3, 3, 3))
	sibling_volume.fill_box(Vector3i.ZERO, sibling_volume.size, 3)

	var parent_lineage := MatterLineageMap.new(VOLUME_SIZE)
	var next_token := 50001
	for cell in _occupied_cells(parent_volume):
		parent_lineage.set_lineage(cell, next_token)
		next_token += 1
	var anchor_owner_token := parent_lineage.get_lineage(ANCHOR_OWNER_CELL)
	_check(anchor_owner_token != 0, "mechanical anchor owner starts with a retained Matter lineage token")

	var assembly_transform := Transform3D(
		Basis.from_euler(Vector3(0.18, -0.51, 0.27)),
		Vector3(14.0, 7.0, -9.0)
	)
	var parent := _make_body(world, "JointedParent", parent_volume, assembly_transform)
	var sibling := _make_body(
		world,
		"PersistentSibling",
		sibling_volume,
		assembly_transform * Transform3D(Basis.IDENTITY, Vector3(10.0, 0.0, 0.0))
	)
	var parent_id := parent.get_instance_id()
	var sibling_id := sibling.get_instance_id()

	var anchor_parent_local := Vector3(10.0, 1.5, 1.5)
	var anchor_world: Vector3 = parent.to_global(anchor_parent_local)
	var sibling_anchor_local: Vector3 = sibling.to_local(anchor_world)
	var common_linear_at_anchor := Vector3(1.3, -0.2, 0.9)
	var common_angular := Vector3(0.22, -0.34, 0.31)
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

	var joint := PinJoint3D.new()
	joint.name = "PersistentMechanicalLink"
	world.add_child(joint)
	joint.global_position = anchor_world
	joint.node_a = joint.get_path_to(parent)
	joint.node_b = joint.get_path_to(sibling)
	joint.exclude_nodes_from_collision = true
	var joint_id := joint.get_instance_id()

	var max_pre_split_anchor_gap := 0.0
	for _frame in range(PRE_SPLIT_FRAMES):
		await physics_frame
		await process_frame
		max_pre_split_anchor_gap = max(
			max_pre_split_anchor_gap,
			parent.to_global(anchor_parent_local).distance_to(sibling.to_global(sibling_anchor_local))
		)
	_check(max_pre_split_anchor_gap < 0.01, "mechanical anchor is stable before topology split")

	# Commit the topology replacement before the upcoming PhysicsServer step.
	await physics_frame
	var parent_transform: Transform3D = parent.global_transform
	var parent_linear: Vector3 = parent.linear_velocity
	var parent_angular: Vector3 = parent.angular_velocity
	var parent_com_world: Vector3 = parent.to_global(parent.matter_center_of_mass_local)
	var joint_anchor_world_before: Vector3 = parent.to_global(anchor_parent_local)
	var joint_node_staleness: float = joint.global_position.distance_to(joint_anchor_world_before)

	_check(parent.volume.set_cell(CUT_CELL, CellVolume.EMPTY), "split transaction removes the intended bridge cell")
	parent_lineage.clear_lineage(CUT_CELL)
	var components: Array[CellVolume] = MatterTopology.extract_connected_components(parent.volume)
	_check(components.size() == 2, "jointed parent topology split produces exactly two successor components")
	if components.size() != 2:
		_finish()
		return

	var children: Array[ConstructBody] = []
	var child_origins: Array[Vector3i] = []
	var child_lineages: Array[MatterLineageMap] = []
	var anchor_child_index := -1
	var max_split_world_error := 0.0
	var max_split_velocity_error := 0.0
	var retained_lineage_mismatches := 0

	for index in range(components.size()):
		var source_component: CellVolume = components[index]
		var compact_info: Dictionary = MatterTopology.compact_volume(source_component)
		var source_origin: Vector3i = compact_info["origin"]
		var compact_volume: CellVolume = compact_info["volume"]
		var child := _make_body(
			world,
			"JointSuccessor_%d" % index,
			compact_volume,
			parent_transform * Transform3D(Basis.IDENTITY, Vector3(source_origin))
		)
		var child_com_world: Vector3 = child.to_global(child.matter_center_of_mass_local)
		child.linear_velocity = _velocity_at_point(parent_linear, parent_angular, parent_com_world, child_com_world)
		child.angular_velocity = parent_angular
		children.append(child)
		child_origins.append(source_origin)

		var child_lineage := MatterLineageMap.new(compact_volume.size)
		for source_cell in _occupied_cells(source_component):
			var compact_cell: Vector3i = source_cell - source_origin
			var token := parent_lineage.get_lineage(source_cell)
			child_lineage.set_lineage(compact_cell, token)
			if child_lineage.get_lineage(compact_cell) != token:
				retained_lineage_mismatches += 1

			var parent_point_world: Vector3 = parent_transform * (Vector3(source_cell) + Vector3(0.5, 0.5, 0.5))
			var child_point_world: Vector3 = child.to_global(Vector3(compact_cell) + Vector3(0.5, 0.5, 0.5))
			max_split_world_error = max(max_split_world_error, parent_point_world.distance_to(child_point_world))
			var parent_point_velocity := _velocity_at_point(parent_linear, parent_angular, parent_com_world, parent_point_world)
			var child_point_velocity := _velocity_at_point(child.linear_velocity, child.angular_velocity, child_com_world, child_point_world)
			max_split_velocity_error = max(max_split_velocity_error, parent_point_velocity.distance_to(child_point_velocity))
		child_lineages.append(child_lineage)

		if source_component.get_cell(ANCHOR_OWNER_CELL) != CellVolume.EMPTY:
			anchor_child_index = index

	_check(anchor_child_index >= 0, "exactly one successor retains the mechanical anchor owner Matter")
	if anchor_child_index < 0:
		_finish()
		return

	var anchor_child: ConstructBody = children[anchor_child_index]
	var free_child: ConstructBody = children[1 - anchor_child_index]
	var anchor_origin: Vector3i = child_origins[anchor_child_index]
	var mapped_anchor_local: Vector3 = anchor_parent_local - Vector3(anchor_origin)
	var mapped_owner_cell: Vector3i = ANCHOR_OWNER_CELL - anchor_origin
	var inherited_anchor_token := child_lineages[anchor_child_index].get_lineage(mapped_owner_cell)
	_check(inherited_anchor_token == anchor_owner_token, "joint endpoint successor is selected by retained anchor-owner Matter lineage")
	_check(max_split_world_error < 0.00001, "jointed split preserves retained Matter world positions")
	_check(max_split_velocity_error < 0.00001, "jointed split preserves retained Matter instantaneous velocity field")
	_check(retained_lineage_mismatches == 0, "jointed split preserves every retained Matter lineage mapping")
	_check(anchor_child.to_global(mapped_anchor_local).distance_to(joint_anchor_world_before) < 0.00001, "mechanical anchor maps continuously into compact successor coordinates")

	# PinJoint3D configures body-local pivots from the Joint3D node's current
	# global origin whenever an endpoint changes. The joint node itself does not
	# ride the constrained bodies, so its original scene transform is stale by
	# the time a moving topology replacement occurs. Rebase the joint frame onto
	# the current logical anchor before swapping the endpoint.
	_check(joint_node_staleness > 0.1, "moving assembly makes the persistent Joint3D scene anchor materially stale before succession")
	joint.global_position = joint_anchor_world_before
	joint.force_update_transform()
	var joint_rebase_error: float = joint.global_position.distance_to(joint_anchor_world_before)
	_check(joint_rebase_error < 0.000001, "joint scene anchor rebases onto current logical anchor before endpoint replacement")

	# Preserve logical mechanical-link identity while atomically replacing only
	# the body endpoint that owned its anchor Matter.
	joint.node_a = joint.get_path_to(anchor_child)
	_check(joint.get_instance_id() == joint_id, "mechanical-link identity survives endpoint frame replacement")
	_check(sibling.get_instance_id() == sibling_id, "unaffected mechanical endpoint keeps its physics identity")
	_check(anchor_child.get_instance_id() != parent_id, "topology successor has new physics-body identity")
	parent.free()

	# Let the freshly created successors participate in the already-upcoming
	# solver step, then cross a physics-frame boundary for node synchronization.
	await process_frame
	await physics_frame
	await process_frame

	var max_post_split_anchor_gap := 0.0
	var max_free_child_separation := 0.0
	var anchor_child_linear_before := anchor_child.linear_velocity
	var anchor_child_angular_before := anchor_child.angular_velocity

	# Stress both branches differently. The sibling drives the retained joint;
	# the non-owning successor receives an independent impulse and must stay free.
	sibling.apply_torque_impulse(assembly_transform.basis * Vector3(9.0, 17.0, -6.0))
	free_child.apply_central_impulse(assembly_transform.basis * Vector3(-8.0, 4.0, 13.0))
	var free_child_start := free_child.global_position

	for _frame in range(POST_SPLIT_FRAMES):
		await physics_frame
		await process_frame
		max_post_split_anchor_gap = max(
			max_post_split_anchor_gap,
			anchor_child.to_global(mapped_anchor_local).distance_to(sibling.to_global(sibling_anchor_local))
		)
		max_free_child_separation = max(max_free_child_separation, free_child.global_position.distance_to(free_child_start))
		_check(_finite_body_state(anchor_child) and _finite_body_state(free_child) and _finite_body_state(sibling), "mechanical succession remains numerically finite")

	var final_anchor_gap := anchor_child.to_global(mapped_anchor_local).distance_to(sibling.to_global(sibling_anchor_local))
	var anchor_child_linear_change := anchor_child.linear_velocity.distance_to(anchor_child_linear_before)
	var anchor_child_angular_change := anchor_child.angular_velocity.distance_to(anchor_child_angular_before)

	_check(max_post_split_anchor_gap < 0.02, "successor-owned joint remains bounded after parent frame replacement")
	_check(final_anchor_gap < 0.005, "successor-owned joint ends with a tight anchor")
	_check(max_free_child_separation > 0.1, "non-owning topology successor remains mechanically independent")
	_check(anchor_child_linear_change > 0.01 or anchor_child_angular_change > 0.01, "retained successor receives mechanical reaction through inherited joint")
	_check(joint.node_a == joint.get_path_to(anchor_child), "joint endpoint remains explicitly mapped to anchor-owning successor")
	_check(joint.node_b == joint.get_path_to(sibling), "unaffected joint endpoint remains on persistent sibling")

	print(
		"MULTIFRAME_JOINT_SPLIT_SUCCESSION_METRIC components=%d anchor_child_index=%d anchor_origin=%s anchor_owner_token=%d inherited_anchor_token=%d split_world_error=%.10f split_velocity_error=%.10f lineage_mismatches=%d pre_anchor_gap=%.10f joint_node_staleness=%.10f joint_rebase_error=%.10f post_anchor_gap=%.10f final_anchor_gap=%.10f free_child_separation=%.6f anchor_child_linear_change=%.6f anchor_child_angular_change=%.6f parent_id=%d anchor_child_id=%d free_child_id=%d sibling_id=%d joint_id=%d"
		% [
			components.size(),
			anchor_child_index,
			anchor_origin,
			anchor_owner_token,
			inherited_anchor_token,
			max_split_world_error,
			max_split_velocity_error,
			retained_lineage_mismatches,
			max_pre_split_anchor_gap,
			joint_node_staleness,
			joint_rebase_error,
			max_post_split_anchor_gap,
			final_anchor_gap,
			max_free_child_separation,
			anchor_child_linear_change,
			anchor_child_angular_change,
			parent_id,
			anchor_child.get_instance_id(),
			free_child.get_instance_id(),
			sibling_id,
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
		print("MULTIFRAME_JOINT_SPLIT_SUCCESSION_PROBE_PASS: a mechanical-link endpoint followed retained anchor Matter through compact topology split while the non-owning successor remained independent and the logical joint identity survived.")
		quit(0)
		return
	for failure in _failures:
		push_error("MULTIFRAME_JOINT_SPLIT_SUCCESSION_PROBE_FAIL: " + failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
