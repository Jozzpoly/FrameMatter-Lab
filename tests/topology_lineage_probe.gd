extends SceneTree

const SOURCE_SIZE := Vector3i(14, 5, 5)
const MASS_PER_CELL := 1.7
const INITIAL_TOKEN := 10001
const RECREATED_TOKEN := 900001

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	world.name = "TopologyLineageWorld"
	get_root().add_child(world)

	var source := _make_source_volume()
	var lineage := MatterLineageMap.new(source.size)
	var original_lineage: Dictionary = {}
	var next_token := INITIAL_TOKEN

	for z in range(source.size.z):
		for y in range(source.size.y):
			for x in range(source.size.x):
				var cell := Vector3i(x, y, z)
				if source.get_cell(cell) == CellVolume.EMPTY:
					continue
				lineage.set_lineage(cell, next_token)
				original_lineage[cell] = next_token
				next_token += 1

	_check(lineage.count_assigned() == source.count_solid(), "every initial Matter cell has exactly one lineage token")

	var source_transform := Transform3D(
		Basis.from_euler(Vector3(0.21, -0.47, 0.33)),
		Vector3(13.0, -4.0, 9.0)
	)
	var source_body := _make_body(world, "LineageSourceBody", source, source_transform)
	var source_body_id := source_body.get_instance_id()

	var components: Array[CellVolume] = MatterTopology.extract_connected_components(source)
	_check(components.size() == 2, "source Matter splits into exactly two disconnected components")
	if components.size() != 2:
		_finish()
		return

	var merged_origin := _occupied_min(source)
	var merged_max := _occupied_max(source)
	var merged_size: Vector3i = merged_max - merged_origin + Vector3i.ONE
	var merged := CellVolume.new(merged_size)
	var merged_lineage := MatterLineageMap.new(merged_size)

	var compact_rebased_cells := 0
	var merged_rebased_cells := 0
	var max_world_position_error := 0.0
	var tracked_source_cell := Vector3i(10, 1, 2)
	var tracked_child_cell := Vector3i.ZERO
	var tracked_merged_cell := tracked_source_cell - merged_origin
	var tracked_token_before := lineage.get_lineage(tracked_source_cell)

	for component in components:
		var compact_info: Dictionary = MatterTopology.compact_volume(component)
		var component_origin: Vector3i = compact_info["origin"]
		var compact: CellVolume = compact_info["volume"]
		var compact_lineage := MatterLineageMap.new(compact.size)

		for z in range(component.size.z):
			for y in range(component.size.y):
				for x in range(component.size.x):
					var source_cell := Vector3i(x, y, z)
					var material_id: int = component.get_cell(source_cell)
					if material_id == CellVolume.EMPTY:
						continue

					var lineage_token := lineage.get_lineage(source_cell)
					_check(lineage_token != MatterLineageMap.NONE, "split component never loses source lineage")

					var child_cell: Vector3i = source_cell - component_origin
					compact_lineage.set_lineage(child_cell, lineage_token)
					_check(compact.get_cell(child_cell) == material_id, "compact child preserves source material at remapped address")
					_check(compact_lineage.get_lineage(child_cell) == lineage_token, "compact child preserves lineage at remapped address")
					if child_cell != source_cell:
						compact_rebased_cells += 1

					if source_cell == tracked_source_cell:
						tracked_child_cell = child_cell

					var merged_cell: Vector3i = source_cell - merged_origin
					merged.set_cell(merged_cell, material_id)
					merged_lineage.set_lineage(merged_cell, compact_lineage.get_lineage(child_cell))
					if merged_cell != source_cell:
						merged_rebased_cells += 1

	_check(compact_rebased_cells > 0, "split actually performs non-identity compact rebasing")
	_check(merged_rebased_cells == source.count_solid(), "merge actually places every retained cell into a new address frame")
	_check(tracked_token_before != MatterLineageMap.NONE, "tracked source cell has lineage before topology changes")
	_check(tracked_child_cell != tracked_source_cell, "tracked cell changes address in compact child")
	_check(tracked_merged_cell != tracked_source_cell, "tracked cell changes address again in merged frame")

	var successor_transform := source_transform * Transform3D(Basis.IDENTITY, Vector3(merged_origin))
	var successor_body := _make_body(world, "LineageSuccessorBody", merged, successor_transform)
	var successor_body_id := successor_body.get_instance_id()
	_check(successor_body_id != source_body_id, "physics-body identity changes across topology replacement")

	var lineage_mismatches := 0
	var material_mismatches := 0
	for source_cell_variant in original_lineage.keys():
		var source_cell: Vector3i = source_cell_variant
		var successor_cell: Vector3i = source_cell - merged_origin
		var expected_token: int = original_lineage[source_cell]
		if merged_lineage.get_lineage(successor_cell) != expected_token:
			lineage_mismatches += 1
		if merged.get_cell(successor_cell) != source.get_cell(source_cell):
			material_mismatches += 1

		var source_world: Vector3 = source_body.global_transform * (Vector3(source_cell) + Vector3(0.5, 0.5, 0.5))
		var successor_world: Vector3 = successor_body.global_transform * (Vector3(successor_cell) + Vector3(0.5, 0.5, 0.5))
		max_world_position_error = max(max_world_position_error, source_world.distance_to(successor_world))

	_check(lineage_mismatches == 0, "split/rebase/merge preserves every retained lineage token")
	_check(material_mismatches == 0, "split/rebase/merge preserves every retained material id")
	_check(merged_lineage.count_assigned() == merged.count_solid(), "merged successor has one lineage token per retained Matter cell")
	_check(max_world_position_error < 0.00001, "new merged address frame preserves retained Matter world positions")
	_check(merged_lineage.get_lineage(tracked_merged_cell) == tracked_token_before, "tracked lineage survives both address-space changes")

	var recreated_cell := tracked_merged_cell
	var recreated_material := merged.get_cell(recreated_cell)
	var destroyed_token := merged_lineage.get_lineage(recreated_cell)
	_check(recreated_material != CellVolume.EMPTY, "recreation target starts occupied")
	_check(destroyed_token != MatterLineageMap.NONE, "recreation target starts with lineage")

	merged.set_cell(recreated_cell, CellVolume.EMPTY)
	merged_lineage.clear_lineage(recreated_cell)
	_check(merged.get_cell(recreated_cell) == CellVolume.EMPTY, "destroyed Matter becomes empty")
	_check(merged_lineage.get_lineage(recreated_cell) == MatterLineageMap.NONE, "destroyed Matter lineage is retired")

	merged.set_cell(recreated_cell, recreated_material)
	merged_lineage.set_lineage(recreated_cell, RECREATED_TOKEN)
	_check(merged.get_cell(recreated_cell) == recreated_material, "recreated Matter can match the previous material exactly")
	_check(merged_lineage.get_lineage(recreated_cell) == RECREATED_TOKEN, "recreated Matter receives a fresh lineage token")
	_check(RECREATED_TOKEN != destroyed_token, "same coordinate and material do not resurrect destroyed lineage")

	print(
		"TOPOLOGY_LINEAGE_METRIC source_cells=%d components=%d compact_rebased_cells=%d merged_rebased_cells=%d lineage_mismatches=%d material_mismatches=%d max_world_position_error=%.10f source_body_id=%d successor_body_id=%d tracked_source=%s tracked_child=%s tracked_merged=%s tracked_token=%d recreated_token=%d"
		% [
			source.count_solid(),
			components.size(),
			compact_rebased_cells,
			merged_rebased_cells,
			lineage_mismatches,
			material_mismatches,
			max_world_position_error,
			source_body_id,
			successor_body_id,
			tracked_source_cell,
			tracked_child_cell,
			tracked_merged_cell,
			tracked_token_before,
			RECREATED_TOKEN,
		]
	)

	source_body.free()
	successor_body.free()
	_finish()


func _make_source_volume() -> CellVolume:
	var volume := CellVolume.new(SOURCE_SIZE)
	volume.fill_box(Vector3i(2, 1, 1), Vector3i(5, 3, 3), 2)
	volume.fill_box(Vector3i(9, 0, 1), Vector3i(13, 3, 4), 3)

	# Keep both regions connected while making material payload and shape nontrivial.
	volume.set_cell(Vector3i(2, 1, 1), 4)
	volume.set_cell(Vector3i(4, 2, 2), CellVolume.EMPTY)
	volume.set_cell(Vector3i(9, 0, 1), CellVolume.EMPTY)
	volume.set_cell(Vector3i(12, 2, 3), 5)
	return volume


func _occupied_min(volume: CellVolume) -> Vector3i:
	var result := Vector3i(volume.size.x, volume.size.y, volume.size.z)
	for z in range(volume.size.z):
		for y in range(volume.size.y):
			for x in range(volume.size.x):
				var cell := Vector3i(x, y, z)
				if volume.get_cell(cell) == CellVolume.EMPTY:
					continue
				result.x = min(result.x, x)
				result.y = min(result.y, y)
				result.z = min(result.z, z)
	return result


func _occupied_max(volume: CellVolume) -> Vector3i:
	var result := Vector3i(-1, -1, -1)
	for z in range(volume.size.z):
		for y in range(volume.size.y):
			for x in range(volume.size.x):
				var cell := Vector3i(x, y, z)
				if volume.get_cell(cell) == CellVolume.EMPTY:
					continue
				result.x = max(result.x, x)
				result.y = max(result.y, y)
				result.z = max(result.z, z)
	return result


func _make_body(world: Node3D, body_name: String, volume: CellVolume, transform: Transform3D) -> ConstructBody:
	var body := ConstructBody.new()
	body.name = body_name
	body.gravity_scale = 0.0
	body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.linear_damp = 0.0
	body.angular_damp = 0.0
	body.collision_layer = 0
	body.collision_mask = 0
	body.mass_per_cell = MASS_PER_CELL
	world.add_child(body)
	body.global_transform = transform
	body.set_volume(volume)
	return body


func _finish() -> void:
	if _failures.is_empty():
		print("TOPOLOGY_LINEAGE_PROBE_PASS: retained Matter lineage survived split, compact rebasing, merged-frame rebasing and physics-body replacement; destroy/recreate at the same address produced a new lineage.")
		quit(0)
		return
	for failure in _failures:
		push_error("TOPOLOGY_LINEAGE_PROBE_FAIL: " + failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
