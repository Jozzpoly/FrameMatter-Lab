extends SceneTree

const ACQUIRE_FRAMES := 14
const POST_RELEASE_FRAMES := 3
const MOTION_FRAMES := 12
const POST_REBASE_FRAMES := 3
const POST_SPLIT_FRAMES := 4
const POST_FREEZE_FRAMES := 3

const CENTRAL_IMPULSE := Vector3(0.0, 0.0, -36.0)
const TORQUE_IMPULSE := Vector3(0.0, 90.0, 0.0)
const EDGE_Z := 8

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://p1/main.tscn") as PackedScene
	_check(packed != null, "integrated P1 scene loads")
	if packed == null:
		_finish()
		return

	var p1 := packed.instantiate()
	get_root().add_child(p1)
	await process_frame
	await _advance_frames(ACQUIRE_FRAMES)

	var source := p1.call("get_space") as LocalMatterSpace
	var player := p1.call("get_player") as SpaceQueryCharacter
	var camera_rig := p1.call("get_camera_rig") as P1CameraRig
	var interactor := p1.call("get_interactor") as P1MatterInteractor
	var registry := p1.get_node("P1SpaceRegistry") as P1SpaceRegistry
	_check(source != null and player != null and camera_rig != null and interactor != null and registry != null, "integrated P1 roles resolve")
	if source == null or player == null or camera_rig == null or interactor == null or registry == null:
		p1.free()
		_finish()
		return

	var logical_space_id: int = source.get_instance_id()
	_check(source.get_provider_kind() == LocalMatterSpace.ProviderKind.STATIC, "integrated loop starts from static representation")
	_check(player.grounded and player.support_space == source, "actor starts grounded on authored logical Space")
	_check(camera_rig.context_target == source.get_active_provider(), "camera starts contextualized to authored Space")

	# 1. Representation release must itself create no motion.
	_check(bool(p1.call("toggle_focused_space_for_test")), "Owner-facing toggle queues zero-launch dynamic release")
	await source.provider_transition_committed
	await _advance_frames(POST_RELEASE_FRAMES)
	var body := source.get_active_provider() as ConstructBody
	_check(body != null, "release installs ConstructBody provider")
	if body == null:
		p1.free()
		_finish()
		return
	_check(body.linear_velocity.length() < 0.0001, "release contributes no hidden linear launch")
	_check(body.angular_velocity.length() < 0.0001, "release contributes no hidden angular launch")
	_check(player.grounded and player.support_space == source, "actor remains on same logical Space after release")

	# 2. Motion comes only from explicit finite impulses.
	_check(bool(p1.call("apply_focused_central_impulse_for_test", CENTRAL_IMPULSE)), "Owner-facing finite central impulse is accepted")
	_check(bool(p1.call("apply_focused_torque_impulse_for_test", TORQUE_IMPULSE)), "Owner-facing finite torque impulse is accepted")
	await _advance_frames(MOTION_FRAMES)
	body = source.get_active_provider() as ConstructBody
	_check(body != null and body.linear_velocity.length() > 0.01, "finite impulse produces measurable rigid translation")
	_check(body != null and body.angular_velocity.length() > 0.001, "finite torque produces measurable rigid rotation")
	_check(player.grounded and player.support_space == source, "actor rides explicitly moving Space")
	var ride_anchor_error := 0.0
	if body != null and player.grounded:
		ride_anchor_error = body.to_global(player.support_local_center).distance_to(player.global_position)
	_check(ride_anchor_error < 0.001, "actor ride anchor remains coherent before editing")

	# 3. Build a connected spur to the low-x storage edge, then request one more
	# connected cell outside storage. This intentionally forces a non-zero frame
	# rebase while the same dynamic Space is moving.
	_check(interactor.apply_edit_to_cell(source, Vector3i(1, 0, EDGE_Z), P1MatterInteractor.EditMode.PLACE), "moving Space accepts first connected edge placement")
	_check(interactor.apply_edit_to_cell(source, Vector3i(0, 0, EDGE_Z), P1MatterInteractor.EditMode.PLACE), "moving Space accepts second connected edge placement")
	var provider_id_before_rebase: int = source.get_active_provider().get_instance_id()
	var support_local_before_rebase: Vector3 = player.support_local_center
	var linear_before_rebase: Vector3 = body.linear_velocity
	var angular_before_rebase: Vector3 = body.angular_velocity
	var source_edge_cell := Vector3i(-1, 0, EDGE_Z)
	_check(interactor.request_place_to_cell(source, source_edge_cell), "out-of-storage connected placement requests maintenance transaction")
	_check(source.is_storage_rebase_pending(), "storage maintenance is pending before physics boundary")
	await source.storage_rebase_committed
	var rebase_report: Dictionary = source.get_last_storage_rebase_report()
	var local_shift: Vector3i = rebase_report["local_shift"]
	_check(local_shift != Vector3i.ZERO, "integrated storage pressure forces a real local-frame shift")
	_check(source.get_instance_id() == logical_space_id, "storage rebase preserves logical Space identity")
	_check(source.get_active_provider().get_instance_id() == provider_id_before_rebase, "storage rebase preserves provider identity")
	_check(player.support_local_center.distance_to(support_local_before_rebase + Vector3(local_shift)) < 0.001, "actor support relation is remapped into rebased frame")
	_check(player.grounded and player.support_space == source and player.support_body == source.get_active_provider(), "actor remains attached to same logical/provider relation through storage maintenance")
	_check(camera_rig.context_target == source.get_active_provider(), "camera context remains on same moving provider through storage maintenance")

	await process_frame # deferred mapped placement after the maintenance signal stack
	await _advance_frames(POST_REBASE_FRAMES)
	var mapped_edge_cell: Vector3i = source_edge_cell + local_shift
	_check(source.volume.in_bounds(mapped_edge_cell), "rebased source cell maps inside expanded storage")
	_check(source.volume.get_cell(mapped_edge_cell) != CellVolume.EMPTY, "deferred mapped placement commits actual Matter after rebase")
	_check(source.lineage.get_lineage(mapped_edge_cell) != MatterLineageMap.NONE, "mapped placement receives fresh lineage below UI authority")
	body = source.get_active_provider() as ConstructBody
	var linear_rebase_error: float = body.linear_velocity.distance_to(linear_before_rebase) if body != null else INF
	var angular_rebase_error: float = body.angular_velocity.distance_to(angular_before_rebase) if body != null else INF
	_check(linear_rebase_error < 0.02, "moving storage maintenance preserves solver linear state")
	_check(angular_rebase_error < 0.02, "moving storage maintenance preserves solver angular state")
	_check(player.grounded and player.support_space == source, "actor keeps riding after expand-and-place transaction")

	# 4. Cut the already-moving, already-rebased Space through the same authored
	# causal seam. Coordinates are mapped through the maintenance shift rather
	# than assuming storage coordinates are stable identity.
	var removed := 0
	var actor_local_before_split: Vector3 = player.support_local_center
	for z in range(2, 14):
		var mapped_cut_cell := Vector3i(6, 0, z) + local_shift
		var changed := interactor.apply_edit_to_cell(source, mapped_cut_cell, P1MatterInteractor.EditMode.REMOVE)
		_check(changed, "integrated topology cut removes mapped cell %s" % str(mapped_cut_cell))
		if changed:
			removed += 1
		if z < 13:
			_check(not source.is_topology_split_pending(), "partial integrated cut remains connected")
	_check(removed == 12, "integrated cut removes the full authored seam")
	_check(source.is_topology_split_pending(), "final integrated cut queues one-to-many topology succession")
	await source.topology_split_committed
	var split_result: LocalMatterSplitResult = source.get_last_split_result()
	var handoff_world_error := INF
	_check(split_result != null and split_result.size() == 2, "integrated split produces two successor Spaces")
	if split_result != null:
		var expected_handoff_world: Vector3 = split_result.source_transform * actor_local_before_split
		handoff_world_error = player.global_position.distance_to(expected_handoff_world)
		_check(handoff_world_error < 0.0001, "actor source-to-successor handoff is world-continuous at split commit")
	await _advance_frames(POST_SPLIT_FRAMES)

	var active_spaces: Array[LocalMatterSpace] = p1.call("get_active_spaces") as Array[LocalMatterSpace]
	_check(source.is_retired(), "integrated source retires after split")
	_check(active_spaces.size() == 2 and not active_spaces.has(source), "consumer registry exposes two live successors and no retired source")
	_check(player.grounded and player.support_space != null and active_spaces.has(player.support_space), "actor relation succeeds onto one live successor")
	var successor: LocalMatterSpace = player.support_space
	_check(successor != null and successor.get_provider_kind() == LocalMatterSpace.ProviderKind.DYNAMIC, "actor-owned successor remains dynamic after succession")
	if successor == null:
		p1.free()
		_finish()
		return
	_check(player.support_body == successor.get_active_provider(), "actor support body follows successor provider")
	_check(camera_rig.context_target == successor.get_active_provider(), "camera follows actor-owned successor")
	_check(p1.call("get_space") == successor, "P1 focus follows actor-owned successor")

	# 5. Freeze the actor-owned successor at its current solver pose. This closes
	# the loop back to a static representation without reconstructing old state.
	_check(bool(p1.call("toggle_focused_space_for_test")), "Owner-facing toggle queues freeze for focused successor")
	await successor.provider_transition_committed
	var freeze_report: Dictionary = successor.get_last_transition_report()
	var freeze_previous: Transform3D = freeze_report["previous_transform"]
	var freeze_current: Transform3D = freeze_report["current_transform"]
	_check(freeze_previous.origin.distance_to(freeze_current.origin) < 0.0001, "freeze preserves successor world position at transition boundary")
	_check(_basis_error(freeze_previous.basis, freeze_current.basis) < 0.0001, "freeze preserves successor world orientation at transition boundary")
	await _advance_frames(POST_FREEZE_FRAMES)
	_check(successor.get_provider_kind() == LocalMatterSpace.ProviderKind.STATIC, "actor-owned successor finishes as static representation")
	_check(player.grounded and player.support_space == successor, "actor remains logically supported after successor freeze")
	_check(player.support_body == successor.get_active_provider(), "actor refreshes support to new static provider")
	_check(camera_rig.context_target == successor.get_active_provider(), "camera context follows frozen successor provider")

	var final_provider: Node3D = successor.get_active_provider()
	var final_anchor_error: float = final_provider.to_global(player.support_local_center).distance_to(player.global_position)
	_check(final_anchor_error < 0.001, "final actor/support anchor remains coherent")

	print(
		"P1_INTEGRATED_CAUSAL_LOOP_METRIC logical_space_id=%d rebase_shift=%s mapped_edge=%s linear_rebase_error=%.8f angular_rebase_error=%.8f handoff_world_error=%.8f successors=%d ride_anchor_error=%.8f final_anchor_error=%.8f"
		% [
			logical_space_id,
			str(local_shift),
			str(mapped_edge_cell),
			linear_rebase_error,
			angular_rebase_error,
			handoff_world_error,
			active_spaces.size(),
			ride_anchor_error,
			final_anchor_error,
		]
	)

	p1.free()
	_finish()


func _basis_error(a: Basis, b: Basis) -> float:
	return maxf(
		a.x.distance_to(b.x),
		maxf(a.y.distance_to(b.y), a.z.distance_to(b.z))
	)


func _advance_frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame
		await process_frame


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _finish() -> void:
	if _failures.is_empty():
		print("P1_INTEGRATED_CAUSAL_LOOP_PASS: one logical Matter Space composes zero-launch release, finite motion, actor ride, moving storage expansion+placement, topology succession, actor/camera handoff and successor freeze.")
		quit(0)
		return
	for failure in _failures:
		push_error("P1_INTEGRATED_CAUSAL_LOOP_FAIL: " + failure)
	quit(1)
