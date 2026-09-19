extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://p1/recovery_main.tscn") as PackedScene
	_check(packed != null, "reciprocal Owner scene loads")
	if packed == null:
		_finish(null)
		return

	var root := packed.instantiate()
	get_root().add_child(root)
	await process_frame
	await physics_frame
	await process_frame

	var player := root.get_node_or_null("P1Player") as SpaceQueryCharacter
	var registry := root.get_node_or_null("P1SpaceRegistry") as P1SpaceRegistry
	_check(player != null, "Owner scene exposes query actor")
	_check(player != null and player.reciprocal_dynamic_contact_enabled, "Owner scene enables reciprocal contact challenger")
	_check(registry != null and registry.get_active_count() == 1, "bounded props do not redefine logical Space registry")

	var props: Array[ConstructBody] = root.call("get_reciprocal_contact_props_for_test")
	_check(props.size() == 2, "Owner scene exposes exactly two bounded reciprocal contact props")
	if props.size() == 2:
		var light := props[0]
		var heavy := props[1]
		for prop in props:
			if prop.name == "ReciprocalLightMatter":
				light = prop
			elif prop.name == "ReciprocalHeavyMatter":
				heavy = prop
		_check(light.name == "ReciprocalLightMatter", "light contact specimen is present")
		_check(heavy.name == "ReciprocalHeavyMatter", "heavy contact specimen is present")
		_check(absf(light.mass - 1.0) < 0.01, "light specimen has finite 1-unit mass")
		_check(absf(heavy.mass - 64.0) < 0.01, "heavy specimen has finite 64-unit mass")
		_check(light.volume != null and light.volume.count_solid() == 1, "light specimen is one Matter cell")
		_check(heavy.volume != null and heavy.volume.count_solid() == 8, "heavy specimen is visibly larger eight-cell Matter")

	print(
		"RECIPROCAL_OWNER_SCENE_METRIC reciprocal=%s props=%d registry_spaces=%d headless_scale=%.1f"
		% [
			str(player != null and player.reciprocal_dynamic_contact_enabled),
			props.size(),
			registry.get_active_count() if registry != null else -1,
			float(root.call("get_c1_scale_probe_factor")),
		]
	)

	_finish(root)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _finish(root: Node) -> void:
	if root != null and is_instance_valid(root):
		root.free()
	if _failures.is_empty():
		print("RECIPROCAL_OWNER_SCENE_PASS: Owner sandbox enables finite reciprocity and exposes light/heavy Matter without changing logical Space startup.")
		quit(0)
		return
	for failure in _failures:
		push_error("RECIPROCAL_OWNER_SCENE_FAIL: " + failure)
	quit(1)
