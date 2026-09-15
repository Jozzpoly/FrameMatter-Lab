class_name MatterLineageIssuer
extends RefCounted

# Transient runtime token issuer for experiments that create fresh Matter.
# This is deliberately NOT a persistence/UUID schema. Its only current contract
# is monotonic non-zero uniqueness across Spaces that share this issuer.

var _next_token := 1


func _init(first_token: int = 1) -> void:
	assert(first_token > MatterLineageMap.NONE)
	_next_token = first_token


func absorb_existing(lineage: MatterLineageMap) -> void:
	if lineage == null:
		return
	var max_existing := MatterLineageMap.NONE
	for token in lineage.duplicate_tokens():
		max_existing = max(max_existing, int(token))
	reserve_at_least(max_existing + 1)


func reserve_at_least(next_candidate: int) -> void:
	_next_token = max(_next_token, max(MatterLineageMap.NONE + 1, next_candidate))


func allocate() -> int:
	var token := _next_token
	_next_token += 1
	assert(token != MatterLineageMap.NONE)
	return token


func peek_next() -> int:
	return _next_token
