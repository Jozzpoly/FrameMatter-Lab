extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	get_root().add_child(world)

	var volume := CellVolume.new(Vector3i(5, 3, 3))
	for cell in [
		Vector3i(0, 0, 0),
		Vector3i(1, 0, 0),
		Vector3i(2, 0, 0),
		Vector3i(2, 1, 0),
		Vector3i(2, 0, 1),
	]:
		volume.set_cell(cell, CellVolume.SOLID)

	var construct := ConstructBody.new()
	construct.name = "G2LiveMutationConstruct"
	construct.gravity_scale = 0.0
	construct.position = Vector3(3.0, 4.0, -2.0)
	construct.linear_velocity = Vector3(2.5, 0.6, -1.1)
	construct.angular_velocity = Vector3(0.45, -0.35, 0.25)
	world.add_child(construct)
	construct.set_volume(volume)

	for _step in range(5):
		await physics_frame

	var initial_expected_com := _expected_com(volume)
	var initial_solver_com := construct.observed_center_of_mass_local
	var initial_inverse_inertia := construct.observed_inverse_inertia
	var initial_position := construct.position
	var initial_revision := volume.revision

	_check(construct.mass == 5.0, "initial mass derives from five solid cells")
	_check(abs(construct.observed_inverse_mass - 0.2) < 0.0001, "solver inverse mass matches Matter-derived mass")
	_check(initial_solver_com.distance_to(initial_expected_com) < 0.001, "initial solver COM matches analytic Matter COM")
	_check(_bounded_vector(initial_inverse_inertia, 1000.0), "initial inverse inertia is finite and bounded")

	# Removal while the body is already translating and rotating.
	volume.set_cell(Vector3i(0, 0, 0), CellVolume.EMPTY)
	var velocity_before_remove := construct.linear_velocity
	var angular_before_remove := construct.angular_velocity
	construct.rebuild_derived()
	var remove_rebuild_usec := construct.last_rebuild_usec

	for _step in range(3):
		await physics_frame

	var removed_expected_com := _expected_com(volume)
	var removed_solver_com := construct.observed_center_of_mass_local
	var removed_inverse_inertia := construct.observed_inverse_inertia
	var removed_expected_shapes := CellCollisionBoxer.build_boxes(volume, construct.collision_mode).size()

	_check(volume.revision == initial_revision + 1, "Matter revision advances for live removal")
	_check(construct.get_collision_shape_count() == removed_expected_shapes, "live removal rebuilds collision from Matter through the active collision compiler")
	_check(construct.mass == 4.0, "live removal refreshes body mass")
	_check(abs(construct.observed_inverse_mass - 0.25) < 0.0001, "solver sees refreshed inverse mass after removal")
	_check(removed_solver_com.distance_to(removed_expected_com) < 0.001, "solver COM follows analytic Matter COM after removal")
	_check(removed_solver_com.distance_to(initial_solver_com) > 0.05, "asymmetric removal materially shifts COM")
	_check(removed_inverse_inertia.distance_to(initial_inverse_inertia) > 0.0001, "asymmetric removal changes inertia")
	_check(_bounded_vector(construct.linear_velocity, 100.0), "linear velocity remains numerically bounded after live removal")
	_check(_bounded_vector(construct.angular_velocity, 100.0), "angular velocity remains numerically bounded after live removal")
	_check(construct.position.distance_to(initial_position) > 0.05, "construct continues moving through live removal")

	# Addition is tested only as representation/mass-property refresh. G2 does not
	# claim final momentum semantics for material attachment.
	volume.set_cell(Vector3i(4, 1, 1), CellVolume.SOLID)
	construct.rebuild_derived()
	var add_rebuild_usec := construct.last_rebuild_usec

	for _step in range(3):
		await physics_frame

	var added_expected_com := _expected_com(volume)
	var added_solver_com := construct.observed_center_of_mass_local
	var added_expected_shapes := CellCollisionBoxer.build_boxes(volume, construct.collision_mode).size()

	_check(construct.get_collision_shape_count() == added_expected_shapes, "live addition rebuilds collision from Matter through the active collision compiler")
	_check(construct.mass == 5.0, "live addition refreshes body mass")
	_check(abs(construct.observed_inverse_mass - 0.2) < 0.0001, "solver sees refreshed inverse mass after addition")
	_check(added_solver_com.distance_to(added_expected_com) < 0.001, "solver COM follows analytic Matter COM after addition")
	_check(_bounded_vector(construct.observed_inverse_inertia, 1000.0), "post-addition inertia remains finite and bounded")
	_check(_bounded_vector(construct.linear_velocity, 100.0), "linear velocity remains bounded after live addition")
	_check(_bounded_vector(construct.angular_velocity, 100.0), "angular velocity remains bounded after live addition")
	_check(construct.get_mesh_vertex_count() == CellMesher.count_exposed_faces(volume) * 6, "live-mutated mesh remains derived from Matter")

	print(
		"G2_METRIC remove_rebuild_us=%d add_rebuild_us=%d initial_com=%s removed_com=%s added_com=%s linear_before_remove=%s linear_after=%s angular_before_remove=%s angular_after=%s"
		% [
			remove_rebuild_usec,
			add_rebuild_usec,
			initial_solver_com,
			removed_solver_com,
			added_solver_com,
			velocity_before_remove,
			construct.linear_velocity,
			angular_before_remove,
			construct.angular_velocity,
		]
	)

	world.free()

	if _failures.is_empty():
		print("G2_SMOKE_PASS: moving construct refreshed geometry, collision, mass, COM and inertia after live Matter mutation.")
		quit(0)
	else:
		for failure in _failures:
			push_error("G2_SMOKE_FAIL: " + failure)
		quit(1)


func _expected_com(volume: CellVolume) -> Vector3:
	var weighted_sum := Vector3.ZERO
	var count := 0
	for z in range(volume.size.z):
		for y in range(volume.size.y):
			for x in range(volume.size.x):
				if volume.get_cell(Vector3i(x, y, z)) == CellVolume.EMPTY:
					continue
				weighted_sum += Vector3(float(x) + 0.5, float(y) + 0.5, float(z) + 0.5)
				count += 1
	if count == 0:
		return Vector3.ZERO
	return weighted_sum / float(count)


func _bounded_vector(value: Vector3, limit: float) -> bool:
	return abs(value.x) < limit and abs(value.y) < limit and abs(value.z) < limit


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
