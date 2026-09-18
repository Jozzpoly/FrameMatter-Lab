class_name P1MatterStatePresentation
extends Node

# Derived Owner-facing semantics only. This presenter does not own Matter,
# topology, provider lifecycle, focus selection or physics. It observes the
# current P1 consumer state and decorates each live provider with a selective
# side-surface state rim plus a separate top-surface focus crown.

const STATE_OVERLAY_NAME := "P1MatterStateContour"
const FOCUS_OVERLAY_NAME := "P1MatterFocusCrown"
const STATIC_COLOR := Color(0.22, 0.56, 0.72, 0.32)
const DYNAMIC_COLOR := Color(0.86, 0.53, 0.20, 0.36)
const FOCUS_COLOR := Color(0.96, 0.98, 1.0, 0.62)
const CONTOUR_OFFSET := 0.012
const FOCUS_CROWN_OFFSET := 0.020

var registry: P1SpaceRegistry
var interactor: P1MatterInteractor
var focus_source: Node
var enabled := true
var last_refresh_usec := 0
var last_refresh_space_id := 0

var _focus_space: LocalMatterSpace
var _state_signatures: Dictionary = {}
var _focus_signatures: Dictionary = {}


func _ready() -> void:
	# Children become ready before P1Main. Defer scene binding so the parent can
	# finish its own initialization without presentation becoming an authority.
	call_deferred("_bind_from_scene")


func _process(_delta: float) -> void:
	# Focus is a lightweight scene-consumer state. Geometry/provider changes stay
	# event-driven; only reference identity is observed here. This deliberately
	# avoids inventing a second focus authority merely for presentation.
	_sync_focus_from_source(false)


func set_sources(value_registry: P1SpaceRegistry, value_interactor: P1MatterInteractor) -> void:
	clear_all()
	if registry != null and is_instance_valid(registry):
		_disconnect_registry(registry)
	if interactor != null and is_instance_valid(interactor):
		_disconnect_interactor(interactor)

	registry = value_registry
	interactor = value_interactor

	if registry != null:
		_connect_registry(registry)
	if interactor != null:
		_connect_interactor(interactor)
	refresh_all()


func set_focus_source(value: Node) -> void:
	focus_source = value
	_sync_focus_from_source(true)


func set_focus_space(space: LocalMatterSpace) -> void:
	if space != null and (not is_instance_valid(space) or space.is_retired()):
		space = null
	if _focus_space == space:
		return
	var previous := _focus_space
	_focus_space = space
	if _is_live_space(previous):
		_ensure_focus(previous)
	if _is_live_space(_focus_space):
		_ensure_focus(_focus_space)

func get_focus_space() -> LocalMatterSpace:
	return _focus_space


func set_enabled(value: bool) -> void:
	if enabled == value:
		return
	enabled = value
	if enabled:
		_sync_focus_from_source(true)
		refresh_all()
	else:
		clear_all()


func refresh_all() -> void:
	if registry == null or not is_instance_valid(registry):
		return
	if not enabled:
		clear_all()
		return
	for space in registry.get_active_spaces():
		refresh_space(space)


func refresh_space(space: LocalMatterSpace) -> void:
	var started_usec := Time.get_ticks_usec()
	last_refresh_space_id = (
		space.get_instance_id()
		if space != null and is_instance_valid(space)
		else 0
	)
	if not _is_live_space(space) or space.volume == null:
		last_refresh_usec = Time.get_ticks_usec() - started_usec
		return
	_refresh_state(space)
	_refresh_focus(space)
	last_refresh_usec = Time.get_ticks_usec() - started_usec


func refresh_cell(space: LocalMatterSpace, cell: Vector3i) -> void:
	var cells: Array[Vector3i] = [cell]
	refresh_cells(space, cells)


func refresh_cells(space: LocalMatterSpace, cells: Array[Vector3i]) -> void:
	var started_usec := Time.get_ticks_usec()
	last_refresh_space_id = (
		space.get_instance_id()
		if space != null and is_instance_valid(space)
		else 0
	)
	if (
		not _is_live_space(space)
		or space.volume == null
		or cells.is_empty()
	):
		last_refresh_usec = Time.get_ticks_usec() - started_usec
		return
	var edge := _chunk_edge_for_space(space)
	if edge <= 0:
		refresh_space(space)
		return
	if space.volume.count_solid() == 0:
		refresh_space(space)
		return
	var provider := space.get_active_provider()
	var state_root := provider.get_node_or_null(STATE_OVERLAY_NAME) as MeshInstance3D
	if state_root == null:
		refresh_space(space)
		return
	var state_material := state_root.material_override as StandardMaterial3D
	if state_material == null:
		state_material = _create_state_material(space)
		state_root.material_override = state_material
	var dirty_origins: Dictionary = {}
	for cell in cells:
		if not space.volume.in_bounds(cell):
			refresh_space(space)
			return
		for origin in _dirty_chunk_origins(space.volume.size, cell, edge):
			dirty_origins[origin] = true
	for origin_variant in dirty_origins.keys():
		_install_state_chunk(state_root, space.volume, origin_variant, edge, state_material)
	_state_signatures[space.get_instance_id()] = _state_signature(space)

	if space == _focus_space:
		var focus_root := provider.get_node_or_null(FOCUS_OVERLAY_NAME) as MeshInstance3D
		if focus_root == null:
			_refresh_focus(space)
		else:
			var focus_material := focus_root.material_override as StandardMaterial3D
			if focus_material == null:
				focus_material = _create_focus_material()
				focus_root.material_override = focus_material
			for origin_variant in dirty_origins.keys():
				_install_focus_chunk(focus_root, space.volume, origin_variant, edge, focus_material)
			_focus_signatures[space.get_instance_id()] = _focus_signature(space)
	last_refresh_usec = Time.get_ticks_usec() - started_usec

func get_state_chunk_ids_for_test(space: LocalMatterSpace) -> Dictionary:
	return _chunk_ids_for_root(get_state_overlay_for_space(space), "StateChunk_")


func get_focus_chunk_ids_for_test(space: LocalMatterSpace) -> Dictionary:
	return _chunk_ids_for_root(get_focus_overlay_for_space(space), "FocusChunk_")


func _chunk_ids_for_root(root: MeshInstance3D, prefix: String) -> Dictionary:
	var result: Dictionary = {}
	if root == null:
		return result
	for child in root.get_children():
		if child is MeshInstance3D and str(child.name).begins_with(prefix):
			result[str(child.name)] = child.get_instance_id()
	return result

func clear_all() -> void:
	if registry != null and is_instance_valid(registry):
		for space in registry.get_active_spaces():
			if not _is_live_space(space):
				continue
			_remove_overlays_from_provider(space.get_active_provider())
	_state_signatures.clear()
	_focus_signatures.clear()


func _ensure_active_spaces() -> void:
	if registry == null or not is_instance_valid(registry):
		return
	var live_ids: Dictionary = {}
	for space in registry.get_active_spaces():
		if not _is_live_space(space):
			continue
		live_ids[space.get_instance_id()] = true
		_ensure_state(space)
		_ensure_focus(space)
	for cached_id in _state_signatures.keys():
		if not live_ids.has(cached_id):
			_state_signatures.erase(cached_id)
	for cached_id in _focus_signatures.keys():
		if not live_ids.has(cached_id):
			_focus_signatures.erase(cached_id)


func _ensure_state(space: LocalMatterSpace) -> void:
	if not _is_live_space(space) or space.volume == null:
		return
	var provider := space.get_active_provider()
	var overlay := provider.get_node_or_null(STATE_OVERLAY_NAME) as MeshInstance3D
	var space_id := space.get_instance_id()
	var signature := _state_signature(space)
	if overlay != null and str(_state_signatures.get(space_id, "")) == signature:
		return
	_refresh_state(space)


func _ensure_focus(space: LocalMatterSpace) -> void:
	if not _is_live_space(space) or space.volume == null:
		return
	var provider := space.get_active_provider()
	var existing := provider.get_node_or_null(FOCUS_OVERLAY_NAME) as MeshInstance3D
	var space_id := space.get_instance_id()
	if space != _focus_space:
		if existing != null:
			existing.free()
		_focus_signatures.erase(space_id)
		return
	var signature := _focus_signature(space)
	if existing != null and str(_focus_signatures.get(space_id, "")) == signature:
		return
	_refresh_focus(space)


func _refresh_state(space: LocalMatterSpace) -> void:
	var provider := space.get_active_provider()
	_remove_overlay_from_provider(provider, STATE_OVERLAY_NAME)
	var space_id := space.get_instance_id()
	_state_signatures.erase(space_id)
	if not enabled or space.volume.count_solid() == 0:
		return

	var state_overlay := MeshInstance3D.new()
	state_overlay.name = STATE_OVERLAY_NAME
	state_overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var state_material := _create_state_material(space)
	state_overlay.material_override = state_material
	provider.add_child(state_overlay)

	var edge := _chunk_edge_for_space(space)
	if edge > 0:
		state_overlay.mesh = ArrayMesh.new()
		for origin in _chunk_origins(space.volume.size, edge):
			_install_state_chunk(state_overlay, space.volume, origin, edge, state_material)
	else:
		state_overlay.mesh = build_side_surface_contour(space.volume)
	_state_signatures[space_id] = _state_signature(space)

func _refresh_focus(space: LocalMatterSpace) -> void:
	var provider := space.get_active_provider()
	_remove_overlay_from_provider(provider, FOCUS_OVERLAY_NAME)
	var space_id := space.get_instance_id()
	_focus_signatures.erase(space_id)
	if not enabled or space != _focus_space or space.volume.count_solid() == 0:
		return

	var focus_overlay := MeshInstance3D.new()
	focus_overlay.name = FOCUS_OVERLAY_NAME
	focus_overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var focus_material := _create_focus_material()
	focus_overlay.material_override = focus_material
	provider.add_child(focus_overlay)

	var edge := _chunk_edge_for_space(space)
	if edge > 0:
		focus_overlay.mesh = ArrayMesh.new()
		for origin in _chunk_origins(space.volume.size, edge):
			_install_focus_chunk(focus_overlay, space.volume, origin, edge, focus_material)
		if focus_overlay.get_child_count() == 0:
			focus_overlay.free()
			return
	else:
		var focus_mesh := build_top_surface_perimeter(space.volume)
		if focus_mesh.get_surface_count() == 0:
			focus_overlay.free()
			return
		focus_overlay.mesh = focus_mesh
	_focus_signatures[space_id] = _focus_signature(space)


func _install_state_chunk(
	root: MeshInstance3D,
	volume: CellVolume,
	origin: Vector3i,
	edge: int,
	material: StandardMaterial3D
) -> void:
	var node_name := _state_chunk_name(origin)
	var existing := root.get_node_or_null(node_name)
	if existing != null:
		existing.free()
	var mesh := build_side_surface_contour_region(volume, origin, _chunk_end(volume.size, origin, edge))
	if mesh.get_surface_count() == 0:
		return
	var child := MeshInstance3D.new()
	child.name = node_name
	child.mesh = mesh
	child.material_override = material
	child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(child)


func _install_focus_chunk(
	root: MeshInstance3D,
	volume: CellVolume,
	origin: Vector3i,
	edge: int,
	material: StandardMaterial3D
) -> void:
	var node_name := _focus_chunk_name(origin)
	var existing := root.get_node_or_null(node_name)
	if existing != null:
		existing.free()
	var mesh := build_top_surface_perimeter_region(volume, origin, _chunk_end(volume.size, origin, edge))
	if mesh.get_surface_count() == 0:
		return
	var child := MeshInstance3D.new()
	child.name = node_name
	child.mesh = mesh
	child.material_override = material
	child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(child)


func _create_state_material(space: LocalMatterSpace) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = STATIC_COLOR if space.get_provider_kind() == LocalMatterSpace.ProviderKind.STATIC else DYNAMIC_COLOR
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _create_focus_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = FOCUS_COLOR
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _chunk_edge_for_space(space: LocalMatterSpace) -> int:
	if space == null or not is_instance_valid(space):
		return 0
	var provider := space.get_active_provider()
	if provider is MatterRepresentation:
		return maxi(0, (provider as MatterRepresentation).chunk_edge)
	return 0


func _chunk_origins(size: Vector3i, edge: int) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for z in range(0, size.z, edge):
		for y in range(0, size.y, edge):
			for x in range(0, size.x, edge):
				result.append(Vector3i(x, y, z))
	return result


func _dirty_chunk_origins(size: Vector3i, cell: Vector3i, edge: int) -> Array[Vector3i]:
	var unique: Dictionary = {}
	var candidates: Array[Vector3i] = [cell]
	for offset in MatterTopology.AXIAL_NEIGHBORS:
		var neighbor := cell + offset
		if (
			neighbor.x >= 0 and neighbor.x < size.x
			and neighbor.y >= 0 and neighbor.y < size.y
			and neighbor.z >= 0 and neighbor.z < size.z
		):
			candidates.append(neighbor)
	for candidate in candidates:
		unique[_chunk_origin(candidate, edge)] = true
	var result: Array[Vector3i] = []
	for origin_variant in unique.keys():
		result.append(origin_variant)
	return result


func _state_chunk_name(origin: Vector3i) -> String:
	return "StateChunk_%d_%d_%d" % [origin.x, origin.y, origin.z]


func _focus_chunk_name(origin: Vector3i) -> String:
	return "FocusChunk_%d_%d_%d" % [origin.x, origin.y, origin.z]


func _chunk_origin(cell: Vector3i, edge: int) -> Vector3i:
	return Vector3i(
		floori(float(cell.x) / float(edge)) * edge,
		floori(float(cell.y) / float(edge)) * edge,
		floori(float(cell.z) / float(edge)) * edge
	)


func _chunk_end(size: Vector3i, origin: Vector3i, edge: int) -> Vector3i:
	return Vector3i(
		mini(size.x, origin.x + edge),
		mini(size.y, origin.y + edge),
		mini(size.z, origin.z + edge)
	)

func _state_signature(space: LocalMatterSpace) -> String:
	var provider := space.get_active_provider()
	var provider_id := provider.get_instance_id() if provider != null and is_instance_valid(provider) else 0
	return "%d:%d:%d" % [provider_id, space.volume.revision, space.get_provider_kind()]


func _focus_signature(space: LocalMatterSpace) -> String:
	var provider := space.get_active_provider()
	var provider_id := provider.get_instance_id() if provider != null and is_instance_valid(provider) else 0
	return "%d:%d" % [provider_id, space.volume.revision]

func get_state_overlay_for_space(space: LocalMatterSpace) -> MeshInstance3D:
	if not _is_live_space(space):
		return null
	return space.get_active_provider().get_node_or_null(STATE_OVERLAY_NAME) as MeshInstance3D


func get_focus_overlay_for_space(space: LocalMatterSpace) -> MeshInstance3D:
	if not _is_live_space(space):
		return null
	return space.get_active_provider().get_node_or_null(FOCUS_OVERLAY_NAME) as MeshInstance3D


func get_state_overlay_count() -> int:
	if registry == null or not is_instance_valid(registry):
		return 0
	var count := 0
	for space in registry.get_active_spaces():
		if get_state_overlay_for_space(space) != null:
			count += 1
	return count


func get_focus_overlay_count() -> int:
	if registry == null or not is_instance_valid(registry):
		return 0
	var count := 0
	for space in registry.get_active_spaces():
		if get_focus_overlay_for_space(space) != null:
			count += 1
	return count


# Promoted R-V3 policy: state semantics stay on side-surface boundaries so they
# remain visible from shallow camera angles without drawing a permanent network
# across horizontal Matter surfaces. Focus remains a separate top-surface crown.
static func build_side_surface_contour(volume: CellVolume) -> ArrayMesh:
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
					if absf(normal.dot(Vector3.UP)) > 0.01:
						continue
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


# Retained as a diagnostic/full-contour reference for evidence and future
# challengers. Production state presentation no longer uses this geometry.
static func build_side_surface_contour_region(
	volume: CellVolume,
	from_cell: Vector3i,
	to_cell: Vector3i
) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if volume == null or volume.count_solid() == 0:
		return mesh
	var edge_records: Dictionary = {}
	var scan_from := _scan_from(from_cell)
	var scan_to := _scan_to(volume.size, to_cell)
	for z in range(scan_from.z, scan_to.z):
		for y in range(scan_from.y, scan_to.y):
			for x in range(scan_from.x, scan_to.x):
				var cell := Vector3i(x, y, z)
				if volume.get_cell(cell) == CellVolume.EMPTY:
					continue
				var origin := Vector3(cell)
				for face_index in range(CellMesher.FACE_DIRECTIONS.size()):
					var normal: Vector3 = CellMesher.FACE_NORMALS[face_index]
					if absf(normal.dot(Vector3.UP)) > 0.01:
						continue
					if volume.get_cell(cell + CellMesher.FACE_DIRECTIONS[face_index]) != CellVolume.EMPTY:
						continue
					var corners := _face_corners(origin, face_index)
					for edge_index in range(4):
						var a: Vector3 = corners[edge_index]
						var b: Vector3 = corners[(edge_index + 1) % 4]
						var key := _oriented_edge_key(face_index, a, b)
						if not edge_records.has(key):
							edge_records[key] = {"count": 0, "a": a, "b": b, "face": face_index, "owner": cell}
						var record: Dictionary = edge_records[key]
						record["count"] = int(record["count"]) + 1
						edge_records[key] = record
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_LINES)
	var emitted := false
	for record_variant in edge_records.values():
		var record: Dictionary = record_variant
		if int(record["count"]) != 1:
			continue
		var owner: Vector3i = record["owner"]
		if not _cell_in_region(owner, from_cell, to_cell):
			continue
		var normal: Vector3 = CellMesher.FACE_NORMALS[int(record["face"])]
		_add_segment(surface, Vector3(record["a"]) + normal * CONTOUR_OFFSET, Vector3(record["b"]) + normal * CONTOUR_OFFSET)
		emitted = true
	if not emitted:
		return mesh
	return surface.commit(mesh)

static func build_surface_contour(volume: CellVolume) -> ArrayMesh:
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


static func build_top_surface_perimeter(volume: CellVolume) -> ArrayMesh:
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


static func build_top_surface_perimeter_region(
	volume: CellVolume,
	from_cell: Vector3i,
	to_cell: Vector3i
) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if volume == null or volume.count_solid() == 0:
		return mesh
	var edge_records: Dictionary = {}
	var scan_from := _scan_from(from_cell)
	var scan_to := _scan_to(volume.size, to_cell)
	for z in range(scan_from.z, scan_to.z):
		for y in range(scan_from.y, scan_to.y):
			for x in range(scan_from.x, scan_to.x):
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
							edge_records[key] = {"count": 0, "a": a, "b": b, "owner": cell}
						var record: Dictionary = edge_records[key]
						record["count"] = int(record["count"]) + 1
						edge_records[key] = record
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_LINES)
	var emitted := false
	for record_variant in edge_records.values():
		var record: Dictionary = record_variant
		if int(record["count"]) != 1:
			continue
		var owner: Vector3i = record["owner"]
		if not _cell_in_region(owner, from_cell, to_cell):
			continue
		_add_segment(surface, Vector3(record["a"]) + Vector3.UP * FOCUS_CROWN_OFFSET, Vector3(record["b"]) + Vector3.UP * FOCUS_CROWN_OFFSET)
		emitted = true
	if not emitted:
		return mesh
	return surface.commit(mesh)

func _bind_from_scene() -> void:
	var scene_root := get_parent()
	if scene_root == null:
		return
	var value_registry := scene_root.get_node_or_null("P1SpaceRegistry") as P1SpaceRegistry
	var value_interactor := scene_root.get_node_or_null("P1MatterInteractor") as P1MatterInteractor
	set_sources(value_registry, value_interactor)
	set_focus_source(scene_root)


func _sync_focus_from_source(_force: bool) -> void:
	var candidate: LocalMatterSpace
	if focus_source != null and is_instance_valid(focus_source) and focus_source.has_method("get_space"):
		candidate = focus_source.call("get_space") as LocalMatterSpace
	if candidate != null and (not is_instance_valid(candidate) or candidate.is_retired()):
		candidate = null
	set_focus_space(candidate)

func _connect_registry(value: P1SpaceRegistry) -> void:
	if not value.active_spaces_changed.is_connected(_on_active_spaces_changed):
		value.active_spaces_changed.connect(_on_active_spaces_changed)
	if not value.provider_changed.is_connected(_on_provider_changed):
		value.provider_changed.connect(_on_provider_changed)
	if not value.storage_rebased.is_connected(_on_storage_rebased):
		value.storage_rebased.connect(_on_storage_rebased)
	if not value.split_committed.is_connected(_on_split_committed):
		value.split_committed.connect(_on_split_committed)


func _disconnect_registry(value: P1SpaceRegistry) -> void:
	if value.active_spaces_changed.is_connected(_on_active_spaces_changed):
		value.active_spaces_changed.disconnect(_on_active_spaces_changed)
	if value.provider_changed.is_connected(_on_provider_changed):
		value.provider_changed.disconnect(_on_provider_changed)
	if value.storage_rebased.is_connected(_on_storage_rebased):
		value.storage_rebased.disconnect(_on_storage_rebased)
	if value.split_committed.is_connected(_on_split_committed):
		value.split_committed.disconnect(_on_split_committed)


func _connect_interactor(value: P1MatterInteractor) -> void:
	if not value.edit_applied.is_connected(_on_edit_applied):
		value.edit_applied.connect(_on_edit_applied)


func _disconnect_interactor(value: P1MatterInteractor) -> void:
	if value.edit_applied.is_connected(_on_edit_applied):
		value.edit_applied.disconnect(_on_edit_applied)


func _on_active_spaces_changed() -> void:
	_sync_focus_from_source(true)
	_ensure_active_spaces()


func _on_provider_changed(space: LocalMatterSpace) -> void:
	refresh_space(space)


func _on_storage_rebased(space: LocalMatterSpace, _report: Dictionary) -> void:
	refresh_space(space)


func _on_split_committed(_source: LocalMatterSpace, _result: LocalMatterSplitResult) -> void:
	_sync_focus_from_source(true)
	_ensure_active_spaces()


func _on_edit_applied(space: LocalMatterSpace, cell: Vector3i, _mode: int, _split_queued: bool) -> void:
	if _chunk_edge_for_space(space) > 0:
		refresh_cell(space, cell)
	else:
		refresh_space(space)


func _remove_overlays_from_provider(provider: Node3D) -> void:
	if provider == null or not is_instance_valid(provider):
		return
	for node_name in [STATE_OVERLAY_NAME, FOCUS_OVERLAY_NAME]:
		_remove_overlay_from_provider(provider, node_name)


func _remove_overlay_from_provider(provider: Node3D, node_name: String) -> void:
	if provider == null or not is_instance_valid(provider):
		return
	var existing := provider.get_node_or_null(node_name)
	if existing != null:
		existing.free()


func _is_live_space(space: LocalMatterSpace) -> bool:
	return space != null and is_instance_valid(space) and not space.is_retired() and space.get_active_provider() != null


static func _scan_from(origin: Vector3i) -> Vector3i:
	return Vector3i(maxi(0, origin.x - 1), maxi(0, origin.y - 1), maxi(0, origin.z - 1))


static func _scan_to(size: Vector3i, end: Vector3i) -> Vector3i:
	return Vector3i(mini(size.x, end.x + 1), mini(size.y, end.y + 1), mini(size.z, end.z + 1))


static func _cell_in_region(cell: Vector3i, from_cell: Vector3i, to_cell: Vector3i) -> bool:
	return (
		cell.x >= from_cell.x and cell.x < to_cell.x
		and cell.y >= from_cell.y and cell.y < to_cell.y
		and cell.z >= from_cell.z and cell.z < to_cell.z
	)

static func _face_corners(origin: Vector3, face_index: int) -> Array:
	var face_vertices: Array = CellMesher.FACE_VERTICES[face_index]
	return [
		origin + face_vertices[0],
		origin + face_vertices[1],
		origin + face_vertices[2],
		origin + face_vertices[5],
	]


static func _add_segment(surface: SurfaceTool, a: Vector3, b: Vector3) -> void:
	surface.add_vertex(a)
	surface.add_vertex(b)


static func _oriented_edge_key(face_index: int, a: Vector3, b: Vector3) -> String:
	var ai := Vector3i(int(a.x), int(a.y), int(a.z))
	var bi := Vector3i(int(b.x), int(b.y), int(b.z))
	if _vector3i_less(bi, ai):
		var swap := ai
		ai = bi
		bi = swap
	return "%d|%d,%d,%d|%d,%d,%d" % [face_index, ai.x, ai.y, ai.z, bi.x, bi.y, bi.z]


static func _plain_edge_key(a: Vector3, b: Vector3) -> String:
	var ai := Vector3i(int(a.x), int(a.y), int(a.z))
	var bi := Vector3i(int(b.x), int(b.y), int(b.z))
	if _vector3i_less(bi, ai):
		var swap := ai
		ai = bi
		bi = swap
	return "%d,%d,%d|%d,%d,%d" % [ai.x, ai.y, ai.z, bi.x, bi.y, bi.z]


static func _vector3i_less(a: Vector3i, b: Vector3i) -> bool:
	if a.x != b.x:
		return a.x < b.x
	if a.y != b.y:
		return a.y < b.y
	return a.z < b.z