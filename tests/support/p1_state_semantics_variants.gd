extends RefCounted

# Test-only G3-S challenger language. Physical Space state and focus are kept
# intentionally separate so one cue does not silently encode several meanings.

# First-round values are retained for evidence reproducibility.
const MATERIAL_STATIC_V1 := Color(0.68, 0.75, 0.84, 1.0)
const MATERIAL_DYNAMIC_V1 := Color(0.80, 0.73, 0.60, 1.0)
const CONTOUR_STATIC_V1 := Color(0.24, 0.62, 0.80, 0.68)
const CONTOUR_DYNAMIC_V1 := Color(0.92, 0.60, 0.20, 0.72)

# Second-round values.
const MATERIAL_STATIC_V2 := Color(0.70, 0.77, 0.85, 1.0)
const MATERIAL_DYNAMIC_V2 := Color(0.78, 0.76, 0.68, 1.0)
const CONTOUR_STATIC_V2 := Color(0.22, 0.56, 0.72, 0.42)
const CONTOUR_DYNAMIC_V2 := Color(0.86, 0.53, 0.20, 0.46)

# Final contour-intensity challenger: same hue family, lower occupation.
const CONTOUR_STATIC_V3 := Color(0.22, 0.56, 0.72, 0.32)
const CONTOUR_DYNAMIC_V3 := Color(0.86, 0.53, 0.20, 0.36)

const FOCUS_V1 := Color(0.66, 0.88, 1.0, 0.78)
const FOCUS_CROWN_BLUE := Color(0.76, 0.90, 1.0, 0.58)
const FOCUS_CROWN_NEUTRAL := Color(0.96, 0.98, 1.0, 0.62)
const CONTOUR_OFFSET := 0.012
const FOCUS_MARGIN := 0.09
const FOCUS_LENGTH := 0.34
const FOCUS_CROWN_OFFSET := 0.020
const META_BASE_COLOR := &"g3s_original_base_color"
const META_ROUGHNESS := &"g3s_original_roughness"
const META_METALLIC := &"g3s_original_metallic"


static func refresh(p1: Node, variant: String, failures: Array[String]) -> void:
	var spaces: Array[LocalMatterSpace] = p1.call("get_active_spaces")
	if spaces.is_empty():
		failures.append("state-semantics challenger found no active Spaces")
		return
	var focus := p1.call("get_space") as LocalMatterSpace

	for space in spaces:
		if space == null or space.is_retired() or space.volume == null:
			continue
		var provider: Node3D = space.get_active_provider()
		if provider == null:
			continue
		_remove_test_nodes(provider)
		_restore_or_capture_base_material(provider, false)

		match variant:
			"state_material":
				_apply_material_state(space, provider, failures, false)
			"state_material_refined":
				_apply_material_state(space, provider, failures, true)
			"state_contour":
				_restore_or_capture_base_material(provider, true)
				_apply_contour_state(space, provider, 1)
			"state_contour_refined", "state_contour_neutral_focus":
				_restore_or_capture_base_material(provider, true)
				_apply_contour_state(space, provider, 2)
			"state_contour_soft_neutral_focus":
				_restore_or_capture_base_material(provider, true)
				_apply_contour_state(space, provider, 3)
			_:
				failures.append("unsupported state-semantics variant: %s" % variant)
				return

		if space != focus:
			continue
		if variant == "state_material" or variant == "state_contour":
			_add_focus_brackets(space, provider)
		elif variant == "state_material_refined" or variant == "state_contour_refined":
			_add_focus_crown(space, provider, FOCUS_CROWN_BLUE)
		else:
			_add_focus_crown(space, provider, FOCUS_CROWN_NEUTRAL)


static func _apply_material_state(
	space: LocalMatterSpace,
	provider: Node3D,
	failures: Array[String],
	refined: bool
) -> void:
	var mesh_instance := provider.get_node_or_null("DerivedMesh") as MeshInstance3D
	if mesh_instance == null:
		failures.append("state_material cannot resolve DerivedMesh")
		return
	var roughness := 0.80
	var metallic := 0.0
	if mesh_instance.has_meta(META_ROUGHNESS):
		roughness = float(mesh_instance.get_meta(META_ROUGHNESS))
	if mesh_instance.has_meta(META_METALLIC):
		metallic = float(mesh_instance.get_meta(META_METALLIC))
	var material := StandardMaterial3D.new()
	if space.get_provider_kind() == LocalMatterSpace.ProviderKind.STATIC:
		material.albedo_color = MATERIAL_STATIC_V2 if refined else MATERIAL_STATIC_V1
	else:
		material.albedo_color = MATERIAL_DYNAMIC_V2 if refined else MATERIAL_DYNAMIC_V1
	material.roughness = roughness
	material.metallic = metallic
	mesh_instance.material_override = material


static func _apply_contour_state(space: LocalMatterSpace, provider: Node3D, profile: int) -> void:
	var overlay := MeshInstance3D.new()
	overlay.name = "G3SStateContour"
	overlay.mesh = _build_surface_contour(space.volume)
	overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var is_static := space.get_provider_kind() == LocalMatterSpace.ProviderKind.STATIC
	if profile == 1:
		material.albedo_color = CONTOUR_STATIC_V1 if is_static else CONTOUR_DYNAMIC_V1
	elif profile == 2:
		material.albedo_color = CONTOUR_STATIC_V2 if is_static else CONTOUR_DYNAMIC_V2
	else:
		material.albedo_color = CONTOUR_STATIC_V3 if is_static else CONTOUR_DYNAMIC_V3
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	overlay.material_override = material
	provider.add_child(overlay)


static func _add_focus_crown(space: LocalMatterSpace, provider: Node3D, color: Color) -> void:
	var mesh := _build_top_surface_perimeter(space.volume)
	if mesh.get_surface_count() == 0:
		return
	var overlay := MeshInstance3D.new()
	overlay.name = "G3SFocusCrown"
	overlay.mesh = mesh
	overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	overlay.material_override = material
	provider.add_child(overlay)


static func _add_focus_brackets(space: LocalMatterSpace, provider: Node3D) -> void:
	var bounds := _occupied_bounds(space.volume)
	if bounds.is_empty():
		return
	var min_corner: Vector3 = Vector3(bounds["min"]) - Vector3.ONE * FOCUS_MARGIN
	var max_corner: Vector3 = Vector3(bounds["max_exclusive"]) + Vector3.ONE * FOCUS_MARGIN
	var mesh := ArrayMesh.new()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_LINES)
	for xi in [0, 1]:
		for yi in [0, 1]:
			for zi in [0, 1]:
				var corner := Vector3(
					min_corner.x if xi == 0 else max_corner.x,
					min_corner.y if yi == 0 else max_corner.y,
					min_corner.z if zi == 0 else max_corner.z
				)
				var sx := 1.0 if xi == 0 else -1.0
				var sy := 1.0 if yi == 0 else -1.0
				var sz := 1.0 if zi == 0 else -1.0
				_add_segment(surface, corner, corner + Vector3(sx * FOCUS_LENGTH, 0, 0))
				_add_segment(surface, corner, corner + Vector3(0, sy * FOCUS_LENGTH, 0))
				_add_segment(surface, corner, corner + Vector3(0, 0, sz * FOCUS_LENGTH))
	surface.commit(mesh)

	var overlay := MeshInstance3D.new()
	overlay.name = "G3SFocusBrackets"
	overlay.mesh = mesh
	overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = FOCUS_V1
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	overlay.material_override = material
	provider.add_child(overlay)


static func _build_top_surface_perimeter(volume: CellVolume) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if volume == null or volume.count_solid() == 0:
		return mesh
	var edge_records: Dictionary = {}
	for z in range(volume.size.z):
		for y in range(volume.size.y):
			for x in range(volume.size.x):
				var cell := Vector3i(x, y, z)
				if volume.get_cell(cell) == CellVolume.EMPTY:
					continue
				var origin := Vector3(cell)
				for face_index in range(CellMesher.FACE_DIRECTIONS.size()):
					var normal: Vector3 = CellMesher.FACE_NORMALS[face_index]
					if normal.dot(Vector3.UP) < 0.99:
						continue
					if volume.get_cell(cell + CellMesher.FACE_DIRECTIONS[face_index]) != CellVolume.EMPTY:
						continue
					var corners := _face_corners(origin, face_index)
					for edge_index in range(4):
						var a: Vector3 = corners[edge_index]
						var b: Vector3 = corners[(edge_index + 1) % 4]
						var key := _plain_edge_key(a, b)
						if not edge_records.has(key):
							edge_records[key] = {"count": 0, "a": a, "b": b}
						var record: Dictionary = edge_records[key]
						record["count"] = int(record["count"]) + 1
						edge_records[key] = record
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_LINES)
	for record_variant in edge_records.values():
		var record: Dictionary = record_variant
		if int(record["count"]) != 1:
			continue
		_add_segment(
			surface,
			Vector3(record["a"]) + Vector3.UP * FOCUS_CROWN_OFFSET,
			Vector3(record["b"]) + Vector3.UP * FOCUS_CROWN_OFFSET
		)
	return surface.commit(mesh)


static func _build_surface_contour(volume: CellVolume) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if volume == null or volume.count_solid() == 0:
		return mesh
	var edge_records: Dictionary = {}
	for z in range(volume.size.z):
		for y in range(volume.size.y):
			for x in range(volume.size.x):
				var cell := Vector3i(x, y, z)
				if volume.get_cell(cell) == CellVolume.EMPTY:
					continue
				var origin := Vector3(cell)
				for face_index in range(CellMesher.FACE_DIRECTIONS.size()):
					if volume.get_cell(cell + CellMesher.FACE_DIRECTIONS[face_index]) != CellVolume.EMPTY:
						continue
					var corners := _face_corners(origin, face_index)
					for edge_index in range(4):
						var a: Vector3 = corners[edge_index]
						var b: Vector3 = corners[(edge_index + 1) % 4]
						var key := _oriented_edge_key(face_index, a, b)
						if not edge_records.has(key):
							edge_records[key] = {"count": 0, "a": a, "b": b, "face": face_index}
						var record: Dictionary = edge_records[key]
						record["count"] = int(record["count"]) + 1
						edge_records[key] = record
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_LINES)
	for record_variant in edge_records.values():
		var record: Dictionary = record_variant
		if int(record["count"]) != 1:
			continue
		var normal: Vector3 = CellMesher.FACE_NORMALS[int(record["face"])]
		_add_segment(
			surface,
			Vector3(record["a"]) + normal * CONTOUR_OFFSET,
			Vector3(record["b"]) + normal * CONTOUR_OFFSET
		)
	return surface.commit(mesh)


static func _face_corners(origin: Vector3, face_index: int) -> Array:
	var face_vertices: Array = CellMesher.FACE_VERTICES[face_index]
	return [
		origin + face_vertices[0],
		origin + face_vertices[1],
		origin + face_vertices[2],
		origin + face_vertices[5],
	]


static func _occupied_bounds(volume: CellVolume) -> Dictionary:
	if volume == null or volume.count_solid() == 0:
		return {}
	var minimum := Vector3i(2147483647, 2147483647, 2147483647)
	var maximum := Vector3i(-2147483648, -2147483648, -2147483648)
	for z in range(volume.size.z):
		for y in range(volume.size.y):
			for x in range(volume.size.x):
				var cell := Vector3i(x, y, z)
				if volume.get_cell(cell) == CellVolume.EMPTY:
					continue
				minimum.x = mini(minimum.x, x)
				minimum.y = mini(minimum.y, y)
				minimum.z = mini(minimum.z, z)
				maximum.x = maxi(maximum.x, x)
				maximum.y = maxi(maximum.y, y)
				maximum.z = maxi(maximum.z, z)
	return {"min": minimum, "max_exclusive": maximum + Vector3i.ONE}


static func _restore_or_capture_base_material(provider: Node3D, restore: bool) -> void:
	var mesh_instance := provider.get_node_or_null("DerivedMesh") as MeshInstance3D
	if mesh_instance == null:
		return
	if not mesh_instance.has_meta(META_BASE_COLOR):
		var base_color := Color(0.72, 0.77, 0.84, 1.0)
		var roughness := 0.82
		var metallic := 0.0
		if mesh_instance.material_override is StandardMaterial3D:
			var original := mesh_instance.material_override as StandardMaterial3D
			base_color = original.albedo_color
			roughness = original.roughness
			metallic = original.metallic
		mesh_instance.set_meta(META_BASE_COLOR, base_color)
		mesh_instance.set_meta(META_ROUGHNESS, roughness)
		mesh_instance.set_meta(META_METALLIC, metallic)
	if not restore:
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = mesh_instance.get_meta(META_BASE_COLOR)
	material.roughness = float(mesh_instance.get_meta(META_ROUGHNESS))
	material.metallic = float(mesh_instance.get_meta(META_METALLIC))
	mesh_instance.material_override = material


static func _remove_test_nodes(provider: Node3D) -> void:
	for node_name in ["G3SStateContour", "G3SFocusBrackets", "G3SFocusCrown"]:
		var existing := provider.get_node_or_null(node_name)
		if existing != null:
			existing.free()


static func _add_segment(surface: SurfaceTool, a: Vector3, b: Vector3) -> void:
	surface.add_vertex(a)
	surface.add_vertex(b)


static func _plain_edge_key(a: Vector3, b: Vector3) -> String:
	var ai := Vector3i(int(a.x), int(a.y), int(a.z))
	var bi := Vector3i(int(b.x), int(b.y), int(b.z))
	if _vector3i_less(bi, ai):
		var swap := ai
		ai = bi
		bi = swap
	return "%d,%d,%d|%d,%d,%d" % [ai.x, ai.y, ai.z, bi.x, bi.y, bi.z]


static func _oriented_edge_key(face_index: int, a: Vector3, b: Vector3) -> String:
	return "%d|%s" % [face_index, _plain_edge_key(a, b)]


static func _vector3i_less(a: Vector3i, b: Vector3i) -> bool:
	if a.x != b.x:
		return a.x < b.x
	if a.y != b.y:
		return a.y < b.y
	return a.z < b.z
