extends Node3D

const PROBE_CELL := Vector3i(3, 1, 3)

var _volume: CellVolume
var _representation: MatterRepresentation


func _ready() -> void:
	$Camera3D.look_at(Vector3(4, 1.5, 4), Vector3.UP)
	$DirectionalLight3D.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	_reset_volume()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_M:
			_toggle_probe_cell()
		elif event.physical_keycode == KEY_R:
			_reset_volume()


func _reset_volume() -> void:
	_volume = CellVolume.new(Vector3i(8, 4, 8))
	_volume.fill_box(Vector3i(0, 0, 0), Vector3i(8, 1, 8), CellVolume.SOLID)
	_volume.fill_box(Vector3i(1, 1, 1), Vector3i(2, 3, 2), CellVolume.SOLID)
	_volume.fill_box(Vector3i(6, 1, 5), Vector3i(7, 4, 6), CellVolume.SOLID)
	_volume.set_cell(PROBE_CELL, CellVolume.SOLID)

	if _representation != null:
		_representation.queue_free()

	_representation = MatterRepresentation.new()
	_representation.name = "MatterRepresentation"
	add_child(_representation)
	_representation.set_volume(_volume)
	_update_hud("reset from logical Matter")


func _toggle_probe_cell() -> void:
	var next_material := CellVolume.SOLID
	if _volume.get_cell(PROBE_CELL) != CellVolume.EMPTY:
		next_material = CellVolume.EMPTY
	_volume.set_cell(PROBE_CELL, next_material)
	_representation.rebuild()
	_update_hud("mutated local cell %s" % PROBE_CELL)


func _update_hud(last_action: String) -> void:
	$HUD/Panel/Label.text = (
		"FrameMatter Lab — G0 Matter Truth\n"
		+ "M: toggle probe cell    R: destroy/rebuild representation\n\n"
		+ "Matter revision: %d\n" % _volume.revision
		+ "Solid cells: %d\n" % _volume.count_solid()
		+ "Exposed faces: %d\n" % CellMesher.count_exposed_faces(_volume)
		+ "Derived collision shapes: %d\n" % _representation.get_collision_shape_count()
		+ "Derived mesh vertices: %d\n" % _representation.get_mesh_vertex_count()
		+ "Last rebuild: %d us\n" % _representation.last_rebuild_usec
		+ "Last action: %s" % last_action
	)
