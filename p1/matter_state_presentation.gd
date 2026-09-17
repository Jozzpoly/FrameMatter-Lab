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
	state_overlay.mesh = build_side_surface_contour(space.volume)
	state_overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var state_material := StandardMaterial3D.new()
	state_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	state_material.albedo_color = STATIC_COLOR if space.get_provider_kind() == LocalMatterSpace.ProviderKind.STATIC else DYNAMIC_COLOR
	state_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	state_overlay.material_override = state_material
	provider.add_child(state_overlay)
	_state_signatures[space_id] = _state_signature(space)


func _refresh_focus(space: LocalMatterSpace) -> void:
	var provider := space.get_active_provider()
	_remove_overlay_from_provider(provider, FOCUS_OVERLAY_NAME)
	var space_id := space.get_instance_id()
	_focus_signatures.erase(space_id)
	if not enabled or space != _focus_space or space.volume.count_solid() == 0:
		return
	var focus_mesh := build_top_surface_perimeter(space.volume)
	if focus_mesh.get_surface_count() == 0:
		return
	var focus_overlay := MeshInstance3D.new()
	focus_overlay.name = FOCUS_OVERLAY_NAME
	focus_overlay.mesh = focus_mesh
	focus_overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var focus_material := StandardMaterial3D.new()
	focus_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	focus_material.albedo_color = FOCUS_COLOR
	focus_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	focus_overlay.material_override = focus_material
	provider.add_child(focus_overlay)
	_focus_signatures[space_id] = _focus_signature(space)


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


func _on_edit_applied(space: LocalMatterSpace, _cell: Vector3i, _mode: int, _split_queued: bool) -> void:
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