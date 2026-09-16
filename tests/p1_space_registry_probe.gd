extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Node3D.new()
	host.name = "P1SpaceRegistryProbe"
	get_root().add_child(host)

	var registry := P1SpaceRegistry.new()
	registry.name = "Registry"
	host.add_child(registry)

	var volume := CellVolume.new(Vector3i(7, 2, 3))
	volume.fill_box(Vector3i(0, 0, 0), Vector3i(3, 1, 3), CellVolume.SOLID)
	volume.fill_box(Vector3i(4, 0, 0), Vector3i(7, 1, 3), CellVolume.SOLID)
	var bridge := Vector3i(3, 0, 1)
	volume.set_cell(bridge, CellVolume.SOLID)

	var lineage := MatterLineageMap.new(volume.size)
	var token := 810000
	for cell in _occupied_cells(volume):
		lineage.set_lineage(cell, token)
		token += 1
	var max_source_token := token - 1

	var space := LocalMatterSpace.new()
	space.name = "RegistrySourceSpace"
	space.dynamic_gravity_scale = 0.0
	space.dynamic_linear_damp = 0.0
	space.dynamic_angular_damp = 0.0
	space.dynamic_can_sleep = false
	host.add_child(space)
	space.initialize_dynamic(
		volume,
		lineage,
		Transform3D.IDENTITY,
		Vector3(0.3, 0.0, 0.0),
		Vector3(0.0, 0.2, 0.0)
	)
	registry.register_space(space)

	_check(registry.get_active_count() == 1, "registry starts with one live Space")
	_check(registry.find_space_for_provider(space.get_active_provider()) == space, "registry maps provider back to logical Space")

	var bridge_token := lineage.get_lineage(bridge)
	_check(bridge_token != MatterLineageMap.NONE, "bridge carries lineage before destructive edit")
	_check(space.mutate_cell(bridge, CellVolume.EMPTY), "destructive mutation succeeds through LocalMatterSpace")
	_check(space.request_connected_component_split(), "disconnected dynamic Space queues topology split")

	await space.topology_split_committed
	await process_frame

	var result := space.get_last_split_result()
	_check(result != null and result.size() == 2, "split produces two successor Spaces")
	_check(space.is_retired(), "source Space retires after split")
	_check(registry.get_active_count() == 2, "registry replaces retired source with both successors")
	_check(not registry.get_active_spaces().has(space), "retired source is absent from registry")

	if result != null and result.size() == 2:
		var first := result.successors[0] as LocalMatterSpace
		var second := result.successors[1] as LocalMatterSpace
		_check(first != null and second != null, "successors are concrete LocalMatterSpace instances")
		if first != null and second != null:
			_check(registry.get_active_spaces().has(first) and registry.get_active_spaces().has(second), "both successors are discoverable")
			_check(first.lineage_issuer == second.lineage_issuer, "split successors share one transient lineage issuer")
			var first_fresh := first.allocate_lineage_token()
			var second_fresh := second.allocate_lineage_token()
			_check(first_fresh > max_source_token, "fresh successor lineage advances beyond source namespace")
			_check(second_fresh > first_fresh, "siblings cannot issue colliding fresh lineage tokens")
			_check(registry.find_space_for_provider(first.get_active_provider()) == first, "registry maps first successor provider")
			_check(registry.find_space_for_provider(second.get_active_provider()) == second, "registry maps second successor provider")
			print(
				"P1_SPACE_REGISTRY_METRIC source_cells=%d successors=%d first_fresh=%d second_fresh=%d" % [
					19,
					result.size(),
					first_fresh,
					second_fresh,
				]
			)

	host.free()
	_finish()


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
		print("P1_SPACE_REGISTRY_PASS: consumer lifecycle index follows one-to-many Space succession and fresh Matter identity issuance stays below UI authority.")
		quit(0)
		return
	for failure in _failures:
		push_error("P1_SPACE_REGISTRY_FAIL: " + failure)
	quit(1)
