class_name P1RecoveryHudPresentation
extends Node

var _host: Node
var _panel: PanelContainer
var _status: Label
var _hint: Label


func _ready() -> void:
	_host = get_parent()
	call_deferred("_bind")


func _process(_delta: float) -> void:
	_refresh()


func _bind() -> void:
	if _host == null or not is_instance_valid(_host):
		return
	_panel = _host.get_node_or_null("HUD/Panel") as PanelContainer
	_status = _host.get_node_or_null("HUD/Panel/MarginContainer/VBoxContainer/Status") as Label
	_hint = _host.get_node_or_null("HUD/Panel/MarginContainer/VBoxContainer/Hint") as Label
	if _panel != null:
		_panel.offset_right = _panel.offset_left + 700.0
		_panel.offset_bottom = _panel.offset_top + 58.0
	_refresh()


func _refresh() -> void:
	if _host == null or _status == null or _hint == null:
		return
	var focus := _host.call("get_space") as LocalMatterSpace if _host.has_method("get_space") else null
	var world := _host.call("get_recovery_world_space") as LocalMatterSpace if _host.has_method("get_recovery_world_space") else null
	var spaces: Array[LocalMatterSpace] = _host.call("get_active_spaces") if _host.has_method("get_active_spaces") else []
	if focus == null or not is_instance_valid(focus) or focus.is_retired():
		_status.text = "FRAME MATTER · NO FOCUS"
		_hint.text = "WASD move   ·   Space jump   ·   MMB orbit"
		return

	var is_world := focus == world
	var kind := "STATIC" if focus.get_provider_kind() == LocalMatterSpace.ProviderKind.STATIC else "DYNAMIC"
	var role := "WORLD MATTER" if is_world else "DETACHED MATTER"
	_status.text = "%s   ·   %s   ·   %d LIVE SPACE%s" % [
		role,
		kind,
		spaces.size(),
		"" if spaces.size() == 1 else "S",
	]

	if is_world:
		_hint.text = "LMB remove   ·   RMB build   ·   cut support to detach Matter   ·   WASD move   ·   Space jump   ·   MMB orbit"
		return

	var toggle_label := "T freeze" if focus.get_provider_kind() == LocalMatterSpace.ProviderKind.DYNAMIC else "T release"
	_hint.text = "LMB remove   ·   RMB build   ·   %s   ·   arrows push/turn   ·   WASD move   ·   Space jump   ·   MMB orbit" % toggle_label
