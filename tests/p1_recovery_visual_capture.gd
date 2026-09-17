extends SceneTree

const SETTLE_FRAMES := 20
const MOTION_FRAMES := 45
const TARGET_SETTLE_FRAMES := 3

var _failures: Array[String] = []
var _output_dir := ""
var _root: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_output_dir = OS.get_environment("P1_RECOVERY_VISUAL_DIR")
	if _output_dir.is_empty():
		_output_dir = ProjectSettings.globalize_path("res://artifacts/p1-recovery-visual")
	DirAccess.make_dir_recursive_absolute(_output_dir)

	var packed := load("res://p1/recovery_main.tscn") as PackedScene
	_check(packed != null, "recovery visual capture loads recovery scene")
	if packed == null:
		_finish()
		return

	_root = packed.instantiate()
	get_root().add_child(_root)
	await process_frame
	await _advance_frames(SETTLE_FRAMES)

	var player := _root.call("get_player") as SpaceQueryCharacter
	var camera_rig := _root.call("get_camera_rig") as P1CameraRig
	var interactor := _root.call("get_interactor") as P1MatterInteractor
	var world := _root.call("get_recovery_world_space") as LocalMatterSpace
	var moving := _root.call("get_recovery_demo_space") as LocalMatterSpace
	_check(player != null and camera_rig != null and interactor != null, "capture resolves interactive roles")
	_check(world != null and moving != null, "capture resolves world and moving Matter")
	if player == null or camera_rig == null or interactor == null or world == null or moving == null:
		_root.free()
		_finish()
		return

	await _capture("00_first_contact")
	var moving_start := moving.get_active_provider().global_transform
	await _advance_frames(MOTION_FRAMES)
	var moving_delta := moving.get_active_provider().global_position.distance_to(moving_start.origin)
	_check(moving_delta > 0.05, "moving Matter visibly changes world position during capture")
	await _capture("01_world_alive")

	# Owner-facing direct-edit readability: use the real centre pointer on the
	# canonical recovery camera. This is not a synthetic fixture target.
	var centre := get_root().get_visible_rect().size * 0.5
	interactor.set_mode(P1MatterInteractor.EditMode.REMOVE)
	interactor.update_target_from_pointer_position(centre)
	await _advance_frames(TARGET_SETTLE_FRAMES)
	await _capture("02_direct_remove_target")

	interactor.set_mode(P1MatterInteractor.EditMode.PLACE)
	interactor.update_target_from_pointer_position(centre)
	await _advance_frames(TARGET_SETTLE_FRAMES)
	await _capture("03_direct_build_target")

	# One alternate view to catch the old class of camera/form lies without
	# turning this into another giant visual campaign.
	camera_rig.set("_yaw", -0.62)
	camera_rig.set("_pitch", 0.54)
	camera_rig.set("_distance", 9.0)
	camera_rig.call("_apply_user_orbit_immediately")
	await _advance_frames(4)
	await _capture("04_alternate_view")

	print("P1_RECOVERY_VISUAL_METRIC moving_delta=%.6f target_space=%s target_cell=%s" % [
		moving_delta,
		interactor.target_space.name if interactor.target_space != null else "none",
		str(interactor.target_cell),
	])

	_root.free()
	_finish()


func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_root().get_texture().get_image()
	_check(image != null and not image.is_empty(), "capture %s produced pixels" % label)
	if image == null or image.is_empty():
		return
	var path := _output_dir.path_join(label + ".png")
	var error := image.save_png(path)
	_check(error == OK, "capture %s saved PNG" % label)
	if error == OK:
		print("P1_RECOVERY_VISUAL_FRAME: %s %dx%d -> %s" % [label, image.get_width(), image.get_height(), path])


func _advance_frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame
		await process_frame


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _finish() -> void:
	if _failures.is_empty():
		print("P1_RECOVERY_VISUAL_PASS: recovery Owner surface produced first-contact, live-world, direct-edit and alternate-view rendered evidence.")
		quit(0)
		return
	for failure in _failures:
		push_error("P1_RECOVERY_VISUAL_FAIL: " + failure)
	quit(1)
