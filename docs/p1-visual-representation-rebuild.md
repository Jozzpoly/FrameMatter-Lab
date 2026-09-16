# P1 visual representation architecture rebuild

Status: **ACTIVE / R-V0 FORENSIC ISOLATION**

Owner-failed baseline: `b5050b669ec4101226095183929f5790f0a034fc`

Primary evidence: `docs/evidence/p1-owner-test-visual-failure-and-rebuild.md`

Active acceptance contract: `quality/contracts/p1-owner-facing-recovery.v4.json`

## Why this is a rebuild, not polish

The delivered P1 candidate proved that a mechanically sophisticated runtime and a carefully gated sequence of local presentation improvements can still produce a globally weak or misleading image.

The immediate target is therefore not prettier color, texture or post-processing. It is to rebuild the representation stack so that **physical Matter form is visually truthful before any semantic overlay is allowed to help it**.

## Protected substrate

Do not casually rewrite these to solve a presentation problem:

- logical Matter authority,
- logical Space identity,
- provider replacement semantics,
- storage-frame maintenance,
- topology succession,
- finite solver-owned Space motion,
- volumetric actor movement authority,
- exact merged-cuboid collision,
- strict zero-engine-error floor.

## Explicitly replaceable presentation

No protection is granted merely because these previously earned bounded PASS:

- `CellMesher` as a visual renderer,
- static/dynamic provider-owned material duplication,
- permanent surface grid,
- permanent state contour,
- focus crown,
- current target geometry,
- current lighting parameters,
- current camera presentation policy,
- world-datum styling.

Historical evidence remains useful; implementation is replaceable when stronger evidence falsifies the composed result.

## Core visual invariant

> With all semantic overlays disabled, base Matter must immediately read as solid, opaque, coherent 3D mass across clean and accumulated irregular geometry.

If this invariant fails, later cell/state/interaction styling cannot compensate for it.

---

# R-V0 — base-surface forensic isolation

**Current active tranche. No canonical visual change yet.**

Question:

> Is the hollow/transparent Owner-visible failure primarily caused by base triangle winding/culling, or does it survive a winding-correct base surface?

Exact A/B/C variants on the same source/runtime state:

1. `current` — existing mesh + ordinary back-face culling,
2. `cull_front` — existing geometry, only cull direction reversed,
3. `corrected_winding` — reversed triangle order + normal back-face culling.

Semantic overlays are disabled. HUD/player visual are hidden. The corpus includes clean canonical Matter and a deterministic accumulated irregular edit state.

### R-V0 promotion logic

#### Case A — `cull_front` and `corrected_winding` both materially restore solid near surfaces

Interpretation: winding/culling hypothesis strongly confirmed.

Next:

- implement corrected winding only,
- keep normal back-face culling,
- rerun full mechanical suite,
- expand base-surface corpus,
- then isolate shadows before any larger presentation work.

`CULL_FRONT` is diagnostic only and cannot become the canonical fix because it would encode a known geometry error into material state.

#### Case B — only one challenger improves

Interpretation: hypothesis incomplete or harness interaction exists.

Next:

- inspect normals/winding/material state directly,
- do not promote,
- add a primitive reference mesh in the same scene before changing runtime.

#### Case C — neither materially improves

Interpretation: winding is not the dominant Owner-visible root cause.

Next:

- keep canonical runtime unchanged,
- move directly to R-V0b shadow/depth isolation.

---

# R-V0b — shadow / depth isolation

Run only if R-V0 leaves unexplained diagonal breakup or false transparency.

Matrix, still on base Matter only:

- canonical shadows ON,
- Matter cast shadows OFF,
- primary directional shadows OFF,
- shadow normal-bias/bias challenger only if the artifact is shadow-specific,
- primitive `BoxMesh` reference under the same light/material environment.

Question:

> Are remaining diagonal regions legal cast shadows, self-shadow artifacts, or a non-shadow geometry/depth problem?

Do not tune a bias merely because one screenshot becomes prettier. The chosen setting must survive multiple angles and irregular geometry without visibly detaching legitimate contact shadows.

---

# R-V1 — canonical base-form correction

Starts only after R-V0/R-V0b identify a demonstrated correction.

Goals:

- promote the smallest proven base-surface fix,
- re-run hidden/mechanical invariants,
- prove static and dynamic providers render the **same Matter identity**,
- remove accidental material differences caused solely by provider kind,
- establish one shared visual configuration/source of truth for Matter surface appearance.

Likely architectural pressure:

> physics provider owns transform/body semantics; Matter surface renderer owns visual surface semantics.

Do not force this refactor if the forensic fix is smaller and there is no current pressure. But do not preserve duplicate static/dynamic material setup as a design virtue.

---

# R-V2 — macro-surface representation challenger

Only after the base surface is correct.

Question:

> Should the renderer continue tessellating at logical cell frequency, or should coplanar exposed Matter be represented as larger macro surfaces?

Compare at minimum:

1. corrected per-cell exposed-face meshing,
2. greedy / merged coplanar surface meshing.

Evaluate:

- clean slab/wall,
- holes/concavity,
- stairs/protrusions,
- chaotic accumulated edit corpus,
- rebuild cost,
- edit correctness,
- shading/shadow seams,
- ability to layer contextual one-cell information independently.

Greedy meshing is not automatically promoted because it is faster or prettier. It must preserve exact exposed geometry and remain an implementation detail below Matter authority.

---

# R-V3 — presentation architecture / perceptual budget

Starts from the best proven base form with **all old semantic overlays OFF**.

Reintroduce information only when it proves net value to the composed image.

Priority hierarchy:

1. physical mass/form,
2. surface / local structure,
3. system state,
4. interaction intent,
5. transient event feedback,
6. optional instrumentation/debug.

## Default policy hypothesis

### Cell structure

Prefer contextual / distance-dependent visibility:

- far: no one-cell grid,
- mid: minimal structure only if needed,
- near: restrained cell boundaries,
- active target neighborhood: explicit local cell structure.

### System state

Prefer event/context semantics over permanent full-object line shells:

- state change pulse/accent,
- temporary successor differentiation after split,
- compact HUD confirmation,
- persistent world geometry only if it demonstrates unique value.

### Interaction

Move from debug-volume language toward surface-local action language:

- exact face/cell remains authoritative,
- operation preview stays local,
- success/rejection is brief,
- the player and semantic overlays must not obscure the active surface.

## Composer pressure

If independent presenters continue to overdraw each other, introduce one presentation-policy/composer layer that controls **when** each consumer may be visible. It must not become gameplay authority.

---

# R-V4 — camera / visual safety rebuild

Owner recording proves the current camera can collapse into the avatar.

Add explicit visual invariants beyond desired SpringArm distance:

- measure actual final camera-to-avatar distance,
- never allow an inside-avatar frame as the normal obstruction solution,
- when no third-person orbit can satisfy clearance, use a defined fallback such as avatar fade / alternate presentation,
- add active interaction point as a presentation-only composition hint,
- keep user movement control frame independent of automatic presentation recovery.

Evidence must include real Matter obstruction plus freeform edit geometry, not only authored walls.

---

# R-V5 — accumulated chaotic Owner-surface rehearsal

This gate exists specifically because the old G8 did not accumulate geometry entropy.

Minimum session:

- 30–60 seconds equivalent deterministic edit accumulation,
- at least 20 non-restored edits,
- holes + concavities + protrusions + stairs / narrow features,
- near and mid camera work,
- REMOVE and PLACE,
- at least one state/motion transition after the geometry is already ugly,
- continuous video plus representative frames.

Acceptance is deliberately gestalt-heavy:

- Matter still reads as solid rather than hollow/wireframe,
- no unexplained diagonal surface breakup,
- camera never enters the avatar or loses the useful interaction surface for a sustained interval,
- semantic presentation becomes **more selective**, not denser, as geometry becomes complex,
- the final scene remains understandable without knowing the scripted test.

This rehearsal cannot restore removed cells immediately merely to keep the authored shape tidy.

---

# Re-promotion sequence

A future Owner candidate requires:

1. R-V0/R-V0b root-cause evidence,
2. corrected base-surface gate PASS,
3. full presentation stack re-earned against contract v4,
4. camera visual-safety PASS,
5. chaotic-edit scenario PASS,
6. candidate freeze on one exact runtime,
7. exact-candidate reruns,
8. new independent assurance against contract v4,
9. new final readiness audit,
10. only then Owner delivery.

The previous `b5050b669...` package must remain available as a negative comparison baseline; it must not silently become the new implementation branch point by virtue of having once been frozen.

## Current next move

Wait for R-V0 rendered matrix on the live OPEN branch. Inspect the raw pixels before changing `CellMesher` canonically.

No further styling work is justified until that matrix is understood.