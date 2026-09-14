extends SceneTree

const MASS_PER_CELL := 2.0
const CYCLES := 32

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var linear_process: Dictionary = await _run_case(
		"linear_process",
		Vector3(2.3, -0.7, 1.4),
		Vector3.ZERO,
		false
	)
	var linear_physics: Dictionary = await _run_case(
		"linear_physics",
		Vector3(2.3, -0.7, 1.4),
		Vector3.ZERO,
		true
	)
	var rotating_process: Dictionary = await _run_case(
		"rotating_process",
		Vector3(2.3, -0.7, 1.4),
		Vector3(0.43, -0.31, 0.57),
		false
	)
	var rotating_physics: Dictionary = await _run_case(
		"rotating_physics",
		Vector3(2.3, -0.7, 1.4),
		Vector3(0.43, -0.31, 0.57),
		true
	)

	_check(float(linear_process["origin_gap"]) > 0.5, "process-frame replacement reproduces material translation phase loss")
	_check(float(linear_physics["origin_gap"]) < 0.005, "pre-step physics-frame replacement preserves translational phase")
	_check(float(linear_physics["linear_gap"]) < 0.0001, "pre-step physics-frame replacement preserves linear velocity")

	_check(float(rotating_process["origin_gap"]) > 0.5, "process-frame rotating replacement reproduces material position phase loss")
	_check(float(rotating_process["angle_gap"]) > 0.05, "process-frame rotating replacement reproduces material orientation phase loss")
	_check(float(rotating_physics["origin_gap"]) < 0.01, "pre-step physics-frame rotating replacement preserves world position phase")
	_check(float(rotating_physics["angle_gap"]) < 0.002, "pre-step physics-frame rotating replacement preserves orientation phase")
	_check(float(rotating_physics["linear_gap"]) < 0.0002, "pre-step physics-frame rotating replacement preserves linear velocity")
	_check(float(rotating_physics["angular_gap"]) < 0.0002, "pre-step physics-frame rotating replacement preserves angular velocity")

	print(
		"RIGID_REPLACEMENT_TIMING_METRIC cycles=%d linear_process_origin=%.10f linear_process_velocity=%.10f linear_physics_origin=%.10f linear_physics_velocity=%.10f rotating_process_origin=%.10f rotating_process_angle=%.10f rotating_process_linear=%.10f rotating_process_angular=%.10f rotating_physics_origin=%.10f rotating_physics_angle=%.10f rotating_physics_linear=%.10f rotating_physics_angular=%.10f"
		% [
			CYCLES,
			float(linear_process["origin_gap"]),
			float(linear_process["linear_gap"]),
			float(linear_physics["origin_gap"]),
			float(linear_physics["linear_gap"]),
			float(rotating_process["origin_gap"]),
			float(rotating_process["angle_gap"]),
			float(rotating_process["linear_gap"]),
			float(rotating_process["angular_gap"]),
			float(rotating_physics["origin_gap"]),
			float(rotating_physics["angle_gap"]),
			float(rotating_physics["linear_gap"]),
			float(rotating_physics["angular_gap"]),
		]
	)
	_finish()


func _run_case(case_name: String, linear: Vector3, angular: Vector3, replace_pre_step: bool) -> Dictionary:
	var world := Node3D.new()
	world.name = "Timing_" + case_name
	get_root().add_child(world)

	var volume := _make_volume()
	var initial_transform := Transform3D(
		Basis.from_euler(Vector3(0.21, -0.37, 0.16)),
		Vector3(6.0, -3.0, 8.0)
	)
	var control := _make_body(world, "Continuous", volume, initial_transform)
	control.linear_velocity = linear
	control.angular_velocity = angular
	var replaced := _make_body(world, "Replaced_0", _clone_volume(volume), initial_transform)
	replaced.linear_velocity = linear
	replaced.angular_velocity = angular

	var max_origin_gap := 0.0
	var max_angle_gap := 0.0
	var max_linear_gap := 0.0
	var max_angular_gap := 0.0

	if replace_pre_step:
		for cycle in range(CYCLES):
			# SceneTree.physics_frame is emitted before node _physics_process callbacks
			# and before the PhysicsServer step. Recreate the body here so the new RID
			# can participate in the upcoming physics tick.
			await physics_frame
			replaced = _replace_body(world, replaced, "Replaced_%d" % (cycle + 1))
			await process_frame
			var gap: Dictionary = _body_gap(control, replaced)
			max_origin_gap = max(max_origin_gap, float(gap["origin_gap"]))
			max_angle_gap = max(max_angle_gap, float(gap["angle_gap"]))
			max_linear_gap = max(max_linear_gap, float(gap["linear_gap"]))
			max_angular_gap = max(max_angular_gap, float(gap["angular_gap"]))
	else:
		for cycle in range(CYCLES):
			await physics_frame
			await process_frame
			var gap: Dictionary = _body_gap(control, replaced)
			max_origin_gap = max(max_origin_gap, float(gap["origin_gap"]))
			max_angle_gap = max(max_angle_gap, float(gap["angle_gap"]))
			max_linear_gap = max(max_linear_gap, float(gap["linear_gap"]))
			max_angular_gap = max(max_angular_gap, float(gap["angular_gap"]))
			# This matches the earlier round-trip campaign timing: the PhysicsServer
			# has already completed this tick before the replacement is created.
			replaced = _replace_body(world, replaced, "Replaced_%d" % (cycle + 1))

		await physics_frame
		await process_frame
		var final_gap: Dictionary = _body_gap(control, replaced)
		max_origin_gap = max(max_origin_gap, float(final_gap["origin_gap"]))
		max_angle_gap = max(max_angle_gap, float(final_gap["angle_gap"]))
		max_linear_gap = max(max_linear_gap, float(final_gap["linear_gap"]))
		max_angular_gap = max(max_angular_gap, float(final_gap["angular_gap"]))

	var result := {
		"origin_gap": max_origin_gap,
		"angle_gap": max_angle_gap,
		"linear_gap": max_linear_gap,
		"angular_gap": max_angular_gap,
	}
	world.free()
	await process_frame
	return result


func _replace_body(world: Node3D, old_body: ConstructBody, body_name: String) -> ConstructBody:
	var transform: Transform3D = old_body.global_transform
	var linear: Vector3 = old_body.linear_velocity
	var angular: Vector3 = old_body.angular_velocity
	var volume: CellVolume = _clone_volume(old_body.volume)
	var successor := _make_body(world, body_name, volume, transform)
	successor.linear_velocity = linear
	successor.angular_velocity = angular
	old_body.free()
	return successor


func _make_volume() -> CellVolume:
	var volume := CellVolume.new(Vector3i(5, 3, 4))
	volume.fill_box(Vector3i.ZERO, volume.size, CellVolume.SOLID)
	volume.set_cell(Vector3i(0, 0, 0), CellVolume.EMPTY)
	volume.set_cell(Vector3i(4, 2, 3), CellVolume.EMPTY)
	volume.set_cell(Vector3i(1, 2, 0), 3)
	return volume


func _make_body(world: Node3D, body_name: String, volume: CellVolume, transform: Transform3D) -> ConstructBody:
	var body := ConstructBody.new()
	body.name = body_name
	body.gravity_scale = 0.0
	body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.linear_damp = 0.0
	body.angular_damp = 0.0
	body.collision_layer = 0
	body.collision_mask = 0
	body.can_sleep = false
	body.mass_per_cell = MASS_PER_CELL
	world.add_child(body)
	body.global_transform = transform
	body.set_volume(volume)
	return body


func _clone_volume(source: CellVolume) -> CellVolume:
	var clone := CellVolume.new(source.size)
	for z in range(source.size.z):
		for y in range(source.size.y):
			for x in range(source.size.x):
				var cell := Vector3i(x, y, z)
				var material_id: int = source.get_cell(cell)
				if material_id != CellVolume.EMPTY:
					clone.set_cell(cell, material_id)
	return clone


func _body_gap(reference_body: ConstructBody, candidate_body: ConstructBody) -> Dictionary:
	var reference_q := Quaternion(reference_body.global_transform.basis.orthonormalized())
	var candidate_q := Quaternion(candidate_body.global_transform.basis.orthonormalized())
	return {
		"origin_gap": reference_body.global_position.distance_to(candidate_body.global_position),
		"angle_gap": reference_q.angle_to(candidate_q),
		"linear_gap": reference_body.linear_velocity.distance_to(candidate_body.linear_velocity),
		"angular_gap": reference_body.angular_velocity.distance_to(candidate_body.angular_velocity),
	}


func _finish() -> void:
	if _failures.is_empty():
		print("RIGID_REPLACEMENT_TIMING_PROBE_PASS: rigid-body replacement before the PhysicsServer step preserved phase that was lost when replacement occurred after the step.")
		quit(0)
		return
	for failure in _failures:
		push_error("RIGID_REPLACEMENT_TIMING_PROBE_FAIL: " + failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
