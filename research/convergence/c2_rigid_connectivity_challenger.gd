class_name C2RigidConnectivityChallenger
extends RefCounted

# Convergence C2 experiment only.
#
# MatterTopology remains the material-connectivity control:
# occupied axial neighbors are materially continuous.
#
# This derived view asks a narrower question:
# may rigid connectivity traverse this specific occupied adjacency?
#
# Blocked interfaces are identified by the opaque lineage tokens of the two
# endpoint Matter cells. This is an experiment-local dialect, not a final
# MaterialAnchor/Bond schema.


static func extract_rigid_components(
	volume: CellVolume,
	lineage: MatterLineageMap,
	blocked_interfaces: Array
) -> Dictionary:
	if volume == null or lineage == null:
		return _invalid("missing Matter authority")
	if lineage.size != volume.size:
		return _invalid("Matter/lineage size mismatch")

	var blocked: Dictionary = {}
	for interface_variant in blocked_interfaces:
		if not (interface_variant is Dictionary):
			return _invalid("blocked interface is not a dictionary")
		var interface: Dictionary = interface_variant
		var token_a := int(interface.get("a", MatterLineageMap.NONE))
		var token_b := int(interface.get("b", MatterLineageMap.NONE))
		if token_a == MatterLineageMap.NONE or token_b == MatterLineageMap.NONE:
			return _invalid("blocked interface is missing live lineage")
		if token_a == token_b:
			return _invalid("blocked interface endpoints must be distinct")
		blocked[_pair_key(token_a, token_b)] = true

	var components: Array = []
	var encountered_blocked: Dictionary = {}
	var visited := PackedByteArray()
	visited.resize(volume.size.x * volume.size.y * volume.size.z)
	visited.fill(0)

	for z in range(volume.size.z):
		for y in range(volume.size.y):
			for x in range(volume.size.x):
				var start := Vector3i(x, y, z)
				var start_index := _flat_index(volume.size, start)
				if volume.get_cell(start) == CellVolume.EMPTY or visited[start_index] != 0:
					continue
				if lineage.get_lineage(start) == MatterLineageMap.NONE:
					return _invalid("occupied Matter is missing lineage")

				var component: Array[Vector3i] = []
				var queue: Array[Vector3i] = [start]
				var cursor := 0
				visited[start_index] = 1

				while cursor < queue.size():
					var cell: Vector3i = queue[cursor]
					cursor += 1
					component.append(cell)
					var cell_token := lineage.get_lineage(cell)
					if cell_token == MatterLineageMap.NONE:
						return _invalid("occupied Matter is missing lineage")

					for offset in MatterTopology.AXIAL_NEIGHBORS:
						var neighbor := cell + offset
						if not volume.in_bounds(neighbor):
							continue
						if volume.get_cell(neighbor) == CellVolume.EMPTY:
							continue

						var neighbor_token := lineage.get_lineage(neighbor)
						if neighbor_token == MatterLineageMap.NONE:
							return _invalid("occupied Matter is missing lineage")

						var pair_key := _pair_key(cell_token, neighbor_token)
						if blocked.has(pair_key):
							encountered_blocked[pair_key] = true
							continue

						var neighbor_index := _flat_index(volume.size, neighbor)
						if visited[neighbor_index] != 0:
							continue
						visited[neighbor_index] = 1
						queue.append(neighbor)

				components.append(component)

	for key_variant in blocked.keys():
		if not encountered_blocked.has(key_variant):
			return _invalid("blocked interface does not resolve to a live occupied adjacency")

	return {
		"valid": true,
		"reason": "",
		"components": components,
		"blocked_interface_count": blocked.size(),
		"encountered_blocked_interface_count": encountered_blocked.size(),
	}


static func _pair_key(token_a: int, token_b: int) -> String:
	var low := mini(token_a, token_b)
	var high := maxi(token_a, token_b)
	return "%d:%d" % [low, high]


static func _flat_index(volume_size: Vector3i, cell: Vector3i) -> int:
	return cell.x + volume_size.x * (cell.y + volume_size.y * cell.z)


static func _invalid(reason: String) -> Dictionary:
	return {
		"valid": false,
		"reason": reason,
		"components": [],
		"blocked_interface_count": 0,
		"encountered_blocked_interface_count": 0,
	}
