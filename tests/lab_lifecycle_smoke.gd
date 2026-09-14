extends SceneTree

const PROBE_CELL := Vector3i(3, 1, 3)
const MATERIAL_CELL := Vector3i(6, 1, 5)
const ACTIVE_FRAMES := 8
const STATIC_OBSERVE_FRAMES := 8

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://lab/main.tscn") as PackedScene
	_check(packed != null, "interactive LAB scene loads")
	if packed == null:
		_finish()
		return

	var lab := packed.instantiate()
	get_root().add_child(lab)
	await process_frame

	var space := lab.get_node_or_null("InteractiveLocalMatterSpace") as LocalMatterSpace
	_check(space != null, "LAB boots through LocalMatterSpace rather than owning a provider directly")
	if space == null:
		_finish()
		return

	var logical_space_id := space.get_instance_id()
	var volume := space.volume
	var lineage := space.lineage
	var initial_provider := space.get_active_provider()
	_check(initial_provider is MatterRepresentation, "LAB boots with the shared static provider path")
	_check(space.get_provider_node_count() == 1, "LAB boot has exactly one active provider")
	_check(volume != null and lineage != null, "LAB exposes one authoritative Matter + lineage pair through LocalMatterSpace")
	if volume == null or lineage == null or not initial_provider is MatterRepresentation:
		_finish()
		return

	var initial_static_id := initial_provider.get_instance_id()
	var initial_probe_token := lineage.get_lineage(PROBE_CELL)
	var initial_material_token := lineage.get_lineage(MATERIAL_CELL)
	var initial_solid_count := volume.count_solid()

	lab.call("_activate_dynamic")
	_check(space.is_transition_pending(), "LAB A action queues shared static→dynamic transition")
	await space.provider_transition_committed

	var dynamic_provider := space.get_active_provider()
	_check(dynamic_provider is ConstructBody, "LAB A action installs ConstructBody through shared lifecycle")
	if not dynamic_provider is ConstructBody:
		_finish()
		return
	var body := dynamic_provider as ConstructBody
	var dynamic_id := body.get_instance_id()
	var dynamic_commit_transform := body.global_transform
	_check(space.get_instance_id() == logical_space_id, "LAB activation preserves logical Space identity")
	_check(dynamic_id != initial_static_id, "LAB activation really changes provider identity")
	_check(space.volume == volume and space.lineage == lineage, "LAB activation retains authoritative Matter + lineage references")
	_check(space.get_provider_node_count() == 1, "LAB activation ends with exactly one provider")

	await process_frame
	var first_server_transform := PhysicsServer3D.body_get_state(
		body.get_rid(),
		PhysicsServer3D.BODY_STATE_TRANSFORM
	) as Transform3D
	var first_server_displacement := first_server_transform.origin.distance_to(dynamic_commit_transform.origin)
	_check(first_server_displacement > 0.005, "LAB dynamic provider participates in its first solver step")

	await physics_frame
	var synced_server_transform := PhysicsServer3D.body_get_state(
		body.get_rid(),
		PhysicsServer3D.BODY_STATE_TRANSFORM
	) as Transform3D
	var first_node_sync_gap := synced_server_transform.origin.distance_to(body.global_position)
	_check(first_node_sync_gap < 0.00001, "LAB Node visibility converges to PhysicsServer state on the next sync")

	for _frame in range(ACTIVE_FRAMES):
		await physics_frame
		await process_frame
	var dynamic_translation := body.global_position.distance_to(dynamic_commit_transform.origin)
	_check(dynamic_translation > 0.1, "LAB visibly advances while dynamic")

	var dynamic_id_before_mutation := body.get_instance_id()
	lab.call("_toggle_probe_cell")
	_check(volume.get_cell(PROBE_CELL) == CellVolume.EMPTY, "LAB M removes Matter through shared mutation authority")
	_check(lineage.get_lineage(PROBE_CELL) == MatterLineageMap.NONE, "LAB M removal retires lineage")
	_check(volume.count_solid() == initial_solid_count - 1, "LAB M removal changes authoritative occupancy exactly once")
	_check(space.get_active_provider().get_instance_id() == dynamic_id_before_mutation, "LAB dynamic mutation rebuilds without replacing provider identity")

	lab.call("_toggle_probe_cell")
	var recreated_probe_token := lineage.get_lineage(PROBE_CELL)
	_check(volume.get_cell(PROBE_CELL) != CellVolume.EMPTY, "LAB M recreates Matter through shared mutation authority")
	_check(recreated_probe_token != MatterLineageMap.NONE and recreated_probe_token != initial_probe_token, "LAB M recreation receives fresh lineage")
	_check(volume.count_solid() == initial_solid_count, "LAB M recreation restores occupancy")

	var material_before := volume.get_cell(MATERIAL_CELL)
	lab.call("_cycle_retained_material")
	var material_after := volume.get_cell(MATERIAL_CELL)
	_check(material_after != material_before, "LAB C mutates retained Matter material")
	_check(lineage.get_lineage(MATERIAL_CELL) == initial_material_token, "LAB C retains Matter lineage across material mutation")
	_check(space.get_active_provider().get_instance_id() == dynamic_id_before_mutation, "LAB C rebuild remains on the same dynamic provider")

	lab.call("_freeze_to_static")
	_check(space.is_transition_pending(), "LAB F action queues shared dynamic→static transition")
	await space.provider_transition_committed

	var final_provider := space.get_active_provider()
	_check(final_provider is MatterRepresentation, "LAB F action installs static MatterRepresentation through shared lifecycle")
	if not final_provider is MatterRepresentation:
		_finish()
		return
	var final_static := final_provider as MatterRepresentation
	var final_static_id := final_static.get_instance_id()
	_check(space.get_instance_id() == logical_space_id, "LAB freeze preserves logical Space identity")
	_check(final_static_id != dynamic_id and final_static_id != initial_static_id, "LAB freeze installs a genuinely fresh static provider")
	_check(space.volume == volume and space.lineage == lineage, "LAB freeze retains one authoritative Matter + lineage pair")
	_check(space.get_provider_node_count() == 1, "LAB freeze ends with exactly one provider")

	var static_pose := final_static.global_transform
	var max_static_drift := 0.0
	for _frame in range(STATIC_OBSERVE_FRAMES):
		await physics_frame
		await process_frame
		max_static_drift = max(max_static_drift, _transform_gap(static_pose, final_static.global_transform))
	_check(max_static_drift < 0.00001, "LAB static provider remains stable after dynamic motion")

	var static_id_before_edit := final_static.get_instance_id()
	var pre_static_edit_token := lineage.get_lineage(PROBE_CELL)
	lab.call("_toggle_probe_cell")
	_check(volume.get_cell(PROBE_CELL) == CellVolume.EMPTY, "LAB remains editable after freeze")
	_check(lineage.get_lineage(PROBE_CELL) == MatterLineageMap.NONE, "post-freeze LAB removal retires lineage")
	_check(final_static.get_instance_id() == static_id_before_edit, "post-freeze LAB edit rebuilds without replacing static provider")
	lab.call("_toggle_probe_cell")
	var post_static_recreate_token := lineage.get_lineage(PROBE_CELL)
	_check(post_static_recreate_token != MatterLineageMap.NONE and post_static_recreate_token != pre_static_edit_token, "post-freeze LAB recreation receives another fresh lineage")

	await process_frame
	var hud := lab.get_node_or_null("HUD/Panel/Label") as Label
	_check(hud != null, "LAB retains visible lifecycle telemetry HUD")
	if hud != null:
		_check(hud.text.contains("provider: STATIC / MatterRepresentation"), "HUD reports current static provider authority")
		_check(hud.text.contains("transitions: 2"), "HUD reports both provider transitions")
		_check(hud.text.contains("PhysicsServer→Node gap: n/a"), "HUD distinguishes static provider from dynamic server telemetry")

	print(
		"LAB_LIFECYCLE_SMOKE_METRIC logical_space_id=%d initial_static_id=%d dynamic_id=%d final_static_id=%d first_server_displacement=%.10f first_node_sync_gap=%.10f dynamic_translation=%.8f max_static_drift=%.10f initial_probe_token=%d recreated_probe_token=%d post_static_recreate_token=%d final_cells=%d"
		% [
			logical_space_id,
			initial_static_id,
			dynamic_id,
			final_static_id,
			first_server_displacement,
			first_node_sync_gap,
			dynamic_translation,
			max_static_drift,
			initial_probe_token,
			recreated_probe_token,
			post_static_recreate_token,
			volume.count_solid(),
		]
	)

	lab.free()
	_finish()


func _transform_gap(a: Transform3D, b: Transform3D) -> float:
	return max(a.origin.distance_to(b.origin), _basis_axis_error(a.basis.orthonormalized(), b.basis.orthonormalized()))


func _basis_axis_error(a: Basis, b: Basis) -> float:
	return max(a.x.distance_to(b.x), max(a.y.distance_to(b.y), a.z.distance_to(b.z)))


func _finish() -> void:
	if _failures.is_empty():
		print("LAB_LIFECYCLE_SMOKE_PASS: the actual interactive LAB scene consumed the shared LocalMatterSpace lifecycle for activation, motion, live mutation, freeze and post-freeze editing without owning replacement orchestration.")
		quit(0)
		return
	for failure in _failures:
		push_error("LAB_LIFECYCLE_SMOKE_FAIL: " + failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
