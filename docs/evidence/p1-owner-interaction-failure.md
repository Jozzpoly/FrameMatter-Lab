# P1 Owner interaction — visual/readability failure

Status: **OWNER-FACING FAIL / MECHANICAL EVIDENCE RETAINED**

This record supersedes the assumption that the first P1 Owner candidate was an adequate visual/interaction measurement surface.

The P1 mechanical/integration evidence remains useful. The Owner-facing acceptance target did not pass.

## Trigger

The first direct Owner recording of the packaged P1 candidate is about 35.8 seconds. It shows a mechanically richer runtime presented through a severely inadequate visual layer.

This is not being classified as “rough but acceptable prototype art”. The presentation materially prevents the Owner from reading the Matter geometry, edit state, motion and spatial relationships that the experiment is supposed to expose.

## Recording findings

Across the recording:

- the dominant horizontal Matter surface is frequently rendered near-black,
- several vertical faces approach flat white, producing extreme black/white separation instead of readable volume,
- cell structure is mostly absent from the surface language,
- the target outline reads as debug wire geometry and can be visible through geometry,
- the camera repeatedly reaches framings where the actor or nearby Matter dominates the screen and experiment context is weak,
- the ground/background provide weak scale and motion reference,
- STATIC/DYNAMIC visual identity is weak,
- the default HUD remains telemetry-like rather than a minimal manipulation interface.

Representative visual failures are visible throughout the run, including the opening view, the close camera states around the early/middle edits, and the final close framing.

## Confirmed code regressions / defects

### V1 — ambient-light source is configured inconsistently

`p1/main.tscn` uses a color background but sets `ambient_light_source = 3`.

In Godot 4, ambient source 3 is **SKY**; COLOR is 2. P1 does not define a Sky resource. P0.5 explicitly used `Environment.AMBIENT_SOURCE_COLOR`.

This is a concrete P1 rendering configuration defect and is directly consistent with the recording: faces not reached by the single directional key light can become extremely dark while directly lit faces become very bright.

The exact visual delta still requires an A/B rendered capture after correction; do not treat the diagnosis as a substitute for that capture.

### V2 — P1 removed P0.5 cell-grid readability

P0.5 generated a subdued per-cell edge grid over occupied Matter. P1 removed that presentation cue without replacing it with another cell-scale visual language.

The result is a large procedural mesh whose broad coplanar regions read as undifferentiated sheets.

### V3 — static/dynamic material distinction regressed

P0.5 deliberately used materially different static and dynamic Matter colors. P1 fell back to the small default difference between `MatterRepresentation` and `ConstructBody` materials.

State change is therefore mechanically meaningful but visually weak.

### V4 — target outline is explicitly a debug-through-wall overlay

`P1MatterInteractor._make_line_material()` sets `no_depth_test = true`.

This guarantees the outline can draw through occluding geometry. That is useful for engineering debug overlays but poor default Owner interaction language.

### V5 — camera contract remains insufficiently visual

P1 replaced the hand-built P0.5 camera with SpringArm and context tracking, which is a real mechanical improvement. However its acceptance gates only assert node composition/context relations, not useful rendered framing.

The camera allows a 3 m minimum distance and can still produce extremely close, visually destructive views. The context blend is driven primarily by actor↔Space-center separation, so standing on the Space often remains predominantly actor-centric.

### V6 — no visual regression gate exists

P1 created strong compile, physics, lifecycle, storage and topology gates but no rendered-frame evidence gate.

A one-line class of lighting configuration error and several obvious presentation regressions could therefore survive 95 branch commits and a fully green delivery pipeline.

This is a process failure, not just a material bug.

## Historical contradiction

The P1 professional rebuild audit defined the acceptance question as:

> does Godot + FrameMatter now provide a coherent, physically legible sandbox loop whose remaining failures point at real substrate questions rather than prototype neglect?

The final P1 evidence record later treated production UI/visuals as an explicit nonclaim and allowed packaging after only mechanical/structural gates.

That narrowed the acceptance bar during execution. It was not faithful to the campaign trigger or Owner intent.

## Current interpretation of Godot

This recording is **not evidence that Godot is unsuitable**.

The most severe visible defect already has a concrete project-side configuration cause, and multiple other failures are direct choices in FrameMatter's presentation code.

Godot viability must be judged only after a dedicated presentation/readability campaign uses the engine's rendering, material, environment, camera and editor-visible tooling competently and produces rendered evidence.

## Decision

P1 is reopened at the Owner-facing layer.

- Retain the mechanical/integration evidence.
- Do not merge the P1 branch to `main` yet.
- Do not issue another Owner candidate from incremental mechanical work.
- Freeze new substrate/feature expansion unless a visual-recovery finding requires it.
- Run a dedicated Owner-facing recovery campaign with rendered-frame gates before another package is offered.

The previous candidate remains historical evidence of a mechanically coherent but visually failed measurement surface.