# P1 Owner-facing recovery campaign

Status: **ACTIVE / G2 + G3 + G3-S BOUNDED PASS / G4 CAMERA NEXT**

This campaign exists because the first P1 Owner candidate passed mechanical/integration gates but failed the actual Owner-facing acceptance target: a coherent, physically legible sandbox loop.

The goal is not to add “graphics polish” after the real work. The rendered/interactive layer is part of the research instrument. If Matter shape, cell structure, edit intent, motion, topology and actor↔Space relationships are not readable, the LAB cannot provide trustworthy Owner evidence.

## Core correction

P1 previously optimized for hidden correctness and treated rendered quality as a secondary nonclaim. That is rejected.

> **A candidate is not Owner-ready unless every contracted quality plane has direct evidence on the exact frozen candidate commit.**

During the OPEN campaign, bounded gates may earn PASS with durable evidence while `verified_runtime_commit` remains empty. Exact-commit binding is re-earned only after one runtime candidate is frozen for final promotion.

The general process authority is `docs/QUALITY-SYSTEM.md`.

The P1-specific machine-readable authorities are:

- `quality/contracts/p1-owner-facing-recovery.v3.json`,
- `quality/p1-owner-readiness.json`,
- `ci/verify_owner_readiness.py`.

## Q0 — quality-system hardening

**PASS / GOVERNANCE FOUNDATION**

Q0 was introduced because the first P1 failure exposed a process defect larger than one renderer bug. The campaign now has a versioned contract, machine-readable readiness, CI drift validation, delivery rejection while BLOCKED, exact-commit final-promotion requirements, adversarial verifier self-tests and a durable failure/evidence chain.

Q0 no longer blocks ordinary recovery work. It remains a protected governance foundation and will be exercised again at G8.

## Frozen evidence, not frozen implementation

Preserve these currently defended semantics unless new evidence falsifies them:

- logical Matter authority independent of render/collision representation,
- logical Space identity independent of provider identity,
- static↔dynamic provider replacement,
- volumetric query actor without accidental infinite-force rigid-body push,
- multi-Space succession after topology split,
- storage-frame rebase with actor/camera coordinate maintenance,
- finite impulse/torque Space control,
- exact merged-cuboid collision as current default,
- strict zero-engine-error evidence floor.

Do **not** protect the current Environment, materials, presentation language, camera policy, HUD, target outline or scene composition merely because they already exist. Promoted visual mechanisms remain replaceable if later evidence finds a better language.

## Definition of done for the next Owner candidate

The next candidate must be mechanically green and allow an informed reviewer, from rendered/recorded interaction without relying on engineering telemetry, to determine:

- the shape and depth of Matter at a glance,
- individual cell scale / edit granularity,
- which cell/face is targeted and what operation will happen,
- whether the active Space is static or dynamic,
- actor position relative to active Space and reference world,
- whether the Space is translating/rotating,
- when destructive editing creates independent successor Spaces,
- whether camera composition preserves experiment context during motion, editing, falls, recovery and close obstacles.

No dominant Matter surface may collapse into featureless black/white at ordinary authored angles. Default presentation must not look like an engineering telemetry/debug view.

This remains a research LAB, not final game art. **Professional and legible is required; final art direction is not.**

---

# Recovery sequence

## G0 — failed baseline / mechanical freeze

**PASS / HISTORICAL BASELINE**

- failed first P1 Owner candidate retained as negative evidence,
- mechanical substrate evidence retained,
- speculative feature/substrate expansion stopped,
- automatic Owner delivery disabled.

Evidence: `docs/evidence/p1-owner-interaction-failure.md`.

## G1 — rendered evidence harness

**PASS AS INSTRUMENTATION / NEGATIVE BASELINE PRESERVED**

The project captures real rendered pixels from deterministic P1 states: initial static, release, dynamic motion, storage rebase/build, split successors, frozen successor, lighting azimuth stress and near/mid/far granularity stress.

Windows D3D12 Forward+ remains the acceptance-relevant parity lane. Linux Compatibility remains a secondary renderer/backend guardrail.

Evidence: `docs/evidence/p1-g1-rendered-baseline.md`.

## G2 — lighting/environment truth

**BOUNDED PASS / BALANCED FILL PROMOTED**

The catastrophic black-surface failure was isolated to project-side Environment configuration, then the surviving flat/over-bright form problem was challenged across eight controlled camera azimuths.

Promoted canonical lighting:

- ambient energy `0.42`,
- primary shadowed key energy `0.88`,
- opposite fill energy `0.24`,
- fill specular `0`,
- fill shadows disabled.

The tested SSAO configuration was not promoted because it added broad darkening/gradients without enough additional authored-form information.

Promotion was re-rendered against the accepted challenger and the mechanical suite remained green.

Evidence: `docs/evidence/p1-g2-lighting-form.md`.

Gate result: **form/depth readability PASS within the current authored P1 scene and tested representative orientations.**

Nonclaims remain: this is not final art direction, camera quality, interaction quality or Owner readiness.

## G3 — Matter granularity / edit scale

**BOUNDED PASS / CLEAN SURFACE GRID 0.14 PROMOTED**

G3 independently compared exposed-surface cell boundaries with per-cell surface tonal modulation. Surface modulation was rejected because it primarily read as a material/checker pattern rather than editable cell boundaries.

The grid direction was refined through softer intensity and an audit that found duplicate same-plane shared-edge emission. A deduplicated implementation was challenged at clean alpha `0.14` and `0.18`; clean `0.14` won because it retained near/mid/far granularity while preserving broad form more quietly.

Production promotion is a separate `P1MatterSurfaceGrid` presentation consumer. It does not own Matter, lineage, collision, topology or provider identity. An executable probe follows edit, storage rebase, provider replacement and topology succession. Rendered production output was compared against an honest test-only reference lane with production presentation disabled first.

Evidence: `docs/evidence/p1-g3-matter-granularity.md`.

Gate result: **Matter granularity PASS within the current P1 visual scale and scenario set.**

Nonclaims remain: no very-large-volume scale proof, final renderer, chunk architecture or Owner readiness.

## G3-S — system-state semantics

**BOUNDED PASS / SOFT STATE CONTOUR + NEUTRAL FOCUS CROWN PROMOTED**

G3-S deliberately kept physical state separate from G3 cell granularity and from Matter material identity.

Two materially different families were challenged:

1. whole-material STATIC/DYNAMIC tint,
2. derived exposed-surface state contour.

The material family was rejected even after refinement. It was readable, but it made simulation state alter the perceived substance of Matter. That would collide with future authored material identities such as wood, metal or earth.

The contour family preserved base material identity and won architecturally. Its first version was too strong/debug-like, while the first AABB focus brackets reduced under occlusion to disconnected floating marks. AABB brackets were rejected.

Focus was replaced with a separate crown derived from the perimeter of actual exposed top Matter surfaces. A pale-blue crown still competed with the cyan STATIC contour, so the final focus cue became neutral-white.

The final bounded state language is:

- STATIC: restrained cyan-family surface contour, alpha `0.32`,
- DYNAMIC: restrained amber-family surface contour, alpha `0.36`,
- focused Space: independent neutral-white top-surface crown, alpha `0.62`.

The final soft-contour profile beat the stronger `0.42/0.46` profile because it remained readable through near/mid/far, split and freeze states while competing less with the G3 cell grid.

Production implementation is the sibling consumer `P1MatterStatePresentation`. It owns no Matter/provider/topology/focus authority and does not recolor the provider-owned base material. Provider/edit/rebase/split changes are event-driven through existing consumer contracts; current focus is observed from the existing P1 current-focus accessor rather than creating a second selection authority.

The production lifecycle probe passed edit, storage rebase, STATIC→DYNAMIC provider replacement, one→many topology succession and freeze. Its final split/freeze state simultaneously contains one focused STATIC successor and one independent DYNAMIC sibling with exactly two state overlays and one focus crown.

Same-commit Windows D3D12 promotion equivalence on workflow run `34992731545`, commit `860dbe6789ff6acc6eb6f4c78a691d217f0d7695`, reproduced the accepted challenger essentially exactly on deterministic states: initial and most turntable/far captures were pixel-identical; the remaining deterministic differences were only a handful of pixels at very small channel deltas. Moving/rebase/split/freeze screenshots are not abused as pixel-equivalence evidence because independent jobs have solver/render timing variation; those lifecycle states are defended by the executable production probe.

Evidence: `docs/evidence/p1-g3s-system-state-semantics.md`.

Gate result: **system-state semantics PASS within the current authored P1 scene and tested scenario/render path.**

Explicit nonclaims remain:

- final colors or art direction,
- broad color-vision accessibility proof,
- REMOVE / PLACE / EXPAND interaction language,
- adequate camera composition,
- world/motion causality,
- default UI hierarchy,
- final focus architecture,
- Owner readiness.

## G4 — camera as experiment instrument

**ACTIVE NEXT / PENDING**

Replace “SpringArm exists” with a rendered framing contract.

Required:

- actor + relevant Space + useful world reference remain understandable,
- active Space extent influences framing/distance,
- standing near Space center must not collapse context pressure toward zero,
- close obstacle handling avoids long-lived useless close-ups,
- fall/recovery, provider replacement, storage rebase and split recover coherent composition,
- immediate post-split framing preserves enough relation to understand what happened,
- the camera may follow the actor without abandoning the experiment the actor is participating in.

The G4 stress sequence must use real authored Matter, the promoted G2/G3/G3-S presentation and real lifecycle events rather than a synthetic neutral fixture.

Gate: scripted/adversarial camera output remains useful enough that an informed reviewer can follow actor↔Space↔world causality without reconstructing off-screen context mentally.

## G5 — interaction visual hierarchy

**PENDING**

Rebuild edit feedback as a tool rather than debug drawing.

- default target cue must respect depth/occlusion,
- REMOVE / PLACE / EXPAND need distinct but related language,
- exact target cell/face must be obvious before click,
- success/rejection feedback should be causal and temporary,
- reticle/UI must remain subordinate to world interaction.

The old `no_depth_test` wire cube is not acceptable as default Owner interaction language.

## G6 — world/motion/topology causality

**PENDING**

Reference environment and state cues must make real physical state readable.

- world provides subdued scale/motion/parallax reference,
- release reads as state change rather than unexplained launch,
- finite translation/yaw are perceivable relative to stable reference,
- split successors read as related but independent Spaces,
- freeze reads as current pose becoming static rather than visual reset.

Do not fake physics with effects; explain actual physics visually.

## G7 — renderer / host viability checkpoint

**PENDING**

Godot is judged only after competent G2–G6 work.

If a deliberately simple FrameMatter scene still cannot reach professional readability with ordinary Godot rendering/material/camera facilities at reasonable complexity, build a tiny equivalent reference in the strongest familiar web stack and compare the same authored geometry/camera target.

Host-switch discussion is evidence-triggered, not frustration-triggered.

The first black-surface recording is not evidence against Godot because a concrete project-side ambient configuration failure has already been reproduced and corrected in a bounded A/B.

## G8 — adversarial preflight / Owner package

**BLOCKED**

Before another Owner executable:

- complete mechanical suite green,
- parity rendered lane green,
- all visual acceptance dimensions V-A through V-G have current evidence and no material FAIL,
- Campaign Contract required gates all PASS,
- every gate re-verified on the exact frozen candidate commit,
- representative scenario coverage re-earned on that exact runtime,
- autonomous real-time rehearsal includes close camera, rapid edits, motion, rebase, split, freeze, fall/recovery,
- rehearsal recording inspected frame-by-frame,
- result clearly superior to P0.5 and failed P1 as an observable research instrument,
- remaining defects documented before packaging,
- zero open blockers,
- Owner attention explicitly authorized,
- `approved_runtime_commit` exactly bound in readiness manifest,
- independent assurance passed.

The final question is:

> **would this build honestly demonstrate the system we claim to be researching, or would the Owner still need to mentally reconstruct it from broken/debug pixels?**

Only the first answer permits delivery.

---

# Process rules during recovery

- Visual/presentation defects are first-class research failures when they contaminate Owner evidence.
- No acceptance property may silently become a nonclaim because testing it is difficult.
- Every Owner-facing claim needs evidence from the actual relevant surface.
- Mechanical, observable, interaction and promotion truth remain separate.
- Every material visual tranche preserves baseline, states one bounded hypothesis, captures equivalent after-state and records regressions.
- One pretty screenshot never outweighs causal/system readability across the representative scenario set.
- Owner tests are scarce high-information events, not first-line obvious-defect QA.
- Evidence from an older commit does not certify a changed frozen candidate at promotion time.
- A lot of accumulated work does not create readiness.
- Resolved challenger lanes should leave active CI once promotion equivalence is recorded; preserve evidence, not permanent runner cost.

## Current stop condition

**Continue G4 camera as experiment instrument.**

Do not merge P1 to `main`. Do not send another Owner candidate. Do not freeze a G8 candidate yet. G2, G3 and G3-S are defended bounded foundations, not a substitute for the remaining camera, interaction, world-causality, UI, rehearsal and assurance gates.
