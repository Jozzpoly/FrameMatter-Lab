extends SceneTree

const VOLUME_SIZE := Vector3i(10, 3, 3)
const CUT_CELL := Vector3i(4, 1, 1)
const MASS_PER_CELL := 1.3

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	world.name = "TopologySplitWorld"
	get_root().add_child(world)

	var volume := CellVolume.new(VOLUME_SIZE)
	volume.fill_box(Vector3i(0, 0, 0), Vector3i(3, 3, 3), CellVolume.SOLID)
	volume.fill_box(Vector3i(6, 0, 0), Vector3i(10, 3, 3), CellVolume.SOLID)
	for x in range(3, 6):
		volume.set_cell(Vector3i(x, 1, 1), CellVolume.SOLID)

	_check(volume.count_solid() == 66, "connected source contains expected 66 cells")
	_check(MatterTopology.extract_connected_components(volume).size() == 1, "bridge makes source one connected component")

	var parent := ConstructBody.new()
	parent.name = "ParentConstruct"
	parent.gravity_scale = 0.0
	parent.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	parent.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	parent.linear_damp = 0.0
	parent.angular_damp = 0.0
	parent.mass_per_cell = MASS_PER_CELL
	world.add_child(parent)
	parent.position = Vector3(8.0, 6.0, -3.0)
	parent.rotation = Vector3(0.18, 0.55, -0.12)
	parent.set_volume(volume)
	parent.linear_velocity = Vector3(2.4, 0.7, -1.3)
	parent.angular_velocity = Vector3(0.4, -0.6, 0.8)

	for _step in range(20):
		await physics_frame

	var parent_transform: Transform3D = parent.global_transform
	var parent_linear: Vector3 = parent.linear_velocity
	var parent_angular: Vector3 = parent.angular_velocity
	var parent_com_local: Vector3 = parent.observed_center_of_mass_local
	var parent_com_expected: Vector3 = MatterTopology.center_of_mass_local(volume)
	var parent_com_world: Vector3 = parent_transform * parent_com_local

	_check(parent_com_local.distance_to(parent_com_expected) < 0.0001, "parent solver COM matches analytic connected Matter COM")

	# The cut changes logical Matter first. The pre-cut rigid state defines the
	# instantaneous velocity field inherited by all retained Matter at release.
	_check(volume.set_cell(CUT_CELL, CellVolume.EMPTY), "cut removes the bridge cell")
	var components: Array[CellVolume] = MatterTopology.extract_connected_components(volume)
	_check(components.size() == 2, "cut produces exactly two 6-connected components")
	_check(_partition_matches_source(volume, components), "component union is exact and disjoint")

	var counts: Array[int] = []
	for component in components:
		counts.append(component.count_solid())
	counts.sort()
	_check(counts == [28, 37], "split component sizes are 28 and 37 cells")
	_check(counts[0] + counts[1] == volume.count_solid(), "split preserves all retained Matter")

	var retained_linear_momentum := Vector3.ZERO
	for z in range(volume.size.z):
		for y in range(volume.size.y):
			for x in range(volume.size.x):
				var cell := Vector3i(x, y, z)
				if volume.get_cell(cell) == CellVolume.EMPTY:
					continue
				var point_world: Vector3 = parent_transform * (Vector3(x, y, z) + Vector3(0.5, 0.5, 0.5))
				retained_linear_momentum += _velocity_at_point(parent_linear, parent_angular, parent_com_world, point_world) * MASS_PER_CELL

	var children: Array[ConstructBody] = []
	var child_linear_momentum := Vector3.ZERO
	var max_velocity_field_error := 0.0

	for index in range(components.size()):
		var component: CellVolume = components[index]
		var child := ConstructBody.new()
		child.name = "SplitChild_%d" % index
		child.gravity_scale = 0.0
		child.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
		child.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
		child.linear_damp = 0.0
		child.angular_damp = 0.0
		child.mass_per_cell = MASS_PER_CELL
		world.add_child(child)
		child.global_transform = parent_transform
		child.set_volume(component)

		var child_com_local: Vector3 = MatterTopology.center_of_mass_local(component)
		var child_com_world: Vector3 = parent_transform * child_com_local
		var inherited_linear: Vector3 = _velocity_at_point(parent_linear, parent_angular, parent_com_world, child_com_world)
		child.linear_velocity = inherited_linear
		child.angular_velocity = parent_angular
		children.append(child)
		child_linear_momentum += inherited_linear * child.mass

		for z in range(component.size.z):
			for y in range(component.size.y):
				for x in range(component.size.x):
					var cell := Vector3i(x, y, z)
					if component.get_cell(cell) == CellVolume.EMPTY:
						continue
					var point_world: Vector3 = parent_transform * (Vector3(x, y, z) + Vector3(0.5, 0.5, 0.5))
					var parent_point_velocity: Vector3 = _velocity_at_point(parent_linear, parent_angular, parent_com_world, point_world)
					var child_point_velocity: Vector3 = _velocity_at_point(inherited_linear, parent_angular, child_com_world, point_world)
					max_velocity_field_error = max(max_velocity_field_error, parent_point_velocity.distance_to(child_point_velocity))

	_check(child_linear_momentum.distance_to(retained_linear_momentum) < 0.0001, "children preserve retained Matter linear momentum at split")
	_check(max_velocity_field_error < 0.00001, "every retained cell inherits the parent's instantaneous velocity field")

	parent.free()

	for _step in range(3):
		await physics_frame

	var max_child_com_error := 0.0
	var max_child_angular_error := 0.0
	for index in range(children.size()):
		var child: ConstructBody = children[index]
		var component: CellVolume = components[index]
		var expected_com: Vector3 = MatterTopology.center_of_mass_local(component)
		var expected_collision_count: int = CellCollisionBoxer.build_boxes(component, child.collision_mode).size()
		max_child_com_error = max(max_child_com_error, child.observed_center_of_mass_local.distance_to(expected_com))
		max_child_angular_error = max(max_child_angular_error, child.angular_velocity.distance_to(parent_angular))
		_check(abs(child.mass - float(component.count_solid()) * MASS_PER_CELL) < 0.0001, "child %d mass follows component Matter" % index)
		_check(child.get_collision_shape_count() == expected_collision_count, "child %d collision representation follows active compiled component Matter" % index)
		_check(_bounded_vector(child.global_position, 1000.0), "child %d position remains bounded after release" % index)
		_check(_bounded_vector(child.linear_velocity, 1000.0), "child %d linear velocity remains bounded after release" % index)

	_check(max_child_com_error < 0.0001, "split child solver COMs match analytic component COMs")
	_check(max_child_angular_error < 0.0001, "split children inherit parent angular velocity")

	print(
		"TOPOLOGY_SPLIT_METRIC parent_cells=66 retained_cells=%d component_counts=%s parent_com=%s retained_linear_momentum=%s child_linear_momentum=%s max_velocity_field_error=%.10f max_child_com_error=%.10f max_child_angular_error=%.10f child0_linear=%s child1_linear=%s"
		% [
			volume.count_solid(),
			counts,
			parent_com_local,
			retained_linear_momentum,
			child_linear_momentum,
			max_velocity_field_error,
			max_child_com_error,
			max_child_angular_error,
			children[0].linear_velocity,
			children[1].linear_velocity,
		]
	)

	if _failures.is_empty():
		print("TOPOLOGY_SPLIT_PROBE_PASS: one moving Matter frame split into two coherent dynamic components with local-coordinate and instantaneous velocity-field continuity.")
		quit(0)
		return

	for failure in _failures:
		push_error("TOPOLOGY_SPLIT_PROBE_FAIL: " + failure)
	quit(1)


func _partition_matches_source(source: CellVolume, components: Array[CellVolume]) -> bool:
	for z in range(source.size.z):
		for y in range(source.size.y):
			for x in range(source.size.x):
				var cell := Vector3i(x, y, z)
				var membership := 0
				for component in components:
					if component.get_cell(cell) != CellVolume.EMPTY:
						membership += 1
				if source.get_cell(cell) == CellVolume.EMPTY:
					if membership != 0:
						return false
				elif membership != 1:
					return false
	return true


func _velocity_at_point(linear: Vector3, angular: Vector3, com_world: Vector3, point_world: Vector3) -> Vector3:
	return linear + angular.cross(point_world - com_world)


func _bounded_vector(value: Vector3, bound: float) -> bool:
	return abs(value.x) < bound and abs(value.y) < bound and abs(value.z) < bound


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
