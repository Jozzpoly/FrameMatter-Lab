extends "res://p1/main.gd"

# Bounded post-Owner-failure recovery consumer.
#
# The old p1/main.tscn remains a mechanical/evidence fixture. This consumer
# deliberately changes the Owner-facing composition without replacing the
# defended Matter/Space/actor substrate beneath it.

const RECOVERY_WORLD_SIZE := Vector3i(32, 5, 32)
const RECOVERY_DEMO_SIZE := Vector3i(7, 3, 7)
const RECOVERY_WORLD_ORIGIN := Vector3(-16.0, -2.0, -16.0)
const RECOVERY_DEMO_ORIGIN := Vector3(-3.5, -0.40, -8.5)
const RECOVERY_DEMO_LINEAR := Vector3(0.16, 0.0, 0.03)
const RECOVERY_DEMO_ANGULAR := Vector3(0.0, 0.12, 0.0)

var _recovery_world_space: LocalMatterSpace
var _recovery_demo_space: LocalMatterSpace


func _ready() -> void:
	super._ready()
	# The recovery surface uses direct mouse semantics through
	# P1RecoveryDirectEdit instead of the old modal E + LMB consumer path.
	_interactor.set_process_unhandled_input(false)
	_last_event = "recovery surface: editable world Matter + moving Matter live"


func get_recovery_world_space() -> LocalMatterSpace:
	return _recovery_world_space


func get_recovery_demo_space() -> LocalMatterSpace:
	return _recovery_demo_space


func _initialize_space() -> void:
	_clear_pending_storage_place()
	_registry.clear()
	for child in $Spaces.get_children():
		child.free()

	_recovery_world_space = _build_world_matter_space()
	_recovery_demo_space = _build_moving_demo_space()
	_registry.register_space(_recovery_world_space)
	_registry.register_space(_recovery_demo_space)
	_focus_space = _recovery_world_space
	_last_event = "world Matter + moving local Space initialized"


func _build_world_matter_space() -> LocalMatterSpace:
	var volume := CellVolume.new(RECOVERY_WORLD_SIZE)
	# The visible ordinary terrain is authoritative Matter, not a separate fake
	# floor. Keep the centre open for spawn and put a little authored relief away
	# from it so the surface reads as a place rather than one laboratory slab.
	volume.fill_box(Vector3i.ZERO, Vector3i(32, 1, 32), CellVolume.SOLID)
	volume.fill_box(Vector3i(3, 1, 4), Vector3i(8, 2, 8), CellVolume.SOLID)
	volume.fill_box(Vector3i(24, 1, 20), Vector3i(29, 3, 24), CellVolume.SOLID)
	volume.fill_box(Vector3i(5, 1, 24), Vector3i(11, 2, 27), CellVolume.SOLID)
	volume.fill_box(Vector3i(22, 1, 5), Vector3i(26, 2, 9), CellVolume.SOLID)

	var lineage := MatterLineageMap.new(RECOVERY_WORLD_SIZE)
	var issuer := MatterLineageIssuer.new(1200001)
	for cell in _occupied_cells(volume):
		lineage.set_lineage(cell, issuer.allocate())

	var space := LocalMatterSpace.new()
	space.name = "RecoveryWorldMatterSpace"
	space.lineage_issuer = issuer
	space.mass_per_cell = 1.0
	space.dynamic_gravity_scale = 0.0
	space.dynamic_linear_damp = 0.02
	space.dynamic_angular_damp = 0.02
	space.dynamic_can_sleep = false
	$Spaces.add_child(space)
	space.initialize_static(
		volume,
		lineage,
		Transform3D(Basis.IDENTITY, RECOVERY_WORLD_ORIGIN)
	)
	return space


func _build_moving_demo_space() -> LocalMatterSpace:
	var volume := CellVolume.new(RECOVERY_DEMO_SIZE)
	volume.fill_box(Vector3i.ZERO, Vector3i(7, 1, 7), CellVolume.SOLID)
	volume.fill_box(Vector3i(0, 1, 0), Vector3i(2, 2, 2), CellVolume.SOLID)
	volume.fill_box(Vector3i(5, 1, 5), Vector3i(7, 2, 7), CellVolume.SOLID)
	volume.fill_box(Vector3i(3, 1, 3), Vector3i(4, 3, 4), CellVolume.SOLID)

	var lineage := MatterLineageMap.new(RECOVERY_DEMO_SIZE)
	var issuer := MatterLineageIssuer.new(1400001)
	for cell in _occupied_cells(volume):
		lineage.set_lineage(cell, issuer.allocate())

	var space := LocalMatterSpace.new()
	space.name = "RecoveryMovingMatterSpace"
	space.lineage_issuer = issuer
	space.mass_per_cell = 1.0
	space.dynamic_gravity_scale = 0.0
	space.dynamic_linear_damp = 0.015
	space.dynamic_angular_damp = 0.015
	space.dynamic_can_sleep = false
	$Spaces.add_child(space)
	space.initialize_dynamic(
		volume,
		lineage,
		Transform3D(Basis.IDENTITY, RECOVERY_DEMO_ORIGIN),
		RECOVERY_DEMO_LINEAR,
		RECOVERY_DEMO_ANGULAR
	)
	return space


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
