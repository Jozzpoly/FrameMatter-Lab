extends SceneTree

const LINEAR := Vector3(120.0, 0.0, 0.0)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	world.name = "RigidCreationLifecycleWorld"
	get_root().add_child(world)

	# Enter the physics-frame callback boundary used by topology replacement.
	await physics_frame

	var volume := CellVolume.new(Vector3i.ONE)
	volume.set_cell(Vector3i.ZERO, CellVolume.SOLID)
	var initial_transform := Transform3D(Basis.IDENTITY, Vector3(0.0, 5.0, 0.0))
	var body := _make_body(world, volume, initial_transform)
	body.linear_velocity = LINEAR

	var rid := body.get_rid()
	var node_origin_created := body.global_position
	var server_origin_created := _server_origin(rid)
	var query_initial_created := _ray_hits_body(world, body, 0.0)
	var query_forward_created := _ray_hits_body(world, body, 2.0)

	# process_frame occurs after the physics iteration. Compare scene-node state,
	# authoritative PhysicsServer RID state and query-space visibility separately.
	await process_frame
	var node_origin_after_process := body.global_position
	var server_origin_after_process := _server_origin(rid)
	var query_initial_after_process := _ray_hits_body(world, body, 0.0)
	var query_forward_after_process := _ray_hits_body(world, body, 2.0)

	# At the next physics_frame, the scene node should receive the prior solver
	# result during server synchronization even before another process_frame.
	await physics_frame
	var node_origin_next_physics := body.global_position
	var server_origin_next_physics := _server_origin(rid)
	var query_initial_next_physics := _ray_hits_body(world, body, 0.0)
	var query_forward_next_physics := _ray_hits_body(world, body, 2.0)

	var node_process_displacement := node_origin_after_process.distance_to(node_origin_created)
	var server_process_displacement := server_origin_after_process.distance_to(server_origin_created)
	var node_sync_gap := node_origin_next_physics.distance_to(server_origin_after_process)

	_check(node_origin_created.distance_to(initial_transform.origin) < 0.000001, "fresh scene node starts at requested transform")
	_check(server_origin_created.distance_to(initial_transform.origin) < 0.000001, "fresh RID starts at requested transform")
	_check(query_initial_created, "fresh body is query-visible at its initial position during creation physics_frame")
	_check(not query_forward_created, "fresh body is not prematurely query-visible at future position")

	_check(server_process_displacement > 1.0, "fresh RID participates materially in the physics iteration before process_frame")
	_check(node_process_displacement < 0.001, "scene-node transform remains unsynchronized immediately after that solver step")
	_check(server_origin_after_process.x > 1.0, "PhysicsServer state exposes the advanced fresh-body transform after the step")
	_check(query_forward_after_process, "direct-space query sees the advanced fresh body after the solver step")
	_check(not query_initial_after_process, "direct-space query no longer treats the initial position as current after the solver step")

	_check(node_sync_gap < 0.001, "next physics_frame synchronizes scene-node transform to prior PhysicsServer state")
	_check(query_forward_next_physics, "advanced body remains query-visible at next physics_frame")
	_check(not query_initial_next_physics, "old query position remains retired at next physics_frame")
	_check(server_origin_next_physics.distance_to(server_origin_after_process) < 0.001, "next physics_frame occurs before another solver advance")

	print(
		"RIGID_CREATION_LIFECYCLE_METRIC node_process_displacement=%.8f server_process_displacement=%.8f node_sync_gap=%.8f node_created=%s server_created=%s node_after_process=%s server_after_process=%s node_next_physics=%s server_next_physics=%s query_created_initial=%s query_created_forward=%s query_process_initial=%s query_process_forward=%s query_next_initial=%s query_next_forward=%s"
		% [
			node_process_displacement,
			server_process_displacement,
			node_sync_gap,
			node_origin_created,
			server_origin_created,
			node_origin_after_process,
			server_origin_after_process,
			node_origin_next_physics,
			server_origin_next_physics,
			query_initial_created,
			query_forward_created,
			query_initial_after_process,
			query_forward_after_process,
			query_initial_next_physics,
			query_forward_next_physics,
		]
	)

	body.free()
	_finish()


func _server_origin(rid: RID) -> Vector3:
	var state: Variant = PhysicsServer3D.body_get_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM)
	return (state as Transform3D).origin


func _ray_hits_body(world: Node3D, body: CollisionObject3D, x: float) -> bool:
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(x, 8.0, 0.5),
		Vector3(x, 2.0, 0.5)
	)
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit["collider"] == body


func _make_body(world: Node3D, volume: CellVolume, transform: Transform3D) -> ConstructBody:
	var body := ConstructBody.new()
	body.name = "FreshBody"
	body.gravity_scale = 0.0
	body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.linear_damp = 0.0
	body.angular_damp = 0.0
	body.can_sleep = false
	body.collision_layer = 1
	body.collision_mask = 0
	world.add_child(body)
	body.global_transform = transform
	body.set_volume(volume)
	return body


func _finish() -> void:
	if _failures.is_empty():
		print("RIGID_CREATION_LIFECYCLE_PROBE_PASS: a body created at physics_frame participated in the upcoming solver step while scene-node transform synchronization lagged until the next physics-frame sync boundary.")
		quit(0)
		return
	for failure in _failures:
		push_error("RIGID_CREATION_LIFECYCLE_PROBE_FAIL: " + failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
