# P1 Owner-facing recovery campaign

Status: **PLANNED / P1 REOPENED**

This campaign exists because the first P1 Owner candidate passed mechanical/integration gates but failed the actual Owner-facing acceptance target: a coherent, physically legible sandbox loop.

The goal is not to add “graphics polish” after the real work. The presentation layer is part of the research instrument. If Matter shape, cell structure, edit intent, motion, topology and actor↔Space relationships are not readable, the LAB cannot provide trustworthy Owner evidence.

## Core correction

P1 previously optimized for hidden correctness and treated rendered quality as a secondary nonclaim. That is rejected.

The new rule is:

> a candidate is not Owner-ready unless mechanical truth and visual truth are both defended.

The campaign preserves mechanically defended substrate semantics but is free to replace the current renderer/material/camera/UI presentation aggressively.

## Frozen evidence, not frozen implementation

Preserve these currently defended semantics unless new evidence falsifies them:

- logical Matter authority is independent of render/collision representation,
- logical Space identity is independent of provider identity,
- static↔dynamic provider replacement,
- volumetric query actor without accidental infinite-force rigid-body push,
- multi-Space succession after topology split,
- storage-frame rebase with actor/camera coordinate maintenance,
- finite impulse/torque Space control,
- exact merged-cuboid collision as current default,
- strict zero-engine-error evidence floor.

Do **not** protect the current P1 Environment, materials, generated mesh appearance, camera policy, HUD, target outline or scene composition merely because they already exist.

## Definition of done for the next Owner candidate

The next candidate must be mechanically green **and** pass a rendered preflight in which an informed reviewer can determine, from frames/video without reading debug text:

- the shape and depth of Matter at a glance,
- individual cell scale or editing granularity,
- which cell/face is currently targeted and what operation will happen,
- whether the active Space is static or dynamic,
- actor position relative to the active Space and reference world,
- whether the Space is translating/rotating,
- when destructive editing creates independent successor Spaces,
- whether the camera still preserves useful experiment context during movement, editing, falls and close obstacles.

No dominant Matter surface may collapse into featureless black/white under ordinary authored camera angles. The default screen must not look like an engineering telemetry/debug view.

This is still a research LAB, not final game art. “Professional and legible” is required; final art direction is not.

## Campaign sequence

### G0 — freeze and baseline the failed candidate

- Keep current P1 mechanical candidate and its hashes as historical evidence.
- Add the Owner-failure evidence record.
- Stop new substrate/features while visual recovery is active.
- Preserve a deterministic set of representative P1 states: initial static, edit target, dynamic moving, storage expansion, post-split successors, freeze, camera-near-obstacle.

### G1 — rendered evidence harness before redesign

Create a real rendering capture path. Mechanical headless gates are insufficient.

The harness should produce deterministic screenshots (and when useful a short camera sequence) from representative P1 states using an actual renderer, not the headless dummy backend. Candidate approaches include a Linux/Xvfb + Mesa rendered capture or a Windows rendered capture; choose the smallest reliable mechanism and prove that it captures the same scene/material path as the Owner executable.

Every subsequent visual change must produce before/after artifacts.

Add simple image diagnostics only as guardrails, not as a substitute for human review: luminance range, fraction of near-black Matter pixels, silhouette/edge contrast and camera framing bounds where practical.

### G2 — lighting/environment truth

First repair the renderer before designing around its broken output.

- Correct the ambient source mismatch and prove the result with A/B frames.
- Establish a deliberate key/fill/ambient hierarchy that keeps all six Matter face orientations readable.
- Audit tone mapping/exposure, shadow strength and background/ground separation.
- Prefer robust StandardMaterial3D/Environment features before custom shaders.
- Verify the same visual intent on Windows Owner export; Web may degrade gracefully but does not set the Windows quality ceiling.

Gate: a plain grey test volume and the authored P1 Matter must remain readable from all representative camera azimuths without black-face or clipped-white collapse.

### G3 — Matter visual language

Restore and improve cell-scale readability without coupling presentation to logical identity or collider partition.

Challenge at least two bounded approaches before choosing one, for example:

- a restrained cell-edge/grid overlay derived from Matter,
- procedural/local-coordinate material treatment, vertex colors or simple face/cell modulation,
- subtle contact/edge darkening or AO where renderer support is reliable.

The chosen mechanism must preserve broad shape readability at distance while exposing edit granularity up close. Avoid turning every block into noisy outlined cubes.

Static/dynamic/focused/successor states need a coherent visual language with meaningful but non-garish differences.

Gate: without HUD text, a reviewer can see the Matter form, cell scale and state changes in deterministic captures.

### G4 — camera as an experiment instrument

Replace the current “SpringArm exists, therefore camera passes” contract with a framing contract.

- Camera must preserve actor + active Space + useful world reference by default.
- Minimum/maximum distance should account for active Space bounds, not only a fixed 3–13 m range.
- Context weighting should not vanish merely because the actor is standing near the Space center.
- Close obstacle handling must avoid giant actor/body frames and geometry-dominated black screens.
- Add smooth recovery/recentering behavior after falls, topology split and provider replacement.
- Camera collision is necessary but not sufficient; composition is the acceptance target.

Gate: scripted stress sequence never loses the experiment or produces a useless close-up for more than a brief transition.

### G5 — interaction visual hierarchy

Rebuild edit feedback as a tool, not debug drawing.

- Remove `no_depth_test` from the default target cue unless a deliberate secondary x-ray mode is explicitly requested.
- Prefer a surface/face cue plus restrained cell boundary over a full through-wall wire cube.
- REMOVE, PLACE and EXPAND need distinct but related language.
- Show action consequence briefly after click so the causal chain is readable.
- Default reticle/UI should be small and quiet; deep telemetry remains optional.

Gate: before clicking, the next operation and exact target are unambiguous in representative frames.

### G6 — world/motion/topology causality

The reference world must help explain motion.

- Add non-distracting scale/motion cues to the ground/reference environment.
- Make static→dynamic release visually legible without relying on text.
- Finite impulse/rotation should be perceivable relative to the world.
- Split successors must read as independent Spaces after destructive separation.
- Freeze should read as the current moving state becoming static at its present pose, not as a visual reset.

Do not fake physics with presentation; present the real state more clearly.

### G7 — renderer and host viability checkpoint

Only after G2–G6 should Godot itself be judged.

If a deliberately simple P1 scene still cannot reach a professional readable baseline using ordinary Godot 4.7 rendering/material/camera facilities, build a tiny equivalent reference scene in the strongest familiar web stack and compare the same authored geometry/camera target.

Host-switch discussion is triggered by evidence, not frustration:

- Godot presentation requires disproportionate custom work for the same baseline, or
- renderer/tooling limitations materially block the intended visual/interaction loop, or
- repeated host-specific defects survive correct usage and bounded reproduction.

The current black-face P1 recording does not meet that threshold because a concrete project-side ambient configuration defect and multiple presentation regressions are already identified.

### G8 — adversarial preflight and Owner package

Before another Owner executable is offered:

- run the complete mechanical P1 suite,
- run deterministic rendered captures for every representative state,
- review the captures side-by-side against the failed P1 candidate,
- record remaining visual defects explicitly,
- run a short autonomous interaction rehearsal that includes close camera, repeated edits, dynamic motion, storage expansion, split and freeze,
- inspect that recording frame-by-frame,
- package only if the result is clearly more readable and coherent than both P0.5 and failed P1.

The final gate is not “no known bug”. It is:

> would this build honestly demonstrate the system we claim to be researching, rather than force the Owner to mentally reconstruct it from debug geometry?

## Process corrections

- Visual/presentation defects are first-class research failures when they contaminate Owner evidence.
- No future campaign may move an original acceptance property into “nonclaims” merely because it lacks an automated test.
- Every Owner-facing campaign needs at least one evidence path for what the Owner actually sees.
- A green CI suite can establish hidden invariants; it cannot certify interaction/readability by itself.
- The next Owner package is a scarce attention event. It must earn that event through internal rendered preflight.

## Current stop condition

Do not merge P1 to `main` and do not send another Owner candidate until G8 passes.

Next execution move: implement G1 first, capture the failed P1 baseline through the new rendered-evidence path, then fix G2 and prove the lighting delta before any broader aesthetic work.