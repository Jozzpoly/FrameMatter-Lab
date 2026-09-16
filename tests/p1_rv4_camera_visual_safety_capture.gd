extends SceneTree

const ACQUIRE_FRAMES := 18
const SETTLE_FRAMES := 12
const OBSERVE_FRAMES := 30
const ACTOR_LOCAL := Vector3(8.5, 1.94, 6.5)
const RING_CENTER := Vector2i(8, 6)
const RING_MIN_Y := 1
const RING_MAX_Y := 4

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
	_output_dir = OS.get_environment("P1_RV4_CAMERA_SAFETY_EVIDENCE_DIR")
	if _output_dir.is_empty():
		_output_dir = ProjectSettings.globalize_path("res://artifacts/p1-rv4-camera-safety")
	DirAccess.make_dir_recursive_absolute(_output_dir)

	var packed := load("res://p1/main.tscn") as PackedScene
	_check(packed != null, "R-V4 baseline loads canonical P1 scene")
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
		"R-V4 baseline resolves canonical Space/player/camera/interactor"
	)
	if _space == null or _player == null or _camera_rig == null or _interactor == null:
		_cleanup_and_finish()
		return

	# Isolate the camera/avatar question. Matter surface/state remain canonical,
	# while target/HUD feedback are unrelated to this visual-safety falsifier.
	var target_presenter := _p1.get_node_or_null("P1MatterTargetPresentation") as P1MatterTargetPresentation
	if target_presenter != null:
		target_presenter.set_enabled(false)
	var hud := _p1.get_node_or_null("HUD") as CanvasLayer
	if hud != null:
		hud.visible = false

	# This is a presentation stress, not an actor-motion test. Keep the actor at
	# an exact world point while real Matter is built around it through the normal
	# edit path.
	_player.set_physics_process(false)
	_move_player_to_space_local(ACTOR_LOCAL)
	_camera_rig.reset_view()
	await _advance_frames(SETTLE_FRAMES)
	_print_camera_avatar_metric("00_open_reference")
	_check(_camera_avatar_signed_distance() > 0.0, "open reference keeps Camera3D outside visible avatar capsule")
	await _capture("00_open_reference")

	_check(_build_tight_matter_ring(), "R-V4 creates real Matter enclosure through normal PLACE edits")
	await _advance_frames(SETTLE_FRAMES)

	var inside_frames := 0
	var minimum_signed := INF
	var maximum_signed := -INF
	var minimum_arm := INF
	for _frame in range(OBSERVE_FRAMES):
		await physics_frame
		await process_frame
		var signed_distance := _camera_avatar_signed_distance()
		minimum_signed = minf(minimum_signed, signed_distance)
		maximum_signed = maxf(maximum_signed, signed_distance)
		minimum_arm = minf(minimum_arm, _actual_arm_length())
		if signed_distance < 0.0:
			inside_frames += 1

	_print_camera_avatar_metric("01_tight_matter_enclosure")
	print(
		"P1_RV4_BASELINE_WINDOW frames=%d inside_frames=%d min_avatar_signed=%.4f max_avatar_signed=%.4f min_actual_arm=%.4f" % [
			OBSERVE_FRAMES,
			inside_frames,
			minimum_signed,
			maximum_signed,
			minimum_arm,
		]
	)

	# A successful baseline acquisition means the known defect is reproduced,
	# not that production is acceptable. Keep CI green only when the falsifier is
	# trustworthy enough to challenge candidate fixes later.
	_check(inside_frames > 0, "tight real-Matter enclosure reproduces at least one Camera3D-inside-avatar frame")
	_check(minimum_signed < 0.0, "R-V4 baseline crosses the visible capsule surface")
	await _capture("01_tight_matter_enclosure")

	if _failures.is_empty():
		print(
			"P1_RV4_BASELINE_REPRODUCED: real Matter obstruction placed canonical Camera3D inside visible avatar geometry; fix not yet promoted."
		)

	_cleanup_and_finish()


func _build_tight_matter_ring() -> bool:
	var all_changed := true
	for y in range(RING_MIN_Y, RING_MAX_Y + 1):
		for z in range(RING_CENTER.y - 1, RING_CENTER.y + 2):
			for x in range(RING_CENTER.x - 1, RING_CENTER.x + 2):
				if x == RING_CENTER.x and z == RING_CENTER.y:
					continue
				var cell := Vector3i(x, y, z)
				if _space.volume.get_cell(cell) != CellVolume.EMPTY:
					all_changed = false
					continue
				if not _interactor.apply_edit_to_cell(_space, cell, P1MatterInteractor.EditMode.PLACE):
					all_changed = false
	return all_changed


func _move_player_to_space_local(local_position: Vector3) -> void:
	var provider := _space.get_active_provider()
	_player.global_position = provider.to_global(local_position)
	_player.desired_local_velocity = Vector3.ZERO
	_player.world_velocity = Vector3.ZERO
	_player.jump_requested = false
	_player.grounded = false
	_player.support_body = null
	_player.support_space = null
	_player.observed_support_velocity = Vector3.ZERO
	_player.reset_physics_interpolation()


func _camera_avatar_signed_distance() -> float:
	var body := _player.get_node_or_null("Body") as MeshInstance3D
	var camera := _camera_rig.get_camera()
	if body == null or camera == null or not (body.mesh is CapsuleMesh):
		return INF
	var capsule := body.mesh as CapsuleMesh
	var local_camera := body.to_local(camera.global_position)
	var axis_half := maxf(0.0, capsule.height * 0.5 - capsule.radius)
	var nearest_axis := Vector3(0.0, clampf(local_camera.y, -axis_half, axis_half), 0.0)
	return local_camera.distance_to(nearest_axis) - capsule.radius


func _actual_arm_length() -> float:
	var spring_arm := _camera_rig.get_node("YawPivot/PitchPivot/SpringArm3D") as SpringArm3D
	return _camera_rig.get_camera().global_position.distance_to(spring_arm.global_position)


func _print_camera_avatar_metric(label: String) -> void:
	var body := _player.get_node_or_null("Body") as MeshInstance3D
	var camera := _camera_rig.get_camera()
	var spring_arm := _camera_rig.get_node("YawPivot/PitchPivot/SpringArm3D") as SpringArm3D
	var local_camera := body.to_local(camera.global_position) if body != null else Vector3.ZERO
	var signed_distance := _camera_avatar_signed_distance()
	var actual_arm := _actual_arm_length()
	var desired_arm := spring_arm.spring_length
	print(
		"P1_RV4_CAMERA_AVATAR_METRIC label=%s desired_arm=%.4f actual_arm=%.4f camera_body_local=(%.4f,%.4f,%.4f) avatar_signed=%.4f inside=%s" % [
			label,
			desired_arm,
			actual_arm,
			local_camera.x,
			local_camera.y,
			local_camera.z,
			signed_distance,
			str(signed_distance < 0.0),
		]
	)


func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := get_root().get_texture().get_image()
	_check(image != null and not image.is_empty(), "R-V4 capture %s produced pixels" % label)
	if image == null or image.is_empty():
		return
	var path := _output_dir.path_join(label + ".png")
	var save_error := image.save_png(path)
	_check(save_error == OK, "R-V4 capture %s saved PNG" % label)
	if save_error == OK:
		print("P1_RV4_CAMERA_SAFETY_FRAME: label=%s %dx%d -> %s" % [label, image.get_width(), image.get_height(), path])


func _advance_frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame
		await process_frame


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _cleanup_and_finish() -> void:
	if _p1 != null and is_instance_valid(_p1):
		_p1.free()
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		quit(0)
		return
	for failure in _failures:
		push_error("P1_RV4_CAMERA_SAFETY_FAIL: " + failure)
	quit(1)
