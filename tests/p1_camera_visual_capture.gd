extends SceneTree

const ACQUIRE_FRAMES := 18
const SETTLE_FRAMES := 8
const SPLIT_SETTLE_FRAMES := 4
const EDGE_LOCAL := Vector3(13.35, 1.94, 8.5)
const WALL_NEAR_LOCAL := Vector3(4.65, 1.94, 6.5)
const FAR_AIRBORNE_WORLD := Vector3(34.5, -7.0, 0.0)
const CENTRAL_IMPULSE := Vector3(0.0, 0.0, -36.0)
const TORQUE_IMPULSE := Vector3(0.0, 90.0, 0.0)
const VARIANT_CANONICAL := "canonical"
const VARIANT_GUARDED_CONTEXT := "guarded_context"
const VARIANT_ADAPTIVE_RELATIONAL := "adaptive_relational"

var _failures: Array[String] = []
var _output_dir := ""
var _variant := VARIANT_CANONICAL
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
	_variant = OS.get_environment("P1_CAMERA_VARIANT").strip_edges()
	if _variant.is_empty():
		_variant = VARIANT_CANONICAL
	_check(
		_variant == VARIANT_CANONICAL
		or _variant == VARIANT_GUARDED_CONTEXT
		or _variant == VARIANT_ADAPTIVE_RELATIONAL,
		"G4 capture variant is supported: %s" % _variant
	)
	if not _failures.is_empty():
		_finish()
		return
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
	_check(source != null and _player != null and _camera_rig != null and _interactor != null, "G4 capture resolves real P1 actor/camera/Space/interactor")
	if source == null or _player == null or _camera_rig == null or _interactor == null:
		_p1.free()
		_finish()
		return

	if _variant == VARIANT_ADAPTIVE_RELATIONAL:
		_camera_rig.set_adaptive_relational_enabled(true)
	else:
		_camera_rig.set_composition_guard_enabled(_variant == VARIANT_GUARDED_CONTEXT)
	_refresh_variant_context()

	# B0 — ordinary centered spawn. This is the case where the current camera's
	# actor↔content-center separation approaches zero and therefore exposes
	# whether Space extent has any independent framing influence.
	_camera_rig.reset_view()
	await _advance_frames(3)
	await _capture("00_default_center")

	# B1 — actor near the authored deck edge while still using the same Space.
	_move_player_to_space_local(source, EDGE_LOCAL)
	await _advance_frames(SETTLE_FRAMES)
	await _capture("01_actor_near_edge")

	# B2 — user-accessible minimum zoom at the same edge position. A legal camera
	# input must not permanently turn the world into an unusable near-field crop.
	_camera_rig.set("_distance", _camera_rig.min_distance)
	_camera_rig.call("_apply_orbit")
	await _advance_frames(3)
	await _capture("02_minimum_zoom_edge")

	# B3 — place the actor beside real authored Matter wall geometry and orient
	# the spring arm through it. This isolates collision compression from good
	# composition: SpringArm may correctly avoid clipping yet still produce an
	# unusable frame. Give challengers enough frames to demonstrate a stable
	# recovery rather than judging their first transient response.
	_camera_rig.reset_view()
	_move_player_to_space_local(source, WALL_NEAR_LOCAL)
	await _advance_frames(SETTLE_FRAMES)
	var provider := source.get_active_provider()
	var wall_world := provider.to_global(Vector3(3.5, 1.6, 6.5))
	var to_wall: Vector3 = wall_world - _player.global_position
	to_wall.y = 0.0
	if to_wall.length_squared() > 0.000001:
		_camera_rig.set("_yaw", atan2(to_wall.x, to_wall.z))
		_camera_rig.call("_apply_orbit")
	await _advance_frames(SETTLE_FRAMES)
	await _capture("03_close_obstacle_compression")

	# B4 — actor far outside the world reference and below the Space while the
	# logical focus/context remains the experiment Space. This is intentionally
	# adversarial but still uses the real camera policy rather than a fixture.
	_camera_rig.reset_view()
	_move_player_world(FAR_AIRBORNE_WORLD)
	await _advance_frames(8)
	await _capture("04_far_airborne_context")

	# B5 — recovery should return to a coherent experiment frame rather than only
	# teleporting the actor while leaving camera state stale.
	_p1.call("recover_player_for_test")
	await _advance_frames(SETTLE_FRAMES)
	await _capture("05_post_recovery")

	# B6 — real dynamic translation+yaw while actor rides the Space.
	source = _p1.call("get_space") as LocalMatterSpace
	_check(bool(_p1.call("toggle_focused_space_for_test")), "G4 sequence releases focused Space")
	await source.provider_transition_committed
	await _advance_frames(3)
	_check(bool(_p1.call("apply_focused_central_impulse_for_test", CENTRAL_IMPULSE)), "G4 sequence applies finite translation")
	_check(bool(_p1.call("apply_focused_torque_impulse_for_test", TORQUE_IMPULSE)), "G4 sequence applies finite yaw")
	await _advance_frames(14)
	await _capture("06_dynamic_motion")

	# B7 — immediate topology succession. The current policy follows only the
	# actor-owned successor; rendered evidence must show whether the causal
	# relation to the sibling is still legible at the transaction boundary.
	for z in range(2, 14):
		var cut_cell := Vector3i(6, 0, z)
		_check(_interactor.apply_edit_to_cell(source, cut_cell, P1MatterInteractor.EditMode.REMOVE), "G4 split removes %s" % str(cut_cell))
	if source.is_topology_split_pending():
		await source.topology_split_committed
	await _advance_frames(SPLIT_SETTLE_FRAMES)
	await _capture("07_immediate_split")

	# B8 — small post-split observation window: enough to expose a camera that
	# instantly abandons the sibling, not enough to demand indefinite multi-body
	# group framing after causality is already understood.
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


func _refresh_variant_context() -> void:
	if (
		_variant != VARIANT_GUARDED_CONTEXT
		and _variant != VARIANT_ADAPTIVE_RELATIONAL
	) or _p1 == null or _camera_rig == null:
		return
	var space := _p1.call("get_space") as LocalMatterSpace
	if space == null or not is_instance_valid(space) or space.is_retired():
		return
	var provider := space.get_active_provider()
	if provider == null:
		return
	_camera_rig.set_context_target(
		provider,
		space.get_content_center_local(),
		_space_planar_radius(space)
	)


func _space_planar_radius(space: LocalMatterSpace) -> float:
	if space == null or space.volume == null or space.volume.count_solid() == 0:
		return 0.0
	var center: Vector3 = space.get_content_center_local()
	var radius := 0.0
	for z in range(space.volume.size.z):
		for y in range(space.volume.size.y):
			for x in range(space.volume.size.x):
				var cell := Vector3i(x, y, z)
				if space.volume.get_cell(cell) == CellVolume.EMPTY:
					continue
				var offset := Vector2(float(x) + 0.5 - center.x, float(z) + 0.5 - center.z)
				radius = maxf(radius, offset.length() + 0.70710678)
	return radius


func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_root().get_texture().get_image()
	_check(image != null and not image.is_empty(), "G4 capture %s produced pixels" % label)
	if image == null or image.is_empty():
		return
	var path := _output_dir.path_join(label + ".png")
	var save_error := image.save_png(path)
	_check(save_error == OK, "G4 capture %s saved PNG" % label)
	_print_composition_metric(label, Vector2(image.get_width(), image.get_height()))
	if save_error == OK:
		print("P1_CAMERA_CAPTURE_FRAME: %s %dx%d -> %s" % [label, image.get_width(), image.get_height(), path])


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
		"P1_CAMERA_METRIC variant=%s label=%s actor_norm=(%.3f,%.3f) spaces_min=(%.3f,%.3f) spaces_max=(%.3f,%.3f) spaces_coverage=(%.3f,%.3f) desired_arm=%.3f actual_arm=%.3f arm_ratio=%.3f active_spaces=%d" % [
			_variant,
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
		_refresh_variant_context()
		await physics_frame
		await process_frame


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _finish() -> void:
	if _failures.is_empty():
		print("P1_CAMERA_CAPTURE_PASS: variant=%s captured center, edge, legal minimum zoom, real-Matter obstacle compression, airborne context, recovery, dynamic motion and topology succession." % _variant)
		quit(0)
		return
	for failure in _failures:
		push_error("P1_CAMERA_CAPTURE_FAIL: " + failure)
	quit(1)
