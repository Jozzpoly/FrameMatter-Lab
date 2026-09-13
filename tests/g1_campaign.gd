extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	get_root().add_child(world)
	_add_ground(world)

	await _run_asymmetric_motion_case(world)
	await _run_large_compound_case(world)

	world.free()

	if _failures.is_empty():
		print("G1_CAMPAIGN_PASS: asymmetric motion and larger compound-body probes completed.")
		quit(0)
	else:
		for failure in _failures:
			push_error("G1_CAMPAIGN_FAIL: " + failure)
		quit(1)


func _run_asymmetric_motion_case(world: Node3D) -> void:
	var volume := CellVolume.new(Vector3i(4, 3, 3))
	for cell in [
		Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(2, 0, 0),
		Vector3i(2, 1, 0), Vector3i(2, 2, 0), Vector3i(2, 0, 1),
		Vector3i(3, 0, 1), Vector3i(3, 0, 2),
	]:
		volume.set_cell(cell, CellVolume.SOLID)
	var truth_snapshot := volume.duplicate_cells()

	var construct := ConstructBody.new()
	construct.name = "AsymmetricConstruct"
	construct.position = Vector3(-2.0, 5.0, -1.0)
	construct.rotation = Vector3(0.24, 0.37, 0.18)
	construct.linear_velocity = Vector3(1.5, -1.0, 0.45)
	construct.angular_velocity = Vector3(1.2, 0.8, -0.65)
	world.add_child(construct)
	construct.set_volume(volume)

	var peak_linear_speed: float = 0.0
	var peak_angular_speed: float = 0.0
	var peak_physics_ms: float = 0.0

	for step in range(300):
		await physics_frame
		peak_linear_speed = max(peak_linear_speed, construct.linear_velocity.length())
		peak_angular_speed = max(peak_angular_speed, construct.angular_velocity.length())
		peak_physics_ms = max(
			peak_physics_ms,
			float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0
		)
		if step == 120:
			construct.apply_torque_impulse(Vector3(0.7, -0.4, 0.55))

	_check(construct.position.length() < 100.0, "asymmetric construct remains spatially bounded")
	_check(construct.linear_velocity.length() < 100.0, "asymmetric construct velocity remains bounded")
	_check(construct.angular_velocity.length() < 100.0, "asymmetric construct angular velocity remains bounded")
	_check(construct.get_collision_shape_count() == volume.count_solid(), "asymmetric construct keeps its derived shape count")
	_check(volume.duplicate_cells() == truth_snapshot, "rotation, impact, settling and torque preserve asymmetric Matter truth")

	print(
		"G1_METRIC asymmetric cells=%d final_pos=%s peak_linear_speed=%.4f peak_angular_speed=%.4f peak_physics_ms=%.4f"
		% [volume.count_solid(), construct.position, peak_linear_speed, peak_angular_speed, peak_physics_ms]
	)
	construct.free()


func _run_large_compound_case(world: Node3D) -> void:
	var volume := CellVolume.new(Vector3i(8, 8, 8))
	volume.fill_box(Vector3i.ZERO, Vector3i(8, 8, 8), CellVolume.SOLID)
	var truth_snapshot := volume.duplicate_cells()

	var construct := ConstructBody.new()
	construct.name = "LargeCompoundConstruct"
	construct.position = Vector3(-4.0, 10.0, -4.0)
	world.add_child(construct)
	construct.set_volume(volume)

	_check(construct.get_collision_shape_count() == 512, "8^3 dynamic construct creates the expected naive shape count")
	var initial_y: float = construct.position.y
	var peak_physics_ms: float = 0.0
	var accumulated_physics_ms: float = 0.0
	var sample_count: int = 0

	for _step in range(150):
		await physics_frame
		var physics_ms: float = float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0
		peak_physics_ms = max(peak_physics_ms, physics_ms)
		accumulated_physics_ms += physics_ms
		sample_count += 1

	var average_physics_ms: float = accumulated_physics_ms / float(max(sample_count, 1))
	_check(construct.position.y < initial_y - 0.5, "8^3 compound construct participates in dynamic physics")
	_check(construct.position.length() < 100.0, "8^3 compound construct stays numerically bounded")
	_check(volume.duplicate_cells() == truth_snapshot, "larger compound motion preserves Matter truth")

	print(
		"G1_METRIC compound8 cells=%d rebuild_us=%d final_y=%.4f avg_physics_ms=%.4f peak_physics_ms=%.4f"
		% [
			volume.count_solid(),
			construct.last_rebuild_usec,
			construct.position.y,
			average_physics_ms,
			peak_physics_ms,
		]
	)
	construct.free()


func _add_ground(world: Node3D) -> void:
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	var ground_shape := CollisionShape3D.new()
	var ground_box := BoxShape3D.new()
	ground_box.size = Vector3(40.0, 1.0, 40.0)
	ground_shape.shape = ground_box
	ground_shape.position = Vector3(0.0, -0.5, 0.0)
	ground.add_child(ground_shape)
	world.add_child(ground)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
