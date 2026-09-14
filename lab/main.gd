extends Node3D

const SIZE := Vector3i(8, 4, 8)
const PROBE_CELL := Vector3i(3, 1, 3)
const MATERIAL_CELL := Vector3i(6, 1, 5)
const MASS_PER_CELL := 1.25
const DRIVE_LINEAR := Vector3(1.15, 0.0, -0.35)
const DRIVE_ANGULAR := Vector3(0.08, 0.34, 0.12)

var _space: LocalMatterSpace
var _volume: CellVolume
var _lineage: MatterLineageMap
var _next_lineage_token := 500001
var _last_action := "boot"
var _transition_count := 0
var _mutation_count := 0


func _ready() -> void:
	$Camera3D.look_at(Vector3(4.0, 1.5, 4.0), Vector3.UP)
	$DirectionalLight3D.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	_reset_lab()


func _process(_delta: float) -> void:
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	match event.physical_keycode:
		KEY_A:
			_activate_dynamic()
		KEY_F:
			_freeze_to_static()
		KEY_M:
			_toggle_probe_cell()
		KEY_C:
			_cycle_retained_material()
		KEY_R:
			_reset_lab()


func _reset_lab() -> void:
	if _space != null:
		_space.free()

	_volume = CellVolume.new(SIZE)
	_volume.fill_box(Vector3i.ZERO, Vector3i(8, 1, 8), CellVolume.SOLID)
	_volume.fill_box(Vector3i(1, 1, 1), Vector3i(3, 3, 3), CellVolume.SOLID)
	_volume.fill_box(Vector3i(6, 1, 5), Vector3i(7, 4, 6), CellVolume.SOLID)
	_volume.set_cell(PROBE_CELL, CellVolume.SOLID)

	_lineage = MatterLineageMap.new(SIZE)
	_next_lineage_token = 500001
	for cell in _occupied_cells(_volume):
		_lineage.set_lineage(cell, _next_lineage_token)
		_next_lineage_token += 1

	_space = LocalMatterSpace.new()
	_space.name = "InteractiveLocalMatterSpace"
	_space.mass_per_cell = MASS_PER_CELL
	_space.dynamic_gravity_scale = 0.0
	_space.dynamic_linear_damp = 0.0
	_space.dynamic_angular_damp = 0.0
	_space.dynamic_can_sleep = false
	add_child(_space)
	_space.provider_transition_committed.connect(_on_provider_transition_committed)
	_space.initialize_static(
		_volume,
		_lineage,
		Transform3D(Basis.IDENTITY, Vector3.ZERO)
	)

	_transition_count = 0
	_mutation_count = 0
	_last_action = "reset → one logical Space with static provider"
	_update_hud()


func _activate_dynamic() -> void:
	if _space == null:
		return
	if _space.get_provider_kind() != LocalMatterSpace.ProviderKind.STATIC:
		_last_action = "A ignored: Space is not static"
		return
	if _space.request_dynamic(DRIVE_LINEAR, DRIVE_ANGULAR):
		_last_action = "A: queued static → dynamic provider replacement"
	else:
		_last_action = "A ignored: transition already pending"


func _freeze_to_static() -> void:
	if _space == null:
		return
	if _space.get_provider_kind() != LocalMatterSpace.ProviderKind.DYNAMIC:
		_last_action = "F ignored: Space is not dynamic"
		return
	if _space.request_static():
		_last_action = "F: queued dynamic → static provider replacement"
	else:
		_last_action = "F ignored: transition already pending"


func _toggle_probe_cell() -> void:
	if _space == null:
		return
	if _volume.get_cell(PROBE_CELL) == CellVolume.EMPTY:
		var token := _next_lineage_token
		_next_lineage_token += 1
		if _space.mutate_cell(PROBE_CELL, CellVolume.SOLID, token):
			_mutation_count += 1
			_last_action = "M: created probe cell with fresh lineage %d" % token
	else:
		var retired_token := _lineage.get_lineage(PROBE_CELL)
		if _space.mutate_cell(PROBE_CELL, CellVolume.EMPTY):
			_mutation_count += 1
			_last_action = "M: removed probe cell; retired lineage %d" % retired_token


func _cycle_retained_material() -> void:
	if _space == null:
		return
	var current_material := _volume.get_cell(MATERIAL_CELL)
	if current_material == CellVolume.EMPTY:
		_last_action = "C ignored: retained-material probe cell is unexpectedly empty"
		return
	var next_material := current_material + 1
	if next_material > 8:
		next_material = 2
	var retained_token := _lineage.get_lineage(MATERIAL_CELL)
	if _space.mutate_cell(MATERIAL_CELL, next_material):
		_mutation_count += 1
		_last_action = "C: material %d → %d; lineage %d retained" % [current_material, next_material, retained_token]


func _on_provider_transition_committed(previous_provider_id: int, current_provider_id: int, provider_kind: int) -> void:
	_transition_count += 1
	_last_action = (
		"transition #%d committed: provider %d → %d (%s)"
		% [_transition_count, previous_provider_id, current_provider_id, _provider_kind_name(provider_kind)]
	)


func _update_hud() -> void:
	if _space == null or _space.get_active_provider() == null:
		$HUD/Panel/Label.text = "FrameMatter Lifecycle LAB — no active Space"
		return

	var provider := _space.get_active_provider()
	var provider_kind := _space.get_provider_kind()
	var provider_position := provider.global_position
	var provider_rotation := provider.rotation_degrees
	var collision_shapes := _provider_collision_shape_count(provider)
	var mesh_vertices := _provider_mesh_vertex_count(provider)
	var rebuild_usec := _provider_rebuild_usec(provider)
	var dynamic_line := "velocity: n/a (static provider)"
	var server_node_line := "PhysicsServer→Node gap: n/a"

	if provider is ConstructBody:
		var body := provider as ConstructBody
		dynamic_line = "linear: %s    angular: %s" % [_fmt_vec(body.linear_velocity), _fmt_vec(body.angular_velocity)]
		var server_transform := PhysicsServer3D.body_get_state(
			body.get_rid(),
			PhysicsServer3D.BODY_STATE_TRANSFORM
		) as Transform3D
		server_node_line = "PhysicsServer→Node position gap: %.6f" % server_transform.origin.distance_to(body.global_position)

	var transition_report := _space.get_last_transition_report()
	var transition_line := "last transition: none"
	if not transition_report.is_empty():
		transition_line = (
			"last transition providers: %d → %d    retire/install count: %d/%d"
			% [
				int(transition_report["previous_provider_id"]),
				int(transition_report["current_provider_id"]),
				int(transition_report["provider_count_after_retire"]),
				int(transition_report["provider_count_after_install"]),
			]
		)

	$HUD/Panel/Label.text = (
		"FrameMatter LAB — shared LocalMatterSpace lifecycle\n"
		+ "A activate dynamic    F freeze to static    M remove/create cell    C retained material    R reset\n\n"
		+ "logical Space ID: %d    provider: %s    provider ID: %d\n" % [
			_space.get_instance_id(),
			_provider_kind_name(provider_kind),
			provider.get_instance_id(),
		]
		+ "transition pending: %s    transitions: %d    mutations: %d\n" % [
			str(_space.is_transition_pending()),
			_transition_count,
			_mutation_count,
		]
		+ "position: %s    rotation°: %s\n" % [_fmt_vec(provider_position), _fmt_vec(provider_rotation)]
		+ dynamic_line + "\n"
		+ server_node_line + "\n"
		+ "Matter revision: %d    occupied: %d    lineage assigned: %d\n" % [
			_volume.revision,
			_volume.count_solid(),
			_lineage.count_assigned(),
		]
		+ "probe cell: material=%d lineage=%d    retained cell: material=%d lineage=%d\n" % [
			_volume.get_cell(PROBE_CELL),
			_lineage.get_lineage(PROBE_CELL),
			_volume.get_cell(MATERIAL_CELL),
			_lineage.get_lineage(MATERIAL_CELL),
		]
		+ "derived collision shapes: %d    mesh vertices: %d    rebuild: %d us\n" % [
			collision_shapes,
			mesh_vertices,
			rebuild_usec,
		]
		+ transition_line + "\n"
		+ "last action: " + _last_action
	)


func _provider_kind_name(provider_kind: int) -> String:
	match provider_kind:
		LocalMatterSpace.ProviderKind.STATIC:
			return "STATIC / MatterRepresentation"
		LocalMatterSpace.ProviderKind.DYNAMIC:
			return "DYNAMIC / ConstructBody"
		_:
			return "NONE"


func _provider_collision_shape_count(provider: Node3D) -> int:
	if provider is MatterRepresentation:
		return (provider as MatterRepresentation).get_collision_shape_count()
	if provider is ConstructBody:
		return (provider as ConstructBody).get_collision_shape_count()
	return 0


func _provider_mesh_vertex_count(provider: Node3D) -> int:
	if provider is MatterRepresentation:
		return (provider as MatterRepresentation).get_mesh_vertex_count()
	if provider is ConstructBody:
		return (provider as ConstructBody).get_mesh_vertex_count()
	return 0


func _provider_rebuild_usec(provider: Node3D) -> int:
	if provider is MatterRepresentation:
		return (provider as MatterRepresentation).last_rebuild_usec
	if provider is ConstructBody:
		return (provider as ConstructBody).last_rebuild_usec
	return 0


func _occupied_cells(volume: CellVolume) -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	for z in range(volume.size.z):
		for y in range(volume.size.y):
			for x in range(volume.size.x):
				var cell := Vector3i(x, y, z)
				if volume.get_cell(cell) != CellVolume.EMPTY:
					cells.append(cell)
	return cells


func _fmt_vec(value: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [value.x, value.y, value.z]
