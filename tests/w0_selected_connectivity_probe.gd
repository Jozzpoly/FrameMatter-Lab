extends SceneTree

const VOLUME_SIZE := Vector3i(32, 8, 32)
const REPEATS := 5

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var cases: Array[Dictionary] = [
		{"name": "single", "cells": [Vector3i(16, 4, 16)]},
		{"name": "line", "cells": _line_cells(4, 27, 3, 14)},
		{"name": "elbow", "cells": _elbow_cells()},
		{"name": "disconnected", "cells": [Vector3i(2, 2, 2), Vector3i(28, 2, 28)]},
		{"name": "two_clusters", "cells": _two_cluster_cells()},
	]

	for case in cases:
		var cells: Array[Vector3i] = []
		for cell_variant in case["cells"]:
			cells.append(cell_variant)
		var legacy := _legacy_connected(cells)
		var direct := MatterTopology.cells_form_single_component(cells)
		_check(direct == legacy, "%s direct selected connectivity matches legacy full-volume selection" % str(case["name"]))

	var duplicate := [Vector3i(4, 2, 4), Vector3i(4, 2, 4)]
	_check(not MatterTopology.cells_form_single_component(duplicate), "duplicate selected cells fail closed")
	_check(not MatterTopology.cells_form_single_component([]), "empty selected set fails closed")

	var single: Array[Vector3i] = [Vector3i(16, 4, 16)]
	var line := _line_cells(2, 30, 4, 16)
	var single_legacy_usec := _measure(func() -> void: _legacy_connected(single))
	var single_direct_usec := _measure(func() -> void: MatterTopology.cells_form_single_component(single))
	var line_legacy_usec := _measure(func() -> void: _legacy_connected(line))
	var line_direct_usec := _measure(func() -> void: MatterTopology.cells_form_single_component(line))

	print(
		"W0_SELECTED_CONNECTIVITY_METRIC slots=%d single_cells=%d single_legacy_us=%d single_direct_us=%d line_cells=%d line_legacy_us=%d line_direct_us=%d"
		% [
			VOLUME_SIZE.x * VOLUME_SIZE.y * VOLUME_SIZE.z,
			single.size(),
			single_legacy_usec,
			single_direct_usec,
			line.size(),
			line_legacy_usec,
			line_direct_usec,
		]
	)
	_finish()


func _legacy_connected(cells: Array[Vector3i]) -> bool:
	if cells.is_empty():
		return false
	var selection := CellVolume.new(VOLUME_SIZE)
	for cell in cells:
		if not selection.in_bounds(cell):
			return false
		selection.set_cell(cell, CellVolume.SOLID)
	return MatterTopology.extract_connected_components(selection).size() == 1


func _line_cells(from_x: int, to_x: int, y: int, z: int) -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	for x in range(from_x, to_x):
		cells.append(Vector3i(x, y, z))
	return cells


func _elbow_cells() -> Array[Vector3i]:
	var cells := _line_cells(3, 18, 2, 5)
	for z in range(6, 20):
		cells.append(Vector3i(17, 2, z))
	return cells


func _two_cluster_cells() -> Array[Vector3i]:
	var cells := _line_cells(2, 10, 1, 3)
	cells.append_array(_line_cells(20, 29, 1, 25))
	return cells


func _measure(callback: Callable) -> int:
	var values: Array[int] = []
	for _i in range(REPEATS):
		var started := Time.get_ticks_usec()
		callback.call()
		values.append(Time.get_ticks_usec() - started)
	values.sort()
	return values[values.size() / 2]


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _finish() -> void:
	if _failures.is_empty():
		print("W0_SELECTED_CONNECTIVITY_PASS: selected-cell connectivity is semantically equivalent to legacy full-volume selection for unique inputs and fails closed on duplicate/empty sets.")
		quit(0)
		return
	for failure in _failures:
		push_error("W0_SELECTED_CONNECTIVITY_FAIL: " + failure)
	quit(1)
