extends SceneTree

const ACQUIRE_FRAMES := 24
const RIDE_FRAMES := 16
const WATCHDOG_SECONDS := 12.0

var _failures: Array[String] = []
var _finished := false


func _init() -> void:
	call_deferred("_run")
	call_deferred("_watchdog")


func _watchdog() -> void:
	await create_timer(WATCHDOG_SECONDS).timeout
	if _finished:
		return
	push_error("W0D_RECOVERY_CAUSAL_LOOP_TIMEOUT")
	quit(1)


func _run() -> void:
	var packed := load("res://p1/recovery_main.tscn") as PackedScene
	_check(packed != null, "Owner-facing recovery scene loads")
	if packed == null:
		_finish(null)
		return

	var root := packed.instantiate()
	get_root().add_child(root)
	await process_frame

	var registry := root.get_node_or_null("P1SpaceRegistry") as P1SpaceRegistry
	var player := root.get_node_or_null("P1Player") as SpaceQueryCharacter
	var interactor := root.get_node_or_null("P1MatterInteractor") as P1MatterInteractor
	var world := root.call("get_recovery_world_space") as LocalMatterSpace

	_check(registry != null, "recovery exposes the live Space registry")
	_check(player != null and interactor != null, "recovery exposes actor and shared Matter interactor")
	_check(world is W0AuthorityPartitionSpace, "ordinary recovery terrain owns W0 causal authority partition semantics")
	_check(registry != null and registry.get_active_count() == 1, "startup contains one ordinary world Space; no pre-authored moving Space exists")
	var old_demo = root.call("get_recovery_demo_space") if root.has_method("get_recovery_demo_space") else null
	_check(old_demo == null, "old special moving demo Space is absent from Owner-facing startup")
	_check(root.has_method("get_recovery_causal_bridge_cell_for_test"), "recovery exposes the authored ordinary-Matter bridge cell for deterministic evidence")
	if not (world is W0AuthorityPartitionSpace) or registry == null or player == null or interactor == null or not root.has_method("get_recovery_causal_bridge_cell_for_test"):
		_finish(root)
		return

	var causal_world := world as W0AuthorityPartitionSpace
	var bridge_cell: Vector3i = root.call("get_recovery_causal_bridge_cell_for_test")
	_check(causal_world.volume.in_bounds(bridge_cell), "causal bridge is inside ordinary world Matter storage")
	_check(causal_world.volume.get_cell(bridge_cell) != CellVolume.EMPTY, "causal bridge begins as ordinary authored Matter")

	await _advance_frames(ACQUIRE_FRAMES)
	_check(player.grounded and player.support_space == causal_world, "player starts physically supported by the same ordinary world Space")
	var witness := player.get_support_contact_witness()
	_check(bool(witness.get("valid", false)), "player has exact Matter contact witness before cutting the world")
	if not bool(witness.get("valid", false)):
		_finish(root)
		return

	var witness_cell: Vector3i = witness.get("cell", Vector3i(-999, -999, -999))
	var witness_token: int = causal_world.lineage.get_lineage(witness_cell)
	_check(witness_token != MatterLineageMap.NONE, "player support witness resolves retained world Matter lineage")
	var acquisitions_before := player.observed_ground_acquisitions
	var transfers_before := player.observed_support_transfers
	var actor_world_before := player.global_position

	_check(
		interactor.apply_edit_to_cell(causal_world, bridge_cell, P1MatterInteractor.EditMode.REMOVE),
		"one ordinary REMOVE destroys the causal bridge through shared interaction authority"
	)
	_check(causal_world.volume.get_cell(bridge_cell) == CellVolume.EMPTY, "bridge Matter is actually destroyed")
	_check(causal_world.is_authority_partition_pending(), "the same ordinary REMOVE queues causal ownership transfer instead of a pre-authored motion toggle")
	if not causal_world.is_authority_partition_pending():
		_finish(root)
		return

	await causal_world.authority_partition_committed
	await process_frame
	var result := causal_world.get_last_authority_partition_result()
	var target := result.get("target_space") as LocalMatterSpace
	_check(target != null and is_instance_valid(target), "causal edit creates one fresh live Matter Space")
	_check(registry.get_active_count() == 2, "registry now sees canonical world plus newly detached Matter")
	_check(causal_world.get_provider_kind() == LocalMatterSpace.ProviderKind.STATIC, "canonical terrain remains static after giving up detached Matter")
	_check(target != null and target.get_provider_kind() == LocalMatterSpace.ProviderKind.DYNAMIC, "detached ordinary Matter becomes dynamic without Owner setup ceremony")
	_check(player.grounded and player.support_space == target, "actor immediately follows the Matter that supported it into the fresh frame")
	_check(player.observed_support_transfers == transfers_before + 1, "causal world edit performs exactly one explicit actor frame transfer")
	_check(player.observed_ground_acquisitions == acquisitions_before, "causal world edit does not fake continuity through later ground reacquisition")
	_check(player.global_position.distance_to(actor_world_before) < 0.0001, "actor has no world-space teleport at the authority handoff")

	var source_origin: Vector3i = result.get("source_origin", Vector3i.ZERO)
	var target_witness_cell := witness_cell - source_origin
	_check(causal_world.lineage.get_lineage(witness_cell) == MatterLineageMap.NONE, "exact supporting lineage leaves canonical authority")
	if target != null:
		_check(target.lineage.get_lineage(target_witness_cell) == witness_token, "exact supporting lineage now belongs to detached target")

	var target_provider := target.get_active_provider() if target != null else null
	var target_start_y := target_provider.global_position.y if target_provider != null else 0.0
	var actor_start_y := player.global_position.y
	await _advance_frames(RIDE_FRAMES)
	var target_fall := target_start_y - (target_provider.global_position.y if target_provider != null else target_start_y)
	var actor_fall := actor_start_y - player.global_position.y
	_check(target_fall > 0.05, "newly detached world Matter visibly enters solver-driven fall")
	_check(actor_fall > 0.05, "player visibly rides the causally detached world fragment")
	_check(player.grounded and player.support_space == target, "player remains supported by the same detached Matter while it falls")
	_check(player.observed_ground_acquisitions == acquisitions_before, "ride continuity never falls back to reacquisition")

	print(
		"W0D_RECOVERY_CAUSAL_LOOP_METRIC bridge=%s witness=%s token=%d active_before=1 active_after=%d target_fall=%.6f actor_fall=%.6f transfers=%d acquisitions=%d"
		% [
			str(bridge_cell),
			str(witness_cell),
			witness_token,
			registry.get_active_count(),
			target_fall,
			actor_fall,
			player.observed_support_transfers - transfers_before,
			player.observed_ground_acquisitions - acquisitions_before,
		]
	)

	_finish(root)


func _advance_frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame
		await process_frame


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _finish(root: Node) -> void:
	_finished = true
	if root != null and is_instance_valid(root):
		root.free()
	if _failures.is_empty():
		print("W0D_RECOVERY_CAUSAL_LOOP_PASS: Owner-facing recovery begins as one ordinary editable world; a normal destructive edit creates dynamic Matter and carries the actor with its exact supporting lineage.")
		quit(0)
		return
	for failure in _failures:
		push_error("W0D_RECOVERY_CAUSAL_LOOP_FAIL: " + failure)
	quit(1)
