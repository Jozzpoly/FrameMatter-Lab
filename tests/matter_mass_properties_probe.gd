extends SceneTree

const TENSOR_TOLERANCE := 0.0001
const COM_TOLERANCE := 0.00001
const MASS_TOLERANCE := 0.000001

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	world.name = "MatterMassPropertiesWorld"
	get_root().add_child(world)

	var cases: Array[Dictionary] = []
	cases.append({
		"name": "single_cube",
		"volume": _single_cube(),
		"mass_per_cell": 2.5,
		"transform": Transform3D(Basis.from_euler(Vector3(0.31, -0.44, 0.27)), Vector3(-8.0, 4.0, 3.0)),
	})
	cases.append({
		"name": "rectangular_block",
		"volume": _rectangular_block(),
		"mass_per_cell": 1.7,
		"transform": Transform3D(Basis.from_euler(Vector3(-0.52, 0.19, 0.63)), Vector3(5.0, -6.0, 9.0)),
	})
	cases.append({
		"name": "asymmetric_sparse",
		"volume": _asymmetric_sparse(),
		"mass_per_cell": 3.2,
		"transform": Transform3D(Basis.from_euler(Vector3(0.76, 0.48, -0.35)), Vector3(13.0, 7.0, -12.0)),
	})

	var bodies: Array[ConstructBody] = []
	var properties: Array[Dictionary] = []

	for case in cases:
		var body := ConstructBody.new()
		body.name = case["name"]
		body.gravity_scale = 0.0
		body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
		body.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
		body.linear_damp = 0.0
		body.angular_damp = 0.0
		body.collision_layer = 0
		body.collision_mask = 0
		body.mass_per_cell = float(case["mass_per_cell"])
		world.add_child(body)
		body.global_transform = case["transform"]
		body.set_volume(case["volume"])
		bodies.append(body)
		properties.append(MatterMassProperties.calculate(case["volume"], body.mass_per_cell))

	for _step in range(4):
		await physics_frame
		await process_frame

	var max_com_error := 0.0
	var max_inverse_mass_error := 0.0
	var max_inverse_tensor_error := 0.0

	for index in range(cases.size()):
		var case: Dictionary = cases[index]
		var body: ConstructBody = bodies[index]
		var props: Dictionary = properties[index]
		var expected_mass: float = props["mass"]
		var expected_com: Vector3 = props["center_of_mass_local"]
		var local_inertia: Basis = props["inertia_tensor_local"]
		var expected_world_inverse: Basis = MatterMassProperties.world_inverse_inertia(local_inertia, body.global_transform.basis)

		var com_error: float = body.observed_center_of_mass_local.distance_to(expected_com)
		var inverse_mass_error: float = abs(body.observed_inverse_mass - 1.0 / expected_mass)
		var tensor_error: float = _basis_action_error(body.observed_inverse_inertia_tensor, expected_world_inverse)

		max_com_error = max(max_com_error, com_error)
		max_inverse_mass_error = max(max_inverse_mass_error, inverse_mass_error)
		max_inverse_tensor_error = max(max_inverse_tensor_error, tensor_error)

		_check(com_error < COM_TOLERANCE, "%s analytic COM matches Jolt" % case["name"])
		_check(inverse_mass_error < MASS_TOLERANCE, "%s analytic mass matches Jolt" % case["name"])
		_check(tensor_error < TENSOR_TOLERANCE, "%s analytic full inverse inertia tensor matches Jolt" % case["name"])

		print(
			"MASS_PROPERTIES_CASE name=%s cells=%d mass=%.6f com_error=%.10f inverse_mass_error=%.10f inverse_tensor_error=%.10f expected_com=%s solver_com=%s"
			% [
				case["name"],
				body.volume.count_solid(),
				expected_mass,
				com_error,
				inverse_mass_error,
				tensor_error,
				expected_com,
				body.observed_center_of_mass_local,
			]
		)

	print(
		"MASS_PROPERTIES_METRIC cases=%d max_com_error=%.10f max_inverse_mass_error=%.10f max_inverse_tensor_error=%.10f"
		% [cases.size(), max_com_error, max_inverse_mass_error, max_inverse_tensor_error]
	)
	_finish()


func _basis_action_error(a: Basis, b: Basis) -> float:
	var max_error := 0.0
	for axis in [Vector3.RIGHT, Vector3.UP, Vector3(0.0, 0.0, 1.0)]:
		max_error = max(max_error, (a * axis).distance_to(b * axis))
	return max_error


func _single_cube() -> CellVolume:
	var volume := CellVolume.new(Vector3i.ONE)
	volume.set_cell(Vector3i.ZERO, CellVolume.SOLID)
	return volume


func _rectangular_block() -> CellVolume:
	var volume := CellVolume.new(Vector3i(3, 2, 4))
	volume.fill_box(Vector3i.ZERO, volume.size, CellVolume.SOLID)
	return volume


func _asymmetric_sparse() -> CellVolume:
	var volume := CellVolume.new(Vector3i(6, 5, 4))
	var cells: Array[Vector3i] = [
		Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(2, 0, 0),
		Vector3i(0, 1, 0), Vector3i(0, 2, 0), Vector3i(1, 2, 0),
		Vector3i(3, 1, 1), Vector3i(4, 1, 1), Vector3i(4, 2, 1),
		Vector3i(2, 3, 2), Vector3i(3, 3, 2), Vector3i(5, 4, 3),
	]
	for cell in cells:
		volume.set_cell(cell, CellVolume.SOLID)
	return volume


func _finish() -> void:
	if _failures.is_empty():
		print("MASS_PROPERTIES_PROBE_PASS: analytic equal-density unit-cube Matter mass, COM and full inertia tensor matched Jolt across symmetric and asymmetric shapes/orientations.")
		quit(0)
		return
	for failure in _failures:
		push_error("MASS_PROPERTIES_PROBE_FAIL: " + failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
