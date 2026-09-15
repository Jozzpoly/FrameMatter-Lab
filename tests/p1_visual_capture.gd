extends SceneTree

const ACQUIRE_FRAMES := 18
const MOTION_FRAMES := 14
const POST_REBASE_FRAMES := 5
const POST_SPLIT_FRAMES := 7
const POST_FREEZE_FRAMES := 5
const CENTRAL_IMPULSE := Vector3(0.0, 0.0, -36.0)
const TORQUE_IMPULSE := Vector3(0.0, 90.0, 0.0)
const EDGE_Z := 8

var _failures: Array[String] = []
var _output_dir := ""
var _visual_variant := "canonical"


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

	var p1 := packed.instantiate()
	get_root().add_child(p1)
	await process_frame
	_apply_visual_variant(p1)
	await _advance_frames(ACQUIRE_FRAMES)

	var source := p1.call("get_space") as LocalMatterSpace
	var player := p1.call("get_player") as SpaceQueryCharacter
	var camera_rig := p1.call("get_camera_rig") as P1CameraRig
	var interactor := p1.call("get_interactor") as P1MatterInteractor
	_check(source != null and player != null and camera_rig != null and interactor != null, "P1 visual capture resolves composed roles")
	if source == null or player == null or camera_rig == null or interactor == null:
		p1.free()
		_finish()
		return

	print("P1_VISUAL_CAPTURE_VARIANT: %s" % _visual_variant)
	await _capture("00_initial_static")

	_check(bool(p1.call("toggle_focused_space_for_test")), "visual sequence releases the Space")
	await source.provider_transition_committed
	await _advance_frames(3)
	await _capture("01_released_dynamic")

	_check(bool(p1.call("apply_focused_central_impulse_for_test", CENTRAL_IMPULSE)), "visual sequence applies finite translation")
	_check(bool(p1.call("apply_focused_torque_impulse_for_test", TORQUE_IMPULSE)), "visual sequence applies finite yaw")
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
		_check(bool(p1.call("toggle_focused_space_for_test")), "visual sequence freezes the actor-owned successor")
		await successor.provider_transition_committed
		await _advance_frames(POST_FREEZE_FRAMES)
		await _capture("05_frozen_successor")

	p1.free()
	_finish()


func _apply_visual_variant(p1: Node) -> void:
	if _visual_variant == "canonical":
		return

	var world_environment := p1.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var key := p1.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	_check(world_environment != null and world_environment.environment != null, "visual challenger resolves P1 Environment")
	_check(key != null, "visual challenger resolves P1 key light")
	if world_environment == null or world_environment.environment == null or key == null:
		return

	if _visual_variant == "balanced_fill" or _visual_variant == "balanced_fill_ssao":
		# Bounded G2-B challenger: reduce flat ambient/key energy and add a weak
		# opposite no-shadow/no-specular fill. This follows Godot's documented
		# fake-GI pattern without changing canonical runtime until rendered A/B
		# evidence justifies promotion.
		var environment := world_environment.environment
		environment.ambient_light_energy = 0.42
		key.light_energy = 0.88

		var fill := DirectionalLight3D.new()
		fill.name = "G2TestFillLight"
		fill.rotation_degrees = key.rotation_degrees + Vector3(0.0, 180.0, 0.0)
		fill.light_color = Color(0.72, 0.80, 0.92, 1.0)
		fill.light_energy = 0.24
		fill.light_specular = 0.0
		fill.shadow_enabled = false
		p1.add_child(fill)

		if _visual_variant == "balanced_fill_ssao":
			# Bounded G2-C challenger: add moderate contact/cavity depth on top of
			# the exact same key/fill balance. Kept separate from promotion so its
			# contribution can be judged directly against balanced_fill.
			environment.ssao_enabled = true
			environment.ssao_radius = 1.15
			environment.ssao_intensity = 1.25
			environment.ssao_power = 1.35
		return

	_failures.append("unsupported P1_VISUAL_VARIANT: %s" % _visual_variant)


func _capture(label: String) -> void:
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
		print("P1_VISUAL_CAPTURE_PASS: variant=%s canonical P1 produced rendered evidence for static, dynamic, moving, storage-rebased, split and frozen states." % _visual_variant)
		quit(0)
		return
	for failure in _failures:
		push_error("P1_VISUAL_CAPTURE_FAIL: " + failure)
	quit(1)
