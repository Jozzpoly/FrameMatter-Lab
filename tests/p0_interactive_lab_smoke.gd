extends SceneTree

const STATIC_EDIT_CELL := Vector3i(0, 0, 0)
const DYNAMIC_EDIT_CELL := Vector3i(7, 0, 7)
const GROUND_ACQUIRE_FRAMES := 8
const POST_TRANSITION_FRAMES := 3
const RIDE_FRAMES := 18
const WALK_FRAMES := 18
const POST_EDIT_FRAMES := 8

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://lab/main.tscn") as PackedScene
	_check(packed != null, "P0 LAB scene loads")
	if packed == null:
		_finish()
		return

	var lab := packed.instantiate()
	get_root().add_child(lab)
	await process_frame

	var space := lab.get_node_or_null("InteractiveLocalMatterSpace") as LocalMatterSpace
	var actor := lab.get_node_or_null("InteractiveActor") as FrameProbeCharacter
	_check(space != null, "P0 LAB exposes the shared LocalMatterSpace consumer")
	_check(actor != null, "P0 LAB exposes the embodied FrameProbeCharacter consumer")
	if space == null or actor == null:
		lab.free()
		_finish()
		return

	var logical_space_id := space.get_instance_id()
	var volume := space.volume
	var lineage := space.lineage
	_check(volume != null and lineage != null, "P0 LAB retains one authoritative Matter + lineage pair")
	if volume == null or lineage == null:
		lab.free()
		_finish()
		return

	await _advance_frames(GROUND_ACQUIRE_FRAMES)
	_check(actor.grounded, "P0 actor acquires ordinary support on the static Matter provider")
	_check(actor.support_space == space, "P0 actor support is the logical LocalMatterSpace")
	_check(actor.support_body == space.get_active_provider(), "P0 actor support resolves to the current static provider")
	var initial_support_local: Vector3 = actor.support_local_center

	var static_provider_id := space.get_active_provider().get_instance_id()
	var static_old_token := lineage.get_lineage(STATIC_EDIT_CELL)
	_check(static_old_token != MatterLineageMap.NONE, "P0 static edit target begins with lineage")
	_check(bool(lab.call("_remove_cell", STATIC_EDIT_CELL, "P0 static smoke")), "P0 direct consumer removal succeeds while static")
	_check(volume.get_cell(STATIC_EDIT_CELL) == CellVolume.EMPTY, "P0 static removal changes authoritative occupancy")
	_check(lineage.get_lineage(STATIC_EDIT_CELL) == MatterLineageMap.NONE, "P0 static removal retires lineage")
	_check(space.get_active_provider().get_instance_id() == static_provider_id, "P0 static edit rebuilds without replacing provider identity")
	_check(bool(lab.call("_place_cell", STATIC_EDIT_CELL, "P0 static smoke")), "P0 direct consumer placement succeeds while static")
	var static_new_token := lineage.get_lineage(STATIC_EDIT_CELL)
	_check(static_new_token != MatterLineageMap.NONE and static_new_token != static_old_token, "P0 static recreation receives fresh lineage")

	lab.call("_activate_dynamic")
	_check(space.is_transition_pending(), "P0 activation queues the shared static→dynamic provider transition")
	await space.provider_transition_committed
	await _advance_frames(POST_TRANSITION_FRAMES)

	var dynamic_provider := space.get_active_provider()
	_check(dynamic_provider is ConstructBody, "P0 activation installs the shared dynamic provider")
	_check(space.get_instance_id() == logical_space_id, "P0 activation preserves logical Space identity")
	_check(actor.grounded, "P0 actor remains grounded after provider replacement")
	_check(actor.support_space == space, "P0 actor retains the same logical support Space after activation")
	_check(actor.support_body == dynamic_provider, "P0 actor follows the current dynamic provider without manual test handoff")

	var ride_floor_loss := 0
	var max_stationary_local_drift := 0.0
	for _frame in range(RIDE_FRAMES):
		await physics_frame
		await process_frame
		if not actor.grounded:
			ride_floor_loss += 1
		max_stationary_local_drift = max(max_stationary_local_drift, actor.support_local_center.distance_to(initial_support_local))
	_check(ride_floor_loss == 0, "P0 actor rides the freely moving Space without floor loss")
	_check(max_stationary_local_drift < 0.05, "P0 stationary rider remains local to the moving Space")

	var walk_start_local: Vector3 = actor.support_local_center
	_send_physical_key(KEY_W, true)
	var walk_floor_loss := 0
	for _frame in range(WALK_FRAMES):
		await physics_frame
		await process_frame
		if not actor.grounded:
			walk_floor_loss += 1
	_send_physical_key(KEY_W, false)
	await _advance_frames(2)
	var walk_local_delta := actor.support_local_center.distance_to(walk_start_local)
	_check(walk_floor_loss == 0, "P0 actor walks relative to the dynamic support without floor loss")
	_check(walk_local_delta > 0.25, "P0 embodied movement changes actor position within the moving Space")

	var dynamic_old_token := lineage.get_lineage(DYNAMIC_EDIT_CELL)
	_check(dynamic_old_token != MatterLineageMap.NONE, "P0 dynamic edit target begins with lineage")
	var dynamic_provider_id := dynamic_provider.get_instance_id()
	_check(bool(lab.call("_remove_cell", DYNAMIC_EDIT_CELL, "P0 dynamic smoke")), "P0 direct consumer removal succeeds while moving")
	_check(volume.get_cell(DYNAMIC_EDIT_CELL) == CellVolume.EMPTY, "P0 moving removal changes authoritative occupancy")
	_check(lineage.get_lineage(DYNAMIC_EDIT_CELL) == MatterLineageMap.NONE, "P0 moving removal retires lineage")
	_check(space.get_active_provider().get_instance_id() == dynamic_provider_id, "P0 moving edit rebuilds without replacing dynamic provider identity")

	var post_edit_floor_loss := 0
	for _frame in range(POST_EDIT_FRAMES):
		await physics_frame
		await process_frame
		if not actor.grounded:
			post_edit_floor_loss += 1
	_check(post_edit_floor_loss == 0, "P0 actor support survives occupancy editing while the Space is moving")
	_check(actor.support_space == space and actor.support_body == space.get_active_provider(), "P0 moving edit preserves logical/current-provider support coherence")

	_check(bool(lab.call("_place_cell", DYNAMIC_EDIT_CELL, "P0 dynamic smoke")), "P0 direct consumer placement succeeds while moving")
	var dynamic_new_token := lineage.get_lineage(DYNAMIC_EDIT_CELL)
	_check(dynamic_new_token != MatterLineageMap.NONE and dynamic_new_token != dynamic_old_token, "P0 moving recreation receives fresh lineage")

	lab.call("_freeze_to_static")
	_check(space.is_transition_pending(), "P0 freeze queues the shared dynamic→static provider transition")
	await space.provider_transition_committed
	await _advance_frames(POST_TRANSITION_FRAMES)

	var final_provider := space.get_active_provider()
	_check(final_provider is MatterRepresentation, "P0 freeze installs the shared static provider")
	_check(space.get_instance_id() == logical_space_id, "P0 freeze preserves logical Space identity")
	_check(actor.grounded, "P0 actor remains grounded after freeze")
	_check(actor.support_space == space, "P0 actor still references the same logical Space after freeze")
	_check(actor.support_body == final_provider, "P0 actor follows the final static provider")

	var hud := lab.get_node_or_null("HUD/Panel/Label") as Label
	_check(hud != null, "P0 LAB retains visible interaction/lifecycle telemetry")
	if hud != null:
		_check(hud.text.contains("FrameMatter P0 LAB"), "P0 HUD identifies the embodied consumer")
		_check(hud.text.contains("actor grounded=true"), "P0 HUD exposes actor support state")
		_check(hud.text.contains("transitions: 2"), "P0 HUD exposes both provider transitions")

	print(
		"P0_INTERACTIVE_LAB_METRIC logical_space_id=%d static_provider_id=%d dynamic_provider_id=%d final_provider_id=%d ride_floor_loss=%d walk_floor_loss=%d post_edit_floor_loss=%d max_stationary_local_drift=%.8f walk_local_delta=%.8f static_old_token=%d static_new_token=%d dynamic_old_token=%d dynamic_new_token=%d final_cells=%d"
		% [
			logical_space_id,
			static_provider_id,
			dynamic_provider_id,
			final_provider.get_instance_id(),
			ride_floor_loss,
			walk_floor_loss,
			post_edit_floor_loss,
			max_stationary_local_drift,
			walk_local_delta,
			static_old_token,
			static_new_token,
			dynamic_old_token,
			dynamic_new_token,
			volume.count_solid(),
		]
	)

	_send_physical_key(KEY_W, false)
	lab.free()
	_finish()


func _advance_frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame
		await process_frame


func _send_physical_key(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	event.pressed = pressed
	event.echo = false
	Input.parse_input_event(event)


func _finish() -> void:
	if _failures.is_empty():
		print("P0_INTERACTIVE_LAB_SMOKE_PASS: embodied actor support, direct Matter remove/place, static→dynamic ride/walk, moving edit and dynamic→static freeze composed through the shared LocalMatterSpace path.")
		quit(0)
		return
	for failure in _failures:
		push_error("P0_INTERACTIVE_LAB_SMOKE_FAIL: " + failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
