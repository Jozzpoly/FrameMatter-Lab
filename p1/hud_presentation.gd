class_name P1HudPresentation
extends Node

# Presentation-only G7/V-G challenger. The composed runtime already owns every
# state represented here; this node only chooses what the default Owner surface
# exposes. Engineering telemetry remains in the runtime/evidence systems rather
# than occupying the normal world view.

@export var panel_width := 330.0
@export var panel_height := 58.0

var _host: Node
var _panel: PanelContainer
var _status: Label
var _hint: Label


func bind_host(host: Node) -> void:
	_host = host
	if _host != null and _host.is_node_ready():
		_bind_and_refresh()
	else:
		call_deferred("_bind_and_refresh")


func _ready() -> void:
	if _host == null:
		_host = get_parent()
	call_deferred("_bind_and_refresh")


func _process(_delta: float) -> void:
	if _host == null or not is_instance_valid(_host) or not _host.is_node_ready():
		return
	_refresh()


func _bind_and_refresh() -> void:
	if _host == null or not is_instance_valid(_host) or not _host.is_node_ready():
		return
	_bind_controls()
	_apply_layout()
	_refresh()


func _bind_controls() -> void:
	if _host == null or not is_instance_valid(_host):
		return
	_panel = _host.get_node_or_null("HUD/Panel") as PanelContainer
	_status = _host.get_node_or_null("HUD/Panel/MarginContainer/VBoxContainer/Status") as Label
	_hint = _host.get_node_or_null("HUD/Panel/MarginContainer/VBoxContainer/Hint") as Label


func _apply_layout() -> void:
	if _panel == null or _status == null or _hint == null:
		return
	_panel.offset_right = _panel.offset_left + panel_width
	_panel.offset_bottom = _panel.offset_top + panel_height
	_panel.clip_contents = true
	_status.add_theme_font_size_override("font_size", 15)
	_hint.add_theme_font_size_override("font_size", 11)
	_hint.add_theme_color_override("font_color", Color(0.68, 0.76, 0.84, 1.0))


func _refresh() -> void:
	if _host == null or _status == null or _hint == null:
		return
	if not _host.has_method("get_space") or not _host.has_method("get_active_spaces") or not _host.has_method("get_interactor"):
		return
	var space := _host.call("get_space") as LocalMatterSpace
	var interactor := _host.call("get_interactor") as P1MatterInteractor
	var active_spaces: Array[LocalMatterSpace] = _host.call("get_active_spaces")
	if space == null or not is_instance_valid(space) or space.is_retired() or space.get_active_provider() == null:
		_status.text = "NO ACTIVE SPACE"
		_hint.text = "WASD move   ·   K recover   ·   R reset"
		return
	var kind := "STATIC" if space.get_provider_kind() == LocalMatterSpace.ProviderKind.STATIC else "DYNAMIC"
	var edit_mode := interactor.get_mode_name() if interactor != null else "—"
	_status.text = "%s   ·   %s   ·   %d SPACE%s" % [
		kind,
		edit_mode,
		active_spaces.size(),
		"" if active_spaces.size() == 1 else "S",
	]
	_hint.text = "WASD move   ·   T state   ·   E edit   ·   LMB apply"
