extends SceneTree

const REPEATS := 3
const ANCHOR_CELLS: Array[Vector3i] = [
	Vector3i(1, 0, 1),
	Vector3i(30, 0, 1),
	Vector3i(1, 0, 30),
	Vector3i(30, 0, 30),
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://p1/recovery_main.tscn") as PackedScene
	_check(packed != null, "recovery scene loads for Spark cost scaling probe")
	if packed == null:
		_finish(null)
		return

	var root := packed.instantiate()
	get_root().add_child(root)
	await _advance_frames(4)

	var world := root.call("get_recovery_world_space") as LocalMatterSpace
	var interactor := root.get_node_or_null("P1MatterInteractor") as P1MatterInteractor
	var observer := root.get_node_or_null("P1RecoveryObserver") as P1RecoveryObserver
	var grid := root.get_node_or_null("P1MatterSurfaceGrid") as P1MatterSurfaceGrid
	var state := root.get_node_or_null("P1MatterStatePresentation") as P1MatterStatePresentation
	_check(
		world != null and interactor != null and observer != null and grid != null and state != null,
		"cost probe resolves live recovery roles"
	)
	if world == null or interactor == null or observer == null or grid == null or state == null:
		_finish(root)
		return

	var world_suite := _benchmark_volume(world.volume)

	var compact_one := CellVolume.new(Vector3i.ONE)
	compact_one.set_cell(Vector3i.ZERO, CellVolume.SOLID)
	var padded_one := CellVolume.new(world.volume.size)
	padded_one.set_cell(world.volume.size / 2, CellVolume.SOLID)
	var compact_suite := _benchmark_volume(compact_one)
	var padded_suite := _benchmark_volume(padded_one)

	_check(CellMesher.count_exposed_faces(compact_one) == 6, "compact one-cell fixture has six exposed faces")
	_check(CellMesher.count_exposed_faces(padded_one) == 6, "padded one-cell fixture has identical visible geometry")
	_check(CellCollisionBoxer.build_boxes(compact_one).size() == 1, "compact one-cell fixture has one collision box")
	_check(CellCollisionBoxer.build_boxes(padded_one).size() == 1, "padded one-cell fixture has one collision box")

	var anchor_tokens: Dictionary = {}
	for cell in ANCHOR_CELLS:
		var token: int = world.lineage.get_lineage(cell)
		_check(token != MatterLineageMap.NONE, "canonical benchmark anchor lineage exists at %s" % str(cell))
		if token != MatterLineageMap.NONE:
			anchor_tokens[token] = true
	var policy_usec := _measure(func() -> void:
		W0AnchoredDetachmentPolicy.evaluate(world.volume, world.lineage, anchor_tokens)
	)

	var enabled_cell := Vector3i(3, 4, 4)
	var disabled_cell := Vector3i(4, 4, 4)
	_check(world.volume.get_cell(enabled_cell) != CellVolume.EMPTY, "enabled-presentation edit fixture is occupied")
	_check(world.volume.get_cell(disabled_cell) != CellVolume.EMPTY, "disabled-presentation edit fixture is occupied")
	_check(
		interactor.apply_edit_to_cell(world, enabled_cell, P1MatterInteractor.EditMode.REMOVE),
		"enabled-presentation edit succeeds"
	)
	var enabled_edit := observer.get_last_edit_timing_for_test()

	grid.set_enabled(false)
	state.set_enabled(false)
	_check(
		interactor.apply_edit_to_cell(world, disabled_cell, P1MatterInteractor.EditMode.REMOVE),
		"disabled-presentation edit succeeds"
	)
	var disabled_edit := observer.get_last_edit_timing_for_test()

	_check(int(enabled_edit.get("total_usec", -1)) >= 0, "enabled-presentation edit timing is captured")
	_check(int(disabled_edit.get("total_usec", -1)) >= 0, "disabled-presentation edit timing is captured")

	print(
		"P1_SPARK_COST_SCALING_METRIC world_slots=%d world_solids=%d world_mesh_us=%d world_boxes_us=%d world_grid_us=%d world_state_us=%d world_focus_us=%d world_topology_us=%d world_policy_us=%d compact_slots=%d compact_mesh_us=%d compact_boxes_us=%d compact_grid_us=%d compact_state_us=%d compact_focus_us=%d compact_topology_us=%d padded_slots=%d padded_mesh_us=%d padded_boxes_us=%d padded_grid_us=%d padded_state_us=%d padded_focus_us=%d padded_topology_us=%d enabled_edit_total_us=%d enabled_edit_mutation_us=%d enabled_edit_listeners_us=%d disabled_edit_total_us=%d disabled_edit_mutation_us=%d disabled_edit_listeners_us=%d"
		% [
			_cell_slots(world.volume),
			world.volume.count_solid(),
			world_suite["mesh_usec"],
			world_suite["boxes_usec"],
			world_suite["grid_usec"],
			world_suite["state_usec"],
			world_suite["focus_usec"],
			world_suite["topology_usec"],
			policy_usec,
			_cell_slots(compact_one),
			compact_suite["mesh_usec"],
			compact_suite["boxes_usec"],
			compact_suite["grid_usec"],
			compact_suite["state_usec"],
			compact_suite["focus_usec"],
			compact_suite["topology_usec"],
			_cell_slots(padded_one),
			padded_suite["mesh_usec"],
			padded_suite["boxes_usec"],
			padded_suite["grid_usec"],
			padded_suite["state_usec"],
			padded_suite["focus_usec"],
			padded_suite["topology_usec"],
			int(enabled_edit.get("total_usec", -1)),
			int(enabled_edit.get("mutation_usec", -1)),
			int(enabled_edit.get("listeners_usec", -1)),
			int(disabled_edit.get("total_usec", -1)),
			int(disabled_edit.get("mutation_usec", -1)),
			int(disabled_edit.get("listeners_usec", -1)),
		]
	)

	_finish(root)


func _benchmark_volume(volume: CellVolume) -> Dictionary:
	return {
		"mesh_usec": _measure(func() -> void: CellMesher.build_mesh(volume)),
		"boxes_usec": _measure(func() -> void: CellCollisionBoxer.build_boxes(volume, CellCollisionBoxer.Mode.MERGED_CUBOIDS)),
		"grid_usec": _measure(func() -> void: P1MatterSurfaceGrid.build_exposed_surface_grid(volume)),
		"state_usec": _measure(func() -> void: P1MatterStatePresentation.build_side_surface_contour(volume)),
		"focus_usec": _measure(func() -> void: P1MatterStatePresentation.build_top_surface_perimeter(volume)),
		"topology_usec": _measure(func() -> void: MatterTopology.extract_connected_components(volume)),
	}


func _measure(callback: Callable) -> int:
	var values: Array[int] = []
	for _iteration in range(REPEATS):
		var started_usec := Time.get_ticks_usec()
		callback.call()
		values.append(Time.get_ticks_usec() - started_usec)
	values.sort()
	return values[values.size() / 2]


func _cell_slots(volume: CellVolume) -> int:
	return volume.size.x * volume.size.y * volume.size.z


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
		print("P1_SPARK_COST_SCALING_PASS: diagnostic challenger separates storage-size, derived-representation, topology/policy and presentation contributions without imposing absolute timing thresholds.")
		quit(0)
		return
	for failure in _failures:
		push_error("P1_SPARK_COST_SCALING_FAIL: " + failure)
	quit(1)
