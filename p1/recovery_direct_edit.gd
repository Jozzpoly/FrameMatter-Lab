class_name P1RecoveryDirectEdit
extends Node

# Owner-facing recovery control: direct sandbox editing.
# LMB always means remove, RMB always means place/build. The shared interactor
# still owns targeting, storage expansion, lineage issuance and topology rules.

@onready var _interactor: P1MatterInteractor = get_parent().get_node("P1MatterInteractor") as P1MatterInteractor


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse := event as InputEventMouseButton
	if not mouse.pressed:
		return
	if mouse.button_index != MOUSE_BUTTON_LEFT and mouse.button_index != MOUSE_BUTTON_RIGHT:
		return
	if _interactor == null or not is_instance_valid(_interactor):
		return

	var desired_mode := (
		P1MatterInteractor.EditMode.REMOVE
		if mouse.button_index == MOUSE_BUTTON_LEFT
		else P1MatterInteractor.EditMode.PLACE
	)
	_interactor.set_mode(desired_mode)
	# Refresh after the mode change because REMOVE/PLACE validity and the selected
	# cell are intentionally different sides of the same physical surface hit.
	_interactor.update_target_from_pointer_position(mouse.position)
	if _interactor.target_space == null:
		return
	_interactor.apply_current_edit()
	get_viewport().set_input_as_handled()
