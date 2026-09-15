extends SceneTree

const ACQUIRE_FRAMES := 14
const POST_TRANSITION_FRAMES := 8
const POST_SPLIT_FRAMES := 10

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://p1/main.tscn") as PackedScene
	_check(packed != null, "P1 interactive scene loads for topology consumer probe")
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
	_check(source != null and player != null and camera_rig != null and interactor != null, "P1 exposes composed consumer roles")
	if source == null or player == null or camera_rig == null or interactor == null:
		p1.free()
		_finish()
		return

	_check(player.grounded and player.support_space == source, "actor starts supported by source Space")
	_check(bool(p1.call("activate_dynamic_probe_for_test")), "topology consumer activates source Space dynamically")
	await source.provider_transition_committed
	await _advance_frames(POST_TRANSITION_FRAMES)
	_check(source.get_active_provider() is ConstructBody, "source owns dynamic provider before destructive edit")
	_check(player.grounded and player.support_space == source, "actor remains on source before cut")

	var source_space_id := source.get_instance_id()
	var source_provider_id := source.get_active_provider().get_instance_id()
	var actor_world_before_cut := player.global_position
	var removed := 0
	# The authored deck spans x=[2,13], z=[2,13]. Removing x=6 across the
	# complete z span leaves no decoration bridge and separates left/right Matter.
	for z in range(2, 14):
		var cell := Vector3i(6, 0, z)
		var changed := interactor.apply_edit_to_cell(source, cell, P1MatterInteractor.EditMode.REMOVE)
		_check(changed, "topology cut removes source deck cell %s" % str(cell))
		if changed:
			removed += 1
		if z < 13:
			_check(not source.is_topology_split_pending(), "partial cut remains one connected dynamic Space")

	_check(removed == 12, "full causal cut removes all twelve separating cells")
	_check(source.is_topology_split_pending(), "final destructive edit queues connected-component split")
	await source.topology_split_committed
	await _advance_frames(POST_SPLIT_FRAMES)

	var active_spaces := p1.call("get_active_spaces") as Array[LocalMatterSpace]
	_check(source.is_retired(), "interactive source retires after topology split")
	_check(source.get_active_provider() == null, "retired interactive source retains no provider")
	_check(active_spaces.size() == 2, "interactive consumer now tracks two live successor Spaces")
	_check(not active_spaces.has(source), "retired source is not presented as active world state")

	var provider_ids: Dictionary = {}
	for successor in active_spaces:
		_check(successor != null and not successor.is_retired(), "each consumer successor is live")
		if successor == null:
			continue
		var provider := successor.get_active_provider()
		_check(provider is ConstructBody, "each detached successor has an independent dynamic provider")
		if provider != null:
			provider_ids[provider.get_instance_id()] = true
	_check(provider_ids.size() == 2, "detached Matter no longer shares one rigid provider")

	_check(player.grounded, "actor remains grounded through consumer topology succession")
	_check(player.support_space != null and active_spaces.has(player.support_space), "actor support maps onto one live successor")
	_check(player.support_space != source, "actor no longer references retired source")
	if player.support_space != null:
		_check(player.support_body == player.support_space.get_active_provider(), "actor support body matches successor provider")
		_check(camera_rig.context_target == player.support_space.get_active_provider(), "camera context follows actor-owned successor")

	var actor_world_jump := player.global_position.distance_to(actor_world_before_cut)
	_check(actor_world_jump < 1.0, "topology consumer does not teleport actor materially during cut/succession window")
	print(
		"P1_LIVE_TOPOLOGY_METRIC source_space_id=%d source_provider_id=%d removed=%d successors=%d actor_world_delta=%.6f" % [
			source_space_id,
			source_provider_id,
			removed,
			active_spaces.size(),
			actor_world_jump,
		]
	)

	p1.free()
	_finish()


func _advance_frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame
		await process_frame


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _finish() -> void:
	if _failures.is_empty():
		print("P1_LIVE_TOPOLOGY_PASS: interactive destructive edits produce real successor Spaces and actor/camera context survives source retirement.")
		quit(0)
		return
	for failure in _failures:
		push_error("P1_LIVE_TOPOLOGY_FAIL: " + failure)
	quit(1)
