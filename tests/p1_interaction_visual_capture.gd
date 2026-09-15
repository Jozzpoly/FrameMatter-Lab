extends SceneTree

const ACQUIRE_FRAMES := 18
const SETTLE_FRAMES := 1
const CENTER_ACTOR_LOCAL := Vector3(8.5, 2.15, 8.5)
const EXPAND_ACTOR_LOCAL := Vector3(-2.5, 1.60, 8.5)
const SCAN_YAWS := [
	0.72,
	0.0,
	PI * 0.25,
	PI * 0.5,
	PI * 0.75,
	PI,
	-PI * 0.75,
	-PI * 0.5,
	-PI * 0.25,
]
const SCAN_PITCHES := [0.48, 0.34, 0.62, 0.78]
const SCAN_DISTANCES := [5.2, 7.2, 4.0]
const EXPAND_SCAN_YAWS := [-PI * 0.5, -PI * 0.45, -PI * 0.55, -PI * 0.35, -PI * 0.65]
const EXPAND_SCAN_PITCHES := [0.62, 0.78, 0.48, 0.90]
const EXPAND_SCAN_DISTANCES := [5.2, 7.2]

var _failures: Array[String] = []
var _output_dir := ""
var _p1: Node
var _space: LocalMatterSpace
var _player: SpaceQueryCharacter
var _camera_rig: P1CameraRig
var _interactor: P1MatterInteractor


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_output_dir = OS.get_environment("P1_INTERACTION_EVIDENCE_DIR")
	if _output_dir.is_empty():
		_output_dir = ProjectSettings.globalize_path("res://artifacts/p1-interaction-evidence")
	DirAccess.make_dir_recursive_absolute(_output_dir)

	var packed := load("res://p1/main.tscn") as PackedScene
	_check(packed != null, "G5 capture loads canonical P1 scene")
	if packed == null:
		_finish()
		return

	_p1 = packed.instantiate()
	get_root().add_child(_p1)
	await process_frame
	await _advance_frames(ACQUIRE_FRAMES)

	_space = _p1.call("get_space") as LocalMatterSpace
	_player = _p1.call("get_player") as SpaceQueryCharacter
	_camera_rig = _p1.call("get_camera_rig") as P1CameraRig
	_interactor = _p1.call("get_interactor") as P1MatterInteractor
	_check(
		_space != null and _player != null and _camera_rig != null and _interactor != null,
		"G5 capture resolves real P1 Space/actor/camera/interactor"
	)
	if _space == null or _player == null or _camera_rig == null or _interactor == null:
		_p1.free()
		_finish()
		return

	# Target semantics, not player locomotion, are under test here. Hold the actor
	# at exact authored positions while the real interactor performs its normal
	# center-reticle physics raycast against real Matter collision.
	_player.set_physics_process(false)

	var remove_found := await _find_target(P1MatterInteractor.EditMode.REMOVE, false, CENTER_ACTOR_LOCAL)
	_check(remove_found, "G5 baseline resolves an actionable in-storage REMOVE target")
	if remove_found:
		await _capture_target("00_remove_target", "REMOVE", false)

	var place_found := await _find_target(P1MatterInteractor.EditMode.PLACE, false, CENTER_ACTOR_LOCAL)
	_check(place_found, "G5 baseline resolves an actionable in-storage PLACE target")
	if place_found:
		await _capture_target("01_place_target", "PLACE", false)

	# Build a real connected Matter bridge to the dense-storage X=0 boundary.
	# The next raycast must then hit the outward face of that real boundary cell,
	# making PLACE mean "expand storage, then place" without inventing a test-only
	# interaction mode.
	_check(
		_interactor.apply_edit_to_cell(_space, Vector3i(1, 0, 8), P1MatterInteractor.EditMode.PLACE),
		"G5 baseline builds connected boundary approach cell x=1"
	)
	_check(
		_interactor.apply_edit_to_cell(_space, Vector3i(0, 0, 8), P1MatterInteractor.EditMode.PLACE),
		"G5 baseline builds connected storage-boundary cell x=0"
	)
	await _advance_frames(2)
	var expand_found := await _find_target(P1MatterInteractor.EditMode.PLACE, true, EXPAND_ACTOR_LOCAL)
	_check(expand_found, "G5 baseline resolves a real out-of-storage EXPAND placement target")
	if expand_found:
		await _capture_target("02_expand_target", "EXPAND", true)

	_player.set_physics_process(true)
	_p1.free()
	_finish()


func _find_target(mode: int, require_expand: bool, actor_local: Vector3) -> bool:
	var provider := _space.get_active_provider()
	if provider == null:
		return false
	_move_player_world(provider.to_global(actor_local))
	_interactor.set_mode(mode)
	_camera_rig.reset_view()
	await _advance_frames(2)

	var yaws: Array = EXPAND_SCAN_YAWS if require_expand else SCAN_YAWS
	var pitches: Array = EXPAND_SCAN_PITCHES if require_expand else SCAN_PITCHES
	var distances: Array = EXPAND_SCAN_DISTANCES if require_expand else SCAN_DISTANCES
	for distance_variant in distances:
		var distance := float(distance_variant)
		for pitch_variant in pitches:
			var pitch := float(pitch_variant)
			for yaw_variant in yaws:
				var yaw := float(yaw_variant)
				_camera_rig.set("_yaw", yaw)
				_camera_rig.set("_pitch", pitch)
				_camera_rig.set("_distance", distance)
				_camera_rig.call("_apply_user_orbit_immediately")
				await _advance_frames(SETTLE_FRAMES)
				_interactor.call("_update_target_from_camera")
				if _matches_target(mode, require_expand):
					print(
						"P1_INTERACTION_TARGET_FOUND mode=%s expand=%s yaw=%.3f pitch=%.3f distance=%.2f remove=%s place=%s face=%s" % [
							_interactor.get_mode_name(),
							str(require_expand),
							yaw,
							pitch,
							distance,
							str(_interactor.remove_cell),
							str(_interactor.place_cell),
							str(_interactor.place_cell - _interactor.remove_cell),
						]
					)
					return true
	return false


func _matches_target(mode: int, require_expand: bool) -> bool:
	if _interactor.target_space != _space or not _interactor.target_valid:
		return false
	if mode == P1MatterInteractor.EditMode.REMOVE:
		return _interactor.target_in_storage
	if require_expand:
		return not _interactor.target_in_storage
	return _interactor.target_in_storage


func _capture_target(label: String, semantic_name: String, expect_expand: bool) -> void:
	_interactor.call("_update_target_from_camera")
	_check(_interactor.target_space == _space, "%s targets the live authored Space" % label)
	_check(_interactor.target_valid, "%s target remains actionable at capture" % label)
	_check(
		(not _interactor.target_in_storage) == expect_expand,
		"%s storage relationship matches %s semantics" % [label, semantic_name]
	)
	var face := _interactor.place_cell - _interactor.remove_cell
	_check(
		abs(face.x) + abs(face.y) + abs(face.z) == 1,
		"%s resolves one exact hit face from remove/place cell relation" % label
	)
	print(
		"P1_INTERACTION_TRUTH label=%s semantic=%s target_cell=%s remove=%s place=%s face=%s in_storage=%s valid=%s" % [
			label,
			semantic_name,
			str(_interactor.get_target_cell()),
			str(_interactor.remove_cell),
			str(_interactor.place_cell),
			str(face),
			str(_interactor.target_in_storage),
			str(_interactor.target_valid),
		]
	)
	await process_frame
	await RenderingServer.frame_post_draw
	var image := get_root().get_texture().get_image()
	_check(image != null and not image.is_empty(), "%s produced rendered pixels" % label)
	if image == null or image.is_empty():
		return
	var path := _output_dir.path_join(label + ".png")
	var save_error := image.save_png(path)
	_check(save_error == OK, "%s saved PNG" % label)
	if save_error == OK:
		print("P1_INTERACTION_CAPTURE_FRAME: %s %dx%d -> %s" % [label, image.get_width(), image.get_height(), path])


func _move_player_world(world_position: Vector3) -> void:
	_player.global_position = world_position
	_player.desired_local_velocity = Vector3.ZERO
	_player.world_velocity = Vector3.ZERO
	_player.jump_requested = false
	_player.grounded = false
	_player.support_body = null
	_player.support_space = null
	_player.observed_support_velocity = Vector3.ZERO
	_player.reset_physics_interpolation()


func _advance_frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame
		await process_frame


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _finish() -> void:
	if _failures.is_empty():
		print("P1_INTERACTION_CAPTURE_PASS: truth-asserted canonical baseline captured REMOVE, PLACE and out-of-storage EXPAND targeting.")
		quit(0)
		return
	for failure in _failures:
		push_error("P1_INTERACTION_CAPTURE_FAIL: " + failure)
	quit(1)
