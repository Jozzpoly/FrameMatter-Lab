extends SceneTree

const ACQUIRE_FRAMES := 8

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://p1/main.tscn") as PackedScene
	_check(packed != null, "canonical P1 scene loads for invalidation challenger")
	if packed == null:
		_finish(null)
		return

	var root := packed.instantiate()
	get_root().add_child(root)
	await _advance_frames(ACQUIRE_FRAMES)

	var source := root.call("get_space") as LocalMatterSpace
	var interactor := root.call("get_interactor") as P1MatterInteractor
	var registry := root.get_node_or_null("P1SpaceRegistry") as P1SpaceRegistry
	var grid := root.get_node_or_null("P1MatterSurfaceGrid") as P1MatterSurfaceGrid
	var state := root.get_node_or_null("P1MatterStatePresentation") as P1MatterStatePresentation
	var spaces := root.get_node_or_null("Spaces")
	_check(
		source != null and interactor != null and registry != null and grid != null and state != null and spaces != null,
		"invalidation challenger resolves production presentation roles"
	)
	if source == null or interactor == null or registry == null or grid == null or state == null or spaces == null:
		_finish(root)
		return

	var source_grid := grid.get_overlay_for_space(source)
	var source_state := state.get_state_overlay_for_space(source)
	var source_focus := state.get_focus_overlay_for_space(source)
	_check(source_grid != null and source_state != null and source_focus != null, "source starts with complete presentation")
	var source_grid_id := source_grid.get_instance_id()
	var source_state_id := source_state.get_instance_id()
	var source_focus_id := source_focus.get_instance_id()

	var other := _make_one_cell_space(source, Vector3(40.0, 0.0, 0.0))
	spaces.add_child(other)
	var registration_started := Time.get_ticks_usec()
	registry.register_space(other)
	var registration_usec := Time.get_ticks_usec() - registration_started

	_check(grid.get_overlay_for_space(other) != null, "new unrelated Space receives a surface grid")
	_check(state.get_state_overlay_for_space(other) != null, "new unrelated Space receives a state contour")
	_check(state.get_focus_overlay_for_space(other) == null, "unfocused unrelated Space receives no focus crown")
	_check(grid.get_overlay_for_space(source).get_instance_id() == source_grid_id, "registering unrelated Space preserves existing source grid object")
	_check(state.get_state_overlay_for_space(source).get_instance_id() == source_state_id, "registering unrelated Space preserves existing source state contour object")
	_check(state.get_focus_overlay_for_space(source).get_instance_id() == source_focus_id, "registering unrelated Space preserves existing source focus crown object")

	var edit_cell := Vector3i(3, 2, 4)
	_check(source.volume.get_cell(edit_cell) != CellVolume.EMPTY, "real edit fixture is occupied")
	_check(interactor.apply_edit_to_cell(source, edit_cell, P1MatterInteractor.EditMode.REMOVE), "real Matter edit succeeds")
	var edited_grid := grid.get_overlay_for_space(source)
	var edited_state := state.get_state_overlay_for_space(source)
	var edited_focus := state.get_focus_overlay_for_space(source)
	_check(edited_grid != null and edited_grid.get_instance_id() != source_grid_id, "real Matter revision rebuilds source grid")
	_check(edited_state != null and edited_state.get_instance_id() != source_state_id, "real Matter revision rebuilds source state contour")
	_check(edited_focus != null and edited_focus.get_instance_id() != source_focus_id, "real Matter revision rebuilds source focus crown")

	var edited_state_id := edited_state.get_instance_id()
	var other_state := state.get_state_overlay_for_space(other)
	var other_state_id := other_state.get_instance_id()
	var focus_started := Time.get_ticks_usec()
	state.set_focus_space(other)
	var focus_switch_usec := Time.get_ticks_usec() - focus_started
	_check(state.get_state_overlay_for_space(source).get_instance_id() == edited_state_id, "focus change does not rebuild previous state contour")
	_check(state.get_state_overlay_for_space(other).get_instance_id() == other_state_id, "focus change does not rebuild new state contour")
	_check(state.get_focus_overlay_for_space(source) == null, "previous focus crown is removed")
	_check(state.get_focus_overlay_for_space(other) != null, "new focus crown is created")

	state.set_focus_space(source)
	_check(state.get_state_overlay_for_space(source).get_instance_id() == edited_state_id, "restoring focus still preserves source state contour")
	_check(state.get_state_overlay_for_space(other).get_instance_id() == other_state_id, "restoring focus still preserves sibling state contour")

	print(
		"P1_PRESENTATION_INVALIDATION_METRIC registration_us=%d focus_switch_us=%d source_revision=%d active_spaces=%d"
		% [registration_usec, focus_switch_usec, source.volume.revision, registry.get_active_count()]
	)
	_finish(root)


func _make_one_cell_space(source: LocalMatterSpace, origin: Vector3) -> LocalMatterSpace:
	var volume := CellVolume.new(Vector3i.ONE)
	volume.set_cell(Vector3i.ZERO, CellVolume.SOLID)
	var lineage := MatterLineageMap.new(Vector3i.ONE)
	var token := source.allocate_lineage_token()
	lineage.set_lineage(Vector3i.ZERO, token)

	var space := LocalMatterSpace.new()
	space.name = "InvalidationSibling"
	space.lineage_issuer = source.lineage_issuer
	space.mass_per_cell = source.mass_per_cell
	space.collision_mode = source.collision_mode
	space.initialize_static(volume, lineage, Transform3D(Basis.IDENTITY, origin))
	return space


func _advance_frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame
		await process_frame


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _finish(root: Node) -> void:
	if root != null and is_instance_valid(root):
		root.queue_free()
	if _failures.is_empty():
		print("P1_PRESENTATION_INVALIDATION_PASS: unrelated Space publication preserves valid presentation objects, real Matter revisions rebuild them, and focus changes invalidate only the focus crown.")
		quit(0)
		return
	for failure in _failures:
		push_error("P1_PRESENTATION_INVALIDATION_FAIL: " + failure)
	quit(1)
