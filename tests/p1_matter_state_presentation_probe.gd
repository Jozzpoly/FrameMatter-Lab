extends SceneTree

const ACQUIRE_FRAMES := 16
const SETTLE_FRAMES := 5
const EDGE_Z := 8

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://p1/main.tscn") as PackedScene
	_check(packed != null, "P1 state presentation probe loads canonical scene")
	if packed == null:
		_finish()
		return

	var p1 := packed.instantiate()
	get_root().add_child(p1)
	await process_frame
	await _advance_frames(ACQUIRE_FRAMES)

	var source := p1.call("get_space") as LocalMatterSpace
	var interactor := p1.call("get_interactor") as P1MatterInteractor
	var presenter := p1.get_node_or_null("P1MatterStatePresentation") as P1MatterStatePresentation
	_check(source != null and interactor != null and presenter != null, "canonical P1 composes state presentation with Space and interactor")
	if source == null or interactor == null or presenter == null:
		p1.free()
		_finish()
		return

	_check(presenter.get_focus_space() == source, "presenter observes canonical initial focus without owning it")
	_check(presenter.get_state_overlay_count() == 1, "one live Space receives one state contour")
	_check(presenter.get_focus_overlay_count() == 1, "exactly one focused Space receives a focus crown")
	_check(_overlay_matches(presenter.get_state_overlay_for_space(source), P1MatterStatePresentation.STATIC_COLOR), "initial static Space uses restrained cyan state contour")
	_check(_overlay_matches(presenter.get_focus_overlay_for_space(source), P1MatterStatePresentation.FOCUS_COLOR), "focus uses independent neutral crown language")

	var initial_provider := source.get_active_provider()
	var initial_base_color := _base_material_color(initial_provider)
	presenter.set_enabled(false)
	_check(presenter.get_state_overlay_count() == 0 and presenter.get_focus_overlay_count() == 0, "presentation layer can be disabled without changing world authority")
	_check(_color_close(_base_material_color(initial_provider), initial_base_color), "disabling state presentation leaves Matter base material unchanged")
	presenter.set_enabled(true)
	await process_frame
	_check(presenter.get_state_overlay_count() == 1 and presenter.get_focus_overlay_count() == 1, "presentation layer rebuilds from live consumer state")
	_check(_color_close(_base_material_color(initial_provider), initial_base_color), "rebuilding state presentation does not rewrite Matter material identity")

	var overlay_before_edit := presenter.get_state_overlay_for_space(source)
	var overlay_before_edit_id := overlay_before_edit.get_instance_id() if overlay_before_edit != null else 0
	_check(interactor.apply_edit_to_cell(source, Vector3i(13, 0, 13), P1MatterInteractor.EditMode.REMOVE), "ordinary edit commits before lifecycle checks")
	await process_frame
	var overlay_after_edit := presenter.get_state_overlay_for_space(source)
	_check(overlay_after_edit != null and overlay_after_edit.get_instance_id() != overlay_before_edit_id, "committed edit rebuilds derived state contour from current Matter")

	var static_provider_id := source.get_active_provider().get_instance_id()
	_check(bool(p1.call("toggle_focused_space_for_test")), "probe releases focused Space")
	await source.provider_transition_committed
	await _advance_frames(SETTLE_FRAMES)
	_check(source.get_provider_kind() == LocalMatterSpace.ProviderKind.DYNAMIC, "source is dynamic after release")
	_check(source.get_active_provider().get_instance_id() != static_provider_id, "provider replacement is real rather than presentation-only")
	_check(_overlay_matches(presenter.get_state_overlay_for_space(source), P1MatterStatePresentation.DYNAMIC_COLOR), "dynamic provider receives amber contour")
	_check(presenter.get_focus_overlay_for_space(source) != null, "focus crown survives provider replacement on logical Space identity")
	_check(_color_close(_base_material_color(source.get_active_provider()), Color(0.74, 0.79, 0.88, 1.0)), "dynamic Matter base material remains provider-owned rather than recolored by state semantics")

	_check(interactor.apply_edit_to_cell(source, Vector3i(1, 0, EDGE_Z), P1MatterInteractor.EditMode.PLACE), "probe extends connected Matter to storage edge 1")
	_check(interactor.apply_edit_to_cell(source, Vector3i(0, 0, EDGE_Z), P1MatterInteractor.EditMode.PLACE), "probe extends connected Matter to storage edge 0")
	var outside_cell := Vector3i(-1, 0, EDGE_Z)
	_check(interactor.request_place_to_cell(source, outside_cell), "outside placement requests storage maintenance")
	if source.is_storage_rebase_pending():
		await source.storage_rebase_committed
	await _advance_frames(SETTLE_FRAMES)
	var shift: Vector3i = source.get_last_storage_rebase_report().get("local_shift", Vector3i.ZERO)
	_check(shift != Vector3i.ZERO, "probe observes a real storage-frame shift")
	_check(presenter.get_state_overlay_for_space(source) != null and presenter.get_focus_overlay_for_space(source) != null, "state and focus presentation survive storage rebase")
	_check(_overlay_matches(presenter.get_state_overlay_for_space(source), P1MatterStatePresentation.DYNAMIC_COLOR), "storage maintenance does not change physical-state semantics")

	for z in range(2, 14):
		var cut_cell := Vector3i(6, 0, z) + shift
		_check(interactor.apply_edit_to_cell(source, cut_cell, P1MatterInteractor.EditMode.REMOVE), "topology cut removes source cell %s" % str(cut_cell))
	if source.is_topology_split_pending():
		await source.topology_split_committed
	await _advance_frames(SETTLE_FRAMES)

	var successors: Array[LocalMatterSpace] = p1.call("get_active_spaces")
	var focused := p1.call("get_space") as LocalMatterSpace
	_check(source.is_retired(), "topology source retires")
	_check(successors.size() == 2, "topology split produces two live successor Spaces")
	_check(presenter.get_state_overlay_count() == 2, "each successor receives its own derived state contour")
	_check(presenter.get_focus_overlay_count() == 1, "split preserves exactly one focused successor crown")
	_check(focused != null and successors.has(focused), "canonical focus resolves to one live successor")
	_check(presenter.get_focus_space() == focused, "presentation observes successor focus handoff")
	for successor in successors:
		_check(_overlay_matches(presenter.get_state_overlay_for_space(successor), P1MatterStatePresentation.DYNAMIC_COLOR), "each post-split dynamic successor remains amber")
		_check((presenter.get_focus_overlay_for_space(successor) != null) == (successor == focused), "focus crown belongs only to canonical focused successor")

	_check(bool(p1.call("toggle_focused_space_for_test")), "probe freezes focused successor")
	await focused.provider_transition_committed
	await _advance_frames(SETTLE_FRAMES)
	_check(focused.get_provider_kind() == LocalMatterSpace.ProviderKind.STATIC, "focused successor becomes static")
	_check(_overlay_matches(presenter.get_state_overlay_for_space(focused), P1MatterStatePresentation.STATIC_COLOR), "frozen focused successor switches to cyan contour")
	_check(presenter.get_focus_overlay_for_space(focused) != null, "neutral focus crown remains independent of STATIC state")

	var sibling: LocalMatterSpace
	for successor in successors:
		if successor != focused:
			sibling = successor
			break
	_check(sibling != null and sibling.get_provider_kind() == LocalMatterSpace.ProviderKind.DYNAMIC, "non-focused sibling remains independently dynamic")
	if sibling != null:
		_check(_overlay_matches(presenter.get_state_overlay_for_space(sibling), P1MatterStatePresentation.DYNAMIC_COLOR), "dynamic sibling remains amber beside frozen cyan successor")
		_check(presenter.get_focus_overlay_for_space(sibling) == null, "non-focused sibling does not inherit focus presentation")

	print(
		"P1_MATTER_STATE_PRESENTATION_METRIC static_alpha=%.2f dynamic_alpha=%.2f focus_alpha=%.2f successors=%d state_overlays=%d focus_overlays=%d shift=%s" % [
			P1MatterStatePresentation.STATIC_COLOR.a,
			P1MatterStatePresentation.DYNAMIC_COLOR.a,
			P1MatterStatePresentation.FOCUS_COLOR.a,
			successors.size(),
			presenter.get_state_overlay_count(),
			presenter.get_focus_overlay_count(),
			str(shift),
		]
	)

	p1.free()
	_finish()


func _base_material_color(provider: Node3D) -> Color:
	if provider == null:
		return Color.TRANSPARENT
	var derived_mesh := provider.get_node_or_null("DerivedMesh") as MeshInstance3D
	if derived_mesh == null or not (derived_mesh.material_override is StandardMaterial3D):
		return Color.TRANSPARENT
	return (derived_mesh.material_override as StandardMaterial3D).albedo_color


func _overlay_matches(overlay: MeshInstance3D, expected: Color) -> bool:
	if overlay == null or not (overlay.material_override is StandardMaterial3D):
		return false
	return _color_close((overlay.material_override as StandardMaterial3D).albedo_color, expected)


func _color_close(a: Color, b: Color, tolerance: float = 0.0001) -> bool:
	return absf(a.r - b.r) <= tolerance and absf(a.g - b.g) <= tolerance and absf(a.b - b.b) <= tolerance and absf(a.a - b.a) <= tolerance


func _advance_frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame
		await process_frame


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _finish() -> void:
	if _failures.is_empty():
		print("P1_MATTER_STATE_PRESENTATION_PASS: restrained physical-state contours and independent focus crown remain derived presentation through edit, rebase, provider replacement, topology succession and freeze.")
		quit(0)
		return
	for failure in _failures:
		push_error("P1_MATTER_STATE_PRESENTATION_FAIL: " + failure)
	quit(1)
