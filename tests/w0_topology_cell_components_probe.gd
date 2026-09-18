extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var fixtures: Array[Dictionary] = [
		{"name": "empty", "volume": CellVolume.new(Vector3i(4, 3, 4))},
		{"name": "connected", "volume": _connected_fixture()},
		{"name": "split", "volume": _split_fixture()},
		{"name": "bridged", "volume": _bridged_fixture()},
		{"name": "pattern", "volume": _pattern_fixture()},
	]

	for fixture in fixtures:
		var name: String = fixture["name"]
		var volume := fixture["volume"] as CellVolume
		var legacy := _legacy_signatures(volume)
		var cell_components := _cell_signatures(volume)
		_check(
			legacy == cell_components,
			"%s cell-component challenger preserves legacy connected membership" % name
		)
		var cell_count := 0
		for component_variant in MatterTopology.extract_connected_cell_components(volume):
			var component: Array = component_variant
			cell_count += component.size()
			for cell_variant in component:
				var cell: Vector3i = cell_variant
				_check(volume.get_cell(cell) != CellVolume.EMPTY, "%s challenger never emits empty cells" % name)
		_check(cell_count == volume.count_solid(), "%s challenger conserves occupied-cell cardinality" % name)

	_finish()


func _connected_fixture() -> CellVolume:
	var volume := CellVolume.new(Vector3i(6, 3, 6))
	volume.fill_box(Vector3i(1, 0, 1), Vector3i(5, 1, 3), CellVolume.SOLID)
	volume.fill_box(Vector3i(3, 1, 2), Vector3i(5, 3, 4), CellVolume.SOLID)
	return volume


func _split_fixture() -> CellVolume:
	var volume := CellVolume.new(Vector3i(8, 3, 5))
	volume.fill_box(Vector3i(0, 0, 0), Vector3i(3, 2, 2), CellVolume.SOLID)
	volume.fill_box(Vector3i(5, 0, 3), Vector3i(8, 1, 5), CellVolume.SOLID)
	volume.set_cell(Vector3i(4, 2, 0), CellVolume.SOLID)
	return volume


func _bridged_fixture() -> CellVolume:
	var volume := CellVolume.new(Vector3i(8, 2, 3))
	volume.fill_box(Vector3i(0, 0, 0), Vector3i(3, 1, 3), CellVolume.SOLID)
	volume.fill_box(Vector3i(5, 0, 0), Vector3i(8, 1, 3), CellVolume.SOLID)
	volume.fill_box(Vector3i(3, 0, 1), Vector3i(6, 1, 2), CellVolume.SOLID)
	return volume


func _pattern_fixture() -> CellVolume:
	var volume := CellVolume.new(Vector3i(9, 4, 9))
	for z in range(volume.size.z):
		for y in range(volume.size.y):
			for x in range(volume.size.x):
				if (x * 17 + y * 7 + z * 13) % 11 < 3:
					volume.set_cell(Vector3i(x, y, z), CellVolume.SOLID)
	return volume


func _legacy_signatures(volume: CellVolume) -> Array[String]:
	var signatures: Array[String] = []
	for component in MatterTopology.extract_connected_components(volume):
		signatures.append(_signature(_occupied_cells(component)))
	signatures.sort()
	return signatures


func _cell_signatures(volume: CellVolume) -> Array[String]:
	var signatures: Array[String] = []
	for component_variant in MatterTopology.extract_connected_cell_components(volume):
		var component: Array = component_variant
		var cells: Array[Vector3i] = []
		for cell_variant in component:
			cells.append(cell_variant)
		signatures.append(_signature(cells))
	signatures.sort()
	return signatures


func _signature(cells: Array[Vector3i]) -> String:
	var parts: Array[String] = []
	for cell in cells:
		parts.append("%d,%d,%d" % [cell.x, cell.y, cell.z])
	parts.sort()
	return "|".join(parts)


func _occupied_cells(volume: CellVolume) -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	for z in range(volume.size.z):
		for y in range(volume.size.y):
			for x in range(volume.size.x):
				var cell := Vector3i(x, y, z)
				if volume.get_cell(cell) != CellVolume.EMPTY:
					cells.append(cell)
	return cells


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _finish() -> void:
	if _failures.is_empty():
		print("W0_TOPOLOGY_CELL_COMPONENTS_PASS: lightweight cell-list components preserve legacy connectivity membership and occupied-cell cardinality across deterministic adversarial fixtures.")
		quit(0)
		return
	for failure in _failures:
		push_error("W0_TOPOLOGY_CELL_COMPONENTS_FAIL: " + failure)
	quit(1)
