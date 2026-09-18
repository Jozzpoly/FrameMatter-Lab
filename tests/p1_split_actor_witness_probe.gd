extends SceneTree

const ACQUIRE_FRAMES := 18
const POST_TRANSITION_FRAMES := 8
const POST_SPLIT_FRAMES := 4
const SUPPORT_CELL := Vector3i(6, 0, 8)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://p1/main.tscn") as PackedScene
	_check(packed != null, "P1 scene loads for destroyed-support split witness probe")
	if packed == null:
		_finish(null)
		return

	var p1 := packed.instantiate()
	get_root().add_child(p1)
	await process_frame

	var source := p1.call("get_space") as LocalMatterSpace
	var player := p1.call("get_player") as SpaceQueryCharacter
	var interactor := p1.call("get_interactor") as P1MatterInteractor
	_check(source != null and player != null and interactor != null, "composed P1 roles are available")
	if source == null or player == null or interactor == null:
		_finish(p1)
		return

	# Put the actor directly over the cell that will be the final bridge in the
	# proven x=6 deck cut. The exact support voxel is deliberately removed last.
	player.call("_detach_from_support", false)
	player.global_position = source.get_active_provider().to_global(Vector3(
		float(SUPPORT_CELL.x) + 0.5,
		1.0 + player.height * 0.5 + 0.04,
		float(SUPPORT_CELL.z) + 0.5
	))
	player.desired_local_velocity = Vector3.ZERO
	player.world_velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	await _advance_frames(ACQUIRE_FRAMES)

	var witness_before := player.get_support_contact_witness()
	_check(player.grounded and player.support_space == source, "actor acquires authored source deck")
	_check(bool(witness_before.get("valid", false)), "actor has exact support witness before dynamic split")
	_check(
		witness_before.get("cell", Vector3i(-999, -999, -999)) == SUPPORT_CELL,
		"fixture places the exact support witness on the final bridge voxel"
	)
	if not bool(witness_before.get("valid", false)) or witness_before.get("cell", Vector3i(-999, -999, -999)) != SUPPORT_CELL:
		_finish(p1)
		return

	_check(bool(p1.call("activate_dynamic_probe_for_test")), "source activates dynamically through normal P1 lifecycle")
	await source.provider_transition_committed
	await _advance_frames(POST_TRANSITION_FRAMES)
	var dynamic_witness := player.get_support_contact_witness()
	_check(bool(dynamic_witness.get("valid", false)), "support witness remains valid on moving source before cut")
	_check(
		dynamic_witness.get("cell", Vector3i(-999, -999, -999)) == SUPPORT_CELL,
		"moving source retains the same supporting Matter cell"
	)

	# Remove every other x=6 deck cell first. The source stays connected through
	# SUPPORT_CELL, so no split can queue until that exact supporting Matter dies.
	for z in range(2, 14):
		if z == SUPPORT_CELL.z:
			continue
		var cut_cell := Vector3i(6, 0, z)
		_check(
			interactor.apply_edit_to_cell(source, cut_cell, P1MatterInteractor.EditMode.REMOVE),
			"partial separating cut removes %s" % str(cut_cell)
		)
		_check(not source.is_topology_split_pending(), "support voxel remains the sole bridge before final edit")

	var transfers_before := player.observed_support_transfers
	var acquisitions_before := player.observed_ground_acquisitions
	_check(
		interactor.apply_edit_to_cell(source, SUPPORT_CELL, P1MatterInteractor.EditMode.REMOVE),
		"final edit destroys the exact supporting Matter voxel"
	)
	_check(source.is_topology_split_pending(), "destroying final support voxel queues the dynamic topology split")
	_check(
		not bool(player.get_support_contact_witness().get("valid", false)),
		"destroyed support Matter invalidates the contact witness before split commit"
	)

	await source.topology_split_committed
	_check(source.is_retired(), "dynamic source retires into successors")
	_check(
		player.observed_support_transfers == transfers_before,
		"split commit does not fabricate an explicit handoff when supporting Matter was destroyed"
	)
	_check(
		player.support_space == source,
		"at the transaction boundary actor is not silently attached to a nearby successor"
	)

	await _advance_frames(POST_SPLIT_FRAMES)
	_check(player.support_space != source, "normal actor simulation leaves retired source after the no-handoff boundary")
	_check(
		player.observed_support_transfers == transfers_before,
		"later fall/reacquisition cannot masquerade as an explicit topology transfer"
	)
	if player.grounded and player.support_space != null:
		_check(
			player.observed_ground_acquisitions > acquisitions_before,
			"any later successor support is a normal contact acquisition, not fabricated lineage continuity"
		)

	_finish(p1)


func _advance_frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame
		await process_frame


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _finish(root: Node) -> void:
	if root != null and is_instance_valid(root):
		root.free()
	if _failures.is_empty():
		print("P1_SPLIT_ACTOR_WITNESS_PASS: dynamic split transfers actor only when its exact supporting Matter survives; deleting that Matter yields zero fabricated successor handoff.")
		quit(0)
		return
	for failure in _failures:
		push_error("P1_SPLIT_ACTOR_WITNESS_FAIL: " + failure)
	quit(1)
