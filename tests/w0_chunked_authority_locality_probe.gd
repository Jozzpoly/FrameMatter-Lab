extends SceneTree

const ACQUIRE_FRAMES := 20

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://p1/recovery_main.tscn") as PackedScene
	_check(packed != null, "Recovery scene loads for chunk-local authority detach")
	if packed == null:
		_finish(null)
		return

	var root := packed.instantiate()
	get_root().add_child(root)
	await _advance_frames(ACQUIRE_FRAMES)

	var world := root.call("get_recovery_world_space") as W0AuthorityPartitionSpace
	var player := root.get_node_or_null("P1Player") as SpaceQueryCharacter
	var interactor := root.get_node_or_null("P1MatterInteractor") as P1MatterInteractor
	var grid := root.get_node_or_null("P1MatterSurfaceGrid") as P1MatterSurfaceGrid
	var state := root.get_node_or_null("P1MatterStatePresentation") as P1MatterStatePresentation
	var provider: MatterRepresentation
	if world != null:
		provider = world.get_active_provider() as MatterRepresentation
	_check(
		world != null and player != null and interactor != null
		and grid != null and state != null and provider != null,
		"authority-locality probe resolves Recovery roles"
	)
	if world == null or player == null or interactor == null or grid == null or state == null or provider == null:
		_finish(root)
		return

	var bridge: Vector3i = root.call("get_recovery_causal_bridge_cell_for_test")
	_check(world.volume.get_cell(bridge) != CellVolume.EMPTY, "causal bridge begins occupied")
	_check(player.grounded and player.support_space == world and player.support_body == provider, "actor begins on canonical WORLD provider")

	_check(
		interactor.apply_edit_to_cell(world, bridge, P1MatterInteractor.EditMode.REMOVE),
		"bridge edit succeeds and queues causal partition"
	)
	_check(world.is_authority_partition_pending(), "bridge edit queues authority partition")

	# Capture identities after the ordinary bridge edit but before the deferred
	# authority commit. The next delta therefore measures commit locality itself.
	var mesh_before := provider.get_chunk_mesh_ids_for_test()
	var collision_before := provider.get_chunk_collision_ids_for_test()
	var grid_root_before := grid.get_overlay_for_space(world)
	var state_root_before := state.get_state_overlay_for_space(world)
	var grid_before := grid.get_chunk_ids_for_test(world)
	var state_before := state.get_state_chunk_ids_for_test(world)
	_check(grid_root_before != null and state_root_before != null, "source presentation roots exist before authority commit")
	var grid_root_id := grid_root_before.get_instance_id() if grid_root_before != null else 0
	var state_root_id := state_root_before.get_instance_id() if state_root_before != null else 0

	await world.authority_partition_committed
	var result := world.get_last_authority_partition_result()
	var target := result.get("target_space") as LocalMatterSpace
	_check(target != null and is_instance_valid(target), "authority commit creates live target")
	_check(target != null and target.get_provider_kind() == LocalMatterSpace.ProviderKind.DYNAMIC, "detached target enters dynamic provider")

	var mesh_after := provider.get_chunk_mesh_ids_for_test()
	var collision_after := provider.get_chunk_collision_ids_for_test()
	var grid_after_root := grid.get_overlay_for_space(world)
	var state_after_root := state.get_state_overlay_for_space(world)
	var grid_after := grid.get_chunk_ids_for_test(world)
	var state_after := state.get_state_chunk_ids_for_test(world)

	var changed_mesh := _changed_ids(mesh_before, mesh_after)
	var changed_collision := _changed_ids(collision_before, collision_after)
	var changed_grid := _changed_ids(grid_before, grid_after)
	var changed_state := _changed_ids(state_before, state_after)
	_check(changed_mesh > 0 and _unchanged_ids(mesh_before, mesh_after) > 0, "authority commit changes only a subset of source mesh chunks")
	_check(changed_collision > 0 and _unchanged_ids(collision_before, collision_after) > 0, "authority commit changes only a subset of source collision chunks")
	_check(changed_grid > 0 and _unchanged_ids(grid_before, grid_after) > 0, "authority publication changes only a subset of source grid chunks")
	_check(changed_state > 0 and _unchanged_ids(state_before, state_after) > 0, "authority publication changes only a subset of source state chunks")
	_check(grid_after_root != null and grid_after_root.get_instance_id() == grid_root_id, "source grid root survives authority publication")
	_check(state_after_root != null and state_after_root.get_instance_id() == state_root_id, "source state root survives authority publication")

	var reference_mesh := CellMesher.build_mesh(world.volume)
	_check(provider.get_mesh_vertex_count() == _mesh_vertex_count(reference_mesh), "source chunk mesh remains exactly equivalent to whole-volume mesh after authority commit")
	_check(_same_keys(_segment_set(P1MatterSurfaceGrid.build_exposed_surface_grid(world.volume)), _segment_set_from_root(grid_after_root)), "source grid remains exactly equivalent to whole-volume reference after authority commit")
	_check(_same_keys(_segment_set(P1MatterStatePresentation.build_side_surface_contour(world.volume)), _segment_set_from_root(state_after_root)), "source state contour remains exactly equivalent to whole-volume reference after authority commit")

	await _advance_frames(3)
	_check(player.support_space == target and player.support_body == target.get_active_provider(), "actor handoff still resolves to detached target after local authority commit")

	var timing: Dictionary = result.get("timing", {})
	print(
		"W0_CHUNKED_AUTHORITY_LOCALITY_METRIC transferred=%d changed_mesh=%d changed_collision=%d changed_grid=%d changed_state=%d source_rebuild_us=%d publication_us=%d source_mesh_chunks=%d source_shapes=%d"
		% [
			(result.get("source_cells", []) as Array).size(),
			changed_mesh,
			changed_collision,
			changed_grid,
			changed_state,
			int(timing.get("source_rebuild_usec", -1)),
			int(root.call("get_last_recovery_partition_publication_usec")),
			mesh_after.size(),
			provider.get_collision_shape_count(),
		]
	)
	_finish(root)


func _segment_set_from_root(root: MeshInstance3D) -> Dictionary:
	var result: Dictionary = {}
	if root == null:
		return result
	if root.mesh != null:
		_merge_segments(result, _segment_set(root.mesh))
	for child in root.get_children():
		if child is MeshInstance3D:
			_merge_segments(result, _segment_set((child as MeshInstance3D).mesh))
	return result


func _segment_set(mesh: Mesh) -> Dictionary:
	var result: Dictionary = {}
	if mesh == null:
		return result
	for surface_index in range(mesh.get_surface_count()):
		var vertices := mesh.surface_get_arrays(surface_index)[Mesh.ARRAY_VERTEX] as PackedVector3Array
		for index in range(0, vertices.size(), 2):
			result[_segment_key(vertices[index], vertices[index + 1])] = true
	return result


func _merge_segments(target: Dictionary, source: Dictionary) -> void:
	for key in source.keys():
		target[key] = true


func _same_keys(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for key in a.keys():
		if not b.has(key):
			return false
	return true


func _segment_key(a: Vector3, b: Vector3) -> String:
	var ak := "%.5f,%.5f,%.5f" % [a.x, a.y, a.z]
	var bk := "%.5f,%.5f,%.5f" % [b.x, b.y, b.z]
	return "%s|%s" % [ak, bk] if ak < bk else "%s|%s" % [bk, ak]


func _mesh_vertex_count(mesh: Mesh) -> int:
	if mesh == null or mesh.get_surface_count() == 0:
		return 0
	return (mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()


func _changed_ids(before: Dictionary, after: Dictionary) -> int:
	var keys: Dictionary = {}
	for key in before.keys():
		keys[key] = true
	for key in after.keys():
		keys[key] = true
	var changed := 0
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
		print("W0_CHUNKED_AUTHORITY_LOCALITY_PASS: causal detach preserves exact source mesh/grid/state truth while authority commit and publication rebuild only dirty chunk subsets, with actor handoff intact.")
		quit(0)
		return
	for failure in _failures:
		push_error("W0_CHUNKED_AUTHORITY_LOCALITY_FAIL: " + failure)
	quit(1)
