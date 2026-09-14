extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	get_root().add_child(world)

	var ground := StaticBody3D.new()
	var ground_shape := CollisionShape3D.new()
	var ground_box := BoxShape3D.new()
	ground_box.size = Vector3(20.0, 1.0, 20.0)
	ground_shape.shape = ground_box
	ground_shape.position = Vector3(0.0, -0.5, 0.0)
	ground.add_child(ground_shape)
	world.add_child(ground)

	var volume := CellVolume.new(Vector3i(2, 1, 2))
	volume.fill_box(Vector3i.ZERO, Vector3i(2, 1, 2), CellVolume.SOLID)
	var truth_snapshot := volume.duplicate_cells()

	var construct := ConstructBody.new()
	construct.name = "G1Construct"
	construct.position = Vector3(-1.0, 3.0, -1.0)
	world.add_child(construct)
	construct.set_volume(volume)

	var expected_collision_shapes := CellCollisionBoxer.build_boxes(volume, construct.collision_mode).size()
	_check(construct.get_collision_shape_count() == expected_collision_shapes, "dynamic construct collision derives from the same CellVolume through the active collision compiler")
	_check(construct.get_mesh_vertex_count() == CellMesher.count_exposed_faces(volume) * 6, "dynamic construct mesh derives from Matter")

	await physics_frame
	await physics_frame
	var initial_position := construct.position

	for _step in range(90):
		await physics_frame

	_check(construct.position.y < initial_position.y - 0.5, "construct falls under real physics")
	_check(volume.duplicate_cells() == truth_snapshot, "world-space motion does not mutate local Matter")

	var max_horizontal_drift := 0.0
	for _step in range(120):
		await physics_frame
		var horizontal_delta := Vector2(
			construct.position.x - initial_position.x,
			construct.position.z - initial_position.z
		).length()
		max_horizontal_drift = max(max_horizontal_drift, horizontal_delta)

	_check(construct.position.y > -0.15 and construct.position.y < 0.25, "construct settles on the static ground")
	_check(abs(construct.linear_velocity.y) < 0.2, "settled construct has low vertical velocity")
	_check(max_horizontal_drift < 0.05, "symmetric construct does not accumulate material horizontal drift")
	_check(volume.duplicate_cells() == truth_snapshot, "settling and collision preserve Matter truth")

	var x_before_impulse := construct.position.x
	var target_delta_velocity := Vector3(2.0, 1.0, 0.0)
	construct.apply_central_impulse(target_delta_velocity * construct.mass)
	for _step in range(60):
		await physics_frame
	_check(construct.position.x > x_before_impulse + 0.05, "construct responds to a mass-normalized impulse")
	_check(volume.duplicate_cells() == truth_snapshot, "impulse-driven motion preserves Matter truth")

	print(
		"G1_METRIC final_pos=%s final_linear_velocity=%s max_horizontal_drift=%.6f mass=%.3f collision_shapes=%d"
		% [construct.position, construct.linear_velocity, max_horizontal_drift, construct.mass, construct.get_collision_shape_count()]
	)

	world.free()

	if _failures.is_empty():
		print("G1_SMOKE_PASS: same CellVolume survived dynamic Jolt motion, collision, settling, and mass-normalized impulse response.")
		quit(0)
	else:
		for failure in _failures:
			push_error("G1_SMOKE_FAIL: " + failure)
		quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
