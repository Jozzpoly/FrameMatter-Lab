extends SceneTree

const VOLUME_SIZE := Vector3i(10, 3, 3)
const CUT_CELL := Vector3i(4, 1, 1)
const SUPPORT_SOURCE_CELL := Vector3i(7, 1, 1)
const ACTOR_LOCAL_START := Vector3(7.5, 4.15, 1.5)
const MASS_PER_CELL := 1.7
const DRIVE_LINEAR := Vector3(-1.8, 0.0, 2.7)
const DRIVE_ANGULAR := Vector3(0.0, 0.72, 0.0)
const PRE_SPLIT_RIDE_FRAMES := 45
const POST_SPLIT_RIDE_FRAMES := 90

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	world.name = "SharedTopologySplitWorld"
	get_root().add_child(world)

	var volume := _make_source_volume()
	var lineage := MatterLineageMap.new(volume.size)
	var next_token := 720001
	for cell in _occupied_cells(volume):
		lineage.set_lineage(cell, next_token)
		next_token += 1
	var cut_token := lineage.get_lineage(CUT_CELL)
	_check(cut_token != MatterLineageMap.NONE, "bridge Matter starts with retained identity before destruction")

	var space := LocalMatterSpace.new()
	space.name = "IntegratedTopologySpace"
	space.mass_per_cell = MASS_PER_CELL
	space.dynamic_gravity_scale = 0.0
	space.dynamic_linear_damp = 0.0
	space.dynamic_angular_damp = 0.0
	space.dynamic_can_sleep = false
	world.add_child(space)
	var initial_transform := Transform3D(
		Basis.from_euler(Vector3(0.0, 0.71, 0.0)).orthonormalized(),
		Vector3(13.0, 8.0, -11.0)
	)
	space.initialize_static(volume, lineage, initial_transform)
	var source_space_id := space.get_instance_id()

	_check(space.request_dynamic(DRIVE_LINEAR, DRIVE_ANGULAR), "I3 activates source through shared lifecycle before topology work")
	await space.provider_transition_committed
	var source_provider := space.get_active_provider()
	_check(source_provider is ConstructBody, "I3 source is a dynamic LocalMatterSpace provider")
	if not source_provider is ConstructBody:
		_finish(world)
		return
	var source_body := source_provider as ConstructBody
	var source_provider_id := source_body.get_instance_id()

	var actor := FrameProbeCharacter.new()
	actor.name = "TopologyActor"
	world.add_child(actor)
	actor.global_position = source_body.to_global(ACTOR_LOCAL_START)

	var acquired := false
	for _step in range(60):
		await physics_frame
		await process_frame
		if actor.grounded and actor.support_space == space and actor.support_body == source_body:
			acquired = true
			break
	_check(acquired, "actor acquires dynamic source Space before shared split")
	if not acquired:
		_finish(world)
		return

	var pre_split_local_start := source_body.to_local(actor.global_position)
	var max_pre_split_drift := 0.0
	for _step in range(PRE_SPLIT_RIDE_FRAMES):
		await physics_frame
		await process_frame
		var local_now := source_body.to_local(actor.global_position)
		max_pre_split_drift = max(
			max_pre_split_drift,
			Vector2(local_now.x - pre_split_local_start.x, local_now.z - pre_split_local_start.z).length()
		)
	_check(max_pre_split_drift < 0.002, "actor remains locally stable before shared topology transaction")
	_check(actor.grounded and actor.support_space == space, "actor still owns source logical support before cut")

	# Ordinary shared mutation retires bridge Matter. No solver phase occurs between
	# this mutation and requesting the connected-component lifecycle transaction.
	_check(space.mutate_cell(CUT_CELL, CellVolume.EMPTY), "shared mutation path destroys bridge Matter")
	_check(lineage.get_lineage(CUT_CELL) == MatterLineageMap.NONE, "bridge destruction retires its lineage before split")
	var retained_truth := _snapshot_truth(volume, lineage)
	var retained_token_set := _token_set(lineage)
	var retained_cell_count := volume.count_solid()
	var actor_source_local := source_body.to_local(actor.global_position)
	var actor_world_before_request := actor.global_position
	var transfers_before := actor.observed_support_transfers

	_check(space.request_connected_component_split(), "disconnected dynamic Space accepts shared connected-component split request")
	_check(space.is_topology_split_pending(), "I3 split waits for shared lifecycle boundary")
	await space.topology_split_committed
	var result := space.get_last_split_result()
	_check(result != null, "shared split publishes an explicit source→successor mapping result")
	if result == null:
		_finish(world)
		return

	_check(space.is_retired(), "source logical Space retires after one-to-many topology split")
	_check(space.get_active_provider() == null and space.get_provider_kind() == LocalMatterSpace.ProviderKind.NONE, "retired source has no live provider authority")
	_check(space.volume == null and space.lineage == null, "retired source keeps no live Matter/lineage authority")
	_check(space.get_provider_node_count() == 0, "source provider is retired before successor authority remains")
	_check(result.source_space == space and result.source_provider_id == source_provider_id, "split result identifies the retired source transaction")
	_check(result.size() == 2, "shared runtime produces exactly two connected-component successor Spaces")

	var mapping := result.map_source_local_point_for_cell(SUPPORT_SOURCE_CELL, actor_source_local)
	_check(not mapping.is_empty(), "shared split result maps the actor-owned source cell to one successor")
	if mapping.is_empty():
		_finish(world)
		return
	var support_index: int = mapping["index"]
	var support_space := mapping["space"] as LocalMatterSpace
	var mapped_actor_local: Vector3 = mapping["local_point"]
	_check(support_space != null, "actor mapping resolves a successor logical Space")
	if support_space == null:
		_finish(world)
		return
	var support_provider := support_space.get_active_provider()
	_check(support_provider is ConstructBody, "actor-owned successor has a dynamic provider")
	if not support_provider is ConstructBody:
		_finish(world)
		return
	var support_body := support_provider as ConstructBody

	# The old dynamic provider legitimately advances to the transaction-boundary
	# sync before split. Compare the handoff to that exact boundary, not to the
	# stale scene-node pose sampled in the previous process frame.
	var expected_actor_world_at_transaction := result.source_transform * actor_source_local
	var split_phase_advance := expected_actor_world_at_transaction.distance_to(actor_world_before_request)
	var handoff_ok := actor.transfer_support_frame(support_body, mapped_actor_local)
	var handoff_world_jump := actor.global_position.distance_to(expected_actor_world_at_transaction)
	_check(handoff_ok, "actor consumes shared topology mapping through the existing explicit rebase handoff")
	_check(actor.observed_support_transfers == transfers_before + 1, "I3 actor handoff records exactly one topology transfer")
	_check(actor.support_space == support_space and actor.support_body == support_body, "actor support relation succeeds onto successor logical Space + provider")
	_check(handoff_world_jump < 0.0001, "shared split mapping preserves actor world position at transaction boundary")

	var successor_space_ids: Dictionary = {}
	var successor_provider_ids: Dictionary = {}
	var successor_total_cells := 0
	var successor_total_lineage := 0
	var successor_token_set: Dictionary = {}
	var max_world_cell_error := 0.0
	var max_velocity_field_error := 0.0
	var compact_rebased_cells := 0
	var min_first_server_displacement := INF
	var successor_commit_transforms: Array = []

	for index in range(result.size()):
		var successor := result.successors[index] as LocalMatterSpace
		var source_origin: Vector3i = result.source_origins[index]
		var source_component: CellVolume = result.source_components[index]
		_check(successor != null and not successor.is_retired(), "every split successor is a live logical Space")
		if successor == null:
			continue
		var body := successor.get_active_provider() as ConstructBody
		_check(body != null, "every split successor owns exactly one dynamic provider")
		if body == null:
			continue
		_check(successor.get_provider_node_count() == 1, "every successor has exactly one provider")
		_check(successor.get_instance_id() != source_space_id, "no arbitrary component inherits retired source Space identity")
		_check(body.get_instance_id() != source_provider_id, "every successor has fresh provider identity")
		_check(not successor_space_ids.has(successor.get_instance_id()), "successor logical Space identities are unique")
		_check(not successor_provider_ids.has(body.get_instance_id()), "successor provider identities are unique")
		successor_space_ids[successor.get_instance_id()] = true
		successor_provider_ids[body.get_instance_id()] = true
		successor_total_cells += successor.volume.count_solid()
		successor_total_lineage += successor.lineage.count_assigned()
		successor_commit_transforms.append(body.global_transform)

		for child_cell in _occupied_cells(successor.volume):
			var lineage_token := successor.lineage.get_lineage(child_cell)
			_check(lineage_token != MatterLineageMap.NONE, "successor Matter never loses lineage")
			_check(not successor_token_set.has(lineage_token), "retained lineage exists in exactly one successor")
			successor_token_set[lineage_token] = true

		for source_cell in _occupied_cells(source_component):
			var child_cell := source_cell - source_origin
			if child_cell != source_cell:
				compact_rebased_cells += 1
			var truth: Dictionary = retained_truth[source_cell]
			_check(successor.volume.get_cell(child_cell) == int(truth["material"]), "successor compact storage preserves source material")
			_check(successor.lineage.get_lineage(child_cell) == int(truth["lineage"]), "successor compact storage preserves source lineage")

			var source_world := result.source_transform * (Vector3(source_cell) + Vector3(0.5, 0.5, 0.5))
			var successor_world := body.global_transform * (Vector3(child_cell) + Vector3(0.5, 0.5, 0.5))
			max_world_cell_error = max(max_world_cell_error, source_world.distance_to(successor_world))

			var source_velocity := _velocity_at_point(
				result.source_linear_velocity,
				result.source_angular_velocity,
				result.source_com_world,
				source_world
			)
			var successor_com_world := body.global_transform * body.matter_center_of_mass_local
			var successor_velocity := _velocity_at_point(
				body.linear_velocity,
				body.angular_velocity,
				successor_com_world,
				successor_world
			)
			max_velocity_field_error = max(max_velocity_field_error, source_velocity.distance_to(successor_velocity))

	_check(successor_total_cells == retained_cell_count, "successor Spaces partition every retained Matter cell exactly once")
	_check(successor_total_lineage == retained_cell_count, "successor Spaces carry exactly one lineage token per retained Matter cell")
	_check(successor_token_set.size() == retained_token_set.size(), "successor lineage union has the same retained cardinality")
	for lineage_token_variant in retained_token_set.keys():
		_check(successor_token_set.has(lineage_token_variant), "every retained lineage token survives into one successor")
	_check(not successor_token_set.has(cut_token), "destroyed bridge lineage does not resurrect in any successor")
	_check(compact_rebased_cells > 0, "I3 exercises non-identity compact local-coordinate rebasing")
	_check(max_world_cell_error < 0.00001, "shared split preserves retained Matter world positions")
	_check(max_velocity_field_error < 0.00001, "shared split preserves the source rigid velocity field at retained Matter points")

	# The split commits at physics_frame. Fresh successor RIDs should participate
	# in the upcoming solver step even though their scene-node transforms will not
	# show that result until the next PhysicsServer sync.
	await process_frame
	for index in range(result.size()):
		var successor := result.successors[index] as LocalMatterSpace
		var body := successor.get_active_provider() as ConstructBody
		var server_transform := PhysicsServer3D.body_get_state(body.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM) as Transform3D
		var commit_transform: Transform3D = successor_commit_transforms[index]
		min_first_server_displacement = min(
			min_first_server_displacement,
			server_transform.origin.distance_to(commit_transform.origin)
		)
	_check(min_first_server_displacement > 0.005, "every fresh successor participates in the first upcoming solver step")

	await physics_frame
	var support_server_transform := PhysicsServer3D.body_get_state(
		support_body.get_rid(),
		PhysicsServer3D.BODY_STATE_TRANSFORM
	) as Transform3D
	var support_node_sync_gap := support_server_transform.origin.distance_to(support_body.global_position)
	_check(support_node_sync_gap < 0.00001, "support successor Node catches PhysicsServer state on the next sync")

	# At this point the successor Node has received its first solver result but the
	# actor has not yet executed this tick. The explicit topology mapping remains
	# the authoritative local support coordinate; sampling actor global_position
	# here would intentionally observe one phase behind the support Node.
	var ride_local_start := mapped_actor_local
	var max_post_split_drift := 0.0
	var floor_loss := 0
	var wrong_support_frames := 0
	for _step in range(POST_SPLIT_RIDE_FRAMES):
		await physics_frame
		await process_frame
		var local_now := support_body.to_local(actor.global_position)
		max_post_split_drift = max(
			max_post_split_drift,
			Vector2(local_now.x - ride_local_start.x, local_now.z - ride_local_start.z).length()
		)
		if not actor.grounded:
			floor_loss += 1
		if actor.support_space != support_space or actor.support_body != support_body:
			wrong_support_frames += 1

	_check(floor_loss == 0, "actor remains grounded after shared topology split")
	_check(wrong_support_frames == 0, "actor remains bound to mapped successor Space/provider after split")
	_check(max_post_split_drift < 0.002, "actor remains locally stable on compact successor after shared split")
	_check(not space.request_static(), "retired source rejects further provider lifecycle requests")
	_check(not space.mutate_cell(SUPPORT_SOURCE_CELL, 9), "retired source rejects further Matter mutation")

	print(
		"LIFECYCLE_SHARED_TOPOLOGY_SPLIT_METRIC source_space_id=%d source_provider_id=%d successors=%d support_index=%d pre_split_drift=%.10f split_phase_advance=%.10f handoff_world_jump=%.10f compact_rebased_cells=%d world_cell_error=%.10f velocity_field_error=%.10f min_first_server_displacement=%.10f support_node_sync_gap=%.10f post_split_drift=%.10f floor_loss=%d wrong_support=%d retained_cells=%d lineage_union=%d"
		% [
			source_space_id,
			source_provider_id,
			result.size(),
			support_index,
			max_pre_split_drift,
			split_phase_advance,
			handoff_world_jump,
			compact_rebased_cells,
			max_world_cell_error,
			max_velocity_field_error,
			min_first_server_displacement,
			support_node_sync_gap,
			max_post_split_drift,
			floor_loss,
			wrong_support_frames,
			retained_cell_count,
			successor_token_set.size(),
		]
	)

	_finish(world)


func _make_source_volume() -> CellVolume:
	var volume := CellVolume.new(VOLUME_SIZE)
	volume.fill_box(Vector3i(0, 0, 0), Vector3i(3, 3, 3), CellVolume.SOLID)
	volume.fill_box(Vector3i(6, 0, 0), Vector3i(10, 3, 3), CellVolume.SOLID)
	for x in range(3, 6):
		volume.set_cell(Vector3i(x, 1, 1), CellVolume.SOLID)
	return volume


func _snapshot_truth(volume: CellVolume, lineage: MatterLineageMap) -> Dictionary:
	var snapshot: Dictionary = {}
	for cell in _occupied_cells(volume):
		snapshot[cell] = {
			"material": volume.get_cell(cell),
			"lineage": lineage.get_lineage(cell),
		}
	return snapshot


func _token_set(lineage: MatterLineageMap) -> Dictionary:
	var result: Dictionary = {}
	for z in range(lineage.size.z):
		for y in range(lineage.size.y):
			for x in range(lineage.size.x):
				var token := lineage.get_lineage(Vector3i(x, y, z))
				if token != MatterLineageMap.NONE:
					result[token] = true
	return result


func _occupied_cells(volume: CellVolume) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for z in range(volume.size.z):
		for y in range(volume.size.y):
			for x in range(volume.size.x):
				var cell := Vector3i(x, y, z)
				if volume.get_cell(cell) != CellVolume.EMPTY:
					result.append(cell)
	return result


func _velocity_at_point(linear: Vector3, angular: Vector3, com_world: Vector3, point_world: Vector3) -> Vector3:
	return linear + angular.cross(point_world - com_world)


func _finish(world: Node3D) -> void:
	if _failures.is_empty():
		print("LIFECYCLE_SHARED_TOPOLOGY_SPLIT_PROBE_PASS: one moving LocalMatterSpace retired into fresh compact successor Spaces through shared runtime while retained Matter lineage, rigid velocity field and explicit actor succession remained coherent.")
		world.free()
		quit(0)
		return
	for failure in _failures:
		push_error("LIFECYCLE_SHARED_TOPOLOGY_SPLIT_PROBE_FAIL: " + failure)
	world.free()
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
