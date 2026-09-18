extends SceneTree

const ACQUIRE_FRAMES := 20
const EDIT_CELL := Vector3i(8, 0, 8)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://p1/recovery_main.tscn") as PackedScene
	_check(packed != null, "Recovery scene loads with chunked static provider challenger")
	if packed == null:
		_finish(null)
		return

	var root := packed.instantiate()
	get_root().add_child(root)
	await _advance_frames(ACQUIRE_FRAMES)

	var world := root.call("get_recovery_world_space") as LocalMatterSpace
	var player := root.get_node_or_null("P1Player") as SpaceQueryCharacter
	var interactor := root.get_node_or_null("P1MatterInteractor") as P1MatterInteractor
	var provider: MatterRepresentation
	if world != null:
		provider = world.get_active_provider() as MatterRepresentation
	_check(world != null and provider != null and interactor != null and player != null, "chunk runtime probe resolves Recovery roles")
	if world == null or provider == null or interactor == null or player == null:
		_finish(root)
		return

	_check(provider.chunk_edge == 8, "Recovery canonical WORLD opts into edge-8 static chunks")
	_check(world.get_provider_kind() == LocalMatterSpace.ProviderKind.STATIC, "chunked provider remains ordinary STATIC representation")
	_check(player.grounded and player.support_space == world and player.support_body == provider, "chunk collision resolves actor support to the same logical provider frame")
	_check(world.volume.get_cell(EDIT_CELL) != CellVolume.EMPTY, "locality edit fixture is occupied ordinary WORLD Matter")

	var reference_vertices_before := _mesh_vertex_count(CellMesher.build_mesh(world.volume))
	_check(provider.get_mesh_vertex_count() == reference_vertices_before, "chunk mesh union matches whole-volume mesh vertex cardinality before edit")
	_check(provider.get_collision_shape_count() > 0, "chunked provider exposes physical collision shapes")

	var mesh_before := provider.get_chunk_mesh_ids_for_test()
	var collision_before := provider.get_chunk_collision_ids_for_test()
	_check(mesh_before.size() > 1 and collision_before.size() > 1, "Recovery WORLD materializes multiple derived chunks")

	_check(
		interactor.apply_edit_to_cell(world, EDIT_CELL, P1MatterInteractor.EditMode.REMOVE),
		"ordinary local WORLD edit succeeds through shared Matter authority"
	)
	var local_rebuild_usec := provider.last_rebuild_usec
	var mesh_after := provider.get_chunk_mesh_ids_for_test()
	var collision_after := provider.get_chunk_collision_ids_for_test()
	var changed_mesh := _changed_ids(mesh_before, mesh_after)
	var changed_collision := _changed_ids(collision_before, collision_after)
	var unchanged_mesh := _unchanged_ids(mesh_before, mesh_after)

	_check(changed_mesh >= 1 and changed_mesh <= 4, "one-cell edit rebuilds only own/face-neighbor mesh chunks")
	_check(changed_collision == 1, "one-cell edit rebuilds exactly one collision chunk")
	_check(unchanged_mesh > 0, "unrelated mesh chunks preserve node identity across local edit")
	_check(world.get_provider_kind() == LocalMatterSpace.ProviderKind.STATIC, "local chunk rebuild does not change provider lifecycle")
	_check(not (world as W0AuthorityPartitionSpace).is_authority_partition_pending(), "ordinary floor edit does not invent an authority partition")

	var reference_vertices_after := _mesh_vertex_count(CellMesher.build_mesh(world.volume))
	_check(provider.get_mesh_vertex_count() == reference_vertices_after, "chunk mesh union stays exact after local edit")
	await _advance_frames(3)
	_check(player.grounded and player.support_space == world and player.support_body == provider, "actor support remains on the same provider after unrelated local chunk rebuild")

	print(
		"P1_CHUNKED_STATIC_PROVIDER_METRIC chunk_edge=%d mesh_chunks=%d collision_chunks=%d changed_mesh=%d changed_collision=%d unchanged_mesh=%d local_rebuild_us=%d vertices=%d shapes=%d"
		% [
			provider.chunk_edge,
			mesh_after.size(),
			collision_after.size(),
			changed_mesh,
			changed_collision,
			unchanged_mesh,
			local_rebuild_usec,
			provider.get_mesh_vertex_count(),
			provider.get_collision_shape_count(),
		]
	)
	_finish(root)


func _changed_ids(before: Dictionary, after: Dictionary) -> int:
	var changed := 0
	var keys: Dictionary = {}
	for key in before.keys():
		keys[key] = true
	for key in after.keys():
		keys[key] = true
	for key in keys.keys():
		if int(before.get(key, 0)) != int(after.get(key, 0)):
			changed += 1
	return changed


func _unchanged_ids(before: Dictionary, after: Dictionary) -> int:
	var unchanged := 0
	for key in before.keys():
		if int(before.get(key, 0)) != 0 and int(before.get(key, 0)) == int(after.get(key, 0)):
			unchanged += 1
	return unchanged


func _mesh_vertex_count(mesh: ArrayMesh) -> int:
	if mesh == null or mesh.get_surface_count() == 0:
		return 0
	return (mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()


func _advance_frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame
		await process_frame


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _finish(root: Node) -> void:
	if root != null and is_instance_valid(root):
		root.queue_free()
	if _failures.is_empty():
		print("P1_CHUNKED_STATIC_PROVIDER_PASS: Recovery WORLD keeps one static provider/Space authority while one-cell edits rebuild only bounded derived chunks and preserve exact mesh cardinality plus actor support.")
		quit(0)
		return
	for failure in _failures:
		push_error("P1_CHUNKED_STATIC_PROVIDER_FAIL: " + failure)
	quit(1)
