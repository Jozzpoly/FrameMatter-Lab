extends SceneTree

const SOURCE_SIZE := Vector3i(9, 7, 5)
const SOURCE_TRANSFORM := Transform3D(Basis.IDENTITY, Vector3(-4.0, 0.0, -2.0))
const DETACHED_CELLS: Array[Vector3i] = [
	Vector3i(6, 4, 1),
	Vector3i(7, 4, 1),
	Vector3i(6, 4, 2),
	Vector3i(7, 4, 2),
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	world.name = "W0BDynamicDetachTimingWorld"
	get_root().add_child(world)

	var volume := CellVolume.new(SOURCE_SIZE)
	# Canonical remainder is deliberately far from the selected elevated island.
	# The selected cells still belong to the same authority before W0B, but after
	# transfer there is no legitimate source collision under/inside the target.
	volume.fill_box(Vector3i(0, 0, 0), Vector3i(3, 1, 5), CellVolume.SOLID)
	for cell in DETACHED_CELLS:
		volume.set_cell(cell, CellVolume.SOLID)

	var lineage := MatterLineageMap.new(SOURCE_SIZE)
	var issuer := MatterLineageIssuer.new(320001)
	for cell in _occupied_cells(volume):
		lineage.set_lineage(cell, issuer.allocate())

	var source := W0AuthorityPartitionSpace.new()
	source.name = "W0BCanonicalSource"
	source.lineage_issuer = issuer
	source.dynamic_gravity_scale = 1.0
	source.dynamic_linear_damp = 0.0
	source.dynamic_angular_damp = 0.0
	source.dynamic_can_sleep = true
	world.add_child(source)
	source.initialize_static(volume, lineage, SOURCE_TRANSFORM)

	var accepted := source.request_authority_partition(
		DETACHED_CELLS,
		LocalMatterSpace.ProviderKind.DYNAMIC
	)
	_check(accepted, "W0B accepts a connected selected portion for zero-launch dynamic authority transfer")
	if not accepted:
		_finish(world)
		return

	# The authority transaction commits on physics_frame, before the upcoming
	# PhysicsServer step. At this point the fresh body must exist at the exact
	# source pose with zero motion, while the source collider must already exclude
	# transferred cells.
	await physics_frame
	var result := source.get_last_authority_partition_result()
	var target := result.get("target_space") as LocalMatterSpace
	_check(target != null and is_instance_valid(target), "W0B creates a fresh target Space")
	if target == null:
		_finish(world)
		return
	_check(target.get_provider_kind() == LocalMatterSpace.ProviderKind.DYNAMIC, "W0B target enters the dynamic provider regime")
	var body := target.get_active_provider() as ConstructBody
	_check(body != null, "W0B target owns a real ConstructBody")
	if body == null:
		_finish(world)
		return

	var target_rid := body.get_rid()
	var pre_step_transform: Transform3D = body.global_transform
	var pre_step_linear := body.linear_velocity
	var pre_step_angular := body.angular_velocity
	_check(pre_step_linear.length() < 0.000001, "dynamic detach has no hidden launch velocity")
	_check(pre_step_angular.length() < 0.000001, "dynamic detach has no hidden angular launch")

	var source_origin: Vector3i = result.get("source_origin")
	var stale_collision_hits := 0
	for source_cell in DETACHED_CELLS:
		var target_cell := source_cell - source_origin
		var cell_world := body.global_transform * (Vector3(target_cell) + Vector3(0.5, 0.5, 0.5))
		stale_collision_hits += _count_external_collision_at(world, cell_world, target_rid)
	_check(stale_collision_hits == 0, "canonical source collision no longer occupies transferred Matter before first solver step")

	# The first motion must come from the solver. A stale source collider would
	# typically create an upward/lateral separation response because the fresh
	# body starts exactly where the transferred static shapes used to be.
	await process_frame
	var server_transform: Transform3D = PhysicsServer3D.body_get_state(target_rid, PhysicsServer3D.BODY_STATE_TRANSFORM)
	var server_linear: Vector3 = PhysicsServer3D.body_get_state(target_rid, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY)
	var server_angular: Vector3 = PhysicsServer3D.body_get_state(target_rid, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY)
	var displacement := server_transform.origin - pre_step_transform.origin
	_check(displacement.y < -0.00001, "fresh detached Matter moves downward in its first solver step under gravity")
	_check(absf(displacement.x) < 0.0001 and absf(displacement.z) < 0.0001, "first solver step has no lateral ghost-collision kick")
	_check(server_linear.y < -0.0001, "gravity produces the first nonzero linear velocity")
	_check(absf(server_linear.x) < 0.0001 and absf(server_linear.z) < 0.0001, "first velocity contains no lateral hidden launch")
	_check(server_angular.length() < 0.0001, "symmetric detach receives no ghost angular impulse")

	var source_tokens := _token_set(source.lineage)
	var target_tokens := _token_set(target.lineage)
	var overlap := 0
	for token_variant in source_tokens.keys():
		if target_tokens.has(token_variant):
			overlap += 1
	_check(overlap == 0, "dynamic handoff still preserves single lineage authority")

	print(
		"W0B_DYNAMIC_DETACH_METRIC stale_collision_hits=%d pre_v=%s pre_w=%s first_displacement=%s first_v=%s first_w=%s token_overlap=%d"
		% [
			stale_collision_hits,
			str(pre_step_linear),
			str(pre_step_angular),
			str(displacement),
			str(server_linear),
			str(server_angular),
			overlap,
		]
	)

	_finish(world)


func _count_external_collision_at(world: Node3D, world_point: Vector3, exclude_rid: RID) -> int:
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.70, 0.70, 0.70)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, world_point)
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [exclude_rid]
	return world.get_world_3d().direct_space_state.intersect_shape(query, 16).size()


func _token_set(lineage: MatterLineageMap) -> Dictionary:
	var result: Dictionary = {}
	for z in range(lineage.size.z):
		for y in range(lineage.size.y):
			for x in range(lineage.size.x):
				var token := lineage.get_lineage(Vector3i(x, y, z))
				if token != MatterLineageMap.NONE:
					result[token] = true
	return result


func _occupied_cells(volume: CellVolume) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for z in range(volume.size.z):
		for y in range(volume.size.y):
			for x in range(volume.size.x):
				var cell := Vector3i(x, y, z)
				if volume.get_cell(cell) != CellVolume.EMPTY:
					result.append(cell)
	return result


func _finish(world: Node3D) -> void:
	if _failures.is_empty():
		print("W0B_DYNAMIC_DETACH_PASS: selected canonical Matter transfers to a zero-launch dynamic Space, source collision retires before the first solver step and gravity supplies the first motion.")
		world.free()
		quit(0)
		return
	for failure in _failures:
		push_error("W0B_DYNAMIC_DETACH_FAIL: " + failure)
	world.free()
	quit(1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
