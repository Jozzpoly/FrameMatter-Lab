class_name P1MatterSurfaceGrid
extends Node

# Derived presentation only. This node does not own Matter, lineage, topology,
# collision, mass or provider lifecycle. It observes the P1 consumer contracts
# and rebuilds a lightweight surface-granularity cue on each current provider.

const OVERLAY_NAME := "P1MatterSurfaceGridOverlay"
const SURFACE_OFFSET := 0.006
const LINE_ALPHA := 0.14
const LINE_COLOR := Color(0.035, 0.075, 0.11, LINE_ALPHA)

var registry: P1SpaceRegistry
var interactor: P1MatterInteractor
var enabled := true
var last_refresh_usec := 0
var last_refresh_space_id := 0

var _overlay_signatures: Dictionary = {}


func _ready() -> void:
	var parent := get_parent()
	if parent == null:
		return
	set_sources(
		parent.get_node_or_null("P1SpaceRegistry") as P1SpaceRegistry,
		parent.get_node_or_null("P1MatterInteractor") as P1MatterInteractor
	)


func set_sources(value_registry: P1SpaceRegistry, value_interactor: P1MatterInteractor) -> void:
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


func set_enabled(value: bool) -> void:
	if enabled == value:
		return
	enabled = value
	if enabled:
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
	var space_id := (
		space.get_instance_id()
		if space != null and is_instance_valid(space)
		else 0
	)
	last_refresh_space_id = space_id
	if space == null or not is_instance_valid(space) or space.is_retired() or space.volume == null:
		if space_id != 0:
			_overlay_signatures.erase(space_id)
		last_refresh_usec = Time.get_ticks_usec() - started_usec
		return
	var provider: Node3D = space.get_active_provider()
	if provider == null or not is_instance_valid(provider):
		_overlay_signatures.erase(space_id)
		last_refresh_usec = Time.get_ticks_usec() - started_usec
		return

	_remove_overlay_from_provider(provider)
	_overlay_signatures.erase(space_id)
	if not enabled or space.volume.count_solid() == 0:
		last_refresh_usec = Time.get_ticks_usec() - started_usec
		return

	var overlay := MeshInstance3D.new()
	overlay.name = OVERLAY_NAME
	overlay.mesh = build_exposed_surface_grid(space.volume)
	overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = LINE_COLOR
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Depth test intentionally remains enabled: this is a surface cue, not an
	# x-ray/debug overlay.
	overlay.material_override = material
	provider.add_child(overlay)
	_overlay_signatures[space_id] = _overlay_signature(space)
	last_refresh_usec = Time.get_ticks_usec() - started_usec

func clear_all() -> void:
	if registry != null and is_instance_valid(registry):
		for space in registry.get_active_spaces():
			if space == null or not is_instance_valid(space):
				continue
			var provider: Node3D = space.get_active_provider()
			if provider != null and is_instance_valid(provider):
				_remove_overlay_from_provider(provider)
	_overlay_signatures.clear()


func _ensure_active_spaces() -> void:
	if registry == null or not is_instance_valid(registry):
		return
	var live_ids: Dictionary = {}
	for space in registry.get_active_spaces():
		if space == null or not is_instance_valid(space) or space.is_retired():
			continue
		live_ids[space.get_instance_id()] = true
		_ensure_space(space)
	for cached_id in _overlay_signatures.keys():
		if not live_ids.has(cached_id):
			_overlay_signatures.erase(cached_id)


func _ensure_space(space: LocalMatterSpace) -> void:
	if space == null or not is_instance_valid(space) or space.is_retired() or space.volume == null:
		return
	var provider := space.get_active_provider()
	if provider == null or not is_instance_valid(provider):
		return
	var space_id := space.get_instance_id()
	var overlay := provider.get_node_or_null(OVERLAY_NAME) as MeshInstance3D
	var signature := _overlay_signature(space)
	if overlay != null and str(_overlay_signatures.get(space_id, "")) == signature:
		return
	refresh_space(space)


func _overlay_signature(space: LocalMatterSpace) -> String:
	var provider := space.get_active_provider()
	var provider_id := provider.get_instance_id() if provider != null and is_instance_valid(provider) else 0
	return "%d:%d" % [provider_id, space.volume.revision]

func get_overlay_for_space(space: LocalMatterSpace) -> MeshInstance3D:
	if space == null or not is_instance_valid(space) or space.is_retired():
		return null
	var provider: Node3D = space.get_active_provider()
	if provider == null or not is_instance_valid(provider):
		return null
	return provider.get_node_or_null(OVERLAY_NAME) as MeshInstance3D


func get_overlay_count() -> int:
	if registry == null or not is_instance_valid(registry):
		return 0
	var count := 0
	for space in registry.get_active_spaces():
		if get_overlay_for_space(space) != null:
			count += 1
	return count


static func build_exposed_surface_grid(volume: CellVolume) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if volume == null or volume.count_solid() == 0:
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
					var offset := normal * SURFACE_OFFSET
					var raw_corners := [
						origin + face_vertices[0],
						origin + face_vertices[1],
						origin + face_vertices[2],
						origin + face_vertices[5],
					]
					for edge_index in range(4):
						var raw_a: Vector3 = raw_corners[edge_index]
						var raw_b: Vector3 = raw_corners[(edge_index + 1) % 4]
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
	# Keep face orientation in the key. Coplanar same-normal duplicates collapse,
	# while a true crease keeps one slightly offset segment for each surface.
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
	_ensure_active_spaces()


func _on_provider_changed(space: LocalMatterSpace) -> void:
	refresh_space(space)


func _on_storage_rebased(space: LocalMatterSpace, _report: Dictionary) -> void:
	refresh_space(space)


func _on_split_committed(_source: LocalMatterSpace, _result: LocalMatterSplitResult) -> void:
	_ensure_active_spaces()


func _on_edit_applied(space: LocalMatterSpace, _cell: Vector3i, _mode: int, _split_queued: bool) -> void:
	refresh_space(space)


func _remove_overlay_from_provider(provider: Node3D) -> void:
	var existing := provider.get_node_or_null(OVERLAY_NAME)
	if existing != null:
		existing.free()
