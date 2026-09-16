# P1 visual representation architecture rebuild

Status: **ACTIVE / R-V4 CAMERA VISUAL SAFETY NEXT**

Owner-failed baseline: `b5050b669ec4101226095183929f5790f0a034fc`

Primary failure record: `docs/evidence/p1-owner-test-visual-failure-and-rebuild.md`

Active acceptance contract: `quality/contracts/p1-owner-facing-recovery.v4.json`

Latest closed presentation tranche: `docs/evidence/p1-rv3-state-presentation-policy.md`

## Live truth

The visual rebuild is no longer at initial forensic isolation.

Defended results now include:

- **R-V0 PASS** — the dominant hollow/transparent Matter failure was incorrect procedural triangle front-face ordering; corrected winding is canonical and engine-native orientation is regression-tested.
- **R-V1 PASS** — STATIC/DYNAMIC providers share one neutral Matter surface identity instead of changing base material merely because the physics host changes.
- **R-V2 DEFERRED** — greedy/macro-surface meshing remains a valid future challenger, but corrected per-cell Matter is visually coherent and there is no current evidence pressure strong enough to displace higher-value visual risks.
- **R-V3 PASS** — persistent state presentation was reduced from a full exposed-surface contour to selective side-surface boundaries; focus remains a separate top crown. The promoted policy preserves shallow-angle STATIC/DYNAMIC readability while cutting state-line geometry by about 44% in the representative corpus.
- **R-V4 ACTIVE NEXT** — camera/avatar visual safety is the next demonstrated risk.
- **R-V5 PENDING** — accumulated chaotic Owner-surface rehearsal still has to prove the composed result under sustained geometry entropy.

This document is current synthesis. Historical evidence remains in `docs/evidence/` and should not be rewritten to match newer architecture.

## Why this is a rebuild, not polish

The delivered P1 candidate proved that a mechanically sophisticated runtime and a carefully gated sequence of local presentation improvements can still produce a globally weak or misleading image.

The target is not prettier color, texture or post-processing. It is to make the runtime a trustworthy visual research instrument:

> physical Matter form must be visually truthful before semantic overlays are allowed to help it, and every persistent presentation layer must justify its perceptual cost.

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

No presentation mechanism is protected merely because an earlier campaign gave it a bounded PASS:

- `CellMesher` as a visual renderer beyond its defended winding invariant,
- surface-grid visibility policy,
- state cue geometry,
- focus cue geometry,
- target geometry,
- interaction feedback styling,
- lighting parameters,
- camera presentation policy,
- world-datum styling.

Historical evidence is evidence, not a demand to preserve implementation.

## Core visual invariant

> With semantic overlays disabled, base Matter must immediately read as solid, opaque, coherent 3D mass across clean and accumulated irregular geometry.

R-V0 currently defends this invariant for its bounded corpus. Later chaotic rehearsal can reopen it if new evidence appears.

---

# R-V0 — base-surface forensic isolation

Status: **PASS / CLOSED**

Evidence: `docs/evidence/p1-rv0-base-surface-forensics.md`

The Owner-visible hollow/transparent failure was traced to wrong procedural triangle front-face ordering in `CellMesher`. The minimal canonical correction reverses triangle emission while retaining authored outward normals and ordinary back-face culling.

The correction restored solid near surfaces without changing material alpha, lighting or shadow policy, and now matches Godot's built-in primitive front-face orientation convention.

R-V0b shadow tuning was therefore not justified as the primary fix.

---

# R-V1 — canonical base-form / provider surface identity

Status: **PASS / CLOSED FOR CURRENT SCOPE**

Evidence:

- `docs/evidence/p1-rv1-presentation-stack-forensics.md`
- `docs/evidence/p1-rv1-provider-surface-identity.md`

The corrected base surface remains coherent under deterministic irregular geometry. STATIC and DYNAMIC providers now derive the same neutral Matter surface style from shared visual configuration rather than encoding provider kind into base material identity.

Current invariant:

> physics provider owns body/transform semantics; logical Matter keeps its visual material identity across provider replacement.

This is not final authored-material architecture or final art direction.

---

# R-V2 — macro-surface representation challenger

Status: **DEFERRED / NOT REJECTED**

Question:

> Should the renderer continue tessellating at logical cell frequency, or should coplanar exposed Matter be represented as larger macro surfaces?

A future comparison should still consider:

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

Why deferred now:

- corrected per-cell geometry reads as solid in the current corpus,
- R-V1 did not expose macro-surface representation as the dominant visual defect,
- camera safety and accumulated-session composition have stronger direct Owner evidence behind them,
- greedy meshing should not be promoted merely because it sounds architecturally cleaner or could be faster.

Reopen R-V2 when measured rebuild/shading/representation pressure justifies it.

---

# R-V3 — presentation architecture / perceptual budget

Status: **PASS / SELECTIVE STATE POLICY PROMOTED**

Evidence: `docs/evidence/p1-rv3-state-presentation-policy.md`

## Hierarchy

Presentation continues to follow this priority order:

1. physical mass/form,
2. surface / local structure,
3. system state,
4. interaction intent,
5. transient event feedback,
6. optional instrumentation/debug.

## Cell structure

The current grid remains viable as one-cell scale information, but its permanent/contextual distance policy is still open. Do not infer from viability that it must be visible everywhere forever.

Preferred direction remains:

- far: no one-cell grid unless evidence shows unique value,
- mid: minimal structure,
- near: restrained cell boundaries when useful,
- active target neighborhood: explicit local cell structure.

This should be decided from composed interaction/chaos evidence, not from isolated style preference.

## System state — promoted current policy

A strict Windows Forward+ / D3D12 comparison tested:

- historical full exposed-surface contour,
- top-only state crown,
- selective side-surface state rim with separate top focus crown.

Findings:

- full contour is directionally robust but unnecessarily dense,
- top-only state loses too much signal at shallow angles and competes with focus for the same top-surface channel,
- side-rim preserves mixed STATIC/DYNAMIC readability while removing roughly 44% of state-line geometry in the representative single/split Space states.

Current bounded policy:

> **physical state lives on exposed side boundaries; focus lives on the top perimeter.**

STATIC/DYNAMIC colors and presentation lifecycle remain derived consumer semantics, not Matter/Space authority.

The old full-contour builder remains only as diagnostic/reference geometry.

## Interaction

G5's surface-local action language remains the current interaction baseline:

- exact face/cell stays authoritative,
- target prediction stays local and depth-tested,
- REMOVE / PLACE / EXPAND remain visually distinct but related,
- success/rejection feedback is causal and temporary,
- interaction presentation must not become another dense shell around Matter.

R-V3 does not freeze this styling permanently; R-V5 can still falsify it under accumulated geometry entropy.

## Composer pressure

A centralized presentation-policy/composer layer is still only conditional architecture pressure.

Introduce it only if independent presenters demonstrably overdraw or conflict in composed evidence. Do not create a new gameplay authority merely to coordinate visibility.

---

# R-V4 — camera / visual safety rebuild

Status: **ACTIVE NEXT**

Owner recording demonstrated that the current camera can collapse into/through the avatar under obstruction. Earlier G4 evidence protects camera/control-frame separation and several recovery behaviors, but it does not close this newly demonstrated visual-safety failure.

R-V4 must add explicit visual invariants beyond desired SpringArm distance.

At minimum investigate and prove:

- actual final camera-to-avatar / camera-to-relevant-geometry clearance, not only requested boom length,
- no normal obstruction solution may leave the camera inside opaque avatar geometry,
- real Matter obstruction and user-created/freeform geometry, not only authored walls,
- near-obstacle transitions without violent composition discontinuity,
- preservation of user movement control frame while automatic presentation recovery acts,
- preservation of a useful interaction surface when the camera is forced near the player.

Candidate fallback mechanisms may include avatar fade, partial hide, alternate near presentation or another bounded mechanism, but no fallback is preselected merely because it is conventional.

The experiment should first reproduce the Owner-observed failure deterministically, then compare bounded challengers against that exact stress case.

Do not let R-V4 become a general camera rewrite unless the evidence actually demands one.

---

# R-V5 — accumulated chaotic Owner-surface rehearsal

Status: **PENDING / REQUIRED BEFORE RE-PROMOTION**

This gate exists because the old G8 did not accumulate enough geometry entropy to expose the failed composed image.

Minimum session:

- 30–60 seconds equivalent deterministic edit accumulation,
- at least 20 non-restored edits,
- holes + concavities + protrusions + stairs / narrow features,
- near and mid camera work,
- REMOVE and PLACE,
- at least one state/motion transition after geometry is already irregular,
- continuous rendered evidence plus representative frames.

Acceptance is deliberately gestalt-heavy:

- Matter still reads as solid rather than hollow/wireframe,
- no unexplained diagonal surface breakup,
- camera never enters the avatar or loses the useful interaction surface for a sustained interval,
- semantic presentation becomes more selective rather than denser as geometry becomes complex,
- state, focus, target and cell cues remain distinguishable when they coexist,
- the final scene remains understandable without knowing the scripted test.

The rehearsal cannot immediately restore every edit merely to keep the authored shape tidy.

---

# Re-promotion sequence

A future Owner candidate requires:

1. R-V0 root-cause/corrected-surface PASS — **done**,
2. provider-independent base-surface identity — **done**,
3. bounded presentation policy re-earned against the rebuilt surface — **R-V3 state policy done; remaining composed policy still falsifiable**,
4. R-V4 camera visual-safety PASS — **open**,
5. R-V5 chaotic-edit scenario PASS — **open**,
6. candidate freeze on one exact runtime,
7. exact-candidate reruns,
8. independent assurance against the active contract,
9. final readiness audit,
10. only then Owner delivery.

The previous `b5050b669...` package remains a negative comparison baseline. It must never regain authority simply because it was once frozen.

## Current next move

Begin **R-V4 camera / visual safety** from a deterministic reproduction of the Owner-observed camera-inside-avatar failure.

Preserve the defended substrate and current R-V0/R-V1/R-V3 evidence, but treat camera presentation implementation as replaceable. The immediate objective is not a prettier orbit; it is a camera that cannot lie about the world by placing the view inside opaque player geometry while still preserving useful interaction composition.
