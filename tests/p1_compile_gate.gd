extends SceneTree

# This gate intentionally loads through the normal project resource cache.
# `class_name` dependencies are part of one Godot project graph; forcing every
# file through CACHE_MODE_IGNORE compiles them as artificial islands and is not
# representative of how the project resolves global script classes.

const SCENE_PATHS: PackedStringArray = [
	"res://p1/player.tscn",
	"res://p1/camera_rig.tscn",
	"res://p1/matter_interactor.tscn",
	"res://p1/main.tscn",
]

const SCRIPT_PATHS: PackedStringArray = [
	"res://matter/cell_volume.gd",
	"res://matter/matter_lineage_map.gd",
	"res://matter/matter_lineage_issuer.gd",
	"res://matter/matter_topology.gd",
	"res://matter/cell_collision_boxer.gd",
	"res://matter/cell_mesher.gd",
	"res://matter/matter_representation.gd",
	"res://construct/construct_body.gd",
	"res://space/local_matter_split_result.gd",
	"res://space/local_matter_space.gd",
	"res://actor/space_query_character.gd",
	"res://p1/camera_rig.gd",
	"res://p1/space_registry.gd",
	"res://p1/matter_interactor.gd",
	"res://p1/space_control.gd",
	"res://p1/main.gd",
	"res://tests/p1_volumetric_actor_challenger.gd",
	"res://tests/p1_scene_foundation_smoke.gd",
	"res://tests/p1_space_registry_probe.gd",
	"res://tests/p1_live_topology_consumer_probe.gd",
	"res://tests/p1_storage_rebase_probe.gd",
	"res://tests/p1_storage_actor_context_challenger.gd",
	"res://tests/p1_finite_space_control_probe.gd",
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	# Load composed scenes first. This exercises the same class/dependency graph
	# the Owner-facing project uses, rather than an isolated-script fiction.
	for path in SCENE_PATHS:
		var resource: Resource = ResourceLoader.load(path)
		if resource == null or not resource is PackedScene:
			_failures.append("scene failed to load: %s" % path)

	for path in SCRIPT_PATHS:
		var resource: Resource = ResourceLoader.load(path)
		if resource == null:
			_failures.append("script failed to load: %s" % path)
			continue
		if not resource is Script:
			_failures.append("expected Script resource: %s" % path)
			continue
		var script := resource as Script
		if not script.can_instantiate():
			_failures.append("script cannot instantiate after project compile: %s" % path)

	if _failures.is_empty():
		print("P1_COMPILE_GATE_PASS: P1 runtime, substrate, probes and composed scenes resolve through the real Godot project class graph.")
		quit(0)
		return

	for failure in _failures:
		push_error("P1_COMPILE_GATE_FAIL: " + failure)
	quit(1)
