class_name P1InteractionFeedback
extends Control

const SUCCESS_DURATION := 0.72
const REJECT_DURATION := 0.92
const FADE_FRACTION := 0.42
const POINTER_OFFSET := Vector2(14.0, 14.0)
const SCREEN_MARGIN := 10.0
const REMOVE_COLOR := Color(1.0, 0.42, 0.28, 1.0)
const PLACE_COLOR := Color(0.44, 1.0, 0.66, 1.0)
const REJECT_COLOR := Color(1.0, 0.62, 0.28, 1.0)

var interactor: P1MatterInteractor
var enabled := true
var _remaining := 0.0
var _duration := 0.0
var _label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.name = "TransientLabel"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_constant_override("outline_size", 4)
	_label.add_theme_color_override("font_outline_color", Color(0.01, 0.015, 0.025, 0.95))
	_label.visible = false
	add_child(_label)
	call_deferred("_bind_from_scene")


func _process(delta: float) -> void:
	if _label == null or not _label.visible:
		return
	_remaining = maxf(0.0, _remaining - maxf(0.0, delta))
	if _remaining <= 0.0:
		_label.visible = false
		return
	var fade_window := maxf(0.001, _duration * FADE_FRACTION)
	var alpha := clampf(_remaining / fade_window, 0.0, 1.0)
	_label.modulate.a = alpha


func set_interactor(value: P1MatterInteractor) -> void:
	if interactor != null and is_instance_valid(interactor):
		_disconnect_interactor(interactor)
	interactor = value
	if interactor != null:
		_connect_interactor(interactor)


func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled and _label != null:
		_label.visible = false


func is_feedback_visible() -> bool:
	return _label != null and _label.visible


func get_feedback_text() -> String:
	return _label.text if _label != null else ""


func _bind_from_scene() -> void:
	if interactor != null and is_instance_valid(interactor):
		return
	var scene_root := get_parent()
	if scene_root is CanvasLayer:
		scene_root = scene_root.get_parent()
	if scene_root == null:
		return
	set_interactor(scene_root.get_node_or_null("P1MatterInteractor") as P1MatterInteractor)


func _connect_interactor(value: P1MatterInteractor) -> void:
	if not value.edit_applied.is_connected(_on_edit_applied):
		value.edit_applied.connect(_on_edit_applied)
	if not value.edit_rejected.is_connected(_on_edit_rejected):
		value.edit_rejected.connect(_on_edit_rejected)


func _disconnect_interactor(value: P1MatterInteractor) -> void:
	if value.edit_applied.is_connected(_on_edit_applied):
		value.edit_applied.disconnect(_on_edit_applied)
	if value.edit_rejected.is_connected(_on_edit_rejected):
		value.edit_rejected.disconnect(_on_edit_rejected)


func _on_edit_applied(
	_space: LocalMatterSpace,
	_cell: Vector3i,
	mode: int,
	_split_queued: bool
) -> void:
	if not enabled:
		return
	if mode == P1MatterInteractor.EditMode.REMOVE:
		_show_feedback("REMOVED", REMOVE_COLOR, SUCCESS_DURATION)
	else:
		_show_feedback("PLACED", PLACE_COLOR, SUCCESS_DURATION)


func _on_edit_rejected(_reason: String) -> void:
	if not enabled:
		return
	_show_feedback("BLOCKED", REJECT_COLOR, REJECT_DURATION)


func _show_feedback(text: String, color: Color, duration: float) -> void:
	if _label == null:
		return
	_label.text = text
	_label.add_theme_color_override("font_color", color)
	_label.modulate = Color.WHITE
	_label.visible = true
	_label.reset_size()
	_duration = duration
	_remaining = duration
	_position_label()


func _position_label() -> void:
	if _label == null:
		return
	var viewport_rect := get_viewport_rect()
	var anchor := viewport_rect.size * 0.5
	if interactor != null and is_instance_valid(interactor):
		anchor = interactor.target_screen_position
	var size := _label.size
	var desired := anchor + POINTER_OFFSET
	desired.x = clampf(desired.x, SCREEN_MARGIN, maxf(SCREEN_MARGIN, viewport_rect.size.x - size.x - SCREEN_MARGIN))
	desired.y = clampf(desired.y, SCREEN_MARGIN, maxf(SCREEN_MARGIN, viewport_rect.size.y - size.y - SCREEN_MARGIN))
	_label.position = desired
