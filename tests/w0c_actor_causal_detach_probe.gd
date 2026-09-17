extends SceneTree

const SOURCE_SIZE := Vector3i(9, 5, 5)
const SOURCE_TRANSFORM := Transform3D(Basis.IDENTITY, Vector3(-4.0, 0.0, -2.0))
const BRIDGE_CELL := Vector3i(3, 1, 2)
const ANCHOR_CELL := Vector3i(1, 0, 2)
const ACTOR_SUPPORT_CELL := Vector3i(5, 1, 2)
const ACQUIRE_FRAMES := 24
const RIDE_FRAMES := 12

var _failures: Array[String] = []
var _actor: SpaceQueryCharacter
var _handoff_requested := false
var _handoff_succeeded := false
var _handoff_world_before := Vector3.ZERO
var _handoff_world_error := INF
var _mapped_actor_local := Vector3.ZERO


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	world.name = "W0CActorCausalDetachWorld"
	get_root().add_child(world)

	var volume := CellVolume.new(SOURCE_SIZE)
	volume.fill_box(Vector3i(0, 0, 0), Vector3i(3, 1, 5), CellVolume.SOLID)
	volume.set_cell(Vector3i(2, 1, 2), CellVolume.SOLID)
	volume.set_cell(BRIDGE_CELL, CellVolume.SOLID)
	volume.fill_box(Vector3i(4, 1, 1), Vector3i(8, 2, 4), CellVolume.SOLID)

	var lineage := MatterLineageMap.new(SOURCE_SIZE)
	var issuer := MatterLineageIssuer.new(340001)
	for cell in _occupied_cells(volume):
		lineage.set_lineage(cell, issuer.allocate())
	var anchor_token := lineage.get_lineage(ANCHOR_CELL)

	var source := W0AuthorityPartitionSpace.new()
	source.name = "W0CCanonicalSource"
	source.lineage_issuer = issuer
	source.dynamic_gravity_scale = 1.0
	source.dynamic_linear_damp = 0.0
	source.dynamic_angular_damp = 0.0
	source.dynamic_can_sleep = true
	world.add_child(source)
	source.initialize_static(volume, lineage, SOURCE_TRANSFORM)

	_actor = SpaceQueryCharacter.new()
	_actor.name = "W0CActor"
	world.add_child(_actor)
	_actor.global_position = SOURCE_TRANSFORM * Vector3(
		float(ACTOR_SUPPORT_CELL.x) + 0.5,
		float(ACTOR_SUPPORT_CELL.y) + 1.0 + _actor.height * 0.5 + 0.04,
		float(ACTOR_SUPPORT_CELL.z) + 0.5
	)

	await _advance_frames(ACQUIRE_FRAMES)
	_check(_actor.grounded, "actor acquires ordinary canonical Matter before the cut")
	_check(_actor.support_space == source, "actor logical support initially belongs to the canonical source")
	_check(_actor.support_body == source.get_active_provider(), "actor physical support initially matches canonical provider")
	if not _actor.grounded or _actor.support_space != source:
		_finish(world)
		return

	# W0C may not choose successor ownership from capsule-center proximity. It
	# needs a real support-contact witness captured when the actor acquired Matter.
	if not _actor.has_method("get_support_contact_witness"):
		_check(false, "actor exposes an exact support-contact witness for authority handoff")
		_finish(world)
		return
	var witness: Dictionary = _actor.call("get_support_contact_witness")
	_check(bool(witness.get("valid", false)), "support-contact witness is valid before causal detach")
	if not bool(witness.get("valid", false)):
		_finish(world)
		return
	var witness_cell: Vector3i = witness.get("cell", Vector3i(-999, -999, -999))
	var witness_world: Vector3 = witness.get("world_point", Vector3.ZERO)
	var witness_token := source.lineage.get_lineage(witness_cell)
	_check(witness_cell == ACTOR_SUPPORT_CELL, "exact contact witness resolves the authored Matter cell under the actor")
	_check(witness_token != MatterLineageMap.NONE, "support witness points at retained logical Matter")

	var transfers_before := _actor.observed_support_transfers
	var acquisitions_before := _actor.observed_ground_acquisitions

	# Ordinary world edit destroys only the bridge Matter. The resulting topology
	# determines which retained Matter becomes eligible for W0 authority transfer.
	_check(source.mutate_cell(BRIDGE_CELL, CellVolume.EMPTY), "ordinary REMOVE destroys the bridge under normal Matter semantics")
	var decision := W0AnchoredDetachmentPolicy.evaluate(source.volume, source.lineage, {anchor_token: true})
	_check(bool(decision.get("valid", false)), "post-edit topology is classifiable by the bounded anchor policy")
	if not bool(decision.get("valid", false)):
		_finish(world)
		return
	var detached_components: Array = decision.get("detached_components", [])
	_check(detached_components.size() == 1, "actor fixture exposes exactly one detached Matter component")
	if detached_components.size() != 1:
		_finish(world)
		return
	var detached_cells: Array[Vector3i] = detached_components[0]
	_check(detached_cells.has(witness_cell), "actual Matter contact witness belongs to the portion changing authority")
	if not detached_cells.has(witness_cell):
		_finish(world)
		return

	source.authority_partition_committed.connect(_on_authority_partition_committed)
	_handoff_world_before = _actor.global_position
	var accepted := source.request_authority_partition(detached_cells, LocalMatterSpace.ProviderKind.DYNAMIC)
	_check(accepted, "same W0 authority path accepts the actor-supported detached portion")
	if not accepted:
		_finish(world)
		return

	await source.authority_partition_committed
	var result := source.get_last_authority_partition_result()
	var target := result.get("target_space") as LocalMatterSpace
	_check(target != null and is_instance_valid(target), "actor-supported Matter receives a fresh target Space")
	_check(_handoff_requested and _handoff_succeeded, "actor support transfers explicitly inside the authority transaction signal")
	_check(_handoff_world_error < 0.0001, "explicit W0 actor handoff has no world-space teleport")
	_check(_actor.grounded, "actor remains grounded at the authority handoff boundary")
	_check(_actor.support_space == target, "actor immediately references fresh Matter owner rather than canonical source")
	if target != null:
		_check(_actor.support_body == target.get_active_provider(), "actor support body immediately matches fresh target provider")
	_check(_actor.observed_support_transfers == transfers_before + 1, "W0 causal detach performs exactly one explicit support transfer")
	_check(_actor.observed_ground_acquisitions == acquisitions_before, "W0 handoff is not disguised as later ground reacquisition")

	var source_origin: Vector3i = result.get("source_origin")
	var target_cell := witness_cell - source_origin
	_check(source.lineage.get_lineage(witness_cell) == MatterLineageMap.NONE, "support Matter no longer belongs to canonical authority")
	if target != null:
		_check(target.lineage.get_lineage(target_cell) == witness_token, "the exact Matter lineage that supported the actor now belongs to fresh target")

	var target_provider := target.get_active_provider() if target != null else null
	var actor_local_after_handoff := target_provider.to_local(_actor.global_position) if target_provider != null else Vector3.ZERO
	var actor_world_at_handoff := _actor.global_position
	await _advance_frames(RIDE_FRAMES)

	_check(_actor.grounded, "actor remains grounded while detached Matter falls")
	_check(_actor.support_space == target, "actor keeps the same fresh Matter owner during solver-driven fall")
	var ride_local_drift := INF
	if target_provider != null:
		ride_local_drift = Vector2(
			target_provider.to_local(_actor.global_position).x - actor_local_after_handoff.x,
			target_provider.to_local(_actor.global_position).z - actor_local_after_handoff.z
		).length()
	_check(ride_local_drift < 0.002, "actor rides the falling world fragment without lateral support drift")
	var actor_fall := actor_world_at_handoff.y - _actor.global_position.y
	_check(actor_fall > 0.02, "actor visibly follows the detached Matter downward")
	_check(_actor.observed_ground_acquisitions == acquisitions_before, "post-detach ride never reacquires support as a substitute for explicit handoff")

	print(
		"W0C_ACTOR_CAUSAL_DETACH_METRIC witness_cell=%s witness_world=%s witness_token=%d handoff_error=%.10f ride_drift=%.8f actor_fall=%.6f transfers=%d acquisitions=%d"
		% [
			str(witness_cell),
			str(witness_world),
			witness_token,
			_handoff_world_error,
			ride_local_drift,
			actor_fall,
			_actor.observed_support_transfers - transfers_before,
			_actor.observed_ground_acquisitions - acquisitions_before,
		]
	)

	_finish(world)


func _on_authority_partition_committed(result: Dictionary) -> void:
	if _actor == null or not _actor.grounded:
		return
	var target := result.get("target_space") as LocalMatterSpace
	var source_origin: Vector3i = result.get("source_origin")
	if target == null or target.get_active_provider() == null:
		return
	_mapped_actor_local = _actor.support_local_center - Vector3(source_origin)
	_handoff_requested = true
	_handoff_succeeded = _actor.transfer_support_frame(target.get_active_provider(), _mapped_actor_local)
	_handoff_world_error = _actor.global_position.distance_to(_handoff_world_before)


func _advance_frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame
		await process_frame


func _occupied_cells(volume: CellVolume) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for z in range(volume.size.z):
		for y in range(volume.size.y):
			for x in range(volume.size.x):
				var cell := Vector3i(x, y, z)
				if volume.get_cell(cell) != CellVolume.EMPTY:
					result.append(cell)
	return result


func _finish(world: Node3D) -> void:
	if _failures.is_empty():
		print("W0C_ACTOR_CAUSAL_DETACH_PASS: actor support follows the exact retained Matter that changes authority, transfers before the first detached solver step and rides the falling fragment without teleport or contact reacquisition.")
		world.free()
		quit(0)
		return
	for failure in _failures:
		push_error("W0C_ACTOR_CAUSAL_DETACH_FAIL: " + failure)
	world.free()
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
