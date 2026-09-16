extends SceneTree

# Cross-layer visible-composition rehearsal. Unlike the isolated G4/G5/G6/V-G
# captures, this keeps one canonical P1 runtime alive while interaction,
# representation, motion, storage maintenance, topology, camera and UI all
# change around the same actor and logical Matter history.

const ACQUIRE_FRAMES := 18
const SETTLE_FRAMES := 3
const MOTION_FRAMES := 36
const POST_REBASE_FRAMES := 3
const POST_SPLIT_FRAMES := 4
const SIBLING_MOTION_FRAMES := 30
const POST_FREEZE_FRAMES := 3
const FEEDBACK_FRAMES := 2

const CENTRAL_IMPULSE := Vector3(0.0, 0.0, -36.0)
const TORQUE_IMPULSE := Vector3(0.0, 180.0, 0.0)
const SIBLING_IMPULSE := Vector3(36.0, 0.0, 0.0)
const EDGE_Z := 8
const HUD_SAFE_POINT := Vector2(50.0, 50.0)
const POINTER_SCAN_STEP := 46
const POINTER_CENTER_EXCLUSION := 0.15
const POINTER_ORBITS := [
	[0.72, 0.48, 7.2],
	[0.20, 0.48, 7.2],
	[1.20, 0.48, 7.2],
	[0.72, 0.62, 7.2],
]

var _failures: Array[String] = []
var _output_dir := ""
var _p1: Node
var _source: LocalMatterSpace
var _player: SpaceQueryCharacter
var _camera_rig: P1CameraRig
var _interactor: P1MatterInteractor
var _control: P1SpaceControl
var _target_presentation: P1MatterTargetPresentation
var _feedback: P1InteractionFeedback


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_output_dir = OS.get_environment("P1_CROSS_LAYER_EVIDENCE_DIR")
	if _output_dir.is_empty():
		_output_dir = ProjectSettings.globalize_path("res://artifacts/p1-cross-layer-rehearsal")
	DirAccess.make_dir_recursive_absolute(_output_dir)

	var packed := load("res://p1/main.tscn") as PackedScene
	_check(packed != null, "cross-layer rehearsal loads canonical P1 scene")
	if packed == null:
		_finish()
		return

	_p1 = packed.instantiate()
	get_root().add_child(_p1)
	await process_frame
	await _advance_frames(ACQUIRE_FRAMES)

	_source = _p1.call("get_space") as LocalMatterSpace
	_player = _p1.call("get_player") as SpaceQueryCharacter
	_camera_rig = _p1.call("get_camera_rig") as P1CameraRig
	_interactor = _p1.call("get_interactor") as P1MatterInteractor
	_control = _p1.call("get_space_control") as P1SpaceControl
	_target_presentation = _p1.get_node_or_null("P1MatterTargetPresentation") as P1MatterTargetPresentation
	_feedback = _p1.get_node_or_null("HUD/P1InteractionFeedback") as P1InteractionFeedback
	var panel := _p1.get_node_or_null("HUD/Panel") as PanelContainer

	_check(
		_source != null and _player != null and _camera_rig != null and _interactor != null and _control != null,
		"cross-layer rehearsal resolves canonical runtime roles"
	)
	_check(_target_presentation != null and _feedback != null and panel != null, "cross-layer rehearsal resolves canonical presentation roles")
	if (
		_source == null or _player == null or _camera_rig == null or _interactor == null
		or _control == null or _target_presentation == null or _feedback == null or panel == null
	):
		_cleanup_and_finish()
		return

	_check(panel.size.x <= 340.0 and panel.size.y <= 64.0, "canonical compact HUD remains bounded at rehearsal start")
	_check(_source.get_provider_kind() == LocalMatterSpace.ProviderKind.STATIC, "rehearsal begins from STATIC Space")
	_check(_player.grounded and _player.support_space == _source, "actor begins grounded on source Space")
	await _capture("00_default_static")

	# 1. Exercise a real production pointer target and a real edit before any
	# representation change. Restore the removed cell afterward so the later
	# topology experiment starts from the same authored geometry.
	var target := await _find_remove_target()
	_check(not target.is_empty(), "rehearsal finds a real off-center pointer REMOVE target")
	if target.is_empty():
		_cleanup_and_finish()
		return
	var target_screen: Vector2 = target["screen"]
	Input.warp_mouse(target_screen)
	await process_frame
	_interactor.update_target_from_pointer_position(target_screen)
	_target_presentation.refresh_now()
	_check(_interactor.target_space == _source and _interactor.target_valid, "real pointer target survives live production polling")
	var removed_cell: Vector3i = _interactor.remove_cell
	await _capture("01_pointer_remove_target")
	_check(_interactor.apply_current_edit(), "real pointer REMOVE commits through production interactor")
	_check(_feedback.is_feedback_visible() and _feedback.get_feedback_text() == "REMOVED", "real pointer edit produces causal REMOVED feedback")
	await _advance_frames(FEEDBACK_FRAMES)
	await _capture("02_remove_success_feedback")
	_check(
		_interactor.apply_edit_to_cell(_source, removed_cell, P1MatterInteractor.EditMode.PLACE),
		"rehearsal restores initial target cell before lifecycle sequence"
	)
	await _advance_frames(SETTLE_FRAMES)
	Input.warp_mouse(HUD_SAFE_POINT)
	await process_frame
	_interactor.update_target_from_pointer_position(HUD_SAFE_POINT)
	_check(_interactor.target_space == null, "HUD-owned pointer region clears target before lifecycle sequence")

	# 2. Representation release is a state change with zero hidden launch.
	_check(_control.release_space(_source), "rehearsal queues zero-launch release")
	await _source.provider_transition_committed
	await _advance_frames(SETTLE_FRAMES)
	var body := _source.get_active_provider() as ConstructBody
	_check(body != null, "release installs dynamic ConstructBody provider")
	if body == null:
		_cleanup_and_finish()
		return
	_check(body.linear_velocity.length() < 0.0001 and body.angular_velocity.length() < 0.0001, "release itself contributes no hidden motion")
	await _capture("03_released_zero_motion")

	# 3. Real motion comes only from production-scale finite inputs. The longer
	# observation interval is intentional evidence design: the first rehearsal
	# proved mechanics but did not leave enough rendered displacement/rotation to
	# make the causal change legible without telemetry.
	_check(_control.apply_local_central_impulse(_source, CENTRAL_IMPULSE), "finite translation impulse accepted")
	_check(_control.apply_local_torque_impulse(_source, TORQUE_IMPULSE), "finite yaw impulse accepted")
	await _advance_frames(MOTION_FRAMES)
	body = _source.get_active_provider() as ConstructBody
	_check(body != null and body.linear_velocity.length() > 0.01 and body.angular_velocity.length() > 0.001, "finite controls create visible rigid motion")
	_check(_player.grounded and _player.support_space == _source, "actor rides moving source Space")
	await _capture("04_dynamic_finite_motion")

	# 4. Edit the still-moving Space and force an actual non-zero storage-frame
	# rebase. This is the previously missing composed scenario: edit + motion +
	# maintenance + actor/camera continuity in one visible runtime.
	_check(_interactor.apply_edit_to_cell(_source, Vector3i(1, 0, EDGE_Z), P1MatterInteractor.EditMode.PLACE), "moving Space accepts connected edge edit 1")
	_check(_interactor.apply_edit_to_cell(_source, Vector3i(0, 0, EDGE_Z), P1MatterInteractor.EditMode.PLACE), "moving Space accepts connected edge edit 2")
	await _capture("05_moving_edit_before_rebase")

	var provider_id_before_rebase: int = _source.get_active_provider().get_instance_id()
	var support_local_before_rebase: Vector3 = _player.support_local_center
	var linear_before_rebase: Vector3 = body.linear_velocity
	var angular_before_rebase: Vector3 = body.angular_velocity
	var source_edge_cell := Vector3i(-1, 0, EDGE_Z)
	_check(_interactor.request_place_to_cell(_source, source_edge_cell), "moving out-of-storage PLACE requests storage maintenance")
	_check(_source.is_storage_rebase_pending(), "storage maintenance is pending before physics boundary")
	await _source.storage_rebase_committed
	var rebase_report: Dictionary = _source.get_last_storage_rebase_report()
	var local_shift: Vector3i = rebase_report["local_shift"]
	_check(local_shift != Vector3i.ZERO, "cross-layer rehearsal performs real non-zero storage rebase")
	_check(_source.get_active_provider().get_instance_id() == provider_id_before_rebase, "rebase preserves active provider identity")
	_check(
		_player.support_local_center.distance_to(support_local_before_rebase + Vector3(local_shift)) < 0.001,
		"actor support coordinates remap across moving rebase"
	)
	await process_frame # deferred mapped placement
	await _advance_frames(POST_REBASE_FRAMES)
	var mapped_edge_cell: Vector3i = source_edge_cell + local_shift
	_check(_source.volume.in_bounds(mapped_edge_cell) and _source.volume.get_cell(mapped_edge_cell) != CellVolume.EMPTY, "mapped out-of-storage placement commits after rebase")
	body = _source.get_active_provider() as ConstructBody
	var linear_rebase_error: float = body.linear_velocity.distance_to(linear_before_rebase) if body != null else INF
	var angular_rebase_error: float = body.angular_velocity.distance_to(angular_before_rebase) if body != null else INF
	_check(linear_rebase_error < 0.02 and angular_rebase_error < 0.02, "moving rebase preserves finite solver state")
	_check(_player.grounded and _player.support_space == _source, "actor remains attached after moving rebase")
	_check(_camera_rig.context_target == _source.get_active_provider(), "camera remains contextualized after moving rebase")
	await _capture("06_post_rebase_mapped_place")

	# 5. Cut the already-moving/rebased Space through the authored seam. Mapping
	# uses the committed storage shift rather than treating storage coordinates as
	# stable logical identity.
	var actor_local_before_split: Vector3 = _player.support_local_center
	for z in range(2, 14):
		var mapped_cut_cell := Vector3i(6, 0, z) + local_shift
		_check(
			_interactor.apply_edit_to_cell(_source, mapped_cut_cell, P1MatterInteractor.EditMode.REMOVE),
			"moving topology cut removes mapped seam cell %s" % str(mapped_cut_cell)
		)
	_check(_source.is_topology_split_pending(), "final moving edit queues topology split")
	await _source.topology_split_committed
	var split_result: LocalMatterSplitResult = _source.get_last_split_result()
	_check(split_result != null and split_result.size() == 2, "moving/rebased source splits into two successors")
	var handoff_world_error := INF
	if split_result != null:
		var expected_handoff_world: Vector3 = split_result.source_transform * actor_local_before_split
		handoff_world_error = _player.global_position.distance_to(expected_handoff_world)
		_check(handoff_world_error < 0.0001, "actor handoff remains world-continuous at split")
	await _advance_frames(POST_SPLIT_FRAMES)
	var active_spaces: Array[LocalMatterSpace] = _p1.call("get_active_spaces") as Array[LocalMatterSpace]
	_check(active_spaces.size() == 2, "registry exposes exactly two live successors")
	var actor_successor: LocalMatterSpace = _player.support_space
	_check(actor_successor != null and active_spaces.has(actor_successor), "actor is supported by one live successor")
	_check(actor_successor != null and actor_successor.get_provider_kind() == LocalMatterSpace.ProviderKind.DYNAMIC, "actor successor remains dynamic immediately after split")
	await _capture("07_split_immediate")

	# 6. Give only the sibling an additional production-scale finite impulse. The
	# longer observation window makes independence readable rather than merely
	# measurable while preserving relation to the common source event.
	var sibling: LocalMatterSpace = null
	for candidate in active_spaces:
		if candidate != actor_successor:
			sibling = candidate
			break
	_check(sibling != null and sibling.get_provider_kind() == LocalMatterSpace.ProviderKind.DYNAMIC, "non-actor sibling is a live dynamic successor")
	var sibling_origin_before := Vector3.ZERO
	if sibling != null:
		sibling_origin_before = sibling.get_active_provider().global_position
		_check(_control.apply_local_central_impulse(sibling, SIBLING_IMPULSE), "sibling-only finite impulse accepted")
	await _advance_frames(SIBLING_MOTION_FRAMES)
	var sibling_delta := 0.0
	if sibling != null:
		sibling_delta = sibling.get_active_provider().global_position.distance_to(sibling_origin_before)
		_check(sibling_delta > 0.75, "sibling-only drive creates materially visible independent motion")
	await _capture("08_split_independent_sibling")

	# 7. Freeze only the actor-owned successor at its current pose while the
	# sibling remains dynamic. This is the composed state-language/camera/world
	# endpoint for the first cross-layer rehearsal.
	_check(actor_successor != null and _control.freeze_space(actor_successor), "actor successor queues freeze at current pose")
	if actor_successor != null:
		await actor_successor.provider_transition_committed
	await _advance_frames(POST_FREEZE_FRAMES)
	_check(actor_successor != null and actor_successor.get_provider_kind() == LocalMatterSpace.ProviderKind.STATIC, "actor successor becomes STATIC")
	_check(sibling != null and sibling.get_provider_kind() == LocalMatterSpace.ProviderKind.DYNAMIC, "sibling remains DYNAMIC after actor-successor freeze")
	_check(_player.grounded and _player.support_space == actor_successor, "actor remains supported on frozen successor")
	_check(_camera_rig.context_target == actor_successor.get_active_provider(), "camera follows frozen actor successor")
	await _capture("09_frozen_actor_successor_dynamic_sibling")

	print(
		"P1_CROSS_LAYER_METRIC rebase_shift=%s mapped_edge=%s linear_rebase_error=%.8f angular_rebase_error=%.8f handoff_world_error=%.8f sibling_delta=%.4f successors=%d" % [
			str(local_shift), str(mapped_edge_cell), linear_rebase_error, angular_rebase_error,
			handoff_world_error, sibling_delta, active_spaces.size(),
		]
	)
	_cleanup_and_finish()


func _find_remove_target() -> Dictionary:
	_interactor.set_mode(P1MatterInteractor.EditMode.REMOVE)
	_camera_rig.reset_view()
	await _advance_frames(SETTLE_FRAMES)
	for orbit_variant in POINTER_ORBITS:
		var orbit := orbit_variant as Array
		_camera_rig.set("_yaw", float(orbit[0]))
		_camera_rig.set("_pitch", float(orbit[1]))
		_camera_rig.set("_distance", float(orbit[2]))
		_camera_rig.call("_apply_user_orbit_immediately")
		await _advance_frames(SETTLE_FRAMES)
		var viewport := _camera_rig.get_camera().get_viewport()
		var rect := viewport.get_visible_rect()
		for y in range(int(rect.size.y * 0.24), int(rect.size.y * 0.86), POINTER_SCAN_STEP):
			for x in range(int(rect.size.x * 0.12), int(rect.size.x * 0.88), POINTER_SCAN_STEP):
				var screen := rect.position + Vector2(float(x), float(y))
				var norm := Vector2(float(x) / rect.size.x, float(y) / rect.size.y)
				if norm.distance_to(Vector2(0.5, 0.5)) < POINTER_CENTER_EXCLUSION:
					continue
				_interactor.update_target_from_pointer_position(screen)
				if _interactor.target_space != _source or not _interactor.target_valid or not _interactor.target_in_storage:
					continue
				return {"screen": screen, "norm": norm, "orbit": orbit.duplicate()}
	return {}


func _capture(label: String) -> void:
	_target_presentation.refresh_now()
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
		print("P1_CROSS_LAYER_FRAME: %s %dx%d -> %s" % [label, image.get_width(), image.get_height(), path])


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
		print("P1_CROSS_LAYER_REHEARSAL_PASS: one canonical runtime composed pointer edit, zero-launch release, finite motion, moving edit+storage rebase, topology succession, independent sibling motion and successor freeze.")
		quit(0)
		return
	for failure in _failures:
		push_error("P1_CROSS_LAYER_REHEARSAL_FAIL: " + failure)
	quit(1)
