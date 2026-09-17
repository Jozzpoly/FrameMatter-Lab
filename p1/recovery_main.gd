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
const RECOVERY_CAUSAL_BRIDGE_CELL := Vector3i(14, 5, 16)
const RECOVERY_CAUSAL_SUPPORT_CELL := Vector3i(18, 5, 17)
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


func _ready() -> void:
	super._ready()
	# The recovery surface uses direct mouse semantics through
	# P1RecoveryDirectEdit instead of the old modal E + LMB consumer path.
	_interactor.set_process_unhandled_input(false)
	_last_event = "recovery: edit ordinary Matter; detached Matter becomes physical"


func get_recovery_world_space() -> LocalMatterSpace:
	return _recovery_world_space


func get_recovery_demo_space() -> LocalMatterSpace:
	return _recovery_demo_space


func get_recovery_causal_bridge_cell_for_test() -> Vector3i:
	return RECOVERY_CAUSAL_BRIDGE_CELL


func _initialize_space() -> void:
	_clear_pending_storage_place()
	_clear_pending_causal_actor_handoff()
	_registry.clear()
	for child in $Spaces.get_children():
		child.free()

	_recovery_demo_space = null
	_recovery_world_space = _build_world_matter_space()
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
	super._on_edit_applied(space, cell, mode, split_queued)
	if mode != P1MatterInteractor.EditMode.REMOVE:
		return
	if space != _recovery_world_space or _recovery_world_space == null:
		return
	if _recovery_world_space.is_authority_partition_pending():
		_last_event = "causal detach already pending"
		return

	var policy: Dictionary = W0AnchoredDetachmentPolicy.evaluate(
		_recovery_world_space.volume,
		_recovery_world_space.lineage,
		_recovery_anchor_tokens
	)
	if not bool(policy.get("valid", false)):
		_last_event = "detach policy fail-closed: %s" % str(policy.get("reason", "invalid"))
		return

	var detached_components: Array = policy.get("detached_components", [])
	if detached_components.is_empty():
		# Most edits simply reshape connected world Matter and require no new frame.
		return
	if detached_components.size() != 1:
		# W0 intentionally proves one target. Multiple simultaneous components need
		# a later 0..N transaction rather than arbitrary ordering in the consumer.
		_last_event = "detach deferred: %d independent components" % detached_components.size()
		return

	var selected: Array[Vector3i] = []
	for candidate in detached_components[0]:
		selected.append(candidate)

	_prepare_causal_actor_handoff(selected)
	if not _recovery_world_space.request_authority_partition(
		selected,
		LocalMatterSpace.ProviderKind.DYNAMIC
	):
		_clear_pending_causal_actor_handoff()
		_last_event = "causal authority transfer rejected"
		return
	_last_event = "Matter disconnected → dynamic ownership queued"


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
	var target := result.get("target_space") as LocalMatterSpace
	if target == null or not is_instance_valid(target):
		_clear_pending_causal_actor_handoff()
		_last_event = "causal transfer committed without live target"
		return

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

	# Registry publication happens only after the complete authority commit and
	# optional exact actor handoff, so presentation consumers never observe a
	# half-owned frame.
	_registry.register_space(target)
	if actor_transferred:
		_focus_space = target
	else:
		_focus_space = _recovery_world_space
	_clear_pending_causal_actor_handoff()
	_refresh_camera_context()
	_last_event = (
		"world Matter detached → riding fresh dynamic Space"
		if actor_transferred
		else "world Matter detached → fresh dynamic Space"
	)


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
