extends SceneTree

const ACQUIRE_FRAMES := 18
const SETTLE_FRAMES := 8
const SPLIT_SETTLE_FRAMES := 4
const EDGE_LOCAL := Vector3(13.35, 1.94, 8.5)
const WALL_NEAR_LOCAL := Vector3(4.65, 1.94, 6.5)
const FAR_AIRBORNE_WORLD := Vector3(34.5, -7.0, 0.0)
const TARGET_OLD_FRAME_CELL := Vector3i(-2, 0, 5)
const STORAGE_PADDING := 2
const CENTRAL_IMPULSE := Vector3(0.0, 0.0, -36.0)
const TORQUE_IMPULSE := Vector3(0.0, 90.0, 0.0)
const USABLE_TOP_NORM := 0.22

var _failures: Array[String] = []
var _output_dir := ""
var _p1: Node
var _player: SpaceQueryCharacter
var _camera_rig: P1CameraRig
var _interactor: P1MatterInteractor


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_output_dir = OS.get_environment("P1_CAMERA_EVIDENCE_DIR")
	if _output_dir.is_empty():
		_output_dir = ProjectSettings.globalize_path("res://artifacts/p1-camera-evidence")
	DirAccess.make_dir_recursive_absolute(_output_dir)

	var packed := load("res://p1/main.tscn") as PackedScene
	_check(packed != null, "G4 capture loads canonical P1 scene")
	if packed == null:
		_finish()
		return

	_p1 = packed.instantiate()
	get_root().add_child(_p1)
	await process_frame
	await _advance_frames(ACQUIRE_FRAMES)

	var source := _p1.call("get_space") as LocalMatterSpace
	_player = _p1.call("get_player") as SpaceQueryCharacter
	_camera_rig = _p1.call("get_camera_rig") as P1CameraRig
	_interactor = _p1.call("get_interactor") as P1MatterInteractor
	_check(
		source != null and _player != null and _camera_rig != null and _interactor != null,
		"G4 capture resolves real P1 actor/camera/Space/interactor"
	)
	if source == null or _player == null or _camera_rig == null or _interactor == null:
		_p1.free()
		_finish()
		return

	# Canonical production policy only. The historical challengers have been
	# retired after same-commit promotion equivalence.
	_camera_rig.reset_view()
	await _advance_frames(3)
	await _capture("00_default_center")

	_move_player_to_space_local(source, EDGE_LOCAL)
	await _advance_frames(SETTLE_FRAMES)
	await _capture("01_actor_near_edge")

	_camera_rig.set("_distance", _camera_rig.min_distance)
	_camera_rig.call("_apply_user_orbit_immediately")
	await _advance_frames(3)
	await _capture("02_minimum_zoom_edge")

	# Real Matter obstacle: collision avoidance is not accepted if it leaves a
	# long-lived unusable near-field close-up.
	_camera_rig.reset_view()
	_move_player_to_space_local(source, WALL_NEAR_LOCAL)
	await _advance_frames(SETTLE_FRAMES)
	var provider := source.get_active_provider()
	var wall_world := provider.to_global(Vector3(3.5, 1.6, 6.5))
	var to_wall: Vector3 = wall_world - _player.global_position
	to_wall.y = 0.0
	if to_wall.length_squared() > 0.000001:
		_camera_rig.set("_yaw", atan2(to_wall.x, to_wall.z))
		_camera_rig.call("_apply_user_orbit_immediately")
	await _advance_frames(SETTLE_FRAMES)
	await _capture("03_close_obstacle_compression")

	# Adversarial pre-recovery fall state. This is a camera-composition stress,
	# not a gravity timing test. Freeze the actor physics process so a slow
	# software renderer cannot advance enough hidden physics ticks to trigger the
	# production y<-12 automatic recovery before the evidence frame is captured.
	# B5 below re-enables actor physics and exercises explicit recovery normally.
	_camera_rig.reset_view()
	_player.set_physics_process(false)
	_move_player_world(FAR_AIRBORNE_WORLD)
	await _advance_frames(8)
	_check(
		_player.global_position.distance_to(FAR_AIRBORNE_WORLD) <= 0.001,
		"B4 preserves exact pre-recovery actor world position"
	)
	_check(not _player.grounded, "B4 remains airborne before capture")
	_check(_player.support_body == null and _player.support_space == null, "B4 has no support before capture")
	print(
		"P1_CAMERA_B4_STATE actor_world=(%.3f,%.3f,%.3f) grounded=%s support_space=%s" % [
			_player.global_position.x,
			_player.global_position.y,
			_player.global_position.z,
			str(_player.grounded),
			str(_player.support_space != null),
		]
	)
	await _capture("04_far_airborne_context")
	_player.set_physics_process(true)

	_p1.call("recover_player_for_test")
	await _advance_frames(SETTLE_FRAMES)
	await _capture("05_post_recovery")

	# Storage rebase is coordinate maintenance, not a world-space event. The
	# rendered framing contract therefore requires composition continuity through
	# the real rebase path: same provider, same Matter world location, same actor
	# world location and same camera context point after local coordinates shift.
	source = _p1.call("get_space") as LocalMatterSpace
	var provider_before_rebase := source.get_active_provider()
	var provider_id_before_rebase := provider_before_rebase.get_instance_id()
	var actor_world_before_rebase := _player.global_position
	var content_world_before_rebase := provider_before_rebase.to_global(source.get_content_center_local())
	var camera_context_world_before_rebase := _camera_rig.context_target.to_global(_camera_rig.context_local_point)
	_check(
		camera_context_world_before_rebase.distance_to(content_world_before_rebase) < 0.0001,
		"G4 storage state camera context represents Matter center before rebase"
	)
	_check(
		source.request_storage_rebase(TARGET_OLD_FRAME_CELL, STORAGE_PADDING),
		"G4 sequence queues real storage-frame rebase"
	)
	await source.storage_rebase_committed
	var rebase_report := source.get_last_storage_rebase_report()
	_check(not rebase_report.is_empty(), "G4 storage rebase publishes mapping report")
	var storage_shift := Vector3i.ZERO
	if not rebase_report.is_empty():
		storage_shift = rebase_report["local_shift"]
	await _advance_frames(2)
	var provider_after_rebase := source.get_active_provider()
	var content_world_after_rebase := provider_after_rebase.to_global(source.get_content_center_local())
	var camera_context_world_after_rebase := _camera_rig.context_target.to_global(_camera_rig.context_local_point)
	var actor_world_after_rebase := _player.global_position
	_check(
		provider_after_rebase.get_instance_id() == provider_id_before_rebase,
		"G4 storage rebase preserves provider identity"
	)
	_check(
		content_world_after_rebase.distance_to(content_world_before_rebase) < 0.0001,
		"G4 storage rebase preserves Matter world position"
	)
	_check(
		actor_world_after_rebase.distance_to(actor_world_before_rebase) < 0.01,
		"G4 storage rebase preserves actor world position"
	)
	_check(
		camera_context_world_after_rebase.distance_to(content_world_after_rebase) < 0.0001,
		"G4 storage rebase refreshes camera context without world-space drift"
	)
	print(
		"P1_CAMERA_REBASE_STATE shift=%s actor_world_error=%.8f content_world_error=%.8f camera_context_error=%.8f" % [
			str(storage_shift),
			actor_world_after_rebase.distance_to(actor_world_before_rebase),
			content_world_after_rebase.distance_to(content_world_before_rebase),
			camera_context_world_after_rebase.distance_to(content_world_after_rebase),
		]
	)
	await _capture("05b_storage_rebase_continuity")

	_check(bool(_p1.call("toggle_focused_space_for_test")), "G4 sequence releases focused Space")
	await source.provider_transition_committed
	await _advance_frames(3)
	_check(bool(_p1.call("apply_focused_central_impulse_for_test", CENTRAL_IMPULSE)), "G4 sequence applies finite translation")
	_check(bool(_p1.call("apply_focused_torque_impulse_for_test", TORQUE_IMPULSE)), "G4 sequence applies finite yaw")
	await _advance_frames(14)
	await _capture("06_dynamic_motion")

	# Storage rebase changed only local coordinates. Map the authored cut through
	# its reported shift so topology stress still targets the same world Matter.
	for z in range(2, 14):
		var cut_cell := Vector3i(6, 0, z) + storage_shift
		_check(
			_interactor.apply_edit_to_cell(source, cut_cell, P1MatterInteractor.EditMode.REMOVE),
			"G4 split removes mapped %s" % str(cut_cell)
		)
	if source.is_topology_split_pending():
		await source.topology_split_committed
	await _advance_frames(SPLIT_SETTLE_FRAMES)
	await _capture("07_immediate_split")

	await _advance_frames(16)
	await _capture("08_post_split_context")

	_p1.free()
	_finish()


func _move_player_to_space_local(space: LocalMatterSpace, local_position: Vector3) -> void:
	var provider := space.get_active_provider()
	if provider == null:
		return
	_move_player_world(provider.to_global(local_position))


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


func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_root().get_texture().get_image()
	_check(image != null and not image.is_empty(), "G4 capture %s produced pixels" % label)
	if image == null or image.is_empty():
		return
	var viewport_size := Vector2(image.get_width(), image.get_height())
	_assert_composition_guardrails(label, viewport_size)
	_print_composition_metric(label, viewport_size)
	var path := _output_dir.path_join(label + ".png")
	var save_error := image.save_png(path)
	_check(save_error == OK, "G4 capture %s saved PNG" % label)
	if save_error == OK:
		print("P1_CAMERA_CAPTURE_FRAME: %s %dx%d -> %s" % [label, image.get_width(), image.get_height(), path])


func _assert_composition_guardrails(label: String, viewport_size: Vector2) -> void:
	var camera := _camera_rig.get_camera()
	_check(not camera.is_position_behind(_player.global_position), "%s keeps actor in front of camera" % label)
	var actor_screen := camera.unproject_position(_player.global_position)
	var actor_norm := Vector2(actor_screen.x / viewport_size.x, actor_screen.y / viewport_size.y)
	_check(
		actor_norm.x >= 0.02 and actor_norm.x <= 0.98 and actor_norm.y >= USABLE_TOP_NORM and actor_norm.y <= 0.95,
		"%s keeps actor inside usable viewport" % label
	)

	if label == "03_close_obstacle_compression":
		var spring_arm := _camera_rig.get_node("YawPivot/PitchPivot/SpringArm3D") as SpringArm3D
		var actual_arm := camera.global_position.distance_to(spring_arm.global_position)
		var desired_arm := spring_arm.spring_length
		var ratio := actual_arm / desired_arm if desired_arm > 0.001 else 0.0
		_check(ratio >= 0.75, "B3 avoids catastrophic SpringArm compression")

	if label == "04_far_airborne_context":
		var rect := _project_spaces_rect(camera, _p1.call("get_active_spaces") as Array[LocalMatterSpace])
		_check(not rect.is_empty(), "B4 keeps relevant Space in front of camera")
		if not rect.is_empty():
			var minimum: Vector2 = rect["min"]
			var maximum: Vector2 = rect["max"]
			var min_norm := Vector2(minimum.x / viewport_size.x, minimum.y / viewport_size.y)
			var max_norm := Vector2(maximum.x / viewport_size.x, maximum.y / viewport_size.y)
			_check(
				max_norm.x >= 0.0 and min_norm.x <= 1.0 and max_norm.y >= USABLE_TOP_NORM and min_norm.y <= 1.0,
				"B4 relevant Space intersects usable viewport"
			)

	if label == "07_immediate_split" or label == "08_post_split_context":
		_check(
			(_p1.call("get_active_spaces") as Array[LocalMatterSpace]).size() == 2,
			"%s observes two live successor Spaces" % label
		)


func _print_composition_metric(label: String, viewport_size: Vector2) -> void:
	var camera := _camera_rig.get_camera()
	var spring_arm := _camera_rig.get_node("YawPivot/PitchPivot/SpringArm3D") as SpringArm3D
	var actor_screen := camera.unproject_position(_player.global_position)
	var actor_norm := Vector2(actor_screen.x / viewport_size.x, actor_screen.y / viewport_size.y)
	var rect := _project_spaces_rect(camera, _p1.call("get_active_spaces") as Array[LocalMatterSpace])
	var min_norm := Vector2.ZERO
	var max_norm := Vector2.ZERO
	var coverage := Vector2.ZERO
	if not rect.is_empty():
		var min_screen: Vector2 = rect["min"]
		var max_screen: Vector2 = rect["max"]
		min_norm = Vector2(min_screen.x / viewport_size.x, min_screen.y / viewport_size.y)
		max_norm = Vector2(max_screen.x / viewport_size.x, max_screen.y / viewport_size.y)
		coverage = max_norm - min_norm
	var actual_arm := camera.global_position.distance_to(spring_arm.global_position)
	var desired_arm := spring_arm.spring_length
	var arm_ratio := actual_arm / desired_arm if desired_arm > 0.001 else 0.0
	print(
		"P1_CAMERA_METRIC label=%s actor_norm=(%.3f,%.3f) spaces_min=(%.3f,%.3f) spaces_max=(%.3f,%.3f) spaces_coverage=(%.3f,%.3f) desired_arm=%.3f actual_arm=%.3f arm_ratio=%.3f active_spaces=%d" % [
			label,
			actor_norm.x, actor_norm.y,
			min_norm.x, min_norm.y,
			max_norm.x, max_norm.y,
			coverage.x, coverage.y,
			desired_arm,
			actual_arm,
			arm_ratio,
			(_p1.call("get_active_spaces") as Array[LocalMatterSpace]).size(),
		]
	)


func _project_spaces_rect(camera: Camera3D, spaces: Array[LocalMatterSpace]) -> Dictionary:
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	var count := 0
	for space in spaces:
		if space == null or space.is_retired() or space.volume == null:
			continue
		var provider := space.get_active_provider()
		if provider == null:
			continue
		var bounds := _occupied_bounds(space.volume)
		if bounds.is_empty():
			continue
		var min_local: Vector3 = Vector3(bounds["min"])
		var max_local: Vector3 = Vector3(bounds["max_exclusive"])
		for xi in [min_local.x, max_local.x]:
			for yi in [min_local.y, max_local.y]:
				for zi in [min_local.z, max_local.z]:
					var world_point := provider.to_global(Vector3(xi, yi, zi))
					if camera.is_position_behind(world_point):
						continue
					var screen := camera.unproject_position(world_point)
					minimum.x = minf(minimum.x, screen.x)
					minimum.y = minf(minimum.y, screen.y)
					maximum.x = maxf(maximum.x, screen.x)
					maximum.y = maxf(maximum.y, screen.y)
					count += 1
	return {} if count == 0 else {"min": minimum, "max": maximum, "points": count}


func _occupied_bounds(volume: CellVolume) -> Dictionary:
	if volume == null or volume.count_solid() == 0:
		return {}
	var minimum := Vector3i(2147483647, 2147483647, 2147483647)
	var maximum := Vector3i(-2147483648, -2147483648, -2147483648)
	for z in range(volume.size.z):
		for y in range(volume.size.y):
			for x in range(volume.size.x):
				var cell := Vector3i(x, y, z)
				if volume.get_cell(cell) == CellVolume.EMPTY:
					continue
				minimum.x = mini(minimum.x, x)
				minimum.y = mini(minimum.y, y)
				minimum.z = mini(minimum.z, z)
				maximum.x = maxi(maximum.x, x)
				maximum.y = maxi(maximum.y, y)
				maximum.z = maxi(maximum.z, z)
	return {"min": minimum, "max_exclusive": maximum + Vector3i.ONE}


func _advance_frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame
		await process_frame


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _finish() -> void:
	if _failures.is_empty():
		print("P1_CAMERA_CAPTURE_PASS: canonical camera preserved center, edge, legal minimum zoom, real-Matter obstacle handling, airborne context, recovery, storage rebase continuity, dynamic motion and topology succession.")
		quit(0)
		return
	for failure in _failures:
		push_error("P1_CAMERA_CAPTURE_FAIL: " + failure)
	quit(1)
