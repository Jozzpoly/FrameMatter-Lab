extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Node3D.new()
	host.name = "P1StorageRebaseProbe"
	get_root().add_child(host)

	var volume := CellVolume.new(Vector3i(4, 2, 4))
	volume.fill_box(Vector3i(1, 0, 1), Vector3i(3, 1, 3), CellVolume.SOLID)
	volume.set_cell(Vector3i(1, 1, 1), CellVolume.SOLID)
	var lineage := MatterLineageMap.new(volume.size)
	var issuer := MatterLineageIssuer.new(820000)
	var source_cells := _occupied_cells(volume)
	var max_source_token := MatterLineageMap.NONE
	for cell in source_cells:
		var token := issuer.allocate()
		lineage.set_lineage(cell, token)
		max_source_token = max(max_source_token, token)

	var basis := Basis(Vector3.UP, 0.43)
	var transform := Transform3D(basis, Vector3(3.4, 1.7, -5.2))
	var linear := Vector3(1.1, 0.18, -0.42)
	var angular := Vector3(0.07, 0.36, -0.04)
	var space := LocalMatterSpace.new()
	space.name = "P1ExpandableSpace"
	space.lineage_issuer = issuer
	space.dynamic_gravity_scale = 0.0
	space.dynamic_linear_damp = 0.0
	space.dynamic_angular_damp = 0.0
	space.dynamic_can_sleep = false
	host.add_child(space)
	space.initialize_dynamic(volume, lineage, transform, linear, angular)
	await process_frame

	var body := space.get_active_provider() as ConstructBody
	_check(body != null, "storage challenger uses real ConstructBody")
	if body == null:
		host.free()
		_finish()
		return

	var provider_id := body.get_instance_id()
	var previous_revision := volume.revision
	var old_com_world := body.global_transform * body.matter_center_of_mass_local
	var truth: Dictionary = {}
	for cell in source_cells:
		var world_position := body.global_transform * (Vector3(cell) + Vector3(0.5, 0.5, 0.5))
		truth[cell] = {
			"world": world_position,
			"lineage": lineage.get_lineage(cell),
			"velocity": _velocity_at_point(linear, angular, old_com_world, world_position),
		}

	var requested_old_frame_cell := Vector3i(-2, 0, 5)
	var expansion := space.ensure_storage_contains(requested_old_frame_cell, 2)
	_check(not expansion.is_empty(), "out-of-bounds local target can request bounded dense-storage expansion")
	if expansion.is_empty():
		host.free()
		_finish()
		return

	var shift: Vector3i = expansion["local_shift"]
	var mapped_target: Vector3i = expansion["cell"]
	var current_body := space.get_active_provider() as ConstructBody
	_check(bool(expansion["expanded"]), "storage challenger reports a real expansion")
	_check(shift != Vector3i.ZERO, "negative-side expansion rebases local storage coordinates")
	_check(current_body != null and current_body.get_instance_id() == provider_id, "storage rebase preserves provider identity")
	_check(space.volume.in_bounds(mapped_target), "requested old-frame target maps inside expanded storage")
	_check(space.volume.revision == previous_revision, "pure storage rebase does not masquerade as Matter mutation revision")

	var max_world_error := 0.0
	var max_velocity_error := 0.0
	var lineage_errors := 0
	for old_cell_variant in truth.keys():
		var old_cell := old_cell_variant as Vector3i
		var mapped_cell := old_cell + shift
		var expected: Dictionary = truth[old_cell]
		_check(space.volume.get_cell(mapped_cell) != CellVolume.EMPTY, "rebased storage retains occupied Matter cell")
		if space.lineage.get_lineage(mapped_cell) != int(expected["lineage"]):
			lineage_errors += 1
		var world_now := current_body.global_transform * (Vector3(mapped_cell) + Vector3(0.5, 0.5, 0.5))
		max_world_error = max(max_world_error, world_now.distance_to(expected["world"]))

	var new_com_world := current_body.global_transform * current_body.matter_center_of_mass_local
	var com_world_error := old_com_world.distance_to(new_com_world)
	for old_cell_variant in truth.keys():
		var expected: Dictionary = truth[old_cell_variant]
		var world_position: Vector3 = expected["world"]
		var velocity_now := _velocity_at_point(
			current_body.linear_velocity,
			current_body.angular_velocity,
			new_com_world,
			world_position
		)
		max_velocity_error = max(max_velocity_error, velocity_now.distance_to(expected["velocity"]))

	_check(lineage_errors == 0, "storage rebase preserves every Matter lineage token")
	_check(max_world_error < 0.00001, "storage-coordinate rebase preserves every retained Matter world position")
	_check(com_world_error < 0.00001, "dynamic storage rebase preserves Matter world COM")
	_check(max_velocity_error < 0.00001, "dynamic storage rebase preserves rigid velocity field")
	_check(current_body.linear_velocity.distance_to(linear) < 0.000001, "storage rebase preserves rigid linear velocity")
	_check(current_body.angular_velocity.distance_to(angular) < 0.000001, "storage rebase preserves rigid angular velocity")

	var pre_place_revision := space.volume.revision
	_check(space.mutate_cell(mapped_target, CellVolume.SOLID), "fresh Matter can be placed into newly expanded storage")
	var fresh_token := space.lineage.get_lineage(mapped_target)
	_check(fresh_token > max_source_token, "new Matter after rebase receives fresh non-colliding lineage below UI authority")
	_check(space.volume.revision == pre_place_revision + 1, "actual placement advances Matter revision exactly once")

	print(
		"P1_STORAGE_REBASE_METRIC shift=%s previous_size=%s current_size=%s world_error=%.10f com_error=%.10f velocity_error=%.10f fresh_token=%d" % [
			str(shift),
			str(expansion["previous_size"]),
			str(expansion["current_size"]),
			max_world_error,
			com_world_error,
			max_velocity_error,
			fresh_token,
		]
	)

	host.free()
	_finish()


func _velocity_at_point(
	linear_velocity: Vector3,
	angular_velocity: Vector3,
	com_world: Vector3,
	point_world: Vector3
) -> Vector3:
	return linear_velocity + angular_velocity.cross(point_world - com_world)


func _occupied_cells(volume: CellVolume) -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	for z in range(volume.size.z):
		for y in range(volume.size.y):
			for x in range(volume.size.x):
				var cell := Vector3i(x, y, z)
				if volume.get_cell(cell) != CellVolume.EMPTY:
					cells.append(cell)
	return cells


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _finish() -> void:
	if _failures.is_empty():
		print("P1_STORAGE_REBASE_PASS: dense local storage can grow/rebase without moving retained Matter, changing provider identity or corrupting rigid kinematics.")
		quit(0)
		return
	for failure in _failures:
		push_error("P1_STORAGE_REBASE_FAIL: " + failure)
	quit(1)
