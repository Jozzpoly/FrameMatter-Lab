class_name MatterTopology
extends RefCounted

const AXIAL_NEIGHBORS: Array[Vector3i] = [
	Vector3i(1, 0, 0),
	Vector3i(-1, 0, 0),
	Vector3i(0, 1, 0),
	Vector3i(0, -1, 0),
	Vector3i(0, 0, 1),
	Vector3i(0, 0, -1),
]


# Cell-list connectivity is the lightweight topology representation for callers
# that need component membership but not a full component-sized Matter clone.
# Logical authority remains in the source CellVolume; these arrays are derived.
static func extract_connected_cell_components(source: CellVolume) -> Array:
	var components: Array = []
	if source == null:
		return components

	var visited := PackedByteArray()
	visited.resize(source.size.x * source.size.y * source.size.z)
	visited.fill(0)

	for z in range(source.size.z):
		for y in range(source.size.y):
			for x in range(source.size.x):
				var start := Vector3i(x, y, z)
				var start_index := _flat_index(source.size, start)
				if source.get_cell(start) == CellVolume.EMPTY or visited[start_index] != 0:
					continue

				var component: Array[Vector3i] = []
				var queue: Array[Vector3i] = [start]
				var cursor := 0
				visited[start_index] = 1

				while cursor < queue.size():
					var cell: Vector3i = queue[cursor]
					cursor += 1
					component.append(cell)

					for offset in AXIAL_NEIGHBORS:
						var neighbor := cell + offset
						if not source.in_bounds(neighbor):
							continue
						var neighbor_index := _flat_index(source.size, neighbor)
						if visited[neighbor_index] != 0:
							continue
						if source.get_cell(neighbor) == CellVolume.EMPTY:
							continue
						visited[neighbor_index] = 1
						queue.append(neighbor)

				components.append(component)

	return components


static func prove_connected_after_single_removal(
	source_after_removal: CellVolume,
	removed_cell: Vector3i,
	max_expanded_cells: int = 256
) -> Dictionary:
	# One-sided graph proof. The caller must already know that the source was one
	# connected component immediately before exactly one occupied cell was
	# removed. Under that precondition, G-v remains connected iff all surviving
	# neighbors of v belong to one connected component. This helper may return
	# inconclusive early; it must never infer a split or fabricate components.
	if source_after_removal == null:
		return {"proven_connected": false, "reason": "missing volume", "visited_cells": 0, "occupied_neighbors": 0}
	if not source_after_removal.in_bounds(removed_cell):
		return {"proven_connected": false, "reason": "removed cell out of bounds", "visited_cells": 0, "occupied_neighbors": 0}
	if source_after_removal.get_cell(removed_cell) != CellVolume.EMPTY:
		return {"proven_connected": false, "reason": "removed cell is still occupied", "visited_cells": 0, "occupied_neighbors": 0}
	if source_after_removal.count_solid() == 0:
		return {"proven_connected": false, "reason": "source became empty", "visited_cells": 0, "occupied_neighbors": 0}
	if max_expanded_cells <= 0:
		return {"proven_connected": false, "reason": "zero proof budget", "visited_cells": 0, "occupied_neighbors": 0}

	var neighbors: Array[Vector3i] = []
	for offset in AXIAL_NEIGHBORS:
		var neighbor := removed_cell + offset
		if source_after_removal.in_bounds(neighbor) and source_after_removal.get_cell(neighbor) != CellVolume.EMPTY:
			neighbors.append(neighbor)

	if neighbors.is_empty():
		# If the caller's prior-connected precondition is true, a zero-degree
		# removed vertex can only leave an empty graph. A non-empty graph here
		# means the precondition is not defensible, so fail inconclusive.
		return {"proven_connected": false, "reason": "no surviving neighbor", "visited_cells": 0, "occupied_neighbors": 0}
	if neighbors.size() == 1:
		return {"proven_connected": true, "reason": "single surviving neighbor", "visited_cells": 1, "occupied_neighbors": 1}

	var targets: Dictionary = {}
	for neighbor in neighbors:
		targets[neighbor] = true
	var visited: Dictionary = {}
	var queue: Array[Vector3i] = [neighbors[0]]
	var cursor := 0
	var expanded := 0
	var reached_targets := 1
	visited[neighbors[0]] = true

	while cursor < queue.size():
		if expanded >= max_expanded_cells:
			return {
				"proven_connected": false,
				"reason": "proof budget exhausted",
				"visited_cells": visited.size(),
				"occupied_neighbors": neighbors.size(),
			}
		var cell: Vector3i = queue[cursor]
		cursor += 1
		expanded += 1
		for offset in AXIAL_NEIGHBORS:
			var candidate := cell + offset
			if not source_after_removal.in_bounds(candidate):
				continue
			if visited.has(candidate) or source_after_removal.get_cell(candidate) == CellVolume.EMPTY:
				continue
			visited[candidate] = true
			queue.append(candidate)
			if targets.has(candidate):
				reached_targets += 1
				if reached_targets == neighbors.size():
					return {
						"proven_connected": true,
						"reason": "all surviving neighbors reconnected",
						"visited_cells": visited.size(),
						"occupied_neighbors": neighbors.size(),
					}

	return {
		"proven_connected": false,
		"reason": "surviving neighbors are disconnected",
		"visited_cells": visited.size(),
		"occupied_neighbors": neighbors.size(),
	}


static func prove_partition_after_single_removal_from_connected_source(
	source_after_removal: CellVolume,
	removed_cell: Vector3i,
	live_anchor_cells: Array[Vector3i],
	max_component_cells: int = 128
) -> Dictionary:
	# One-sided bounded partition proof. PRECONDITION: immediately before this
	# exact single-cell removal, the source Matter graph was one connected
	# component. Every component of G-v must therefore contain at least one
	# surviving axial neighbor of v. Small components can be fully enumerated;
	# at most one large unresolved component can be inferred as the anchored
	# remainder when no completed component contains a live anchor.
	if source_after_removal == null:
		return _bounded_partition_inconclusive("missing volume")
	if not source_after_removal.in_bounds(removed_cell):
		return _bounded_partition_inconclusive("removed cell out of bounds")
	if source_after_removal.get_cell(removed_cell) != CellVolume.EMPTY:
		return _bounded_partition_inconclusive("removed cell is still occupied")
	if source_after_removal.count_solid() == 0:
		return _bounded_partition_inconclusive("source became empty")
	if max_component_cells <= 0:
		return _bounded_partition_inconclusive("zero component budget")
	if live_anchor_cells.is_empty():
		return _bounded_partition_inconclusive("no live anchor cells")

	var anchor_set: Dictionary = {}
	for anchor in live_anchor_cells:
		if (
			not source_after_removal.in_bounds(anchor)
			or source_after_removal.get_cell(anchor) == CellVolume.EMPTY
		):
			return _bounded_partition_inconclusive("anchor cell is not live")
		anchor_set[anchor] = true

	var neighbors: Array[Vector3i] = []
	var neighbor_set: Dictionary = {}
	for offset in AXIAL_NEIGHBORS:
		var neighbor := removed_cell + offset
		if source_after_removal.in_bounds(neighbor) and source_after_removal.get_cell(neighbor) != CellVolume.EMPTY:
			neighbors.append(neighbor)
			neighbor_set[neighbor] = true
	if neighbors.is_empty():
		return _bounded_partition_inconclusive("no surviving neighbor")
	if neighbors.size() == 1:
		return {
			"proven": true,
			"reason": "single surviving neighbor",
			"detached_components": [],
			"anchored_component_count": 1,
			"unknown_component_count": 0,
			"visited_cells": 1,
			"occupied_neighbors": 1,
		}

	var consumed_neighbors: Dictionary = {}
	var completed_components: Array = []
	var unknown_component_count := 0
	var total_visited_cells := 0

	for seed in neighbors:
		if consumed_neighbors.has(seed):
			continue
		var visited: Dictionary = {seed: true}
		var queue: Array[Vector3i] = [seed]
		var cursor := 0
		var contains_anchor := anchor_set.has(seed)
		var exceeded_budget := false
		consumed_neighbors[seed] = true

		while cursor < queue.size():
			if cursor >= max_component_cells:
				exceeded_budget = true
				break
			var cell: Vector3i = queue[cursor]
			cursor += 1
			if anchor_set.has(cell):
				contains_anchor = true
			if neighbor_set.has(cell):
				consumed_neighbors[cell] = true
			for offset in AXIAL_NEIGHBORS:
				var candidate := cell + offset
				if not source_after_removal.in_bounds(candidate):
					continue
				if visited.has(candidate) or source_after_removal.get_cell(candidate) == CellVolume.EMPTY:
					continue
				visited[candidate] = true
				queue.append(candidate)

		total_visited_cells += mini(cursor, max_component_cells)
		if exceeded_budget:
			unknown_component_count += 1
			continue

		var cells: Array[Vector3i] = []
		for cell_variant in visited.keys():
			var cell: Vector3i = cell_variant
			cells.append(cell)
		completed_components.append({
			"cells": cells,
			"contains_anchor": contains_anchor,
		})

	if unknown_component_count > 1:
		return {
			"proven": false,
			"reason": "multiple unresolved components",
			"detached_components": [],
			"anchored_component_count": 0,
			"unknown_component_count": unknown_component_count,
			"visited_cells": total_visited_cells,
			"occupied_neighbors": neighbors.size(),
		}

	var anchored_completed := 0
	var detached_components: Array = []
	for component_variant in completed_components:
		var component: Dictionary = component_variant
		if bool(component["contains_anchor"]):
			anchored_completed += 1
		else:
			detached_components.append(component["cells"])

	if unknown_component_count == 1:
		if anchored_completed > 0:
			return {
				"proven": false,
				"reason": "unresolved component may be detached",
				"detached_components": [],
				"anchored_component_count": 0,
				"unknown_component_count": 1,
				"visited_cells": total_visited_cells,
				"occupied_neighbors": neighbors.size(),
			}
		# Every live anchor belongs to some component of G-v. All completed
		# components were exhaustively proven anchor-free, and exactly one
		# component remains unresolved, so that remainder is the sole anchored
		# component without requiring a scan of its full membership.
		return {
			"proven": true,
			"reason": "single unresolved anchored remainder",
			"detached_components": detached_components,
			"anchored_component_count": 1,
			"unknown_component_count": 1,
			"visited_cells": total_visited_cells,
			"occupied_neighbors": neighbors.size(),
		}

	if anchored_completed == 0:
		return _bounded_partition_inconclusive("no completed anchored component")
	return {
		"proven": true,
		"reason": "all components completed",
		"detached_components": detached_components,
		"anchored_component_count": anchored_completed,
		"unknown_component_count": 0,
		"visited_cells": total_visited_cells,
		"occupied_neighbors": neighbors.size(),
	}


static func _bounded_partition_inconclusive(reason: String) -> Dictionary:
	return {
		"proven": false,
		"reason": reason,
		"detached_components": [],
		"anchored_component_count": 0,
		"unknown_component_count": 0,
		"visited_cells": 0,
		"occupied_neighbors": 0,
	}


static func cells_form_single_component(cells: Array[Vector3i]) -> bool:
	if cells.is_empty():
		return false

	var selected: Dictionary = {}
	for cell in cells:
		if selected.has(cell):
			return false
		selected[cell] = true

	var visited: Dictionary = {}
	var queue: Array[Vector3i] = [cells[0]]
	var cursor := 0
	visited[cells[0]] = true

	while cursor < queue.size():
		var cell: Vector3i = queue[cursor]
		cursor += 1
		for offset in AXIAL_NEIGHBORS:
			var neighbor := cell + offset
			if not selected.has(neighbor) or visited.has(neighbor):
				continue
			visited[neighbor] = true
			queue.append(neighbor)

	return visited.size() == selected.size()


static func extract_connected_components(source: CellVolume) -> Array[CellVolume]:
	var components: Array[CellVolume] = []
	var visited: Dictionary = {}

	for z in range(source.size.z):
		for y in range(source.size.y):
			for x in range(source.size.x):
				var start := Vector3i(x, y, z)
				if source.get_cell(start) == CellVolume.EMPTY or visited.has(start):
					continue

				var component := CellVolume.new(source.size)
				var queue: Array[Vector3i] = [start]
				var cursor := 0
				visited[start] = true

				while cursor < queue.size():
					var cell: Vector3i = queue[cursor]
					cursor += 1
					component.set_cell(cell, source.get_cell(cell))

					for offset in AXIAL_NEIGHBORS:
						var neighbor := cell + offset
						if not source.in_bounds(neighbor):
							continue
						if source.get_cell(neighbor) == CellVolume.EMPTY:
							continue
						if visited.has(neighbor):
							continue
						visited[neighbor] = true
						queue.append(neighbor)

				components.append(component)

	return components


static func compact_volume(source: CellVolume) -> Dictionary:
	assert(source.count_solid() > 0)

	var min_cell := Vector3i(source.size.x, source.size.y, source.size.z)
	var max_cell := Vector3i(-1, -1, -1)

	for z in range(source.size.z):
		for y in range(source.size.y):
			for x in range(source.size.x):
				var cell := Vector3i(x, y, z)
				if source.get_cell(cell) == CellVolume.EMPTY:
					continue
				min_cell.x = min(min_cell.x, x)
				min_cell.y = min(min_cell.y, y)
				min_cell.z = min(min_cell.z, z)
				max_cell.x = max(max_cell.x, x)
				max_cell.y = max(max_cell.y, y)
				max_cell.z = max(max_cell.z, z)

	var compact_size: Vector3i = max_cell - min_cell + Vector3i.ONE
	var compact := CellVolume.new(compact_size)

	for z in range(min_cell.z, max_cell.z + 1):
		for y in range(min_cell.y, max_cell.y + 1):
			for x in range(min_cell.x, max_cell.x + 1):
				var source_cell := Vector3i(x, y, z)
				var material_id: int = source.get_cell(source_cell)
				if material_id == CellVolume.EMPTY:
					continue
				compact.set_cell(source_cell - min_cell, material_id)

	return {
		"origin": min_cell,
		"volume": compact,
	}


static func center_of_mass_local(volume: CellVolume) -> Vector3:
	var weighted_sum := Vector3.ZERO
	var solid_count := 0

	for z in range(volume.size.z):
		for y in range(volume.size.y):
			for x in range(volume.size.x):
				var cell := Vector3i(x, y, z)
				if volume.get_cell(cell) == CellVolume.EMPTY:
					continue
				weighted_sum += Vector3(x, y, z) + Vector3(0.5, 0.5, 0.5)
				solid_count += 1

	if solid_count == 0:
		return Vector3.ZERO
	return weighted_sum / float(solid_count)


static func _flat_index(volume_size: Vector3i, cell: Vector3i) -> int:
	return cell.x + volume_size.x * (cell.y + volume_size.y * cell.z)
