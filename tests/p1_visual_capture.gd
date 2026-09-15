extends SceneTree

const VisualVariants = preload("res://tests/support/p1_visual_variants.gd")

const ACQUIRE_FRAMES := 18
const MOTION_FRAMES := 14
const POST_REBASE_FRAMES := 5
const POST_SPLIT_FRAMES := 7
const POST_FREEZE_FRAMES := 5
const CENTRAL_IMPULSE := Vector3(0.0, 0.0, -36.0)
const TORQUE_IMPULSE := Vector3(0.0, 90.0, 0.0)
const EDGE_Z := 8
const LIGHTING_AZIMUTHS_DEG := [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0]

var _failures: Array[String] = []
var _output_dir := ""
var _visual_variant := "canonical"
var _p1: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_output_dir = OS.get_environment("P1_VISUAL_EVIDENCE_DIR")
	if _output_dir.is_empty():
		_output_dir = ProjectSettings.globalize_path("res://artifacts/p1-visual-evidence")
	DirAccess.make_dir_recursive_absolute(_output_dir)

	_visual_variant = OS.get_environment("P1_VISUAL_VARIANT").strip_edges().to_lower()
	if _visual_variant.is_empty():
		_visual_variant = "canonical"

	var packed := load("res://p1/main.tscn") as PackedScene
	_check(packed != null, "P1 visual capture can load the canonical scene")
	if packed == null:
		_finish()
		return

	_p1 = packed.instantiate()
	get_root().add_child(_p1)
	await process_frame
	VisualVariants.refresh(_p1, _visual_variant, _failures)
	await _advance_frames(ACQUIRE_FRAMES)

	var source := _p1.call("get_space") as LocalMatterSpace
	var player := _p1.call("get_player") as SpaceQueryCharacter
	var camera_rig := _p1.call("get_camera_rig") as P1CameraRig
	var interactor := _p1.call("get_interactor") as P1MatterInteractor
	_check(source != null and player != null and camera_rig != null and interactor != null, "P1 visual capture resolves composed roles")
	if source == null or player == null or camera_rig == null or interactor == null:
		_p1.free()
		_finish()
		return

	print("P1_VISUAL_CAPTURE_VARIANT: %s" % _visual_variant)
	await _capture("00_initial_static")
	await _capture_lighting_turntable(camera_rig)
	await _capture_granularity_distances(camera_rig)
	camera_rig.reset_view()
	await _advance_frames(2)

	_check(bool(_p1.call("toggle_focused_space_for_test")), "visual sequence releases the Space")
	await source.provider_transition_committed
	await _advance_frames(3)
	await _capture("01_released_dynamic")

	_check(bool(_p1.call("apply_focused_central_impulse_for_test", CENTRAL_IMPULSE)), "visual sequence applies finite translation")
	_check(bool(_p1.call("apply_focused_torque_impulse_for_test", TORQUE_IMPULSE)), "visual sequence applies finite yaw")
	await _advance_frames(MOTION_FRAMES)
	await _capture("02_dynamic_motion")

	_check(interactor.apply_edit_to_cell(source, Vector3i(1, 0, EDGE_Z), P1MatterInteractor.EditMode.PLACE), "visual sequence builds connected edge cell 1")
	_check(interactor.apply_edit_to_cell(source, Vector3i(0, 0, EDGE_Z), P1MatterInteractor.EditMode.PLACE), "visual sequence builds connected edge cell 2")
	var outside_cell := Vector3i(-1, 0, EDGE_Z)
	_check(interactor.request_place_to_cell(source, outside_cell), "visual sequence requests outside-storage placement")
	if source.is_storage_rebase_pending():
		await source.storage_rebase_committed
	await process_frame
	await _advance_frames(POST_REBASE_FRAMES)
	await _capture("03_storage_rebase_build")

	var shift: Vector3i = source.get_last_storage_rebase_report().get("local_shift", Vector3i.ZERO)
	for z in range(2, 14):
		var cut_cell := Vector3i(6, 0, z) + shift
		_check(interactor.apply_edit_to_cell(source, cut_cell, P1MatterInteractor.EditMode.REMOVE), "visual sequence removes split cell %s" % str(cut_cell))
	if source.is_topology_split_pending():
		await source.topology_split_committed
	await _advance_frames(POST_SPLIT_FRAMES)
	await _capture("04_split_successors")

	var successor := player.support_space as LocalMatterSpace
	_check(successor != null and not successor.is_retired(), "visual sequence resolves actor-owned successor")
	if successor != null and not successor.is_retired():
		_check(bool(_p1.call("toggle_focused_space_for_test")), "visual sequence freezes the actor-owned successor")
		await successor.provider_transition_committed
		await _advance_frames(POST_FREEZE_FRAMES)
		await _capture("05_frozen_successor")

	_p1.free()
	_finish()


func _capture_lighting_turntable(camera_rig: P1CameraRig) -> void:
	# G2 evidence: hold the same authored static state/pitch/distance and orbit
	# through every octant. Retained as a regression surface after G2 promotion.
	for azimuth_deg: float in LIGHTING_AZIMUTHS_DEG:
		camera_rig.set("_yaw", deg_to_rad(azimuth_deg))
		camera_rig.set("_pitch", 0.48)
		camera_rig.set("_distance", 8.4)
		camera_rig.call("_apply_orbit")
		await _advance_frames(2)
		await _capture("10_light_az%03d" % int(azimuth_deg))


func _capture_granularity_distances(camera_rig: P1CameraRig) -> void:
	# G3 evidence: same static Matter, same yaw/pitch, three observation scales.
	# Near should expose one-cell editing scale; far should still read as coherent
	# broad form rather than a noisy wire cage or checkerboard.
	camera_rig.set("_yaw", 0.72)
	camera_rig.set("_pitch", 0.48)
	for entry in [
		["20_granularity_near", 4.8],
		["21_granularity_mid", 7.2],
		["22_granularity_far", 12.0],
	]:
		camera_rig.set("_distance", float(entry[1]))
		camera_rig.call("_apply_orbit")
		await _advance_frames(2)
		await _capture(String(entry[0]))


func _capture(label: String) -> void:
	if _p1 != null and is_instance_valid(_p1):
		VisualVariants.refresh(_p1, _visual_variant, _failures)
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_root().get_texture().get_image()
	_check(image != null and not image.is_empty(), "rendered capture %s produced image pixels" % label)
	if image == null or image.is_empty():
		return
	var path := _output_dir.path_join(label + ".png")
	var save_error := image.save_png(path)
	_check(save_error == OK, "rendered capture %s saved PNG" % label)
	if save_error == OK:
		print("P1_VISUAL_CAPTURE_FRAME: %s %dx%d -> %s" % [label, image.get_width(), image.get_height(), path])


func _advance_frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame
		await process_frame


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _finish() -> void:
	if _failures.is_empty():
		print("P1_VISUAL_CAPTURE_PASS: variant=%s canonical P1 produced rendered evidence for static, lighting azimuth stress, granularity distance stress, dynamic, moving, storage-rebased, split and frozen states." % _visual_variant)
		quit(0)
		return
	for failure in _failures:
		push_error("P1_VISUAL_CAPTURE_FAIL: " + failure)
	quit(1)
