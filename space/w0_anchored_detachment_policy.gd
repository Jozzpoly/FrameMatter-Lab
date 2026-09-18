class_name W0AnchoredDetachmentPolicy
extends RefCounted

# Experiment-local W0 policy seam. It intentionally does not own Matter or
# perform transfers. It only classifies current connected components according
# to retained anchor lineage. Topology says what is connected; this bounded
# policy says which connected portions still belong to the designated canonical
# authority. The W0 authority transaction remains ignorant of why a portion was
# selected.


static func evaluate(
	volume: CellVolume,
	lineage: MatterLineageMap,
	anchor_tokens: Dictionary
) -> Dictionary:
	if volume == null or lineage == null:
		return _invalid("missing Matter authority")
	if lineage.size != volume.size:
		return _invalid("Matter/lineage size mismatch")
	if anchor_tokens.is_empty():
		return _invalid("no canonical anchor lineage supplied")
	if volume.count_solid() == 0:
		return _invalid("canonical Matter is empty")

	var visited := PackedByteArray()
	visited.resize(volume.size.x * volume.size.y * volume.size.z)
	visited.fill(0)

	var anchored_components: Array = []
	var detached_components: Array = []
	var retained_anchor_tokens: Dictionary = {}
	var visited_solid_count := 0

	for z in range(volume.size.z):
		for y in range(volume.size.y):
			for x in range(volume.size.x):
				var start := Vector3i(x, y, z)
				var start_index := _flat_index(volume.size, start)
				if visited[start_index] != 0 or volume.get_cell(start) == CellVolume.EMPTY:
					continue

				var cells: Array[Vector3i] = []
				var contains_anchor := false
				var queue: Array[Vector3i] = [start]
				var cursor := 0
				visited[start_index] = 1

				while cursor < queue.size():
					var cell: Vector3i = queue[cursor]
					cursor += 1
					cells.append(cell)
					visited_solid_count += 1

					var token := lineage.get_lineage(cell)
					if token == MatterLineageMap.NONE:
						return _invalid("occupied Matter is missing lineage")
					if anchor_tokens.has(token):
						contains_anchor = true
						retained_anchor_tokens[token] = true

					for offset in MatterTopology.AXIAL_NEIGHBORS:
						var neighbor := cell + offset
						if not volume.in_bounds(neighbor):
							continue
						var neighbor_index := _flat_index(volume.size, neighbor)
						if visited[neighbor_index] != 0:
							continue
						if volume.get_cell(neighbor) == CellVolume.EMPTY:
							continue
						visited[neighbor_index] = 1
						queue.append(neighbor)

				if contains_anchor:
					anchored_components.append(cells)
				else:
					detached_components.append(cells)

				# Common path: if the first/next component accounts for every
				# occupied cell, no trailing storage scan or second classification
				# pass is needed. count_solid() is an O(1) CellVolume invariant.
				if visited_solid_count == volume.count_solid():
					return _finalize(
						anchored_components,
						detached_components,
						retained_anchor_tokens
					)

	return _finalize(
		anchored_components,
		detached_components,
		retained_anchor_tokens
	)


static func _finalize(
	anchored_components: Array,
	detached_components: Array,
	retained_anchor_tokens: Dictionary
) -> Dictionary:
	if retained_anchor_tokens.is_empty() or anchored_components.is_empty():
		return _invalid("no retained canonical anchor lineage remains")
	return {
		"valid": true,
		"reason": "",
		"anchored_components": anchored_components,
		"detached_components": detached_components,
		"retained_anchor_tokens": retained_anchor_tokens,
	}


static func _flat_index(volume_size: Vector3i, cell: Vector3i) -> int:
	return cell.x + volume_size.x * (cell.y + volume_size.y * cell.z)


static func _invalid(reason: String) -> Dictionary:
	return {
		"valid": false,
		"reason": reason,
		"anchored_components": [],
		"detached_components": [],
		"retained_anchor_tokens": {},
	}
