extends SceneTree

const ACQUIRE_FRAMES := 14
const POST_REBASE_FRAMES := 2
const TARGET_OLD_FRAME_CELL := Vector3i(-2, 0, 5)
const STORAGE_PADDING := 2

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://p1/main.tscn") as PackedScene
	_check(packed != null, "P1 scene loads for storage actor-context challenger")
	if packed == null:
		_finish()
		return

	var p1 := packed.instantiate()
	get_root().add_child(p1)
	await process_frame
	await _advance_frames(ACQUIRE_FRAMES)

	var space := p1.call("get_space") as LocalMatterSpace
	var player := p1.call("get_player") as SpaceQueryCharacter
	var camera_rig := p1.call("get_camera_rig") as P1CameraRig
	_check(space != null and player != null and camera_rig != null, "P1 exposes Space, actor and camera context")
	if space == null or player == null or camera_rig == null:
		p1.free()
		_finish()
		return

	_check(player.grounded and player.support_space == space, "actor is grounded on source Space before storage rebase")
	_check(player.support_body == space.get_active_provider(), "actor support body matches active provider before storage rebase")
	_check(camera_rig.context_target == space.get_active_provider(), "camera context targets source provider before storage rebase")

	var provider_before: Node3D = space.get_active_provider()
	var provider_id_before: int = provider_before.get_instance_id()
	var actor_world_before: Vector3 = player.global_position
	var actor_local_before: Vector3 = player.support_local_center
	var content_world_before: Vector3 = provider_before.to_global(space.get_content_center_local())
	var camera_context_world_before: Vector3 = camera_rig.context_target.to_global(camera_rig.context_local_point)
	_check(camera_context_world_before.distance_to(content_world_before) < 0.0001, "camera context represents the current Matter center before rebase")

	_check(space.request_storage_rebase(TARGET_OLD_FRAME_CELL, STORAGE_PADDING), "out-of-bounds target queues storage-frame rebase while actor is supported")
	await space.storage_rebase_committed
	var report: Dictionary = space.get_last_storage_rebase_report()
	_check(not report.is_empty(), "storage rebase publishes mapping report")
	if report.is_empty():
		p1.queue_free()
		await process_frame
		_finish()
		return

	var shift: Vector3i = report["local_shift"]
	var provider_after: Node3D = space.get_active_provider()
	var expected_actor_local: Vector3 = actor_local_before + Vector3(shift)
	var expected_actor_world: Vector3 = provider_after.to_global(expected_actor_local)
	var support_anchor_immediate: Vector3 = provider_after.to_global(player.support_local_center)
	var latent_support_anchor_error: float = support_anchor_immediate.distance_to(actor_world_before)
	var immediate_actor_world_error: float = player.global_position.distance_to(expected_actor_world)
	var support_local_error: float = player.support_local_center.distance_to(expected_actor_local)
	var content_world_after: Vector3 = provider_after.to_global(space.get_content_center_local())
	var camera_context_world_after: Vector3 = camera_rig.context_target.to_global(camera_rig.context_local_point)
	var camera_context_error: float = camera_context_world_after.distance_to(content_world_after)
	var content_world_error: float = content_world_after.distance_to(content_world_before)

	_check(provider_after.get_instance_id() == provider_id_before, "storage rebase preserves provider identity in composed scene")
	_check(content_world_error < 0.0001, "storage rebase preserves Matter content world position")
	_check(support_local_error < 0.0001, "actor support-local coordinate is rebased with storage frame")
	_check(immediate_actor_world_error < 0.0001, "actor world position remains continuous at storage rebase commit")
	_check(latent_support_anchor_error < 0.0001, "rebased support anchor still resolves to actor world position")
	_check(camera_context_error < 0.0001, "camera context local point is refreshed into rebased storage frame")

	await _advance_frames(POST_REBASE_FRAMES)
	var actor_world_after: Vector3 = player.global_position
	var post_rebase_actor_jump: float = actor_world_after.distance_to(actor_world_before)
	_check(player.grounded and player.support_space == space, "actor remains grounded on same logical Space after storage rebase")
	_check(player.support_body == provider_after, "actor remains attached to same provider identity after storage rebase")
	_check(post_rebase_actor_jump < 0.01, "static storage-frame maintenance does not move actor in world space")

	print(
		"P1_STORAGE_ACTOR_CONTEXT_METRIC shift=%s support_local_error=%.8f immediate_actor_world_error=%.8f latent_anchor_error=%.8f post_actor_jump=%.8f camera_context_error=%.8f content_world_error=%.8f" % [
			str(shift),
			support_local_error,
			immediate_actor_world_error,
			latent_support_anchor_error,
			post_rebase_actor_jump,
			camera_context_error,
			content_world_error,
		]
	)

	p1.free()
	_finish()


func _advance_frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame
		await process_frame


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _finish() -> void:
	if _failures.is_empty():
		print("P1_STORAGE_ACTOR_CONTEXT_PASS: actor support and camera context remain world-continuous through storage-coordinate rebasing.")
		quit(0)
		return
	for failure in _failures:
		push_error("P1_STORAGE_ACTOR_CONTEXT_FAIL: " + failure)
	quit(1)
