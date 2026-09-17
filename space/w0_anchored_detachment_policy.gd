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

	var components: Array = MatterTopology.extract_connected_cell_components(volume)
	if components.is_empty():
		return _invalid("canonical Matter is empty")

	var anchored_components: Array = []
	var detached_components: Array = []
	var retained_anchor_tokens: Dictionary = {}

	for component_variant in components:
		var component: Array = component_variant
		var cells: Array[Vector3i] = []
		var contains_anchor := false
		for cell_variant in component:
			var cell: Vector3i = cell_variant
			var token: int = lineage.get_lineage(cell)
			if token == MatterLineageMap.NONE:
				return _invalid("occupied Matter is missing lineage")
			cells.append(cell)
			if anchor_tokens.has(token):
				contains_anchor = true
				retained_anchor_tokens[token] = true
		if cells.is_empty():
			continue
		if contains_anchor:
			anchored_components.append(cells)
		else:
			detached_components.append(cells)

	# This first W0 policy fails closed if every authored canonical anchor has
	# disappeared. Losing the anchor Matter may later have an explicit world
	# policy, but it must not silently promote an arbitrary remaining component to
	# canonical ownership.
	if retained_anchor_tokens.is_empty() or anchored_components.is_empty():
		return _invalid("no retained canonical anchor lineage remains")

	return {
		"valid": true,
		"reason": "",
		"anchored_components": anchored_components,
		"detached_components": detached_components,
		"retained_anchor_tokens": retained_anchor_tokens,
	}


static func _invalid(reason: String) -> Dictionary:
	return {
		"valid": false,
		"reason": reason,
		"anchored_components": [],
		"detached_components": [],
		"retained_anchor_tokens": {},
	}
