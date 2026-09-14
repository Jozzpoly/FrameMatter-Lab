extends SceneTree

const VOLUME_SIZE := Vector3i(10, 3, 3)
const LIVE_EDIT_CELL := Vector3i(0, 0, 0)
const CUT_CELL := Vector3i(4, 1, 1)
const SUPPORT_SOURCE_CELL := Vector3i(7, 1, 1)
const ACTOR_LOCAL_START := Vector3(7.5, 4.15, 1.5)
const MASS_PER_CELL := 1.7
const DRIVE_LINEAR := Vector3(-1.8, 0.0, 2.7)
const DRIVE_ANGULAR := Vector3(0.0, 0.72, 0.0)
const PRE_EDIT_RIDE_FRAMES := 40
const POST_EDIT_RIDE_FRAMES := 30
const POST_SPLIT_RIDE_FRAMES := 70
const COM_TOLERANCE := 0.00002
const INVERSE_MASS_TOLERANCE := 0.000001
const TENSOR_TOLERANCE := 0.0002

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	world.name = "R1MergedLifecycleIntegrationWorld"
	get_root().add_child(world)

	var volume := _make_source_volume()
	var lineage := MatterLineageMap.new(volume.size)
	var next_token := 4_000_001
	for cell in _occupied_cells(volume):
		lineage.set_lineage(cell, next_token)
		next_token += 1

	var space := LocalMatterSpace.new()
	space.name = "R1MergedLifecycleSpace"
	space.mass_per_cell = MASS_PER_CELL
	space.collision_mode = CellCollisionBoxer.Mode.MERGED_CUBOIDS
	space.dynamic_gravity_scale = 0.0
	space.dynamic_linear_damp = 0.0
	space.dynamic_angular_damp = 0.0
	space.dynamic_can_sleep = false
	world.add_child(space)

	var initial_transform := Transform3D(
		Basis.from_euler(Vector3(0.0, 0.61, 0.0)).orthonormalized(),
		Vector3(11.0, 7.0, -9.0)
	)
	space.initialize_static(volume, lineage, initial_transform)
	var static_provider := space.get_active_provider() as MatterRepresentation
	_check(static_provider != null, "R1 integrated source starts as a static provider")
	if static_provider == null:
		_finish(world)
		return
	var initial_expected_shapes := CellCollisionBoxer.build_boxes(volume, CellCollisionBoxer.Mode.MERGED_CUBOIDS).size()
	_check(static_provider.get_collision_shape_count() == initial_expected_shapes, "R1 integrated static provider uses exact merged collision compilation")
	_check(initial_expected_shapes < volume.count_solid(), "R1 integrated source begins with real collision compression")

	_check(space.request_dynamic(Vector3.ZERO, Vector3.ZERO), "R1 integrated source queues static-to-dynamic replacement")
	await space.provider_transition_committed
	var source_body := space.get_active_provider() as ConstructBody
	_check(source_body != null, "R1 integrated source becomes a ConstructBody")
	if source_body == null:
		_finish(world)
		return
	_check(source_body.collision_mode == CellCollisionBoxer.Mode.MERGED_CUBOIDS, "R1 collision mode survives provider replacement")
	_check(source_body.get_collision_shape_count() == initial_expected_shapes, "R1 dynamic provider installs the same exact merged coverage")

	for _step in range(4):
		await physics_frame
		await process_frame
	_check_solver_mass_properties(source_body, volume, "source_initial")

	source_body.linear_velocity = DRIVE_LINEAR
	source_body.angular_velocity = DRIVE_ANGULAR

	var actor := FrameProbeCharacter.new()
	actor.name = "R1MergedActor"
	world.add_child(actor)
	actor.global_position = source_body.to_global(ACTOR_LOCAL_START)

	var acquired := false
	for _step in range(60):
		await physics_frame
		await process_frame
		if actor.grounded and actor.support_space == space and actor.support_body == source_body:
			acquired = true
			break
	_check(acquired, "R1 actor acquires merged dynamic source through ordinary support queries")
	if not acquired:
		_finish(world)
		return

	var pre_edit_local := source_body.to_local(actor.global_position)
	var pre_edit_drift := 0.0
	for _step in range(PRE_EDIT_RIDE_FRAMES):
		await physics_frame
		await process_frame
		var local_now := source_body.to_local(actor.global_position)
		pre_edit_drift = max(pre_edit_drift, Vector2(local_now.x - pre_edit_local.x, local_now.z - pre_edit_local.z).length())
	_check(pre_edit_drift < 0.002, "R1 actor remains locally stable on moving merged collision")

	var source_id_before_edit := source_body.get_instance_id()
	var edit_token := lineage.get_lineage(LIVE_EDIT_CELL)
	var cells_before_edit := volume.count_solid()
	var velocity_before_edit := source_body.linear_velocity
	var angular_before_edit := source_body.angular_velocity
	var edit_started := Time.get_ticks_usec()
	_check(space.mutate_cell(LIVE_EDIT_CELL, CellVolume.EMPTY), "R1 occupancy-changing live edit rebuilds moving merged provider")
	var edit_rebuild_usec := Time.get_ticks_usec() - edit_started
	_check(lineage.get_lineage(LIVE_EDIT_CELL) == MatterLineageMap.NONE, "R1 live edit retires removed Matter lineage")
	_check(edit_token != MatterLineageMap.NONE, "R1 live-edit cell had real lineage before removal")
	_check(volume.count_solid() == cells_before_edit - 1, "R1 live edit removes exactly one occupied cell")
	_check(source_body.get_instance_id() == source_id_before_edit, "R1 merged live edit does not replace the dynamic provider")
	var edited_expected_shapes := CellCollisionBoxer.build_boxes(volume, CellCollisionBoxer.Mode.MERGED_CUBOIDS).size()
	_check(source_body.get_collision_shape_count() == edited_expected_shapes, "R1 merged live edit rebuilds exact compiled shape count")
	_check(source_body.mass > 0.0 and abs(source_body.mass - float(volume.count_solid()) * MASS_PER_CELL) < 0.001, "R1 merged live edit keeps mass Matter-derived")
	_check(source_body.matter_center_of_mass_local.distance_to(MatterTopology.center_of_mass_local(volume)) < 0.00001, "R1 merged live edit updates authoritative Matter COM")
	_check(source_body.linear_velocity.distance_to(velocity_before_edit) < 0.00001, "R1 merged live edit preserves linear velocity synchronously")
	_check(source_body.angular_velocity.distance_to(angular_before_edit) < 0.00001, "R1 merged live edit preserves angular velocity synchronously")

	# Freeze only the velocities, not the lifecycle/provider, so solver telemetry can
	# be compared against one stable orientation after the in-motion rebuild.
	source_body.linear_velocity = Vector3.ZERO
	source_body.angular_velocity = Vector3.ZERO
	for _step in range(4):
		await physics_frame
		await process_frame
	_check_solver_mass_properties(source_body, volume, "source_after_live_edit")
	source_body.linear_velocity = DRIVE_LINEAR
	source_body.angular_velocity = DRIVE_ANGULAR

	var post_edit_local := source_body.to_local(actor.global_position)
	var post_edit_drift := 0.0
	var post_edit_floor_loss := 0
	for _step in range(POST_EDIT_RIDE_FRAMES):
		await physics_frame
		await process_frame
		var local_now := source_body.to_local(actor.global_position)
		post_edit_drift = max(post_edit_drift, Vector2(local_now.x - post_edit_local.x, local_now.z - post_edit_local.z).length())
		if not actor.grounded:
			post_edit_floor_loss += 1
	_check(post_edit_floor_loss == 0, "R1 actor stays grounded after moving merged occupancy rebuild")
	_check(post_edit_drift < 0.002, "R1 actor stays locally stable after merged occupancy rebuild")

	var cut_token := lineage.get_lineage(CUT_CELL)
	_check(cut_token != MatterLineageMap.NONE, "R1 bridge has lineage before destructive split edit")
	var actor_source_local := source_body.to_local(actor.global_position)
	var transfers_before_split := actor.observed_support_transfers
	_check(space.mutate_cell(CUT_CELL, CellVolume.EMPTY), "R1 bridge destruction rebuilds merged source before split")
	_check(lineage.get_lineage(CUT_CELL) == MatterLineageMap.NONE, "R1 bridge lineage retires before split")
	var split_source_shapes := source_body.get_collision_shape_count()
	var split_expected_shapes := CellCollisionBoxer.build_boxes(volume, CellCollisionBoxer.Mode.MERGED_CUBOIDS).size()
	_check(split_source_shapes == split_expected_shapes, "R1 disconnected source still has exact merged collision coverage")
	_check(space.request_connected_component_split(), "R1 disconnected merged source accepts shared topology split")
	await space.topology_split_committed
	var result := space.get_last_split_result()
	_check(result != null, "R1 merged split publishes source-to-successor mapping")
	if result == null:
		_finish(world)
		return
	_check(result.size() == 2, "R1 merged split produces exactly two connected successors")
	_check(space.is_retired(), "R1 source Space retires after merged topology split")

	var mapping := result.map_source_local_point_for_cell(SUPPORT_SOURCE_CELL, actor_source_local)
	_check(not mapping.is_empty(), "R1 actor support cell maps to one merged successor")
	if mapping.is_empty():
		_finish(world)
		return
	var support_space := mapping["space"] as LocalMatterSpace
	var mapped_actor_local: Vector3 = mapping["local_point"]
	_check(support_space != null, "R1 mapped actor successor exists")
	if support_space == null:
		_finish(world)
		return
	var support_body := support_space.get_active_provider() as ConstructBody
	_check(support_body != null, "R1 mapped successor owns a dynamic ConstructBody")
	if support_body == null:
		_finish(world)
		return

	var expected_actor_world := result.source_transform * actor_source_local
	var handoff_ok := actor.transfer_support_frame(support_body, mapped_actor_local)
	var handoff_world_jump := actor.global_position.distance_to(expected_actor_world)
	_check(handoff_ok, "R1 actor consumes merged split mapping through explicit support transfer")
	_check(actor.observed_support_transfers == transfers_before_split + 1, "R1 merged split records exactly one actor support transfer")
	_check(handoff_world_jump < 0.0001, "R1 merged split preserves actor world position at transaction boundary")

	var successor_cells := 0
	var successor_lineage := 0
	var successor_shapes := 0
	var successor_reference_shapes := 0
	for successor_variant in result.successors:
		var successor := successor_variant as LocalMatterSpace
		_check(successor != null, "R1 every split successor is a LocalMatterSpace")
		if successor == null:
			continue
		_check(successor.collision_mode == CellCollisionBoxer.Mode.MERGED_CUBOIDS, "R1 collision representation policy inherits through topology succession")
		var body := successor.get_active_provider() as ConstructBody
		_check(body != null, "R1 every merged successor owns one dynamic provider")
		if body == null:
			continue
		var expected_shapes := CellCollisionBoxer.build_boxes(successor.volume, CellCollisionBoxer.Mode.MERGED_CUBOIDS).size()
		_check(body.get_collision_shape_count() == expected_shapes, "R1 every successor installs exact merged collision coverage")
		successor_cells += successor.volume.count_solid()
		successor_lineage += successor.lineage.count_assigned()
		successor_shapes += body.get_collision_shape_count()
		successor_reference_shapes += successor.volume.count_solid()

	_check(successor_cells == cells_before_edit - 2, "R1 successors partition all Matter retained after live edit plus bridge destruction")
	_check(successor_lineage == successor_cells, "R1 successor lineage cardinality remains one token per retained Matter cell")
	_check(successor_shapes < successor_reference_shapes, "R1 successor topology keeps real collision compression")

	var ride_local_start := mapped_actor_local
	var max_post_split_drift := 0.0
	var post_split_floor_loss := 0
	var wrong_support_frames := 0
	for _step in range(POST_SPLIT_RIDE_FRAMES):
		await physics_frame
		await process_frame
		var local_now := support_body.to_local(actor.global_position)
		max_post_split_drift = max(max_post_split_drift, Vector2(local_now.x - ride_local_start.x, local_now.z - ride_local_start.z).length())
		if not actor.grounded:
			post_split_floor_loss += 1
		if actor.support_space != support_space or actor.support_body != support_body:
			wrong_support_frames += 1
	_check(post_split_floor_loss == 0, "R1 actor remains grounded on moving merged successor")
	_check(wrong_support_frames == 0, "R1 actor remains bound to mapped merged successor")
	_check(max_post_split_drift < 0.002, "R1 actor remains locally stable on moving merged successor")

	# Settle representation motion only for solver mass-property comparison. This
	# happens after the moving-successor actor stress has already been measured.
	for successor_variant in result.successors:
		var successor := successor_variant as LocalMatterSpace
		if successor == null:
			continue
		var body := successor.get_active_provider() as ConstructBody
		if body == null:
			continue
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
	for _step in range(4):
		await physics_frame
		await process_frame
	for index in range(result.successors.size()):
		var successor := result.successors[index] as LocalMatterSpace
		if successor == null:
			continue
		var body := successor.get_active_provider() as ConstructBody
		if body != null:
			_check_solver_mass_properties(body, successor.volume, "successor_%d" % index)

	print(
		"R1_MERGED_LIFECYCLE_INTEGRATION_METRIC initial_cells=%d final_cells=%d initial_shapes=%d edited_shapes=%d disconnected_shapes=%d successor_shapes=%d reference_successor_shapes=%d edit_rebuild_us=%d pre_edit_drift=%.10f post_edit_drift=%.10f post_split_drift=%.10f handoff_world_jump=%.10f floor_loss_after_edit=%d floor_loss_after_split=%d wrong_support_after_split=%d"
		% [
			cells_before_edit,
			successor_cells,
			initial_expected_shapes,
			edited_expected_shapes,
			split_source_shapes,
			successor_shapes,
			successor_reference_shapes,
			edit_rebuild_usec,
			pre_edit_drift,
			post_edit_drift,
			max_post_split_drift,
			handoff_world_jump,
			post_edit_floor_loss,
			post_split_floor_loss,
			wrong_support_frames,
		]
	)

	_finish(world)


func _check_solver_mass_properties(body: ConstructBody, truth: CellVolume, label: String) -> void:
	var props := MatterMassProperties.calculate(truth, MASS_PER_CELL)
	var expected_mass: float = props["mass"]
	var expected_com: Vector3 = props["center_of_mass_local"]
	var local_inertia: Basis = props["inertia_tensor_local"]
	var expected_world_inverse: Basis = MatterMassProperties.world_inverse_inertia(local_inertia, body.global_transform.basis)
	var com_error := body.observed_center_of_mass_local.distance_to(expected_com)
	var inverse_mass_error := abs(body.observed_inverse_mass - 1.0 / expected_mass)
	var tensor_error := _basis_action_error(body.observed_inverse_inertia_tensor, expected_world_inverse)
	_check(com_error < COM_TOLERANCE, "R1 %s merged solver COM matches Matter" % label)
	_check(inverse_mass_error < INVERSE_MASS_TOLERANCE, "R1 %s merged solver inverse mass matches Matter" % label)
	_check(tensor_error < TENSOR_TOLERANCE, "R1 %s merged solver inertia tensor matches Matter" % label)


func _basis_action_error(a: Basis, b: Basis) -> float:
	var max_error := 0.0
	for axis in [Vector3.RIGHT, Vector3.UP, Vector3(0.0, 0.0, 1.0)]:
		max_error = max(max_error, (a * axis).distance_to(b * axis))
	return max_error


func _make_source_volume() -> CellVolume:
	var volume := CellVolume.new(VOLUME_SIZE)
	volume.fill_box(Vector3i(0, 0, 0), Vector3i(3, 3, 3), CellVolume.SOLID)
	volume.fill_box(Vector3i(6, 0, 0), Vector3i(10, 3, 3), CellVolume.SOLID)
	for x in range(3, 6):
		volume.set_cell(Vector3i(x, 1, 1), CellVolume.SOLID)
	return volume


func _occupied_cells(volume: CellVolume) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for z in range(volume.size.z):
		for y in range(volume.size.y):
			for x in range(volume.size.x):
				var cell := Vector3i(x, y, z)
				if volume.get_cell(cell) != CellVolume.EMPTY:
					result.append(cell)
	return result


func _finish(world: Node3D) -> void:
	if _failures.is_empty():
		print("R1_MERGED_LIFECYCLE_INTEGRATION_PASS: merged cuboid collision remained semantically transparent through provider replacement, solver mass properties, moving live occupancy rebuild, actor support and topology succession.")
		world.free()
		quit(0)
		return
	for failure in _failures:
		push_error("R1_MERGED_LIFECYCLE_INTEGRATION_FAIL: " + failure)
	world.free()
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
