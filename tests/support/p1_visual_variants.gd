extends RefCounted

# Test-only presentation challengers. None of these mechanisms is production
# authority until rendered evidence justifies promotion.

const SURFACE_GRID_OFFSET := 0.006
const SURFACE_GRID_ALPHA := 0.16
const SURFACE_GRID_SOFT_ALPHA := 0.10
const SURFACE_GRID_CLEAN_ALPHA := 0.14
const SURFACE_GRID_CLEAN_STRONG_ALPHA := 0.18
const MODULATION_LOW := 0.93
const MODULATION_HIGH := 1.0
const META_BASE_COLOR := &"g3_original_base_color"
const META_ROUGHNESS := &"g3_original_roughness"
const META_METALLIC := &"g3_original_metallic"


static func refresh(p1: Node, variant: String, failures: Array[String]) -> void:
	if variant == "canonical" or variant == "balanced_fill":
		return

	if variant == "balanced_fill_ssao":
		_apply_ssao(p1, failures)
		return

	if variant == "surface_cells":
		_refresh_surface_cell_overlays(p1, failures, SURFACE_GRID_ALPHA, false)
		return

	if variant == "surface_cells_soft":
		_refresh_surface_cell_overlays(p1, failures, SURFACE_GRID_SOFT_ALPHA, false)
		return

	if variant == "surface_cells_clean":
		_refresh_surface_cell_overlays(p1, failures, SURFACE_GRID_CLEAN_ALPHA, true)
		return

	if variant == "surface_cells_clean_strong":
		_refresh_surface_cell_overlays(p1, failures, SURFACE_GRID_CLEAN_STRONG_ALPHA, true)
		return

	if variant == "surface_modulation":
		_refresh_surface_modulation(p1, failures)
		return

	failures.append("unsupported P1_VISUAL_VARIANT: %s" % variant)


static func _apply_ssao(p1: Node, failures: Array[String]) -> void:
	var world_environment := p1.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_environment == null or world_environment.environment == null:
		failures.append("visual challenger cannot resolve P1 Environment")
		return
	var environment := world_environment.environment
	environment.ssao_enabled = true
	environment.ssao_radius = 1.15
	environment.ssao_intensity = 1.25
	environment.ssao_power = 1.35


static func _refresh_surface_cell_overlays(
	p1: Node,
	failures: Array[String],
	alpha: float,
	deduplicate_coplanar: bool
) -> void:
	var spaces: Array[LocalMatterSpace] = p1.call("get_active_spaces")
	if spaces.is_empty():
		failures.append("surface_cells challenger found no active Spaces")
		return

	for space in spaces:
		if space == null or space.is_retired() or space.volume == null:
			continue
		var provider := space.get_active_provider()
		if provider == null:
			continue

		var existing := provider.get_node_or_null("G3SurfaceCellOverlay")
		if existing != null:
			existing.free()

		var overlay := MeshInstance3D.new()
		overlay.name = "G3SurfaceCellOverlay"
		overlay.mesh = _build_exposed_surface_grid(space.volume, deduplicate_coplanar)
		overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(0.035, 0.075, 0.11, alpha)
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		# Deliberately keep depth testing enabled. G3-A is a surface cue, not an
		# x-ray/debug overlay.
		overlay.material_override = material
		provider.add_child(overlay)


static func _refresh_surface_modulation(p1: Node, failures: Array[String]) -> void:
	var spaces: Array[LocalMatterSpace] = p1.call("get_active_spaces")
	if spaces.is_empty():
		failures.append("surface_modulation challenger found no active Spaces")
		return

	for space in spaces:
		if space == null or space.is_retired() or space.volume == null:
			continue
		var provider := space.get_active_provider()
		if provider == null:
			continue
		var derived_mesh := provider.get_node_or_null("DerivedMesh") as MeshInstance3D
		if derived_mesh == null:
			failures.append("surface_modulation cannot resolve DerivedMesh")
			continue

		if not derived_mesh.has_meta(META_BASE_COLOR):
			var initial_color := Color(0.72, 0.77, 0.84, 1.0)
			var initial_roughness := 0.82
			var initial_metallic := 0.0
			if derived_mesh.material_override is StandardMaterial3D:
				var initial_material := derived_mesh.material_override as StandardMaterial3D
				initial_color = initial_material.albedo_color
				initial_roughness = initial_material.roughness
				initial_metallic = initial_material.metallic
			derived_mesh.set_meta(META_BASE_COLOR, initial_color)
			derived_mesh.set_meta(META_ROUGHNESS, initial_roughness)
			derived_mesh.set_meta(META_METALLIC, initial_metallic)

		var base_color: Color = derived_mesh.get_meta(META_BASE_COLOR)
		var roughness: float = float(derived_mesh.get_meta(META_ROUGHNESS))
		var metallic: float = float(derived_mesh.get_meta(META_METALLIC))

		derived_mesh.mesh = _build_modulated_surface(space.volume, base_color)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color.WHITE
		material.vertex_color_use_as_albedo = true
		material.roughness = roughness
		material.metallic = metallic
		derived_mesh.material_override = material


static func _build_exposed_surface_grid(volume: CellVolume, deduplicate_coplanar: bool) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if volume.count_solid() == 0:
		return mesh

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_LINES)
	var seen_segments: Dictionary = {}

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
					var face_vertices: Array = CellMesher.FACE_VERTICES[face_index]
					var normal: Vector3 = CellMesher.FACE_NORMALS[face_index]
					var offset := normal * SURFACE_GRID_OFFSET
					var raw_corners := [
						origin + face_vertices[0],
						origin + face_vertices[1],
						origin + face_vertices[2],
						origin + face_vertices[5],
					]
					for edge_index in range(4):
						var raw_a: Vector3 = raw_corners[edge_index]
						var raw_b: Vector3 = raw_corners[(edge_index + 1) % 4]
						if deduplicate_coplanar:
							var segment_key := _coplanar_segment_key(face_index, raw_a, raw_b)
							if seen_segments.has(segment_key):
								continue
							seen_segments[segment_key] = true
						surface.add_vertex(raw_a + offset)
						surface.add_vertex(raw_b + offset)

	return surface.commit(mesh)


static func _coplanar_segment_key(face_index: int, a: Vector3, b: Vector3) -> String:
	var ai := Vector3i(int(a.x), int(a.y), int(a.z))
	var bi := Vector3i(int(b.x), int(b.y), int(b.z))
	if _vector3i_less(bi, ai):
		var swap := ai
		ai = bi
		bi = swap
	# `face_index` deliberately remains part of the key. Coplanar same-normal
	# duplicates collapse, while perpendicular crease lines remain separate and
	# keep their own small normal offsets for shape readability.
	return "%d|%d,%d,%d|%d,%d,%d" % [
		face_index,
		ai.x, ai.y, ai.z,
		bi.x, bi.y, bi.z,
	]


static func _vector3i_less(a: Vector3i, b: Vector3i) -> bool:
	if a.x != b.x:
		return a.x < b.x
	if a.y != b.y:
		return a.y < b.y
	return a.z < b.z


static func _build_modulated_surface(volume: CellVolume, base_color: Color) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if volume.count_solid() == 0:
		return mesh

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	for z in range(volume.size.z):
		for y in range(volume.size.y):
			for x in range(volume.size.x):
				var cell := Vector3i(x, y, z)
				if volume.get_cell(cell) == CellVolume.EMPTY:
					continue
				var origin := Vector3(cell)
				var tone := MODULATION_LOW if ((x + y + z) & 1) == 0 else MODULATION_HIGH
				var color := Color(
					clampf(base_color.r * tone, 0.0, 1.0),
					clampf(base_color.g * tone, 0.0, 1.0),
					clampf(base_color.b * tone, 0.0, 1.0),
					1.0
				)
				for face_index in range(CellMesher.FACE_DIRECTIONS.size()):
					if volume.get_cell(cell + CellMesher.FACE_DIRECTIONS[face_index]) != CellVolume.EMPTY:
						continue
					for vertex in CellMesher.FACE_VERTICES[face_index]:
						surface.set_normal(CellMesher.FACE_NORMALS[face_index])
						surface.set_color(color)
						surface.add_vertex(origin + vertex)

	return surface.commit(mesh)
