extends SceneTree

const VOLUME_SIZE := Vector3i(10, 4, 5)
const MASS_PER_CELL := 1.9
const CYCLES := 48

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	world.name = "TopologyRoundTripWorld"
	get_root().add_child(world)

	var initial_volume := _make_volume()
	var reference_cells: PackedInt32Array = initial_volume.duplicate_cells()
	var initial_transform := Transform3D(
		Basis.from_euler(Vector3(0.29, -0.53, 0.37)),
		Vector3(17.0, -6.0, 11.0)
	)
	var initial_linear := Vector3(2.3, -0.7, 1.4)
	var initial_angular := Vector3(0.43, -0.31, 0.57)

	var control := _make_body(world, "UnreplacedControl", initial_volume, initial_transform)
	control.linear_velocity = initial_linear
	control.angular_velocity = initial_angular

	var subject := _make_body(world, "RoundTripSubject_0", _clone_volume(initial_volume), initial_transform)
	subject.linear_velocity = initial_linear
	subject.angular_velocity = initial_angular

	var max_storage_mismatches := 0
	var max_split_world_error := 0.0
	var max_split_velocity_error := 0.0
	var max_merge_com_error := 0.0
	var max_merge_linear_error := 0.0
	var max_merge_angular_error := 0.0
	var max_control_origin_gap := 0.0
	var max_control_angle_gap := 0.0
	var max_control_linear_gap := 0.0
	var max_control_angular_gap := 0.0
	var max_control_world_cell_gap := 0.0

	for cycle in range(CYCLES):
		await physics_frame
		await process_frame

		var pre_control: Dictionary = _control_gap(control, subject)
		max_control_origin_gap = max(max_control_origin_gap, float(pre_control["origin_gap"]))
		max_control_angle_gap = max(max_control_angle_gap, float(pre_control["angle_gap"]))
		max_control_linear_gap = max(max_control_linear_gap, float(pre_control["linear_gap"]))
		max_control_angular_gap = max(max_control_angular_gap, float(pre_control["angular_gap"]))
		max_control_world_cell_gap = max(max_control_world_cell_gap, _world_cell_gap(control, subject))

		var parent_transform: Transform3D = subject.global_transform
		var parent_linear: Vector3 = subject.linear_velocity
		var parent_angular: Vector3 = subject.angular_velocity
		var parent_com_world: Vector3 = subject.to_global(subject.matter_center_of_mass_local)

		var components: Array[CellVolume] = MatterTopology.extract_connected_components(subject.volume)
		_check(components.size() == 2, "cycle %d keeps exactly two disconnected Matter regions" % cycle)
		if components.size() != 2:
			_finish()
			return

		var rebuilt := CellVolume.new(VOLUME_SIZE)
		var child_specs: Array[Dictionary] = []

		for component_index in range(components.size()):
			var source_component: CellVolume = components[component_index]
			var compact_info: Dictionary = MatterTopology.compact_volume(source_component)
			var origin: Vector3i = compact_info["origin"]
			var compact: CellVolume = compact_info["volume"]
			_copy_volume(compact, origin, rebuilt)

			var child_transform: Transform3D = parent_transform * Transform3D(Basis.IDENTITY, Vector3(origin))
			var child := _make_body(world, "Cycle_%d_Child_%d" % [cycle, component_index], compact, child_transform)
			var child_props: Dictionary = MatterMassProperties.calculate(compact, MASS_PER_CELL)
			var child_com_world: Vector3 = child.to_global(child.matter_center_of_mass_local)
			var inherited_linear: Vector3 = _velocity_at_point(parent_linear, parent_angular, parent_com_world, child_com_world)
			child.linear_velocity = inherited_linear
			child.angular_velocity = parent_angular

			child_specs.append({
				"body": child,
				"props": child_props,
				"origin": origin,
				"source": source_component,
			})

			for z in range(source_component.size.z):
				for y in range(source_component.size.y):
					for x in range(source_component.size.x):
						var source_cell := Vector3i(x, y, z)
						if source_component.get_cell(source_cell) == CellVolume.EMPTY:
							continue
						var compact_cell: Vector3i = source_cell - origin
						var parent_point_world: Vector3 = parent_transform * (Vector3(source_cell) + Vector3(0.5, 0.5, 0.5))
						var child_point_world: Vector3 = child_transform * (Vector3(compact_cell) + Vector3(0.5, 0.5, 0.5))
						max_split_world_error = max(max_split_world_error, parent_point_world.distance_to(child_point_world))
						var parent_point_velocity: Vector3 = _velocity_at_point(parent_linear, parent_angular, parent_com_world, parent_point_world)
						var child_point_velocity: Vector3 = _velocity_at_point(inherited_linear, parent_angular, child_com_world, child_point_world)
						max_split_velocity_error = max(max_split_velocity_error, parent_point_velocity.distance_to(child_point_velocity))

		var storage_mismatches := _storage_mismatch_count(reference_cells, rebuilt.duplicate_cells())
		max_storage_mismatches = max(max_storage_mismatches, storage_mismatches)
		_check(storage_mismatches == 0, "cycle %d reconstructs exact Matter storage and material ids" % cycle)

		var merged_props: Dictionary = MatterMassProperties.calculate(rebuilt, MASS_PER_CELL)
		var merged_com_world: Vector3 = parent_transform * Vector3(merged_props["center_of_mass_local"])
		var merged_inertia_world: Basis = MatterMassProperties.world_inertia(merged_props["inertia_tensor_local"], parent_transform.basis)
		var total_p := Vector3.ZERO
		var total_l_about_merged := Vector3.ZERO
		for spec in child_specs:
			var child_body: ConstructBody = spec["body"]
			var child_props: Dictionary = spec["props"]
			var child_mass: float = float(child_props["mass"])
			var child_com_world: Vector3 = child_body.to_global(child_body.matter_center_of_mass_local)
			var child_p: Vector3 = child_body.linear_velocity * child_mass
			var child_inertia_world: Basis = MatterMassProperties.world_inertia(child_props["inertia_tensor_local"], child_body.global_transform.basis)
			total_p += child_p
			total_l_about_merged += child_inertia_world * child_body.angular_velocity
			total_l_about_merged += (child_com_world - merged_com_world).cross(child_p)

		var merged_linear: Vector3 = total_p / float(merged_props["mass"])
		var merged_angular: Vector3 = merged_inertia_world.inverse() * total_l_about_merged
		max_merge_linear_error = max(max_merge_linear_error, merged_linear.distance_to(parent_linear))
		max_merge_angular_error = max(max_merge_angular_error, merged_angular.distance_to(parent_angular))

		var successor := _make_body(world, "RoundTripSubject_%d" % (cycle + 1), rebuilt, parent_transform)
		successor.linear_velocity = merged_linear
		successor.angular_velocity = merged_angular
		max_merge_com_error = max(
			max_merge_com_error,
			successor.matter_center_of_mass_local.distance_to(subject.matter_center_of_mass_local)
		)

		subject.free()
		for spec in child_specs:
			var child_body: ConstructBody = spec["body"]
			child_body.free()
		subject = successor

	await physics_frame
	await process_frame

	var final_control: Dictionary = _control_gap(control, subject)
	max_control_origin_gap = max(max_control_origin_gap, float(final_control["origin_gap"]))
	max_control_angle_gap = max(max_control_angle_gap, float(final_control["angle_gap"]))
	max_control_linear_gap = max(max_control_linear_gap, float(final_control["linear_gap"]))
	max_control_angular_gap = max(max_control_angular_gap, float(final_control["angular_gap"]))
	max_control_world_cell_gap = max(max_control_world_cell_gap, _world_cell_gap(control, subject))

	_check(max_storage_mismatches == 0, "round-trip campaign never changes logical Matter storage")
	_check(max_split_world_error < 0.00002, "compact split keeps retained Matter world positions continuous")
	_check(max_split_velocity_error < 0.00002, "compact split keeps retained Matter velocity field continuous")
	_check(max_merge_com_error < 0.000001, "compatible merge reconstructs Matter COM")
	_check(max_merge_linear_error < 0.0002, "compatible merge reconstructs parent COM linear velocity")
	_check(max_merge_angular_error < 0.0002, "compatible merge reconstructs parent angular velocity")
	_check(max_control_origin_gap < 0.01, "repeated topology replacement keeps world origin bounded against unreplaced control")
	_check(max_control_angle_gap < 0.002, "repeated topology replacement keeps orientation bounded against unreplaced control")
	_check(max_control_linear_gap < 0.001, "repeated topology replacement keeps linear velocity bounded against control")
	_check(max_control_angular_gap < 0.001, "repeated topology replacement keeps angular velocity bounded against control")
	_check(max_control_world_cell_gap < 0.02, "repeated topology replacement keeps Matter world positions bounded against control")

	print(
		"TOPOLOGY_ROUNDTRIP_METRIC cycles=%d max_storage_mismatches=%d split_world_error=%.10f split_velocity_error=%.10f merge_com_error=%.10f merge_linear_error=%.10f merge_angular_error=%.10f control_origin_gap=%.10f control_angle_gap=%.10f control_linear_gap=%.10f control_angular_gap=%.10f control_world_cell_gap=%.10f final_origin_gap=%.10f final_angle_gap=%.10f final_linear_gap=%.10f final_angular_gap=%.10f"
		% [
			CYCLES,
			max_storage_mismatches,
			max_split_world_error,
			max_split_velocity_error,
			max_merge_com_error,
			max_merge_linear_error,
			max_merge_angular_error,
			max_control_origin_gap,
			max_control_angle_gap,
			max_control_linear_gap,
			max_control_angular_gap,
			max_control_world_cell_gap,
			float(final_control["origin_gap"]),
			float(final_control["angle_gap"]),
			float(final_control["linear_gap"]),
			float(final_control["angular_gap"]),
		]
	)
	_finish()


func _make_volume() -> CellVolume:
	var volume := CellVolume.new(VOLUME_SIZE)
	volume.fill_box(Vector3i(0, 0, 0), Vector3i(3, 3, 3), 2)
	volume.set_cell(Vector3i(0, 0, 0), CellVolume.EMPTY)
	volume.set_cell(Vector3i(2, 2, 2), CellVolume.EMPTY)
	volume.set_cell(Vector3i(1, 2, 0), 4)

	volume.fill_box(Vector3i(6, 1, 1), Vector3i(10, 4, 5), 3)
	volume.set_cell(Vector3i(6, 1, 1), CellVolume.EMPTY)
	volume.set_cell(Vector3i(9, 3, 4), CellVolume.EMPTY)
	volume.set_cell(Vector3i(8, 1, 4), 5)
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
	_copy_volume(source, Vector3i.ZERO, clone)
	return clone


func _copy_volume(source: CellVolume, target_origin: Vector3i, target: CellVolume) -> void:
	for z in range(source.size.z):
		for y in range(source.size.y):
			for x in range(source.size.x):
				var cell := Vector3i(x, y, z)
				var material_id: int = source.get_cell(cell)
				if material_id != CellVolume.EMPTY:
					target.set_cell(cell + target_origin, material_id)


func _storage_mismatch_count(reference_cells: PackedInt32Array, candidate_cells: PackedInt32Array) -> int:
	if reference_cells.size() != candidate_cells.size():
		return max(reference_cells.size(), candidate_cells.size())
	var mismatches := 0
	for index in range(reference_cells.size()):
		if reference_cells[index] != candidate_cells[index]:
			mismatches += 1
	return mismatches


func _control_gap(control: ConstructBody, subject: ConstructBody) -> Dictionary:
	var control_q := Quaternion(control.global_transform.basis.orthonormalized())
	var subject_q := Quaternion(subject.global_transform.basis.orthonormalized())
	return {
		"origin_gap": control.global_position.distance_to(subject.global_position),
		"angle_gap": control_q.angle_to(subject_q),
		"linear_gap": control.linear_velocity.distance_to(subject.linear_velocity),
		"angular_gap": control.angular_velocity.distance_to(subject.angular_velocity),
	}


func _world_cell_gap(control: ConstructBody, subject: ConstructBody) -> float:
	var max_gap := 0.0
	for z in range(control.volume.size.z):
		for y in range(control.volume.size.y):
			for x in range(control.volume.size.x):
				var cell := Vector3i(x, y, z)
				if control.volume.get_cell(cell) == CellVolume.EMPTY:
					continue
				var local_point := Vector3(cell) + Vector3(0.5, 0.5, 0.5)
				max_gap = max(max_gap, control.to_global(local_point).distance_to(subject.to_global(local_point)))
	return max_gap


func _velocity_at_point(linear: Vector3, angular: Vector3, com_world: Vector3, point_world: Vector3) -> Vector3:
	return linear + angular.cross(point_world - com_world)


func _finish() -> void:
	if _failures.is_empty():
		print("TOPOLOGY_ROUNDTRIP_CAMPAIGN_PASS: repeated split/compact/compatible-merge replacement preserved exact Matter storage and stayed bounded against an unreplaced dynamic control.")
		quit(0)
		return
	for failure in _failures:
		push_error("TOPOLOGY_ROUNDTRIP_CAMPAIGN_FAIL: " + failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
