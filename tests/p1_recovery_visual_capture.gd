extends SceneTree

const SETTLE_FRAMES := 20
const COMPOSITION_FRAMES := 4
const EARLY_FALL_FRAMES := 6
const LATE_FALL_FRAMES := 6

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
	var registry := _root.get_node_or_null("P1SpaceRegistry") as P1SpaceRegistry
	var world := _root.call("get_recovery_world_space") as W0AuthorityPartitionSpace
	var old_demo := _root.call("get_recovery_demo_space") as LocalMatterSpace
	var bridge_cell: Vector3i = _root.call("get_recovery_causal_bridge_cell_for_test") if _root.has_method("get_recovery_causal_bridge_cell_for_test") else Vector3i(-1, -1, -1)

	_check(player != null and camera_rig != null and interactor != null and registry != null, "capture resolves interactive roles")
	_check(world != null, "capture resolves one causal ordinary-Matter world")
	_check(old_demo == null, "capture contains no pre-authored moving demo Space")
	_check(registry != null and registry.get_active_count() == 1, "capture starts with one live ordinary world Space")
	_check(player != null and player.grounded and player.support_space == world, "capture actor starts supported by ordinary world Matter")
	_check(world != null and world.volume.in_bounds(bridge_cell) and world.volume.get_cell(bridge_cell) != CellVolume.EMPTY, "capture resolves the authored ordinary-Matter causal bridge")
	if player == null or camera_rig == null or interactor == null or registry == null or world == null:
		_root.free()
		_finish()
		return

	# Frame 00 is deliberately untouched: this is the actual first view an Owner
	# receives after startup, including the world-scoped HUD language.
	await _capture("00_first_contact")

	# Prove the causal neck through the same camera ray / registry / cell resolver
	# used by Owner pointer input. No exact-cell mutation is allowed below: the
	# projected top face must be visibly targetable from the default startup view.
	var camera := camera_rig.get_camera() as Camera3D
	var provider := world.get_active_provider()
	_check(camera != null and provider != null, "capture resolves live camera and canonical world provider")
	if camera == null or provider == null:
		_root.free()
		_finish()
		return
	var bridge_face_world := provider.to_global(
		Vector3(bridge_cell) + Vector3(0.5, 1.001, 0.5)
	)
	var bridge_screen := camera.unproject_position(bridge_face_world)
	var visible_rect := camera.get_viewport().get_visible_rect()
	_check(not camera.is_position_behind(bridge_face_world), "causal bridge top face is in front of the default camera")
	_check(visible_rect.has_point(bridge_screen), "causal bridge top face projects inside the Owner viewport")

	interactor.set_mode(P1MatterInteractor.EditMode.REMOVE)
	# Freeze only the automatic pointer polling inside this evidence script so the
	# synthetic pointer position remains stable long enough for the normal target
	# presentation to render. The resolver itself is production P1MatterInteractor.
	interactor.set_process(false)
	interactor.update_target_from_pointer_position(bridge_screen)
	_check(interactor.target_space == world, "default-view pointer ray resolves canonical world Matter")
	_check(interactor.target_valid, "default-view pointer ray resolves a valid REMOVE target")
	_check(interactor.remove_cell == bridge_cell, "default-view pointer ray resolves the exact causal neck cell")
	if interactor.target_space != world or not interactor.target_valid or interactor.remove_cell != bridge_cell:
		_root.free()
		_finish()
		return

	# Frame 01 is what the normal hover cue looks like on the actual causal neck.
	await _capture("01_causal_bridge_before_cut")

	var acquisitions_before := player.observed_ground_acquisitions
	var transfers_before := player.observed_support_transfers
	var actor_before := player.global_position

	var edit_applied := interactor.apply_current_edit()
	_check(edit_applied, "shared pointer-resolved Matter interaction removes the ordinary causal bridge")
	_check(world.volume.get_cell(bridge_cell) == CellVolume.EMPTY, "causal bridge Matter is visibly/logically removed")
	_check(world.is_authority_partition_pending(), "the same ordinary pointer edit queues causal ownership transfer")
	# Clear the now-consumed hover deterministically; later frames should show the
	# changed world, not a stale cue left behind by the evidence harness.
	interactor.update_target_from_screen_position(Vector2(-1.0, -1.0))
	if not world.is_authority_partition_pending():
		_root.free()
		_finish()
		return

	await world.authority_partition_committed
	var result := world.get_last_authority_partition_result()
	var detached := result.get("target_space") as LocalMatterSpace
	_check(detached != null and is_instance_valid(detached), "causal cut creates one fresh live Matter Space")
	_check(registry.get_active_count() == 2, "visual sequence now contains canonical world plus detached Matter")
	_check(detached != null and detached.get_provider_kind() == LocalMatterSpace.ProviderKind.DYNAMIC, "detached ordinary Matter is solver-driven dynamic Matter")
	_check(player.support_space == detached, "actor support follows exact Matter into detached ownership")
	_check(player.observed_support_transfers == transfers_before + 1, "visual causal cut performs one explicit actor frame transfer")
	_check(player.observed_ground_acquisitions == acquisitions_before, "visual causal cut does not fake continuity through reacquisition")
	_check(player.global_position.distance_to(actor_before) < 0.0001, "visual causal cut has no actor teleport at authority handoff")
	if detached == null:
		_root.free()
		_finish()
		return

	# Capture immediately after the ownership commit and before intentionally
	# advancing the detached body's fall. The pixels should show a changed world
	# topology without an authored launch or hidden teleport.
	await _capture("02_causal_detach_committed")

	var detached_provider := detached.get_active_provider()
	var detached_start_y := detached_provider.global_position.y if detached_provider != null else 0.0
	var actor_start_y := player.global_position.y
	await _advance_frames(EARLY_FALL_FRAMES)
	await _capture("03_riding_detached_matter")

	await _advance_frames(LATE_FALL_FRAMES)
	var detached_fall := detached_start_y - (detached_provider.global_position.y if detached_provider != null else detached_start_y)
	var actor_fall := actor_start_y - player.global_position.y
	_check(detached_fall > 0.05, "detached Matter visibly falls under solver gravity")
	_check(actor_fall > 0.05, "actor visibly rides the causally detached Matter")
	_check(absf(detached_fall - actor_fall) < 0.02, "actor and detached Matter retain visual ride continuity")
	_check(player.grounded and player.support_space == detached, "actor remains supported by detached Matter during visual fall")
	_check(player.observed_ground_acquisitions == acquisitions_before, "visual ride never falls back to ground reacquisition")

	# A second view challenges whether the relationship survives camera change,
	# without changing Matter state or adding any artificial motion.
	camera_rig.set("_yaw", -0.62)
	camera_rig.set("_pitch", 0.50)
	camera_rig.set("_distance", 9.0)
	camera_rig.call("_apply_user_orbit_immediately")
	await _advance_frames(COMPOSITION_FRAMES)
	await _capture("04_alternate_riding_view")

	print("P1_RECOVERY_VISUAL_METRIC bridge=%s screen=%s active_spaces=%d detached_fall=%.6f actor_fall=%.6f transfers=%d acquisitions=%d" % [
		str(bridge_cell),
		str(bridge_screen),
		registry.get_active_count(),
		detached_fall,
		actor_fall,
		player.observed_support_transfers - transfers_before,
		player.observed_ground_acquisitions - acquisitions_before,
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
		print("P1_RECOVERY_VISUAL_PASS: default-view camera-ray interaction cut ordinary world Matter, detached it causally and rendered actor-supported dynamic motion.")
		quit(0)
		return
	for failure in _failures:
		push_error("P1_RECOVERY_VISUAL_FAIL: " + failure)
	quit(1)
