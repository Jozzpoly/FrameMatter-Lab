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
const C1_SCALE_PROXY_REACH_BASE := 14.0
const C1_SCALE_PROXY_FACTORS := [1.0, 2.0, 4.0, 8.0]
const C6_SEAM_MARKER_LENGTH := 0.9
const C6_SEAM_MARKER_THICKNESS := 0.08
const C6_ARTIFACT_QUALIFIER = preload("res://p1/c6_artifact_qualifier.gd")
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
var _c1_scale_probe_factor := 1.0
var _pending_recovery_source_connected_after_partition := false
var _last_recovery_policy_mode := "none"
var _last_recovery_policy_visited_cells := 0

# Convergence C6: one bounded structural relation. Logical truth is deliberately
# lineage-owned; body/Space references below are execution caches only.
var _c6_pending_relation: Dictionary = {}
var _c6_relation: Dictionary = {}
var _c6_relation_joint: HingeJoint3D
var _c6_relation_marker: MeshInstance3D
var _c6_relation_host_space: LocalMatterSpace
var _c6_relation_install_physics_frame := -1
var _c6_relation_rebind_count := 0
var _c6_last_authoring_result: Dictionary = {}


func _ready() -> void:
	super._ready()
	# The recovery surface uses direct mouse semantics through
	# P1RecoveryDirectEdit instead of the old modal E + LMB consumer path.
	_interactor.set_process_unhandled_input(false)
	_last_event = "recovery: edit ordinary Matter; detached Matter becomes physical"
	if OS.get_cmdline_user_args().has("--c0-artifact-baseline"):
		call_deferred("_run_c0_artifact_baseline")
	elif OS.get_cmdline_user_args().has("--c6-autonomous-flow"):
		call_deferred("_run_c6_exported_autonomous_flow")
	_apply_c1_scale_probe(1.0, false)


func get_recovery_world_space() -> LocalMatterSpace:
	return _recovery_world_space


func get_recovery_demo_space() -> LocalMatterSpace:
	return _recovery_demo_space


func get_c1_scale_probe_factor() -> float:
	return _c1_scale_probe_factor


func get_c1_scale_probe_equivalent_cell_meters() -> float:
	return 1.0 / maxf(1.0, _c1_scale_probe_factor)


func set_c1_scale_probe_for_test(scale_factor: float) -> void:
	_apply_c1_scale_probe(scale_factor, true)


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


func has_c6_active_relation_for_test() -> bool:
	return not _c6_relation.is_empty()


func get_c6_active_relation_for_test() -> Dictionary:
	return _c6_relation.duplicate(true)


func get_c6_relation_host_space_for_test() -> LocalMatterSpace:
	return _c6_relation_host_space


func get_c6_relation_joint_for_test() -> HingeJoint3D:
	return _c6_relation_joint


func get_c6_relation_install_physics_frame_for_test() -> int:
	return _c6_relation_install_physics_frame


func get_c6_relation_rebind_count_for_test() -> int:
	return _c6_relation_rebind_count


func get_c6_last_authoring_result_for_test() -> Dictionary:
	return _c6_last_authoring_result.duplicate(true)


func request_c6_structural_seam_at_screen(screen_position: Vector2) -> bool:
	if _interactor == null or not is_instance_valid(_interactor):
		_last_event = "structural seam blocked: interactor unavailable"
		return false
	_interactor.update_target_from_pointer_position(screen_position)
	if (
		_interactor.target_space != _recovery_world_space
		or _recovery_world_space == null
		or _recovery_world_space.volume == null
		or not _recovery_world_space.volume.in_bounds(_interactor.remove_cell)
		or _recovery_world_space.volume.get_cell(_interactor.remove_cell) == CellVolume.EMPTY
	):
		_last_event = "structural seam blocked: point at ordinary WORLD Matter"
		return false
	return _c6_request_structural_seam_near_cell(_interactor.remove_cell)


func request_c6_structural_seam_near_cell_for_test(cell: Vector3i) -> bool:
	return _c6_request_structural_seam_near_cell(cell)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("p1_structural_seam") and not _is_echo_key_event(event):
		var viewport := get_viewport()
		if viewport != null:
			request_c6_structural_seam_at_screen(viewport.get_mouse_position())
			viewport.set_input_as_handled()
		return

	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			var requested_scale := 0.0
			match key.physical_keycode:
				KEY_1:
					requested_scale = C1_SCALE_PROXY_FACTORS[0]
				KEY_2:
					requested_scale = C1_SCALE_PROXY_FACTORS[1]
				KEY_3:
					requested_scale = C1_SCALE_PROXY_FACTORS[2]
				KEY_4:
					requested_scale = C1_SCALE_PROXY_FACTORS[3]
			if requested_scale > 0.0:
				_apply_c1_scale_probe(requested_scale, true)
				get_viewport().set_input_as_handled()
				return
	super._unhandled_input(event)


func _apply_c1_scale_probe(scale_factor: float, reset_world: bool) -> void:
	var clamped := clampf(scale_factor, 1.0, 8.0)
	_c1_scale_probe_factor = clamped
	_player.apply_scale_probe(clamped)
	set_player_speed_scale(clamped)
	_interactor.max_distance = C1_SCALE_PROXY_REACH_BASE * clamped
	_camera_rig.apply_scale_probe(clamped)
	if reset_world:
		_reset_experiment()
		_last_event = "C1 scale proxy %.0fx (~%.3f m relative cell); world reset for clean comparison" % [
			clamped,
			1.0 / clamped,
		]


func _initialize_space() -> void:
	_c6_reset_relation_state()
	_clear_pending_storage_place()
	_clear_pending_causal_actor_handoff()
	_pending_recovery_source_connected_after_partition = false
	_recovery_anchor_cells_current.clear()
	for anchor_cell in RECOVERY_ANCHOR_CELLS:
		_recovery_anchor_cells_current.append(anchor_cell)

	# World replacement is a lifecycle transaction. Clear every consumer-facing
	# typed reference before registry callbacks or old Space nodes can retire.
	_focus_space = null
	_recovery_demo_space = null
	_recovery_world_space = null
	if _player != null:
		_player.clear_support_for_world_reset()
	if _camera_rig != null:
		_camera_rig.set_context_target(null)
	var state_presentation := get_node_or_null("P1MatterStatePresentation") as P1MatterStatePresentation
	if state_presentation != null:
		state_presentation.set_focus_space(null)

	_registry.clear()
	for child in $Spaces.get_children():
		child.free()

	_recovery_world_space = _build_world_matter_space()
	# Presentation granularity is intentionally decoupled from physics-provider
	# granularity. Edge 7 won the spatial/lifecycle tradeoff while the static
	# physics provider remains edge 8 to avoid collision-shape inflation.
	var surface_grid := get_node_or_null("P1MatterSurfaceGrid") as P1MatterSurfaceGrid
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
	if (
		not _c6_relation.is_empty()
		and _c6_relation_host_space != null
		and _focus_space == _c6_relation_host_space
	):
		_last_event = "structural relation owns this dynamic regime; provider toggle blocked in C6"
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
	_c6_reconcile_relation_truth("live Matter edit")
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
		_c6_pending_relation.clear()
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

	var c6_relation_manifested := false
	if not _c6_pending_relation.is_empty():
		c6_relation_manifested = _c6_manifest_pending_relation(result, target)
		if not c6_relation_manifested:
			push_error("C6 structural relation failed to manifest inside authority commit")

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
		"structural seam → riding passive dynamic relation"
		if c6_relation_manifested and actor_transferred
		else (
			"structural seam → passive dynamic relation"
			if c6_relation_manifested
			else (
				"world Matter detached → riding fresh dynamic Space"
				if actor_transferred
				else "world Matter detached → fresh dynamic Space"
			)
		)
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
	if space == _recovery_world_space:
		var local_shift: Vector3i = report.get("local_shift", Vector3i.ZERO)
		for index in range(_recovery_anchor_cells_current.size()):
			_recovery_anchor_cells_current[index] += local_shift
	if (
		not _c6_relation.is_empty()
		and (space == _recovery_world_space or space == _c6_relation_host_space)
	):
		_c6_reconcile_relation_truth("storage-frame rebase")


func _on_registry_split_committed(source: LocalMatterSpace, result: LocalMatterSplitResult) -> void:
	var relation_source_split := (
		not _c6_relation.is_empty()
		and _c6_relation_host_space == source
	)
	super._on_registry_split_committed(source, result)
	if relation_source_split:
		_c6_reconcile_relation_truth("topology succession")


func _on_registry_provider_changed(space: LocalMatterSpace) -> void:
	super._on_registry_provider_changed(space)
	if (
		not _c6_relation.is_empty()
		and (space == _recovery_world_space or space == _c6_relation_host_space)
	):
		_c6_reconcile_relation_truth("provider replacement")


func _clear_pending_causal_actor_handoff() -> void:
	_pending_causal_actor_handoff = false
	_pending_causal_actor_local_center = Vector3.ZERO
	_pending_causal_actor_witness_cell = Vector3i.ZERO
	_pending_causal_actor_witness_token = MatterLineageMap.NONE


# --- Convergence C6 bounded structural-seam experiment -----------------------

func _c6_request_structural_seam_near_cell(target_cell: Vector3i) -> bool:
	_c6_last_authoring_result = {}
	if _recovery_world_space == null or _recovery_world_space.volume == null or _recovery_world_space.lineage == null:
		_last_event = "structural seam blocked: WORLD unavailable"
		return false
	if not _c6_relation.is_empty() or not _c6_pending_relation.is_empty():
		_last_event = "structural seam blocked: C6 supports one live relation"
		return false
	if _recovery_world_space.is_authority_partition_pending():
		_last_event = "structural seam blocked: authority transaction pending"
		return false
	if (
		not _recovery_world_space.volume.in_bounds(target_cell)
		or _recovery_world_space.volume.get_cell(target_cell) == CellVolume.EMPTY
	):
		_last_event = "structural seam blocked: target is not live Matter"
		return false

	var candidates: Array = []
	for offset in MatterTopology.AXIAL_NEIGHBORS:
		# C6's first Owner-facing dialect is intentionally horizontal only. The
		# axis is then an unambiguous horizontal tangent and the hinge is placed
		# along the lower interface edge so real WORLD collision need not be
		# globally disabled merely to obtain passive rotation.
		if offset.y != 0:
			continue
		var neighbor := target_cell + offset
		if (
			not _recovery_world_space.volume.in_bounds(neighbor)
			or _recovery_world_space.volume.get_cell(neighbor) == CellVolume.EMPTY
		):
			continue
		var candidate := _c6_build_seam_candidate(target_cell, neighbor)
		if not candidate.is_empty():
			candidates.append(candidate)

	_c6_last_authoring_result = {
		"target_cell": target_cell,
		"candidate_count": candidates.size(),
	}
	if candidates.size() != 1:
		_last_event = (
			"structural seam blocked: no separable adjacency"
			if candidates.is_empty()
			else "structural seam blocked: ambiguous neck (%d candidates)" % candidates.size()
		)
		return false

	var candidate: Dictionary = candidates[0]
	var selected: Array[Vector3i] = []
	for cell_variant in candidate.get("selected_cells", []):
		selected.append(cell_variant)
	_prepare_causal_actor_handoff(selected)

	_c6_pending_relation = {
		"world_lineage": int(candidate["world_lineage"]),
		"island_lineage": int(candidate["island_lineage"]),
		"world_to_island_offset": candidate["world_to_island_offset"],
		"axis_world_local": candidate["axis_world_local"],
	}
	_pending_recovery_source_connected_after_partition = true
	var request_started_usec := Time.get_ticks_usec()
	var accepted := _recovery_world_space.request_authority_partition(
		selected,
		LocalMatterSpace.ProviderKind.DYNAMIC
	)
	_last_recovery_partition_request_usec = Time.get_ticks_usec() - request_started_usec
	if not accepted:
		_c6_pending_relation.clear()
		_pending_recovery_source_connected_after_partition = false
		_clear_pending_causal_actor_handoff()
		_last_event = "structural seam authority composition rejected"
		return false

	_c6_last_authoring_result["accepted"] = true
	_c6_last_authoring_result["selected_cells"] = selected.size()
	_c6_last_authoring_result["world_lineage"] = int(candidate["world_lineage"])
	_c6_last_authoring_result["island_lineage"] = int(candidate["island_lineage"])
	_last_event = "structural seam queued from local Matter law"
	return true


func _c6_build_seam_candidate(cell_a: Vector3i, cell_b: Vector3i) -> Dictionary:
	var token_a := _recovery_world_space.lineage.get_lineage(cell_a)
	var token_b := _recovery_world_space.lineage.get_lineage(cell_b)
	if (
		token_a == MatterLineageMap.NONE
		or token_b == MatterLineageMap.NONE
		or token_a == token_b
	):
		return {}

	var result := C2RigidConnectivityChallenger.extract_rigid_components(
		_recovery_world_space.volume,
		_recovery_world_space.lineage,
		[{"a": token_a, "b": token_b}]
	)
	if not bool(result.get("valid", false)):
		return {}
	var components: Array = result.get("components", [])
	if components.size() != 2:
		return {}

	var anchored_component: Array = []
	var unanchored_component: Array = []
	for component_variant in components:
		var component: Array = component_variant
		if _c6_component_has_recovery_anchor(component):
			if not anchored_component.is_empty():
				return {}
			anchored_component = component
		else:
			if not unanchored_component.is_empty():
				return {}
			unanchored_component = component
	if anchored_component.is_empty() or unanchored_component.is_empty():
		return {}

	var a_anchored := anchored_component.has(cell_a)
	var b_anchored := anchored_component.has(cell_b)
	if a_anchored == b_anchored:
		return {}

	var world_cell := cell_a if a_anchored else cell_b
	var island_cell := cell_b if a_anchored else cell_a
	var offset := island_cell - world_cell
	if absi(offset.x) + absi(offset.y) + absi(offset.z) != 1 or offset.y != 0:
		return {}

	var selected: Array[Vector3i] = []
	for cell_variant in unanchored_component:
		selected.append(cell_variant)
	if selected.is_empty() or not selected.has(island_cell):
		return {}

	return {
		"selected_cells": selected,
		"world_lineage": _recovery_world_space.lineage.get_lineage(world_cell),
		"island_lineage": _recovery_world_space.lineage.get_lineage(island_cell),
		"world_to_island_offset": offset,
		"axis_world_local": _c6_axis_for_interface(offset),
	}


func _c6_component_has_recovery_anchor(component: Array) -> bool:
	for cell_variant in component:
		var cell: Vector3i = cell_variant
		var token := _recovery_world_space.lineage.get_lineage(cell)
		if token != MatterLineageMap.NONE and _recovery_anchor_tokens.has(token):
			return true
	return false


func _c6_axis_for_interface(offset: Vector3i) -> Vector3:
	var normal := Vector3(offset).normalized()
	var axis := Vector3.UP.cross(normal)
	if axis.length_squared() < 0.5:
		axis = Vector3.RIGHT
	return axis.normalized()


func _c6_manifest_pending_relation(result: Dictionary, target: LocalMatterSpace) -> bool:
	if _c6_pending_relation.is_empty() or target == null or not is_instance_valid(target):
		return false
	var body := target.get_active_provider() as ConstructBody
	if body == null:
		return false
	var world_token := int(_c6_pending_relation.get("world_lineage", MatterLineageMap.NONE))
	var island_token := int(_c6_pending_relation.get("island_lineage", MatterLineageMap.NONE))
	if _c6_find_lineage_cell(_recovery_world_space, world_token).is_empty():
		return false
	if _c6_find_lineage_cell(target, island_token).is_empty():
		return false

	var frame := _c6_resolve_world_relation_frame(_c6_pending_relation)
	if frame.is_empty():
		return false

	_c6_relation = _c6_pending_relation.duplicate(true)
	_c6_pending_relation.clear()
	_c6_relation_host_space = target
	_c6_relation_joint = HingeJoint3D.new()
	_c6_relation_joint.name = "C6PassiveStructuralRelation"
	add_child(_c6_relation_joint)
	_c6_relation_joint.global_transform = Transform3D(
		_c6_basis_with_z_axis(frame["axis_world"]),
		frame["anchor_world"]
	)
	_c6_relation_joint.node_b = _c6_relation_joint.get_path_to(body)
	_c6_relation_joint.exclude_nodes_from_collision = true
	_c6_relation_install_physics_frame = Engine.get_physics_frames()
	_c6_relation_rebind_count = 0
	_c6_update_relation_marker()
	return true


func _c6_reconcile_relation_truth(context: String) -> void:
	if _c6_relation.is_empty():
		return
	var world_token := int(_c6_relation.get("world_lineage", MatterLineageMap.NONE))
	var island_token := int(_c6_relation.get("island_lineage", MatterLineageMap.NONE))
	if _c6_find_lineage_cell(_recovery_world_space, world_token).is_empty():
		_c6_kill_relation("%s: WORLD endpoint Matter died" % context)
		return

	var owner := _c6_find_unique_space_for_lineage(island_token)
	if owner == null or owner == _recovery_world_space:
		_c6_kill_relation("%s: island endpoint Matter died or lost unique authority" % context)
		return

	var body := owner.get_active_provider() as ConstructBody
	if body == null:
		_c6_kill_relation("%s: island endpoint no longer has dynamic authority" % context)
		return

	var needs_rebind := (
		_c6_relation_host_space != owner
		or _c6_relation_joint == null
		or not is_instance_valid(_c6_relation_joint)
		or _c6_relation_joint.node_b != _c6_relation_joint.get_path_to(body)
	)
	if needs_rebind:
		if not _c6_rebind_relation_host(owner):
			_c6_kill_relation("%s: host rebind failed" % context)
			return
	else:
		_c6_update_relation_marker()


func _c6_rebind_relation_host(owner: LocalMatterSpace) -> bool:
	if _c6_relation.is_empty() or owner == null or not is_instance_valid(owner):
		return false
	var body := owner.get_active_provider() as ConstructBody
	if body == null:
		return false
	var frame := _c6_resolve_world_relation_frame(_c6_relation)
	if frame.is_empty():
		return false

	if _c6_relation_joint == null or not is_instance_valid(_c6_relation_joint):
		_c6_relation_joint = HingeJoint3D.new()
		_c6_relation_joint.name = "C6PassiveStructuralRelation"
		add_child(_c6_relation_joint)
		_c6_relation_joint.exclude_nodes_from_collision = true
	_c6_relation_joint.global_transform = Transform3D(
		_c6_basis_with_z_axis(frame["axis_world"]),
		frame["anchor_world"]
	)
	_c6_relation_joint.force_update_transform()
	_c6_relation_joint.node_b = _c6_relation_joint.get_path_to(body)
	_c6_relation_host_space = owner
	_c6_relation_rebind_count += 1
	_c6_update_relation_marker()
	return true


func _c6_find_unique_space_for_lineage(token: int) -> LocalMatterSpace:
	if token == MatterLineageMap.NONE:
		return null
	var found: LocalMatterSpace
	for space in _registry.get_active_spaces():
		if _c6_find_lineage_cell(space, token).is_empty():
			continue
		if found != null:
			return null
		found = space
	return found


func _c6_find_lineage_cell(space: LocalMatterSpace, token: int) -> Dictionary:
	if (
		space == null
		or not is_instance_valid(space)
		or space.is_retired()
		or space.volume == null
		or space.lineage == null
		or token == MatterLineageMap.NONE
	):
		return {}
	for z in range(space.lineage.size.z):
		for y in range(space.lineage.size.y):
			for x in range(space.lineage.size.x):
				var cell := Vector3i(x, y, z)
				if space.lineage.get_lineage(cell) == token:
					return {"cell": cell}
	return {}


func _c6_resolve_world_relation_frame(relation: Dictionary) -> Dictionary:
	if _recovery_world_space == null or _recovery_world_space.get_active_provider() == null:
		return {}
	var world_token := int(relation.get("world_lineage", MatterLineageMap.NONE))
	var cell_result := _c6_find_lineage_cell(_recovery_world_space, world_token)
	if cell_result.is_empty():
		return {}
	var world_cell: Vector3i = cell_result["cell"]
	var offset: Vector3i = relation.get("world_to_island_offset", Vector3i.ZERO)
	var axis_local: Vector3 = relation.get("axis_world_local", Vector3.ZERO)
	if absi(offset.x) + absi(offset.y) + absi(offset.z) != 1 or axis_local.length_squared() < 0.5:
		return {}

	var provider := _recovery_world_space.get_active_provider()
	# Lower-edge hinge: with a horizontal seam this lets the gravity-driven arm
	# open away from ordinary WORLD collision instead of requiring global collision
	# suppression as the C4 isolation probe did.
	var anchor_local := (
		Vector3(world_cell)
		+ Vector3(0.5, 0.5, 0.5)
		+ Vector3(offset) * 0.5
		- Vector3.UP * 0.5
	)
	return {
		"anchor_world": provider.to_global(anchor_local),
		"axis_world": (provider.global_basis * axis_local).normalized(),
	}


func _c6_resolve_island_anchor_local(space: LocalMatterSpace) -> Dictionary:
	if _c6_relation.is_empty():
		return {}
	var island_token := int(_c6_relation.get("island_lineage", MatterLineageMap.NONE))
	var cell_result := _c6_find_lineage_cell(space, island_token)
	if cell_result.is_empty():
		return {}
	var island_cell: Vector3i = cell_result["cell"]
	var offset: Vector3i = _c6_relation.get("world_to_island_offset", Vector3i.ZERO)
	return {
		"cell": island_cell,
		"anchor_local": (
			Vector3(island_cell)
			+ Vector3(0.5, 0.5, 0.5)
			- Vector3(offset) * 0.5
			- Vector3.UP * 0.5
		),
	}


func _c6_update_relation_marker() -> void:
	if _c6_relation.is_empty():
		if _c6_relation_marker != null and is_instance_valid(_c6_relation_marker):
			_c6_relation_marker.free()
		_c6_relation_marker = null
		return
	var frame := _c6_resolve_world_relation_frame(_c6_relation)
	if frame.is_empty():
		return
	if _c6_relation_marker == null or not is_instance_valid(_c6_relation_marker):
		_c6_relation_marker = MeshInstance3D.new()
		_c6_relation_marker.name = "C6StructuralSeamMarker"
		var mesh := BoxMesh.new()
		mesh.size = Vector3(C6_SEAM_MARKER_THICKNESS, C6_SEAM_MARKER_THICKNESS, C6_SEAM_MARKER_LENGTH)
		_c6_relation_marker.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.18, 0.88, 1.0, 1.0)
		material.emission_enabled = true
		material.emission = Color(0.04, 0.45, 0.62, 1.0)
		material.emission_energy_multiplier = 1.2
		_c6_relation_marker.material_override = material
		_c6_relation_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_c6_relation_marker)
	_c6_relation_marker.global_transform = Transform3D(
		_c6_basis_with_z_axis(frame["axis_world"]),
		frame["anchor_world"]
	)


func _c6_basis_with_z_axis(axis: Vector3) -> Basis:
	var z := axis.normalized()
	var helper := Vector3.UP if absf(z.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var x := helper.cross(z).normalized()
	var y := z.cross(x).normalized()
	return Basis(x, y, z).orthonormalized()


func _c6_kill_relation(reason: String) -> void:
	if _c6_relation_joint != null and is_instance_valid(_c6_relation_joint):
		_c6_relation_joint.free()
	_c6_relation_joint = null
	if _c6_relation_marker != null and is_instance_valid(_c6_relation_marker):
		_c6_relation_marker.free()
	_c6_relation_marker = null
	_c6_relation.clear()
	_c6_relation_host_space = null
	_last_event = "structural relation ended: %s" % reason


func _c6_reset_relation_state() -> void:
	if _c6_relation_joint != null and is_instance_valid(_c6_relation_joint):
		_c6_relation_joint.free()
	if _c6_relation_marker != null and is_instance_valid(_c6_relation_marker):
		_c6_relation_marker.free()
	_c6_relation_joint = null
	_c6_relation_marker = null
	_c6_relation_host_space = null
	_c6_pending_relation.clear()
	_c6_relation.clear()
	_c6_relation_install_physics_frame = -1
	_c6_relation_rebind_count = 0
	_c6_last_authoring_result = {}


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


func _run_c6_exported_autonomous_flow() -> void:
	var qualifier = C6_ARTIFACT_QUALIFIER.new()
	var report: Dictionary = await qualifier.run(self)
	if bool(report.get("pass", false)):
		print("C6_EXPORTED_AUTONOMOUS_FLOW_PASS: exact packaged Owner scene resolves production pointer/H input into local structural law -> authority composition -> same-frame passive relation -> gravity/ride -> live history.")
		get_tree().quit(0)
		return
	for failure_variant in report.get("failures", []):
		push_error("C6_EXPORTED_AUTONOMOUS_FLOW_FAIL: " + str(failure_variant))
	get_tree().quit(1)


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
	print(
		"C0_PRE_CUT_DIAGNOSTIC player=%s support_local_center=%s support_space_id=%d world_id=%d witness=%s witness_local_point=%s witness_world_point=%s witness_token=%d bridge=%s"
		% [
			str(player.global_position),
			str(player.support_local_center),
			player.support_space.get_instance_id() if player.support_space != null else 0,
			world.get_instance_id(),
			str(witness_cell),
			str(witness.get("local_point", Vector3.ZERO)),
			str(witness.get("world_point", Vector3.ZERO)),
			witness_token,
			str(RECOVERY_CAUSAL_BRIDGE_CELL),
		]
	)

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
	print(
		"C0_POST_PARTITION_DIAGNOSTIC source_origin=%s target_size=%s player=%s player_support_id=%d target_id=%d target_witness=%s source_witness_token=%d target_witness_token=%d"
		% [
			str(source_origin),
			str(target.volume.size),
			str(player.global_position),
			player.support_space.get_instance_id() if player.support_space != null else 0,
			target.get_instance_id(),
			str(target_witness_cell),
			world.lineage.get_lineage(witness_cell),
			target.lineage.get_lineage(target_witness_cell) if target.lineage.in_bounds(target_witness_cell) else MatterLineageMap.NONE,
		]
	)
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
