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
	var source_cells: Array[Vector3i] = _occupied_cells(volume)
	var max_source_token: int = MatterLineageMap.NONE
	for cell in source_cells:
		var token: int = issuer.allocate()
		lineage.set_lineage(cell, token)
		max_source_token = maxi(max_source_token, token)

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

	var provider_id: int = body.get_instance_id()
	var previous_revision: int = volume.revision
	var old_com_local: Vector3 = body.matter_center_of_mass_local
	var lineage_truth: Dictionary = {}
	for cell in source_cells:
		lineage_truth[cell] = lineage.get_lineage(cell)

	var requested_old_frame_cell := Vector3i(-2, 0, 5)
	_check(space.request_storage_rebase(requested_old_frame_cell, 2), "out-of-bounds local target queues bounded storage-frame rebase")
	_check(space.is_storage_rebase_pending(), "storage rebase waits for the shared physics boundary")
	await space.storage_rebase_committed
	var expansion: Dictionary = space.get_last_storage_rebase_report()
	_check(not expansion.is_empty(), "storage boundary publishes explicit rebase mapping")
	if expansion.is_empty():
		# This coroutine resumes synchronously inside storage_rebase_committed.emit().
		# Never destroy the signal emitter before that emission has unwound.
		host.queue_free()
		await process_frame
		_finish()
		return

	var shift: Vector3i = expansion["local_shift"]
	var mapped_target: Vector3i = expansion["mapped_cell"]
	var previous_transform: Transform3D = expansion["previous_transform"]
	var current_body := space.get_active_provider() as ConstructBody
	_check(shift != Vector3i.ZERO, "negative-side expansion rebases local storage coordinates")
	_check(current_body != null and current_body.get_instance_id() == provider_id, "storage rebase preserves provider identity")
	_check(space.volume.in_bounds(mapped_target), "requested old-frame target maps inside expanded storage")
	_check(space.volume.revision == previous_revision, "pure storage rebase does not masquerade as Matter mutation revision")
	_check(not space.is_storage_rebase_pending(), "storage rebase clears pending state at commit boundary")

	var max_world_error: float = 0.0
	var max_velocity_error: float = 0.0
	var lineage_errors := 0
	var old_com_world: Vector3 = previous_transform * old_com_local
	for old_cell_variant in lineage_truth.keys():
		var old_cell: Vector3i = old_cell_variant
		var mapped_cell: Vector3i = old_cell + shift
		_check(space.volume.get_cell(mapped_cell) != CellVolume.EMPTY, "rebased storage retains occupied Matter cell")
		if space.lineage.get_lineage(mapped_cell) != int(lineage_truth[old_cell]):
			lineage_errors += 1
		var expected_world: Vector3 = previous_transform * (Vector3(old_cell) + Vector3(0.5, 0.5, 0.5))
		var world_now: Vector3 = current_body.global_transform * (Vector3(mapped_cell) + Vector3(0.5, 0.5, 0.5))
		max_world_error = maxf(max_world_error, world_now.distance_to(expected_world))

	var new_com_world: Vector3 = current_body.global_transform * current_body.matter_center_of_mass_local
	var com_world_error: float = old_com_world.distance_to(new_com_world)
	for old_cell_variant in lineage_truth.keys():
		var old_cell: Vector3i = old_cell_variant
		var world_position: Vector3 = previous_transform * (Vector3(old_cell) + Vector3(0.5, 0.5, 0.5))
		var expected_velocity: Vector3 = _velocity_at_point(linear, angular, old_com_world, world_position)
		var velocity_now: Vector3 = _velocity_at_point(
			current_body.linear_velocity,
			current_body.angular_velocity,
			new_com_world,
			world_position
		)
		max_velocity_error = maxf(max_velocity_error, velocity_now.distance_to(expected_velocity))

	_check(lineage_errors == 0, "storage rebase preserves every Matter lineage token")
	_check(max_world_error < 0.00001, "storage-coordinate rebase preserves every retained Matter world position")
	_check(com_world_error < 0.00001, "dynamic storage rebase preserves Matter world COM")
	_check(max_velocity_error < 0.00001, "dynamic storage rebase preserves rigid velocity field")
	_check(current_body.linear_velocity.distance_to(linear) < 0.000001, "storage rebase preserves rigid linear velocity")
	_check(current_body.angular_velocity.distance_to(angular) < 0.000001, "storage rebase preserves rigid angular velocity")

	var pre_place_revision: int = space.volume.revision
	_check(space.mutate_cell(mapped_target, CellVolume.SOLID), "fresh Matter can be placed into newly expanded storage after rebase commit")
	var fresh_token: int = space.lineage.get_lineage(mapped_target)
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

	# We are still executing as the synchronous continuation of
	# storage_rebase_committed.emit(). queue_free + one frame yield lets the
	# emitter finish its signal call before the probe tears the host tree down.
	host.queue_free()
	await process_frame
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
		print("P1_STORAGE_REBASE_PASS: physics-boundary dense storage rebasing preserves retained Matter world state/provider identity; placement stays a separate logical edit.")
		quit(0)
		return
	for failure in _failures:
		push_error("P1_STORAGE_REBASE_FAIL: " + failure)
	quit(1)
