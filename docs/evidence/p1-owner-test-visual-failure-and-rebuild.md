# P1 Owner test visual failure and representation rebuild findings

Status: **MATERIAL OWNER-VISIBLE FAILURE / REBUILD INPUT**

Owner-tested runtime: `b5050b669ec4101226095183929f5790f0a034fc`

This record is written after the delivered P1 Owner Candidate passed its contracted internal readiness process and was then directly falsified by the Owner during ordinary desktop interaction.

The failure does **not** invalidate the defended hidden/mechanical substrate. It invalidates the stronger claim that the current rendered/presentation stack is a sufficiently professional and physically legible Owner-facing research surface.

## Owner verdict

The Owner's direct judgment after the first freeform run was approximately:

- graphics still materially poor,
- renderer/Matter presentation appears bugged,
- blocks read as transparent/hollow,
- the result is only minimally better than the earlier failed prototype,
- this is approximately the quality level the **first** prototype should have reached, not the endpoint of the recovery campaign.

A roughly 47-second Owner recording was then reviewed frame-by-frame. Representative moments included approximately `0 s`, `14 s`, `16 s`, `23 s`, `36 s`, `37 s` and `45 s`.

## Direct Owner-visible findings

### O1 — Matter does not reliably read as solid opaque mass — **P0 VISUAL FAILURE**

Under accumulated freeform editing, Matter increasingly reads as a hollow/transparent technical shell rather than solid physical material. Large diagonal triangular regions and apparently visible far-side/internal structure appear in ordinary gameplay views.

This is not acceptable as a mere art-direction rough edge. It corrupts the first visual question of the experiment: **what physical Matter exists here?**

### O2 — visual complexity degrades faster than physical complexity

Simple authored geometry is somewhat readable. More irregular geometry produced by ordinary editing becomes materially harder to parse: concavities, holes, small protrusions and accumulated surface edges create a technical mesh/wire-shell appearance.

The current presentation therefore does not scale perceptually with edit history / geometry entropy.

### O3 — camera can enter the visible player body — **MATERIAL COMPOSITION FAILURE**

The Owner recording contains a short but clear frame where the camera is compressed into the blue capsule and the player body dominates almost the entire view.

The current camera rig has obstruction probing and SpringArm collision, but no hard presentation invariant on the **actual final camera-to-avatar visual distance** and no fallback such as avatar fading when geometry leaves no usable third-person camera position.

### O4 — interaction truth is better, but still reads as instrumentation

Pointer acquisition, depth-tested targeting and causal REMOVE/PLACE feedback are materially better than the old through-wall debug cube. However, red/green/cyan line geometry plus labels still reads primarily as a research gizmo rather than a surface action on physical Matter. The player body can also occlude the useful local edit region even while ray authority remains technically correct.

### O5 — UI is no longer the primary problem

The compact HUD is acceptable for the present research stage. Further HUD polish is not a near-term priority relative to Matter form, camera and interaction composition.

## Repository facts that constrain the diagnosis

### F1 — base Matter materials are opaque

`MatterRepresentation` and `ConstructBody` both use ordinary `StandardMaterial3D` base materials without enabling transparency. The transparent/hollow appearance therefore cannot be explained by an intentional alpha value on the base material.

The two providers currently also duplicate visual material setup and are not identical: static and dynamic providers use slightly different base color/roughness values. This is architecture debt because physical provider kind should not implicitly redefine Matter substance.

### F2 — `CellMesher` is a deliberately simple cell-face renderer

`CellMesher.build_mesh()` emits every exposed cell face independently as two triangles. A large planar wall is therefore tessellated at logical cell frequency even when the macro surface is planar.

Historical R0 evidence explicitly described this as a deliberately simple reference representation and measured it without optimizing it. It was never defended as the final visual surface renderer.

### F3 — logical cell frequency leaks directly into base render geometry

Although Matter authority is conceptually separate from representation, the current base renderer still mirrors the logical grid directly. Collision moved to an aggregated representation (`MERGED_CUBOIDS`), while the visual surface remained a per-exposed-cell renderer.

This coupling should be reconsidered independently of the immediate bug.

### F4 — presentation is implemented as multiple independent line/alpha shells

The current always-on / often-on presentation stack includes:

- exposed cell surface grid,
- STATIC/DYNAMIC state contour,
- focus crown,
- REMOVE/PLACE/EXPAND target geometry,
- world reference grid.

Surface-grid, state and target systems use transparent, unshaded line geometry offset slightly from the physical surface to avoid z-fighting. These channels are semantically separate in code but perceptually reuse the same visual medium: **lines floating above Matter**.

### F5 — line density grows with geometry entropy

The state-contour algorithm emits perimeter-like edges around exposed topology. Additional holes, concavities, steps and protrusions create more unique boundary edges. Thus ordinary destructive editing can increase permanent visual line density faster than it increases useful semantic information.

This is the opposite of the desired behavior: increasingly complex physical Matter should trigger **more selective representation**, not automatically more persistent semantic ink.

### F6 — camera collision and avatar visibility are separate systems

The player is visually represented by a capsule mesh, while movement uses explicit volumetric queries. The SpringArm reasons about world/Matter collision, not about the visible player mesh as an obstacle. Therefore a heavily compressed arm can legally place the camera inside the rendered avatar unless a separate visual-safety policy prevents it.

### F7 — G8 was adversarial for lifecycle, not for accumulated geometry entropy

The G8 rehearsal stressed many real transitions in one live runtime, but its rapid-edit burst removed three known cells and immediately restored them. The later topology cut was also deliberately structured. It did not accumulate irregular freeform geometry comparable to the Owner's ordinary edit behavior.

The previous quality postmortem already identified the absence of an ugly/chaotic Owner-like rehearsal as a process risk. G8 improved lifecycle adversity but did not fully close that visual-entropy gap.

## Strong hypotheses — NOT yet promoted to facts

### H1 — `CellMesher` triangle winding may be reversed for Godot front-face convention

All current `FACE_VERTICES` triangles have geometric cross-product direction aligned with the declared outward normal. Godot's documented procedural-mesh front-face convention must be challenged directly against this ordering.

If current winding is reversed relative to Godot's default back-face culling, the nearest exterior faces could be culled while farther/opposite faces remain visible, producing an image that appears transparent despite an opaque material. This hypothesis fits the Owner recording unusually well, especially when combined with independently generated front-surface line overlays.

**This is currently a high-priority hypothesis, not an accepted root cause.** It requires rendered A/B falsification.

### H2 — cast shadows / self-shadowing may contribute additional triangular artifacts

The primary directional light casts shadows across a highly tessellated per-cell surface. Shadow bias, normal bias and legal cast-shadow patterns may add or amplify diagonal triangular visual regions. This must be isolated after or alongside winding tests rather than assumed.

### H3 — greedy / merged surface meshing may be a better long-term base renderer

Even after any winding defect is fixed, macro surfaces may benefit from a representation that merges coplanar exposed faces independently of logical cell storage. This would better enforce the architectural rule that logical Matter is authority while render geometry is derived representation.

This is a later challenger, not the first corrective commit.

### H4 — bevel / face-orientation cues may replace much of the permanent grid requirement

A stronger physical-form renderer could communicate edges, top/side orientation and material solidity directly through geometry/material/light. The current permanent one-cell grid may then be reduced to a local contextual editing cue instead of an always-on visual crutch.

## Process finding

The previous recovery campaign improved evidence quality substantially, but still optimized many **bounded local presentation questions** independently.

A presentation can be:

- locally clearer than its predecessor,
- correctly depth-tested,
- semantically separated in code,
- individually supported by A/B screenshots,

and still combine into a globally poor image.

The key process correction is therefore:

> **Semantic orthogonality in code does not guarantee perceptual orthogonality on screen.**

Likewise:

> **A scripted adversarial sequence can become so controlled that it stops representing the visual entropy of free Owner interaction.**

## Representation rebuild principle

The next visual architecture should enforce this hierarchy:

1. **physical mass/form** — always present and sufficient by itself,
2. **surface / local structure** — contextual and distance/interaction dependent,
3. **system state** — restrained and often temporal rather than permanent geometry,
4. **interaction intent** — local to the active surface/cell,
5. **event feedback** — brief and causal,
6. **instrumentation/debug** — optional, rich when explicitly requested.

A hard invariant for the next candidate:

> **With all semantic overlays disabled, base Matter must still read immediately as solid, opaque, coherent three-dimensional mass across clean and chaotic edited geometry.**

## Required immediate experiment — R-V0 visual truth isolation

Before art-direction work, greedy meshing, bevels or further semantic styling, run a bounded rendered falsification matrix on identical deterministic geometry:

### Geometry corpus

At minimum:

- clean authored P1 geometry,
- long planar wall/slab,
- concave L/stair state,
- perforated / hole-heavy state,
- deliberately irregular accumulated edit state.

### Base-render variants

1. current frozen behavior,
2. current geometry with culling reversed only,
3. corrected triangle winding with normal back-face culling.

### Lighting isolation

For the useful variants above:

- shadows OFF,
- canonical shadows ON,
- bias/normal-bias challenger only if shadow-specific artifacts remain.

### Presentation isolation

First capture **base Matter only**. Then restore, one at a time:

- cell structure cue,
- state cue,
- target cue.

### Initial acceptance

The winning base variant must:

- show the nearest exterior face rather than a hollow/far shell,
- remain fully opaque under irregular geometry,
- show no unexplained diagonal surface breakup,
- preserve correct outward lighting response,
- remain readable without cell/state overlays,
- keep existing Matter/logical/collision semantics unchanged.

## Work-order conclusion

Do **not** begin with color polish, SSAO, textures, bloom, more HUD work, or large art-direction changes.

The rational execution order is:

1. reopen Owner readiness after the direct visual failure,
2. preserve `b5050b669...` as immutable failed Owner baseline,
3. run R-V0 winding/culling/shadow forensic A/B,
4. promote only the smallest demonstrated base-surface correction,
5. reassess the full presentation stack against chaotic geometry,
6. only then decide whether to pursue greedy surface meshing / unified Matter renderer,
7. rebuild cell/state/interaction presentation around a perceptual budget,
8. add hard camera visual-safety and interaction-composition policy,
9. finish with a genuinely accumulated 30–60 second ugly Owner-edit rehearsal before another package.

The next phase is therefore not "visual polish".

It is a **P1 visual representation architecture rebuild** grounded first in rendered falsification of the base surface.