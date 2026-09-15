extends SceneTree

const ACQUIRE_FRAMES := 12
const WALL_FRAMES := 55
const CEILING_FRAMES := 24
const RIDE_FRAMES := 36
const WALK_FRAMES := 36

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Node3D.new()
	host.name = "P1VolumetricActorProbe"
	get_root().add_child(host)

	await _probe_static_floor_wall_ceiling(host)
	await _probe_dynamic_support_without_push(host)

	host.free()
	_finish()


func _probe_static_floor_wall_ceiling(host: Node3D) -> void:
	var volume := CellVolume.new(Vector3i(8, 5, 8))
	volume.fill_box(Vector3i(0, 0, 0), Vector3i(8, 1, 8), CellVolume.SOLID)
	# Full-height wall at x=5.
	volume.fill_box(Vector3i(5, 1, 0), Vector3i(6, 4, 8), CellVolume.SOLID)
	# Low roof over the spawn/walk side, leaving only a small jump clearance.
	volume.fill_box(Vector3i(0, 3, 0), Vector3i(5, 4, 8), CellVolume.SOLID)
	var lineage: MatterLineageMap = _make_lineage(volume, 710000)

	var space := LocalMatterSpace.new()
	space.name = "P1StaticSpace"
	host.add_child(space)
	space.initialize_static(volume, lineage, Transform3D.IDENTITY)

	var actor := SpaceQueryCharacter.new()
	actor.name = "P1StaticActor"
	host.add_child(actor)
	actor.global_position = Vector3(2.5, 1.93, 4.5)
	await _advance_frames(ACQUIRE_FRAMES)

	_check(actor.grounded, "P1 volumetric actor acquires floor support")
	_check(actor.support_space == space, "P1 volumetric actor resolves logical LocalMatterSpace support")

	actor.desired_local_velocity = Vector3(4.0, 0.0, 0.0)
	for _frame in range(WALL_FRAMES):
		await physics_frame
		await process_frame
	actor.desired_local_velocity = Vector3.ZERO
	_check(actor.global_position.x < 4.72, "P1 volumetric capsule does not pass through a vertical Matter wall")
	_check(actor.observed_wall_blocks > 0, "P1 actor records volumetric wall blocking")
	_check(actor.grounded, "P1 actor remains grounded while blocked by wall")

	actor.free()
	await process_frame

	var jumper := SpaceQueryCharacter.new()
	jumper.name = "P1CeilingActor"
	host.add_child(jumper)
	jumper.global_position = Vector3(2.5, 1.93, 4.5)
	await _advance_frames(ACQUIRE_FRAMES)
	_check(jumper.grounded, "P1 ceiling challenger starts grounded")
	jumper.request_jump()
	var peak_y: float = jumper.global_position.y
	for _frame in range(CEILING_FRAMES):
		await physics_frame
		await process_frame
		peak_y = maxf(peak_y, jumper.global_position.y)
	_check(jumper.observed_ceiling_blocks > 0, "P1 volumetric capsule detects roof contact during jump")
	_check(peak_y < 2.20, "P1 jump cannot tunnel through the low Matter ceiling")

	jumper.free()
	space.free()
	await process_frame


func _probe_dynamic_support_without_push(host: Node3D) -> void:
	var volume := CellVolume.new(Vector3i(8, 2, 8))
	volume.fill_box(Vector3i(0, 0, 0), Vector3i(8, 1, 8), CellVolume.SOLID)
	var lineage: MatterLineageMap = _make_lineage(volume, 720000)

	var space := LocalMatterSpace.new()
	space.name = "P1DynamicSpace"
	space.dynamic_gravity_scale = 0.0
	space.dynamic_linear_damp = 0.0
	space.dynamic_angular_damp = 0.0
	space.dynamic_can_sleep = false
	host.add_child(space)
	space.initialize_dynamic(
		volume,
		lineage,
		Transform3D.IDENTITY,
		Vector3(0.85, 0.0, -0.18),
		Vector3(0.0, 0.31, 0.0)
	)

	var actor := SpaceQueryCharacter.new()
	actor.name = "P1DynamicActor"
	host.add_child(actor)
	actor.global_position = Vector3(3.5, 1.93, 3.5)
	await _advance_frames(ACQUIRE_FRAMES)

	var body := space.get_active_provider() as ConstructBody
	_check(body != null, "P1 dynamic challenger uses real ConstructBody support")
	_check(actor.grounded, "P1 volumetric actor acquires moving rigid support")
	_check(actor.support_space == space, "P1 moving support remains a logical-Space relation")
	if body == null or not actor.grounded:
		actor.free()
		space.free()
		await process_frame
		return

	var stationary_local: Vector3 = actor.support_local_center
	var max_local_drift: float = 0.0
	for _frame in range(RIDE_FRAMES):
		await physics_frame
		await process_frame
		max_local_drift = maxf(max_local_drift, actor.support_local_center.distance_to(stationary_local))
	_check(max_local_drift < 0.05, "P1 volumetric actor remains local while riding translation+yaw support")

	var linear_before: Vector3 = body.linear_velocity
	var angular_before: Vector3 = body.angular_velocity
	var walk_start_local: Vector3 = actor.support_local_center
	actor.desired_local_velocity = Vector3(1.2, 0.0, 0.0)
	for _frame in range(WALK_FRAMES):
		await physics_frame
		await process_frame
	actor.desired_local_velocity = Vector3.ZERO
	var walk_distance: float = actor.support_local_center.distance_to(walk_start_local)
	var linear_delta: float = body.linear_velocity.distance_to(linear_before)
	var angular_delta: float = body.angular_velocity.distance_to(angular_before)

	_check(walk_distance > 0.35, "P1 volumetric actor can walk within a moving Space")
	_check(actor.grounded, "P1 actor remains grounded after moving-Space walk")
	_check(linear_delta < 0.001, "query actor walking does not inject linear velocity into ConstructBody")
	_check(angular_delta < 0.001, "query actor walking does not inject angular velocity into ConstructBody")

	print(
		"P1_VOLUMETRIC_ACTOR_METRIC max_local_drift=%.8f walk_distance=%.6f linear_velocity_delta=%.8f angular_velocity_delta=%.8f wall_blocks=%d ceiling_blocks=%d"
		% [
			max_local_drift,
			walk_distance,
			linear_delta,
			angular_delta,
			actor.observed_wall_blocks,
			actor.observed_ceiling_blocks,
		]
	)

	actor.free()
	space.free()
	await process_frame


func _make_lineage(volume: CellVolume, first_token: int) -> MatterLineageMap:
	var lineage := MatterLineageMap.new(volume.size)
	var token: int = first_token
	for z in range(volume.size.z):
		for y in range(volume.size.y):
			for x in range(volume.size.x):
				var cell := Vector3i(x, y, z)
				if volume.get_cell(cell) == CellVolume.EMPTY:
					continue
				lineage.set_lineage(cell, token)
				token += 1
	return lineage


func _advance_frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame
		await process_frame


func _finish() -> void:
	if _failures.is_empty():
		print("P1_VOLUMETRIC_ACTOR_PASS: capsule shape queries block walls/ceilings, preserve translation+yaw support and do not inject implicit rigid-body push authority.")
		quit(0)
		return
	for failure in _failures:
		push_error("P1_VOLUMETRIC_ACTOR_FAIL: " + failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
