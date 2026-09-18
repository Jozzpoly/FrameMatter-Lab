extends SceneTree

const ACQUIRE_FRAMES := 20
const POST_EDIT_FRAMES := 3
const WATCHDOG_SECONDS := 12.0

var _failures: Array[String] = []
var _finished := false


func _init() -> void:
	call_deferred("_run")
	call_deferred("_watchdog")


func _watchdog() -> void:
	await create_timer(WATCHDOG_SECONDS).timeout
	if _finished:
		return
	push_error("P1_RECOVERY_OWNER_PRESSURE_TIMEOUT")
	quit(1)


func _run() -> void:
	var packed := load("res://p1/recovery_main.tscn") as PackedScene
	_check(packed != null, "recovery scene loads")
	if packed == null:
		_finish()
		return

	var root := packed.instantiate()
	get_root().add_child(root)
	await process_frame

	var registry := root.get_node_or_null("P1SpaceRegistry") as P1SpaceRegistry
	var player := root.get_node_or_null("P1Player") as SpaceQueryCharacter
	var interactor := root.get_node_or_null("P1MatterInteractor") as P1MatterInteractor
	var direct_edit := root.get_node_or_null("P1RecoveryDirectEdit") as P1RecoveryDirectEdit
	var world := root.call("get_recovery_world_space") as LocalMatterSpace
	var old_demo := root.call("get_recovery_demo_space") as LocalMatterSpace
	var bridge_cell: Vector3i = root.call("get_recovery_causal_bridge_cell_for_test") if root.has_method("get_recovery_causal_bridge_cell_for_test") else Vector3i(-1, -1, -1)

	_check(root.get_node_or_null("WorldReference") == null, "recovery surface has no normal-looking non-Matter terrain")
	_check(registry != null and registry.get_active_count() == 1, "recovery starts as one ordinary Matter world rather than world plus a special mover")
	_check(world is W0AuthorityPartitionSpace and world.get_provider_kind() == LocalMatterSpace.ProviderKind.STATIC, "ordinary terrain is the canonical static W0 authority")
	_check(old_demo == null, "recovery has no pre-authored moving demo Space")
	_check(direct_edit != null, "recovery surface owns direct LMB/RMB edit controls")
	_check(interactor != null and not interactor.is_processing_unhandled_input(), "old modal interactor input is disabled on recovery surface")
	_check(world != null and world.volume.in_bounds(bridge_cell) and world.volume.get_cell(bridge_cell) != CellVolume.EMPTY, "causal bridge is ordinary editable world Matter")

	await _advance_frames(ACQUIRE_FRAMES)
	_check(player != null and player.grounded, "player acquires real Matter support")
	_check(player != null and player.support_space == world, "player starts on ordinary world Matter")

	# Pressure a mundane edit that must NOT create a new frame. Causality is not
	# 'every REMOVE makes physics'; only an actual topology disconnect deserves a
	# new owner. W0D separately proves the causal bridge path.
	var edit_cell := Vector3i(2, 0, 2)
	var before_token := world.lineage.get_lineage(edit_cell) if world != null else MatterLineageMap.NONE
	_check(before_token != MatterLineageMap.NONE, "world edit probe begins as authored Matter")
	_check(interactor.apply_edit_to_cell(world, edit_cell, P1MatterInteractor.EditMode.REMOVE), "ordinary world Matter can be removed through shared interaction authority")
	_check(world.volume.get_cell(edit_cell) == CellVolume.EMPTY, "world remove changes authoritative Matter")
	_check(not (world as W0AuthorityPartitionSpace).is_authority_partition_pending(), "non-disconnecting remove does not invent a detached Space")
	_check(registry.get_active_count() == 1, "non-disconnecting remove preserves one-world ownership")
	_check(interactor.apply_edit_to_cell(world, edit_cell, P1MatterInteractor.EditMode.PLACE), "ordinary world Matter can be rebuilt through shared interaction authority")
	var rebuilt_token := world.lineage.get_lineage(edit_cell)
	_check(rebuilt_token != MatterLineageMap.NONE and rebuilt_token != before_token, "world rebuild receives fresh logical Matter lineage")

	await _advance_frames(POST_EDIT_FRAMES)
	_check(registry.get_active_count() == 1, "ordinary reshape remains one Space after physics settles")
	_check(world.get_provider_kind() == LocalMatterSpace.ProviderKind.STATIC, "canonical world remains static after ordinary reshape")
	_check(world.volume.get_cell(bridge_cell) != CellVolume.EMPTY, "unrelated ordinary edits do not disturb the causal bridge")

	print(
		"P1_RECOVERY_OWNER_PRESSURE_METRIC active_spaces=%d world_cells=%d rebuilt_lineage=%d bridge=%s"
		% [registry.get_active_count(), world.volume.count_solid(), rebuilt_token, str(bridge_cell)]
	)

	root.free()
	_finish()


func _advance_frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame
		await process_frame


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _finish() -> void:
	_finished = true
	if _failures.is_empty():
		print("P1_RECOVERY_OWNER_PRESSURE_PASS: canonical recovery starts as one editable causal Matter world; ordinary reshaping stays one Space while real topology detachment is reserved for the W0D causal path.")
		quit(0)
		return
	for failure in _failures:
		push_error("P1_RECOVERY_OWNER_PRESSURE_FAIL: " + failure)
	quit(1)
