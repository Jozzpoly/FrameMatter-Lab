extends SceneTree

const ACQUIRE_FRAMES := 16
const MOTION_FRAMES := 20
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
	var moving := root.call("get_recovery_demo_space") as LocalMatterSpace

	_check(root.get_node_or_null("WorldReference") == null, "recovery surface has no normal-looking non-Matter terrain")
	_check(registry != null and registry.get_active_count() == 2, "recovery starts with world Matter plus a second live Space")
	_check(world != null and world.get_provider_kind() == LocalMatterSpace.ProviderKind.STATIC, "ordinary terrain is a static LocalMatterSpace")
	_check(moving != null and moving.get_provider_kind() == LocalMatterSpace.ProviderKind.DYNAMIC, "moving Matter is alive from startup")
	_check(direct_edit != null, "recovery surface owns direct LMB/RMB edit controls")
	_check(interactor != null and not interactor.is_processing_unhandled_input(), "old modal interactor input is disabled on recovery surface")

	await _advance_frames(ACQUIRE_FRAMES)
	_check(player != null and player.grounded, "player acquires real Matter support")
	_check(player != null and player.support_space == world, "player starts on ordinary world Matter")

	var edit_cell := Vector3i(2, 0, 2)
	var before_token := world.lineage.get_lineage(edit_cell) if world != null else MatterLineageMap.NONE
	_check(before_token != MatterLineageMap.NONE, "world edit probe begins as authored Matter")
	_check(interactor.apply_edit_to_cell(world, edit_cell, P1MatterInteractor.EditMode.REMOVE), "ordinary world Matter can be removed through shared interaction authority")
	_check(world.volume.get_cell(edit_cell) == CellVolume.EMPTY, "world remove changes authoritative Matter")
	_check(interactor.apply_edit_to_cell(world, edit_cell, P1MatterInteractor.EditMode.PLACE), "ordinary world Matter can be rebuilt through shared interaction authority")
	var rebuilt_token := world.lineage.get_lineage(edit_cell)
	_check(rebuilt_token != MatterLineageMap.NONE and rebuilt_token != before_token, "world rebuild receives fresh logical Matter lineage")

	var moving_provider := moving.get_active_provider()
	var moving_start := moving_provider.global_position
	await _advance_frames(MOTION_FRAMES)
	var moving_delta := moving_provider.global_position.distance_to(moving_start)
	_check(moving_delta > 0.02, "second Matter Space visibly translates without Owner setup ceremony")
	_check(absf((moving_provider as ConstructBody).angular_velocity.y) > 0.01, "second Matter Space also carries live yaw motion")

	print(
		"P1_RECOVERY_OWNER_PRESSURE_METRIC active_spaces=%d world_cells=%d moving_delta=%.6f rebuilt_lineage=%d"
		% [registry.get_active_count(), world.volume.count_solid(), moving_delta, rebuilt_token]
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
		print("P1_RECOVERY_OWNER_PRESSURE_PASS: canonical recovery starts on editable world Matter, exposes direct sandbox editing and contains live moving Matter without reverting to a fake reference floor.")
		quit(0)
		return
	for failure in _failures:
		push_error("P1_RECOVERY_OWNER_PRESSURE_FAIL: " + failure)
	quit(1)
