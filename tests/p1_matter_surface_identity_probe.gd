extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var static_provider := MatterRepresentation.new()
	static_provider.name = "StaticMatterProbe"
	get_root().add_child(static_provider)

	var dynamic_provider := ConstructBody.new()
	dynamic_provider.name = "DynamicMatterProbe"
	dynamic_provider.gravity_scale = 0.0
	get_root().add_child(dynamic_provider)
	await process_frame

	static_provider.set_volume(_make_volume())
	dynamic_provider.set_volume(_make_volume())
	await process_frame

	var static_mesh := static_provider.get_node_or_null("DerivedMesh") as MeshInstance3D
	var dynamic_mesh := dynamic_provider.get_node_or_null("DerivedMesh") as MeshInstance3D
	_check(static_mesh != null, "static provider exposes DerivedMesh")
	_check(dynamic_mesh != null, "dynamic provider exposes DerivedMesh")

	if static_mesh != null and dynamic_mesh != null:
		var static_material := static_mesh.material_override as StandardMaterial3D
		var dynamic_material := dynamic_mesh.material_override as StandardMaterial3D
		_check(static_material != null, "static provider uses StandardMaterial3D surface")
		_check(dynamic_material != null, "dynamic provider uses StandardMaterial3D surface")
		if static_material != null and dynamic_material != null:
			_check(static_material.albedo_color == MatterSurfaceStyle.BASE_ALBEDO, "static provider uses canonical Matter albedo")
			_check(dynamic_material.albedo_color == MatterSurfaceStyle.BASE_ALBEDO, "dynamic provider uses canonical Matter albedo")
			_check(is_equal_approx(static_material.roughness, MatterSurfaceStyle.BASE_ROUGHNESS), "static provider uses canonical Matter roughness")
			_check(is_equal_approx(dynamic_material.roughness, MatterSurfaceStyle.BASE_ROUGHNESS), "dynamic provider uses canonical Matter roughness")
			_check(static_material.albedo_color == dynamic_material.albedo_color, "provider kind does not change Matter albedo identity")
			_check(is_equal_approx(static_material.roughness, dynamic_material.roughness), "provider kind does not change Matter roughness identity")

		_check(static_provider.get_mesh_vertex_count() == dynamic_provider.get_mesh_vertex_count(), "provider kind preserves derived surface topology")

	static_provider.free()
	dynamic_provider.free()
	_finish()


func _make_volume() -> CellVolume:
	var volume := CellVolume.new(Vector3i(4, 3, 4))
	volume.fill_box(Vector3i(0, 0, 0), Vector3i(4, 1, 4), CellVolume.SOLID)
	volume.fill_box(Vector3i(1, 1, 1), Vector3i(3, 2, 3), CellVolume.SOLID)
	return volume


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _finish() -> void:
	if _failures.is_empty():
		print("P1_MATTER_SURFACE_IDENTITY_PASS: STATIC and DYNAMIC providers preserve one canonical Matter surface identity.")
		quit(0)
		return
	for failure in _failures:
		push_error("P1_MATTER_SURFACE_IDENTITY_FAIL: " + failure)
	quit(1)
