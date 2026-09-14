extends SceneTree

const MUTATION_STEPS := 120

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world: Node3D = Node3D.new()
	get_root().add_child(world)

	var volume: CellVolume = CellVolume.new(Vector3i(6, 4, 4))
	# Permanent anchor/core prevents the construct from ever becoming shapeless.
	volume.fill_box(Vector3i(1, 1, 1), Vector3i(4, 3, 3), CellVolume.SOLID)

	var construct: ConstructBody = ConstructBody.new()
	construct.name = "G2MutationCampaignConstruct"
	construct.gravity_scale = 0.0
	construct.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	construct.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	construct.linear_damp = 0.0
	construct.angular_damp = 0.0
	construct.position = Vector3(-3.0, 2.0, 1.0)
	construct.linear_velocity = Vector3(1.2, 0.35, -0.55)
	construct.angular_velocity = Vector3(0.8, -0.55, 0.65)
	world.add_child(construct)
	construct.set_volume(volume)

	for _step in range(4):
		await physics_frame

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 22061993
	var max_com_error: float = 0.0
	var max_inverse_mass_error: float = 0.0
	var max_rebuild_usec: int = 0
	var total_rebuild_usec: int = 0
	var initial_revision: int = volume.revision
	var start_position: Vector3 = construct.position

	for step in range(MUTATION_STEPS):
		var cell: Vector3i = _random_mutable_cell(rng, volume)
		var next_material: int = CellVolume.SOLID
		if volume.get_cell(cell) != CellVolume.EMPTY:
			next_material = CellVolume.EMPTY
		volume.set_cell(cell, next_material)

		construct.rebuild_derived()
		max_rebuild_usec = max(max_rebuild_usec, construct.last_rebuild_usec)
		total_rebuild_usec += construct.last_rebuild_usec

		await physics_frame

		var solid_count: int = volume.count_solid()
		var expected_mass: float = float(solid_count)
		var expected_inverse_mass: float = 1.0 / expected_mass
		var expected_com: Vector3 = _expected_com(volume)
		var expected_collision_count: int = CellCollisionBoxer.build_boxes(volume, construct.collision_mode).size()
		var com_error: float = construct.observed_center_of_mass_local.distance_to(expected_com)
		var inverse_mass_error: float = abs(construct.observed_inverse_mass - expected_inverse_mass)
		max_com_error = max(max_com_error, com_error)
		max_inverse_mass_error = max(max_inverse_mass_error, inverse_mass_error)

		_check(construct.get_collision_shape_count() == expected_collision_count, "step %d collision count follows active compiled Matter representation" % step)
		_check(abs(construct.mass - expected_mass) < 0.0001, "step %d mass follows Matter" % step)
		_check(com_error < 0.001, "step %d solver COM follows analytic Matter COM" % step)
		_check(inverse_mass_error < 0.0001, "step %d solver inverse mass follows Matter mass" % step)
		_check(construct.get_mesh_vertex_count() == CellMesher.count_exposed_faces(volume) * 6, "step %d mesh follows Matter" % step)
		_check(_bounded_vector(construct.position, 1000.0), "step %d transform remains bounded" % step)
		_check(_bounded_vector(construct.linear_velocity, 100.0), "step %d linear velocity remains bounded" % step)
		_check(_bounded_vector(construct.angular_velocity, 100.0), "step %d angular velocity remains bounded" % step)
		_check(_bounded_vector(construct.observed_inverse_inertia, 1000.0), "step %d inverse inertia remains bounded" % step)

	var average_rebuild_usec: float = float(total_rebuild_usec) / float(MUTATION_STEPS)
	_check(volume.revision == initial_revision + MUTATION_STEPS, "all deterministic live mutations reached logical Matter")
	_check(construct.position.distance_to(start_position) > 0.5, "construct continued traversing world space throughout mutation campaign")

	print(
		"G2_METRIC campaign mutations=%d final_cells=%d avg_rebuild_us=%.2f max_rebuild_us=%d max_com_error=%.8f max_inverse_mass_error=%.8f final_pos=%s final_linear=%s final_angular=%s"
		% [
			MUTATION_STEPS,
			volume.count_solid(),
			average_rebuild_usec,
			max_rebuild_usec,
			max_com_error,
			max_inverse_mass_error,
			construct.position,
			construct.linear_velocity,
			construct.angular_velocity,
		]
	)

	world.free()

	if _failures.is_empty():
		print("G2_CAMPAIGN_PASS: repeated live Matter mutations kept geometry, collision and mass properties coherent during motion.")
		quit(0)
	else:
		for failure in _failures:
			push_error("G2_CAMPAIGN_FAIL: " + failure)
		quit(1)


func _random_mutable_cell(rng: RandomNumberGenerator, volume: CellVolume) -> Vector3i:
	while true:
		var cell: Vector3i = Vector3i(
			rng.randi_range(0, volume.size.x - 1),
			rng.randi_range(0, volume.size.y - 1),
			rng.randi_range(0, volume.size.z - 1)
		)
		# Keep a small immutable core so mass never reaches zero and every rebuild
		# remains a meaningful rigid-body case.
		if cell.x >= 1 and cell.x < 4 and cell.y >= 1 and cell.y < 3 and cell.z >= 1 and cell.z < 3:
			continue
		return cell
	return Vector3i.ZERO


func _expected_com(volume: CellVolume) -> Vector3:
	var weighted_sum: Vector3 = Vector3.ZERO
	var count: int = 0
	for z in range(volume.size.z):
		for y in range(volume.size.y):
			for x in range(volume.size.x):
				if volume.get_cell(Vector3i(x, y, z)) == CellVolume.EMPTY:
					continue
				weighted_sum += Vector3(float(x) + 0.5, float(y) + 0.5, float(z) + 0.5)
				count += 1
	return weighted_sum / float(count)


func _bounded_vector(value: Vector3, limit: float) -> bool:
	return abs(value.x) < limit and abs(value.y) < limit and abs(value.z) < limit


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
