extends SceneTree

const WORKSPACE_SIZE := Vector3i(18, 7, 7)
const CYCLES := 32
const INITIAL_TOKEN := 20001
const OFFSETS: Array[Vector3i] = [
	Vector3i(2, 1, 1),
	Vector3i(4, 0, 2),
	Vector3i(1, 2, 0),
	Vector3i(5, 1, 2),
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var canonical := _make_canonical_volume()
	var canonical_lineage := MatterLineageMap.new(canonical.size)
	var next_token := INITIAL_TOKEN

	for cell in _occupied_cells(canonical):
		canonical_lineage.set_lineage(cell, next_token)
		next_token += 1

	var initial_solid_count := canonical.count_solid()
	var total_recreations := 0
	var total_address_moves := 0
	var max_lineage_mismatches := 0
	var max_material_mismatches := 0
	var max_duplicate_tokens := 0
	var retired_tokens: Dictionary = {}

	for cycle in range(CYCLES):
		var offset: Vector3i = OFFSETS[cycle % OFFSETS.size()]
		var workspace := CellVolume.new(WORKSPACE_SIZE)
		var workspace_lineage := MatterLineageMap.new(WORKSPACE_SIZE)

		for canonical_cell in _occupied_cells(canonical):
			var workspace_cell: Vector3i = canonical_cell + offset
			workspace.set_cell(workspace_cell, canonical.get_cell(canonical_cell))
			workspace_lineage.set_lineage(workspace_cell, canonical_lineage.get_lineage(canonical_cell))
			if workspace_cell != canonical_cell:
				total_address_moves += 1

		# Destroy and recreate exactly one existing Matter cell with identical
		# coordinate and material. Only this cell is allowed to acquire new lineage.
		var occupied := _occupied_cells(canonical)
		var target_canonical: Vector3i = occupied[(cycle * 7 + 3) % occupied.size()]
		var target_workspace: Vector3i = target_canonical + offset
		var target_material: int = workspace.get_cell(target_workspace)
		var retired_token := workspace_lineage.get_lineage(target_workspace)
		_check(retired_token != MatterLineageMap.NONE, "cycle %d recreation target has lineage before destruction" % cycle)
		retired_tokens[retired_token] = true

		workspace.set_cell(target_workspace, CellVolume.EMPTY)
		workspace_lineage.clear_lineage(target_workspace)
		workspace.set_cell(target_workspace, target_material)
		workspace_lineage.set_lineage(target_workspace, next_token)
		canonical_lineage.set_lineage(target_canonical, next_token)
		next_token += 1
		total_recreations += 1

		var components: Array[CellVolume] = MatterTopology.extract_connected_components(workspace)
		_check(components.size() == 2, "cycle %d retains exactly two disconnected components" % cycle)
		if components.size() != 2:
			_finish()
			return

		var merged_origin := _occupied_min(workspace)
		var merged_max := _occupied_max(workspace)
		var merged_size: Vector3i = merged_max - merged_origin + Vector3i.ONE
		var successor := CellVolume.new(merged_size)
		var successor_lineage := MatterLineageMap.new(merged_size)

		for component in components:
			var compact_info: Dictionary = MatterTopology.compact_volume(component)
			var component_origin: Vector3i = compact_info["origin"]
			var compact: CellVolume = compact_info["volume"]
			var compact_lineage := MatterLineageMap.new(compact.size)

			for source_cell in _occupied_cells(component):
				var child_cell: Vector3i = source_cell - component_origin
				var token := workspace_lineage.get_lineage(source_cell)
				compact_lineage.set_lineage(child_cell, token)
				_check(token != MatterLineageMap.NONE, "cycle %d compact split retains lineage" % cycle)
				_check(compact.get_cell(child_cell) == component.get_cell(source_cell), "cycle %d compact split retains material" % cycle)

				var successor_cell: Vector3i = source_cell - merged_origin
				successor.set_cell(successor_cell, compact.get_cell(child_cell))
				successor_lineage.set_lineage(successor_cell, compact_lineage.get_lineage(child_cell))

		_check(successor.size == canonical.size, "cycle %d returns to the canonical compact address extent" % cycle)
		_check(successor.count_solid() == initial_solid_count, "cycle %d preserves solid count" % cycle)
		_check(successor_lineage.count_assigned() == initial_solid_count, "cycle %d preserves one lineage token per Matter cell" % cycle)

		var lineage_mismatches := 0
		var material_mismatches := 0
		for canonical_cell in _occupied_cells(canonical):
			if successor.get_cell(canonical_cell) != canonical.get_cell(canonical_cell):
				material_mismatches += 1
			if successor_lineage.get_lineage(canonical_cell) != canonical_lineage.get_lineage(canonical_cell):
				lineage_mismatches += 1
		max_lineage_mismatches = max(max_lineage_mismatches, lineage_mismatches)
		max_material_mismatches = max(max_material_mismatches, material_mismatches)
		_check(lineage_mismatches == 0, "cycle %d changes no retained lineage beyond the explicit recreation" % cycle)
		_check(material_mismatches == 0, "cycle %d reconstructs exact material storage" % cycle)

		var seen_tokens: Dictionary = {}
		var duplicate_tokens := 0
		for cell in _occupied_cells(successor):
			var token := successor_lineage.get_lineage(cell)
			if seen_tokens.has(token):
				duplicate_tokens += 1
			seen_tokens[token] = true
			_check(not retired_tokens.has(token), "cycle %d never resurrects a retired lineage token" % cycle)
		max_duplicate_tokens = max(max_duplicate_tokens, duplicate_tokens)
		_check(duplicate_tokens == 0, "cycle %d has no duplicate live lineage tokens" % cycle)

		canonical = successor
		canonical_lineage = successor_lineage

	_check(total_recreations == CYCLES, "campaign executes one explicit Matter recreation per cycle")
	_check(max_lineage_mismatches == 0, "campaign preserves all non-recreated lineage across repeated topology remaps")
	_check(max_material_mismatches == 0, "campaign preserves exact material storage across repeated topology remaps")
	_check(max_duplicate_tokens == 0, "campaign never aliases two live Matter cells to one lineage token")

	print(
		"TOPOLOGY_LINEAGE_CAMPAIGN_METRIC cycles=%d cells=%d recreations=%d retired_tokens=%d total_address_moves=%d max_lineage_mismatches=%d max_material_mismatches=%d max_duplicate_tokens=%d final_assigned=%d next_token=%d"
		% [
			CYCLES,
			initial_solid_count,
			total_recreations,
			retired_tokens.size(),
			total_address_moves,
			max_lineage_mismatches,
			max_material_mismatches,
			max_duplicate_tokens,
			canonical_lineage.count_assigned(),
			next_token,
		]
	)

	_finish()


func _make_canonical_volume() -> CellVolume:
	# Occupied minimum is zero so every workspace offset is a real address-space
	# displacement and compact merge returns deterministically to this extent.
	var volume := CellVolume.new(Vector3i(11, 3, 3))
	volume.fill_box(Vector3i(0, 0, 0), Vector3i(3, 2, 2), 2)
	volume.fill_box(Vector3i(7, 0, 0), Vector3i(11, 3, 3), 3)
	volume.set_cell(Vector3i(0, 0, 0), 4)
	volume.set_cell(Vector3i(2, 1, 1), CellVolume.EMPTY)
	volume.set_cell(Vector3i(7, 0, 0), CellVolume.EMPTY)
	volume.set_cell(Vector3i(10, 2, 2), 5)
	return volume


func _occupied_cells(volume: CellVolume) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for z in range(volume.size.z):
		for y in range(volume.size.y):
			for x in range(volume.size.x):
				var cell := Vector3i(x, y, z)
				if volume.get_cell(cell) != CellVolume.EMPTY:
					result.append(cell)
	return result


func _occupied_min(volume: CellVolume) -> Vector3i:
	var result := Vector3i(volume.size.x, volume.size.y, volume.size.z)
	for cell in _occupied_cells(volume):
		result.x = min(result.x, cell.x)
		result.y = min(result.y, cell.y)
		result.z = min(result.z, cell.z)
	return result


func _occupied_max(volume: CellVolume) -> Vector3i:
	var result := Vector3i(-1, -1, -1)
	for cell in _occupied_cells(volume):
		result.x = max(result.x, cell.x)
		result.y = max(result.y, cell.y)
		result.z = max(result.z, cell.z)
	return result


func _finish() -> void:
	if _failures.is_empty():
		print("TOPOLOGY_LINEAGE_CAMPAIGN_PASS: repeated offset→split→compact→merge cycles preserved every surviving Matter lineage while destroy/recreate events alone created fresh lineage and retired tokens never resurrected.")
		quit(0)
		return
	for failure in _failures:
		push_error("TOPOLOGY_LINEAGE_CAMPAIGN_FAIL: " + failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
