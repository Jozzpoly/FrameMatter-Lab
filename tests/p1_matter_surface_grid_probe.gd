extends SceneTree

const ACQUIRE_FRAMES := 12
const POST_TRANSITION_FRAMES := 4
const POST_SPLIT_FRAMES := 4
const EDGE_Z := 8

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_probe_deduplicated_geometry()

	var packed := load("res://p1/main.tscn") as PackedScene
	_check(packed != null, "P1 scene loads with production Matter surface grid")
	if packed == null:
		_finish()
		return

	var p1 := packed.instantiate()
	get_root().add_child(p1)
	await process_frame
	await _advance_frames(ACQUIRE_FRAMES)

	var source := p1.call("get_space") as LocalMatterSpace
	var interactor := p1.call("get_interactor") as P1MatterInteractor
	var presenter := p1.get_node_or_null("P1MatterSurfaceGrid") as P1MatterSurfaceGrid
	_check(source != null and interactor != null and presenter != null, "surface grid probe resolves source, interactor and presenter")
	if source == null or interactor == null or presenter == null:
		p1.free()
		_finish()
		return

	var static_provider := source.get_active_provider()
	var initial_overlay := presenter.get_overlay_for_space(source)
	_check(initial_overlay != null, "initial live Space receives one production surface overlay")
	_check(presenter.get_overlay_count() == 1, "initial presentation has exactly one overlay for one live Space")
	_check(initial_overlay != null and initial_overlay.get_parent() == static_provider, "surface overlay is a child of the current provider")
	_check(_overlay_uses_promoted_material(initial_overlay), "production overlay uses promoted clean alpha and depth-tested material")

	var initial_overlay_id := initial_overlay.get_instance_id() if initial_overlay != null else 0
	_check(
		interactor.apply_edit_to_cell(source, Vector3i(3, 2, 4), P1MatterInteractor.EditMode.REMOVE),
		"ordinary committed Matter edit succeeds"
	)
	var edited_overlay := presenter.get_overlay_for_space(source)
	_check(edited_overlay != null, "ordinary Matter edit leaves a current overlay")
	_check(edited_overlay != null and edited_overlay.get_instance_id() != initial_overlay_id, "committed edit rebuilds derived presentation rather than mutating authority")
	_check(presenter.get_overlay_count() == 1, "ordinary edit does not duplicate presentation overlays")

	var edited_overlay_id := edited_overlay.get_instance_id() if edited_overlay != null else 0
	var outside_cell := Vector3i(-1, 0, EDGE_Z)
	_check(source.request_storage_rebase(outside_cell, 2), "storage-frame maintenance request is accepted")
	await source.storage_rebase_committed
	await process_frame
	var rebased_overlay := presenter.get_overlay_for_space(source)
	_check(rebased_overlay != null, "storage rebase retains surface presentation")
	_check(rebased_overlay != null and rebased_overlay.get_instance_id() != edited_overlay_id, "storage rebase rebuilds presentation in the new local frame")
	_check(presenter.get_overlay_count() == 1, "storage rebase still presents one overlay for one live Space")

	var rebase_report: Dictionary = source.get_last_storage_rebase_report()
	var shift: Vector3i = rebase_report.get("local_shift", Vector3i.ZERO)
	_check(bool(p1.call("activate_dynamic_probe_for_test")), "surface grid probe releases source to a dynamic provider")
	await source.provider_transition_committed
	await _advance_frames(POST_TRANSITION_FRAMES)
	var dynamic_provider := source.get_active_provider()
	var dynamic_overlay := presenter.get_overlay_for_space(source)
	_check(dynamic_provider is ConstructBody and dynamic_provider != static_provider, "provider lifecycle replaced static representation with ConstructBody")
	_check(dynamic_overlay != null and dynamic_overlay.get_parent() == dynamic_provider, "surface presentation follows the replacement provider")
	_check(presenter.get_overlay_count() == 1, "provider replacement does not leave duplicate live overlays")

	for z in range(2, 14):
		var cut_cell := Vector3i(6, 0, z) + shift
		_check(
			interactor.apply_edit_to_cell(source, cut_cell, P1MatterInteractor.EditMode.REMOVE),
			"topology cut removes source cell %s" % str(cut_cell)
		)
	_check(source.is_topology_split_pending(), "final topology cut queues source split")
	await source.topology_split_committed
	await _advance_frames(POST_SPLIT_FRAMES)

	var active_spaces := p1.call("get_active_spaces") as Array[LocalMatterSpace]
	_check(source.is_retired(), "source retires after topology split")
	_check(source.get_active_provider() == null, "retired source owns no provider")
	_check(active_spaces.size() == 2, "topology split exposes two live successor Spaces")
	_check(presenter.get_overlay_count() == 2, "presentation succession creates one overlay per live successor")
	for successor in active_spaces:
		var provider := successor.get_active_provider() if successor != null else null
		var overlay := presenter.get_overlay_for_space(successor)
		_check(provider != null and overlay != null, "each successor has current provider and surface overlay")
		_check(overlay != null and overlay.get_parent() == provider, "each successor overlay belongs to its own provider")
		_check(_overlay_uses_promoted_material(overlay), "successor presentation preserves promoted G3 material semantics")

	if dynamic_provider != null and is_instance_valid(dynamic_provider):
		_check(dynamic_provider.get_node_or_null(P1MatterSurfaceGrid.OVERLAY_NAME) == null, "retired dynamic provider does not retain a live presentation ghost")

	presenter.set_enabled(false)
	_check(presenter.get_overlay_count() == 0, "presentation can be disabled without changing live Space count")
	_check(active_spaces.size() == 2 and (p1.call("get_active_spaces") as Array[LocalMatterSpace]).size() == 2, "disabling presentation does not mutate Matter/Space authority")
	presenter.set_enabled(true)
	_check(presenter.get_overlay_count() == 2, "presentation can be rebuilt from current authority after re-enable")

	print(
		"P1_MATTER_SURFACE_GRID_METRIC clean_alpha=%.2f successors=%d overlays=%d shift=%s" % [
			P1MatterSurfaceGrid.LINE_ALPHA,
			active_spaces.size(),
			presenter.get_overlay_count(),
			str(shift),
		]
	)

	p1.free()
	_finish()


func _probe_deduplicated_geometry() -> void:
	var volume := CellVolume.new(Vector3i(2, 1, 1))
	volume.fill_box(Vector3i.ZERO, Vector3i(2, 1, 1), CellVolume.SOLID)
	var mesh := P1MatterSurfaceGrid.build_exposed_surface_grid(volume)
	_check(mesh != null and mesh.get_surface_count() == 1, "2x1x1 production grid builds one line surface")
	if mesh == null or mesh.get_surface_count() != 1:
		return
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var segment_count := vertices.size() / 2
	# Two adjacent cubes expose ten faces. Naive per-face edges produce 40 line
	# segments; four coplanar shared edges must collapse, leaving exactly 36.
	_check(segment_count == 36, "coplanar dedupe produces exactly 36 segments for a 2x1x1 Matter prism")


func _overlay_uses_promoted_material(overlay: MeshInstance3D) -> bool:
	if overlay == null or not (overlay.material_override is StandardMaterial3D):
		return false
	var material := overlay.material_override as StandardMaterial3D
	return (
		absf(material.albedo_color.a - P1MatterSurfaceGrid.LINE_ALPHA) < 0.00001
		and material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED
		and not material.no_depth_test
	)


func _advance_frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame
		await process_frame


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)


func _finish() -> void:
	if _failures.is_empty():
		print("P1_MATTER_SURFACE_GRID_PASS: promoted G3 surface granularity is deduplicated derived presentation and follows edit, rebase, provider replacement and topology succession without owning Matter authority.")
		quit(0)
		return
	for failure in _failures:
		push_error("P1_MATTER_SURFACE_GRID_FAIL: " + failure)
	quit(1)
