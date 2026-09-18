extends "res://p1/main.gd"

# Bounded post-Owner-failure recovery consumer.
#
# The old p1/main.tscn remains a mechanical/evidence fixture. This consumer
# deliberately changes the Owner-facing composition without replacing the
# defended Matter/Space/actor substrate beneath it.
#
# W0D removes the temporary pre-authored moving-demo Space. Owner-facing motion
# now has to emerge from ordinary world Matter: destructive topology can detach
# a previously canonical portion into a fresh dynamic frame.

const RECOVERY_WORLD_SIZE := Vector3i(32, 8, 32)
const RECOVERY_WORLD_ORIGIN := Vector3(-16.0, -4.0, -16.0)
const RECOVERY_PRESENTATION_CHUNK_EDGE := 7
const RECOVERY_CAUSAL_BRIDGE_CELL := Vector3i(14, 5, 16)
const RECOVERY_CAUSAL_SUPPORT_CELL := Vector3i(18, 5, 17)
const RECOVERY_BOUNDED_POLICY_BUDGET := 64
const RECOVERY_ANCHOR_CELLS: Array[Vector3i] = [
	Vector3i(1, 0, 1),
	Vector3i(30, 0, 1),
	Vector3i(1, 0, 30),
	Vector3i(30, 0, 30),
]

var _recovery_world_space: W0AuthorityPartitionSpace
# Compatibility getter remains so old consumers can prove that the special
# startup mover is gone rather than silently losing the symbol.
var _recovery_demo_space: LocalMatterSpace
var _recovery_anchor_tokens: Dictionary = {}
var _pending_causal_actor_handoff := false
var _pending_causal_actor_local_center := Vector3.ZERO
var _pending_causal_actor_witness_cell := Vector3i.ZERO
var _pending_causal_actor_witness_token := MatterLineageMap.NONE
var _last_recovery_policy_usec := 0
var _last_recovery_partition_request_usec := 0
var _last_recovery_partition_publication_usec := 0
var _last_recovery_publication_timing: Dictionary = {}
var _recovery_anchor_cells_current: Array[Vector3i] = []
var _recovery_source_known_single_connected := false
var _pending_recovery_source_connected_after_partition := false
var _last_recovery_policy_mode := "none"
var _last_recovery_policy_visited_cells := 0


func _ready() -> void:
	super._ready()
	# The recovery surface uses direct mouse semantics through
	# P1RecoveryDirectEdit instead of the old modal E + LMB consumer path.
	_interactor.set_process_unhandled_input(false)
	_last_event = "recovery: edit ordinary Matter; detached Matter becomes physical"
	if OS.get_cmdline_user_args().has("--c0-artifact-baseline"):
		call_deferred("_run_c0_artifact_baseline")


func get_recovery_world_space() -> LocalMatterSpace:
	return _recovery_world_space


func get_recovery_demo_space() -> LocalMatterSpace:
	return _recovery_demo_space


func get_recovery_causal_bridge_cell_for_test() -> Vector3i:
	return RECOVERY_CAUSAL_BRIDGE_CELL


func get_last_recovery_policy_usec() -> int:
	return _last_recovery_policy_usec


func get_last_recovery_policy_mode() -> String:
	return _last_recovery_policy_mode


func get_last_recovery_policy_visited_cells() -> int:
	return _last_recovery_policy_visited_cells


func is_recovery_source_known_single_connected_for_test() -> bool:
	return _recovery_source_known_single_connected


func get_last_recovery_partition_request_usec() -> int:
	return _last_recovery_partition_request_usec


func get_last_recovery_partition_publication_usec() -> int:
	return _last_recovery_partition_publication_usec


func get_last_recovery_publication_timing() -> Dictionary:
	return _last_recovery_publication_timing.duplicate(true)


func _initialize_space() -> void:
	_clear_pending_storage_place()
	_clear_pending_causal_actor_handoff()
	_pending_recovery_source_connected_after_partition = false
	_recovery_anchor_cells_current.clear()
	for anchor_cell in RECOVERY_ANCHOR_CELLS:
		_recovery_anchor_cells_current.append(anchor_cell)
	_registry.clear()
	for child in $Spaces.get_children():
		child.free()

	_recovery_demo_space = null
	_recovery_world_space = _build_world_matter_space()
	# Presentation granularity is intentionally decoupled from physics-provider
	# granularity. Edge 7 won the spatial/lifecycle tradeoff while the static
	# physics provider remains edge 8 to avoid collision-shape inflation.
	var surface_grid := get_node_or_null("P1MatterSurfaceGrid") as P1MatterSurfaceGrid
	var state_presentation := get_node_or_null("P1MatterStatePresentation") as P1MatterStatePresentation
	if surface_grid != null:
		surface_grid.chunk_edge_override = RECOVERY_PRESENTATION_CHUNK_EDGE
	if state_presentation != null:
		state_presentation.chunk_edge_override = RECOVERY_PRESENTATION_CHUNK_EDGE
	_recovery_source_known_single_connected = (
		MatterTopology.extract_connected_cell_components(_recovery_world_space.volume).size() == 1
	)
	_recovery_world_space.authority_partition_committed.connect(_on_recovery_authority_partition_committed)
	_registry.register_space(_recovery_world_space)
	_focus_space = _recovery_world_space
	_last_event = "one ordinary causal Matter world initialized"


func _build_world_matter_space() -> W0AuthorityPartitionSpace:
	var volume := CellVolume.new(RECOVERY_WORLD_SIZE)
	# The visible terrain is authoritative Matter all the way down. A shallow pit
	# is carved from that same connected mass so a detached shelf has real room to
	# fall without inventing a second terrain ontology or a hidden catcher plane.
	volume.fill_box(Vector3i.ZERO, Vector3i(32, 4, 32), CellVolume.SOLID)
	for x in range(12, 23):
		for y in range(1, 4):
			for z in range(12, 23):
				volume.set_cell(Vector3i(x, y, z), CellVolume.EMPTY)

	# Low authored relief keeps the world readable as terrain rather than a blank
	# laboratory plane. CellVolume.fill_box uses an exclusive end coordinate.
	# Every piece remains ordinary editable Matter in this same canonical Space.
	volume.fill_box(Vector3i(3, 4, 4), Vector3i(8, 5, 9), CellVolume.SOLID)
	volume.fill_box(Vector3i(24, 4, 20), Vector3i(29, 6, 24), CellVolume.SOLID)
	volume.fill_box(Vector3i(5, 4, 24), Vector3i(11, 5, 27), CellVolume.SOLID)
	volume.fill_box(Vector3i(23, 4, 5), Vector3i(27, 5, 9), CellVolume.SOLID)

	# The causal shelf is still ordinary world Matter at startup. A solid mesa on
	# the west rim reaches the shelf height, then a narrow three-cell material neck
	# crosses the visible pit to a broad terrain slab. Removing the outer neck cell
	# changes topology; only then does the slab acquire a fresh dynamic owner.
	volume.fill_box(Vector3i(8, 4, 14), Vector3i(12, 6, 19), CellVolume.SOLID)
	volume.fill_box(Vector3i(12, 5, 16), Vector3i(15, 6, 17), CellVolume.SOLID)
	volume.fill_box(Vector3i(15, 5, 14), Vector3i(21, 6, 20), CellVolume.SOLID)

	var lineage := MatterLineageMap.new(RECOVERY_WORLD_SIZE)
	var issuer := MatterLineageIssuer.new(1200001)
	for cell in _occupied_cells(volume):
		lineage.set_lineage(cell, issuer.allocate())

	var space := W0AuthorityPartitionSpace.new()
	space.name = "RecoveryWorldMatterSpace"
	space.lineage_issuer = issuer
	space.mass_per_cell = 1.0
	# Recovery WORLD stays one logical authority while its static provider uses
	# edge-8 local derived chunks. Detached dynamic targets retain ConstructBody.
	space.static_chunk_edge = 8
	# The canonical source remains static, but W0 targets copy these runtime
	# settings. Gravity is therefore a property of the detached Matter regime,
	# not an artificial launch authored by the recovery scene.
	space.dynamic_gravity_scale = 1.0
	space.dynamic_linear_damp = 0.02
	space.dynamic_angular_damp = 0.02
	space.dynamic_can_sleep = false
	$Spaces.add_child(space)
	space.initialize_static(
		volume,
		lineage,
		Transform3D(Basis.IDENTITY, RECOVERY_WORLD_ORIGIN)
	)

	_recovery_anchor_tokens.clear()
	for anchor_cell in RECOVERY_ANCHOR_CELLS:
		var token: int = lineage.get_lineage(anchor_cell)
		assert(token != MatterLineageMap.NONE, "Recovery canonical anchor must be retained Matter")
		_recovery_anchor_tokens[token] = true
	return space


func _find_safe_spawn_local(space: LocalMatterSpace) -> Vector3:
	if (
		space == _recovery_world_space
		and space.volume != null
		and space.volume.in_bounds(RECOVERY_CAUSAL_SUPPORT_CELL)
		and space.volume.get_cell(RECOVERY_CAUSAL_SUPPORT_CELL) != CellVolume.EMPTY
	):
		# Spawn on the ordinary terrain shelf, away from the narrow neck, so the
		# first causal experiment can carry the actor without a special demo object.
		return Vector3(
			float(RECOVERY_CAUSAL_SUPPORT_CELL.x) + 0.5,
			float(RECOVERY_CAUSAL_SUPPORT_CELL.y) + 1.0 + _player.height * 0.5 + 0.04,
			float(RECOVERY_CAUSAL_SUPPORT_CELL.z) + 0.5
		)
	return super._find_safe_spawn_local(space)


func _toggle_focused_space_state() -> bool:
	if _focus_space == _recovery_world_space:
		_last_event = "world Matter stays canonical; detach Matter by editing support"
		return false
	return super._toggle_focused_space_state()


func _apply_focused_central_impulse(local_impulse: Vector3) -> bool:
	if _focus_space == _recovery_world_space:
		_last_event = "world Matter is not a controllable rigid body; detach Matter first"
		return false
	return super._apply_focused_central_impulse(local_impulse)


func _apply_focused_torque_impulse(local_impulse: Vector3) -> bool:
	if _focus_space == _recovery_world_space:
		_last_event = "world Matter is not a controllable rigid body; detach Matter first"
		return false
	return super._apply_focused_torque_impulse(local_impulse)


func _on_edit_applied(space: LocalMatterSpace, cell: Vector3i, mode: int, split_queued: bool) -> void:
	_last_recovery_policy_usec = 0
	_last_recovery_partition_request_usec = 0
	_last_recovery_policy_mode = "none"
	_last_recovery_policy_visited_cells = 0
	super._on_edit_applied(space, cell, mode, split_queued)
	if space != _recovery_world_space or _recovery_world_space == null:
		return

	if mode == P1MatterInteractor.EditMode.PLACE:
		_last_recovery_policy_mode = "place_connectivity_update"
		if _recovery_source_known_single_connected:
			var attached_to_source := false
			for offset in MatterTopology.AXIAL_NEIGHBORS:
				if _recovery_world_space.volume.get_cell(cell + offset) != CellVolume.EMPTY:
					attached_to_source = true
					break
			_recovery_source_known_single_connected = attached_to_source
		return
	if mode != P1MatterInteractor.EditMode.REMOVE:
		return
	if _recovery_world_space.is_authority_partition_pending():
		_last_event = "causal detach already pending"
		return

	_pending_recovery_source_connected_after_partition = false
	var detached_components: Array = []
	var anchored_component_count := 0
	var bounded_was_proven := false

	if _recovery_source_known_single_connected:
		var live_anchor_cells := _live_recovery_anchor_cells()
		if not live_anchor_cells.is_empty():
			var bounded_started_usec := Time.get_ticks_usec()
			var bounded := MatterTopology.prove_partition_after_single_removal_from_connected_source(
				_recovery_world_space.volume,
				cell,
				live_anchor_cells,
				RECOVERY_BOUNDED_POLICY_BUDGET
			)
			_last_recovery_policy_usec = Time.get_ticks_usec() - bounded_started_usec
			_last_recovery_policy_visited_cells = int(bounded.get("visited_cells", 0))
			anchored_component_count = int(bounded.get("anchored_component_count", 0))
			if bool(bounded.get("proven", false)) and anchored_component_count == 1:
				bounded_was_proven = true
				detached_components = bounded.get("detached_components", [])
				_last_recovery_policy_mode = (
					"bounded_connected"
					if detached_components.is_empty()
					else "bounded_partition"
				)

	if not bounded_was_proven:
		var policy_started_usec := Time.get_ticks_usec()
		var policy: Dictionary = W0AnchoredDetachmentPolicy.evaluate(
			_recovery_world_space.volume,
			_recovery_world_space.lineage,
			_recovery_anchor_tokens
		)
		_last_recovery_policy_usec = Time.get_ticks_usec() - policy_started_usec
		_last_recovery_policy_visited_cells = _recovery_world_space.volume.count_solid()
		_last_recovery_policy_mode = (
			"full_policy_fallback"
			if _recovery_source_known_single_connected
			else "full_policy"
		)
		if not bool(policy.get("valid", false)):
			_recovery_source_known_single_connected = false
			_last_event = "detach policy fail-closed: %s" % str(policy.get("reason", "invalid"))
			return
		var anchored_components: Array = policy.get("anchored_components", [])
		anchored_component_count = anchored_components.size()
		detached_components = policy.get("detached_components", [])

	if detached_components.is_empty():
		# Whether proven boundedly or by the full policy, one anchored component
		# means this post-removal source remains a valid connected precondition for
		# the next single-cell proof.
		_recovery_source_known_single_connected = anchored_component_count == 1
		return

	# The post-removal source is currently disconnected until a successful
	# authority partition removes the detached component from canonical WORLD.
	_recovery_source_known_single_connected = false
	if detached_components.size() != 1:
		_last_event = "detach deferred: %d independent components" % detached_components.size()
		return

	_request_recovery_detach(
		detached_components[0],
		anchored_component_count == 1
	)


func _request_recovery_detach(
	component_variant: Variant,
	source_connected_after_partition: bool
) -> void:
	var selected: Array[Vector3i] = []
	for candidate in component_variant:
		selected.append(candidate)

	_prepare_causal_actor_handoff(selected)
	var request_started_usec := Time.get_ticks_usec()
	var accepted := _recovery_world_space.request_authority_partition(
		selected,
		LocalMatterSpace.ProviderKind.DYNAMIC
	)
	_last_recovery_partition_request_usec = Time.get_ticks_usec() - request_started_usec
	if not accepted:
		_pending_recovery_source_connected_after_partition = false
		_clear_pending_causal_actor_handoff()
		_last_event = "causal authority transfer rejected"
		return
	_pending_recovery_source_connected_after_partition = source_connected_after_partition
	_last_event = "Matter disconnected → dynamic ownership queued"


func _live_recovery_anchor_cells() -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	if _recovery_world_space == null or _recovery_world_space.volume == null or _recovery_world_space.lineage == null:
		return result
	for anchor_cell in _recovery_anchor_cells_current:
		if not _recovery_world_space.volume.in_bounds(anchor_cell):
			continue
		if _recovery_world_space.volume.get_cell(anchor_cell) == CellVolume.EMPTY:
			continue
		var token := _recovery_world_space.lineage.get_lineage(anchor_cell)
		if token != MatterLineageMap.NONE and _recovery_anchor_tokens.has(token):
			result.append(anchor_cell)
	return result

func _prepare_causal_actor_handoff(selected_cells: Array[Vector3i]) -> void:
	_clear_pending_causal_actor_handoff()
	if not _player.grounded or _player.support_space != _recovery_world_space:
		return
	var witness: Dictionary = _player.get_support_contact_witness()
	if not bool(witness.get("valid", false)):
		return
	if int(witness.get("space_id", 0)) != _recovery_world_space.get_instance_id():
		return
	var witness_cell: Vector3i = witness.get("cell", Vector3i(-1, -1, -1))
	if not selected_cells.has(witness_cell):
		return
	var witness_token: int = _recovery_world_space.lineage.get_lineage(witness_cell)
	if witness_token == MatterLineageMap.NONE:
		return

	_pending_causal_actor_handoff = true
	_pending_causal_actor_local_center = _player.support_local_center
	_pending_causal_actor_witness_cell = witness_cell
	_pending_causal_actor_witness_token = witness_token


func _on_recovery_authority_partition_committed(result: Dictionary) -> void:
	var publication_started_usec := Time.get_ticks_usec()
	_recovery_source_known_single_connected = _pending_recovery_source_connected_after_partition
	_pending_recovery_source_connected_after_partition = false
	_last_recovery_publication_timing = {}
	var target := result.get("target_space") as LocalMatterSpace
	if target == null or not is_instance_valid(target):
		_clear_pending_causal_actor_handoff()
		_last_event = "causal transfer committed without live target"
		_last_recovery_partition_publication_usec = Time.get_ticks_usec() - publication_started_usec
		_last_recovery_publication_timing = {
			"actor_handoff_usec": 0,
			"source_grid_usec": 0,
			"source_state_usec": 0,
			"registry_usec": 0,
			"focus_camera_usec": 0,
			"total_usec": _last_recovery_partition_publication_usec,
		}
		return

	var actor_started_usec := Time.get_ticks_usec()
	var actor_transferred := false
	if _pending_causal_actor_handoff:
		var source_origin: Vector3i = result.get("source_origin", Vector3i.ZERO)
		var mapped_witness_cell: Vector3i = _pending_causal_actor_witness_cell - source_origin
		var target_owns_witness := (
			target.lineage != null
			and target.lineage.in_bounds(mapped_witness_cell)
			and target.lineage.get_lineage(mapped_witness_cell) == _pending_causal_actor_witness_token
		)
		if target_owns_witness:
			var mapped_actor_local := _pending_causal_actor_local_center - Vector3(source_origin)
			actor_transferred = _player.transfer_support_frame(
				target.get_active_provider(),
				mapped_actor_local
			)
	var actor_handoff_usec := Time.get_ticks_usec() - actor_started_usec

	# The source authority already committed above. Recovery WORLD uses chunked
	# derived representation, so update exactly the transferred source cells
	# before registry publication. This advances presentation signatures to the
	# new source revision; active_spaces_changed can then add the new target
	# without forcing a second full WORLD rebuild.
	var transferred_source_cells: Array[Vector3i] = []
	for candidate in result.get("source_cells", []):
		transferred_source_cells.append(candidate)
	# If the actor successfully moved with detached Matter, WORLD ceases to be
	# focus in this same publication transaction. Set the authoritative consumer
	# focus before active_spaces_changed so state presentation transitions to the
	# target instead of rebuilding a source crown that would be discarded.
	if actor_transferred:
		_focus_space = target
	else:
		_focus_space = _recovery_world_space

	var source_grid_usec := 0
	var source_state_usec := 0
	if not transferred_source_cells.is_empty():
		var grid := get_node_or_null("P1MatterSurfaceGrid") as P1MatterSurfaceGrid
		var state_presentation := get_node_or_null("P1MatterStatePresentation") as P1MatterStatePresentation
		if grid != null:
			var grid_started_usec := Time.get_ticks_usec()
			grid.refresh_cells(_recovery_world_space, transferred_source_cells)
			source_grid_usec = Time.get_ticks_usec() - grid_started_usec
		if state_presentation != null:
			var state_started_usec := Time.get_ticks_usec()
			state_presentation.refresh_cells(
				_recovery_world_space,
				transferred_source_cells,
				not actor_transferred
			)
			source_state_usec = Time.get_ticks_usec() - state_started_usec

	# Registry publication happens only after the complete authority commit,
	# optional exact actor handoff and source derived-state catch-up, so
	# presentation consumers never observe a half-owned frame.
	var registry_started_usec := Time.get_ticks_usec()
	_registry.register_space(target)
	var registry_usec := Time.get_ticks_usec() - registry_started_usec

	var focus_camera_started_usec := Time.get_ticks_usec()
	_clear_pending_causal_actor_handoff()
	_refresh_camera_context()
	var focus_camera_usec := Time.get_ticks_usec() - focus_camera_started_usec
	_last_event = (
		"world Matter detached → riding fresh dynamic Space"
		if actor_transferred
		else "world Matter detached → fresh dynamic Space"
	)
	_last_recovery_partition_publication_usec = Time.get_ticks_usec() - publication_started_usec
	_last_recovery_publication_timing = {
		"actor_handoff_usec": actor_handoff_usec,
		"source_grid_usec": source_grid_usec,
		"source_state_usec": source_state_usec,
		"registry_usec": registry_usec,
		"focus_camera_usec": focus_camera_usec,
		"total_usec": _last_recovery_partition_publication_usec,
	}


func _on_registry_storage_rebased(space: LocalMatterSpace, report: Dictionary) -> void:
	super._on_registry_storage_rebased(space, report)
	if space != _recovery_world_space:
		return
	var local_shift: Vector3i = report.get("local_shift", Vector3i.ZERO)
	for index in range(_recovery_anchor_cells_current.size()):
		_recovery_anchor_cells_current[index] += local_shift


func _clear_pending_causal_actor_handoff() -> void:
	_pending_causal_actor_handoff = false
	_pending_causal_actor_local_center = Vector3.ZERO
	_pending_causal_actor_witness_cell = Vector3i.ZERO
	_pending_causal_actor_witness_token = MatterLineageMap.NONE


func _refresh_camera_context() -> void:
	var context_space: LocalMatterSpace = _player.support_space if _is_live_space(_player.support_space) else _focus_space
	if not _is_live_space(context_space):
		context_space = _registry.find_nearest_space(_player.global_position)
	if not _is_live_space(context_space):
		_camera_rig.set_context_target(null)
		return

	_focus_space = context_space
	if context_space == _recovery_world_space:
		# A large ordinary world should not make the camera zoom out merely to frame
		# the whole storage extent. The world already supplies visual context.
		_camera_rig.set_context_target(null)
		return

	_camera_rig.set_context_target(
		context_space.get_active_provider(),
		context_space.get_content_center_local(),
		_space_planar_radius(context_space)
	)


# Convergence C0 exact-artifact qualification. This is intentionally embedded
# behind an explicit user argument so the exported Owner scene itself, not a
# source-only test runner, must reproduce the protected Spark causal loop.
func _run_c0_artifact_baseline() -> void:
	var failures: Array[String] = []
	await _c0_advance_frames(24)

	var world := _recovery_world_space
	var registry := _registry
	var player := _player
	var interactor := _interactor
	_c0_check(world != null and is_instance_valid(world), "ordinary WORLD Matter exists", failures)
	_c0_check(registry != null and registry.get_active_count() == 1, "startup has one canonical Matter world", failures)
	_c0_check(_recovery_demo_space == null, "startup has no pre-authored mover", failures)
	_c0_check(player != null and player.grounded and player.support_space == world, "actor begins supported by ordinary WORLD Matter", failures)
	if not failures.is_empty():
		_c0_finish(failures)
		return

	var witness: Dictionary = player.get_support_contact_witness()
	_c0_check(bool(witness.get("valid", false)), "actor has exact Matter support witness", failures)
	if not bool(witness.get("valid", false)):
		_c0_finish(failures)
		return
	var witness_cell: Vector3i = witness.get("cell", Vector3i(-999, -999, -999))
	var witness_token: int = world.lineage.get_lineage(witness_cell)
	_c0_check(witness_token != MatterLineageMap.NONE, "support witness owns live Matter lineage", failures)
	var actor_world_before := player.global_position

	_c0_check(
		interactor.apply_edit_to_cell(world, RECOVERY_CAUSAL_BRIDGE_CELL, P1MatterInteractor.EditMode.REMOVE),
		"ordinary Matter bridge can be removed through production mutation authority",
		failures
	)
	_c0_check(world.volume.get_cell(RECOVERY_CAUSAL_BRIDGE_CELL) == CellVolume.EMPTY, "causal bridge Matter is destroyed", failures)
	_c0_check(world.is_authority_partition_pending(), "topology consequence queues authority repartition", failures)
	if not world.is_authority_partition_pending():
		_c0_finish(failures)
		return

	await world.authority_partition_committed
	var result := world.get_last_authority_partition_result()
	var target := result.get("target_space") as LocalMatterSpace
	_c0_check(target != null and is_instance_valid(target), "detached Matter receives a fresh live owner", failures)
	if target == null or not is_instance_valid(target):
		_c0_finish(failures)
		return

	var actor_handoff_error := player.global_position.distance_to(actor_world_before)
	var source_origin: Vector3i = result.get("source_origin", Vector3i.ZERO)
	var target_witness_cell := witness_cell - source_origin
	_c0_check(registry.get_active_count() == 2, "canonical WORLD and detached Matter coexist", failures)
	_c0_check(world.get_provider_kind() == LocalMatterSpace.ProviderKind.STATIC, "canonical WORLD remains static", failures)
	_c0_check(target.get_provider_kind() == LocalMatterSpace.ProviderKind.DYNAMIC, "detached Matter becomes dynamic without launch ceremony", failures)
	_c0_check(player.grounded and player.support_space == target, "actor follows supporting Matter into derived frame", failures)
	_c0_check(actor_handoff_error < 0.0001, "actor handoff is world-continuous", failures)
	_c0_check(world.lineage.get_lineage(witness_cell) == MatterLineageMap.NONE, "support lineage leaves canonical authority", failures)
	_c0_check(
		target.lineage.in_bounds(target_witness_cell)
		and target.lineage.get_lineage(target_witness_cell) == witness_token,
		"same supporting Matter lineage survives under detached authority",
		failures
	)

	var provider := target.get_active_provider()
	var target_start_y := provider.global_position.y if provider != null else 0.0
	var actor_start_y := player.global_position.y
	await _c0_advance_frames(16)
	var target_fall := target_start_y - (provider.global_position.y if provider != null else target_start_y)
	var actor_fall := actor_start_y - player.global_position.y
	_c0_check(target_fall > 0.05, "gravity moves causally detached Matter", failures)
	_c0_check(actor_fall > 0.05, "actor rides the same falling Matter", failures)
	_c0_check(player.grounded and player.support_space == target, "support relation persists during motion", failures)

	# Protect the experiential Spark property that dynamic Matter remains editable.
	# Use a known corner of the detached authored shelf, mapped through the exact
	# authority-transfer origin rather than treating local coordinates as identity.
	var moving_edit_source_cell := Vector3i(15, 5, 14)
	var moving_edit_cell := moving_edit_source_cell - source_origin
	_c0_check(target.volume.in_bounds(moving_edit_cell), "moving edit target maps inside detached Matter", failures)
	var moving_edit_token := (
		target.lineage.get_lineage(moving_edit_cell)
		if target.volume.in_bounds(moving_edit_cell)
		else MatterLineageMap.NONE
	)
	_c0_check(moving_edit_token != MatterLineageMap.NONE, "moving edit target owns Matter lineage", failures)
	if moving_edit_token != MatterLineageMap.NONE:
		_c0_check(
			interactor.apply_edit_to_cell(target, moving_edit_cell, P1MatterInteractor.EditMode.REMOVE),
			"moving detached Matter accepts a live edit",
			failures
		)
		_c0_check(target.lineage.get_lineage(moving_edit_cell) == MatterLineageMap.NONE, "moving edit destroys exactly that Matter identity", failures)
	await _c0_advance_frames(3)
	_c0_check(is_instance_valid(target) and not target.is_retired(), "edited detached Matter remains part of the living world", failures)
	_c0_check(target.get_provider_kind() == LocalMatterSpace.ProviderKind.DYNAMIC, "moving edit does not collapse physical autonomy", failures)

	print(
		"C0_EXPORTED_SPARK_BASELINE_METRIC target_fall=%.6f actor_fall=%.6f handoff_error=%.8f active_spaces=%d"
		% [target_fall, actor_fall, actor_handoff_error, registry.get_active_count()]
	)
	_c0_finish(failures)


func _c0_advance_frames(count: int) -> void:
	for _frame in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame


func _c0_check(condition: bool, description: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(description)


func _c0_finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("C0_EXPORTED_SPARK_BASELINE_PASS: exact exported Owner scene reproduces ordinary Matter cut -> derived dynamic autonomy -> continuous actor ride -> live moving edit.")
		get_tree().quit(0)
		return
	for failure in failures:
		push_error("C0_EXPORTED_SPARK_BASELINE_FAIL: " + failure)
	get_tree().quit(1)
