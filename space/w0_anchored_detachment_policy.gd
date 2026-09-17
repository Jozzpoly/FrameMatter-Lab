class_name W0AnchoredDetachmentPolicy
extends RefCounted

# Experiment-local W0 policy seam. It intentionally does not own Matter or
# perform transfers. It only classifies current connected components according
# to retained anchor lineage. The RED stub exists so the first test fails on
# behavior rather than on a missing/invalid class graph.


static func evaluate(
	_volume: CellVolume,
	_lineage: MatterLineageMap,
	_anchor_tokens: Dictionary
) -> Dictionary:
	return {
		"valid": false,
		"reason": "W0 anchored detachment policy not implemented",
		"anchored_components": [],
		"detached_components": [],
	}
