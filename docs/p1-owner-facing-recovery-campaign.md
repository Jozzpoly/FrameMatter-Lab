# P1 Owner-facing recovery campaign

Status: **ACTIVE / G2 + G3 BOUNDED PASS / SYSTEM-STATE SEMANTICS NEXT**

This campaign exists because the first P1 Owner candidate passed mechanical/integration gates but failed the actual Owner-facing acceptance target: a coherent, physically legible sandbox loop.

The goal is not to add “graphics polish” after the real work. The rendered/interactive layer is part of the research instrument. If Matter shape, cell structure, edit intent, motion, topology and actor↔Space relationships are not readable, the LAB cannot provide trustworthy Owner evidence.

## Core correction

P1 previously optimized for hidden correctness and treated rendered quality as a secondary nonclaim. That is rejected.

The current rule is stronger:

> **a candidate is not Owner-ready unless every contracted quality plane has direct evidence on the exact frozen candidate commit.**

During the OPEN campaign, bounded gates may earn PASS with durable evidence while `verified_runtime_commit` remains empty. Exact-commit binding is re-earned only after one runtime candidate is frozen for final promotion.

The general process authority is `docs/QUALITY-SYSTEM.md`.

The P1-specific machine-readable authorities are:

- `quality/contracts/p1-owner-facing-recovery.v3.json`,
- `quality/p1-owner-readiness.json`,
- `ci/verify_owner_readiness.py`.

## Q0 — quality-system hardening

**PASS / GOVERNANCE FOUNDATION**

Q0 was introduced because the first P1 failure exposed a process defect larger than one renderer bug. The project needed to distinguish technically sophisticated work in progress from observable quality and from an actually promotable Owner candidate.

The campaign now has:

1. a versioned Campaign Contract,
2. a machine-readable Readiness Manifest,
3. CI validation that contract and readiness cannot silently drift apart,
4. delivery rejection while readiness is BLOCKED,
5. exact-commit verification requirements for final promotion,
6. synchronized quality/process authority,
7. a durable failure/postmortem evidence chain,
8. no automatic Owner artifact production while blocked,
9. adversarial verifier self-tests.

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

The project captures real rendered pixels from deterministic P1 states:

1. initial static,
2. released dynamic,
3. dynamic motion,
4. storage-rebased/build state,
5. split successors,
6. frozen successor,
7. lighting azimuth stress,
8. near/mid/far granularity stress.

Windows D3D12 Forward+ remains the acceptance-relevant parity lane. Linux Compatibility remains a secondary renderer/backend guardrail.

Evidence: `docs/evidence/p1-g1-rendered-baseline.md`.

## G2 — lighting/environment truth

**BOUNDED PASS / BALANCED FILL PROMOTED**

The catastrophic black-surface failure was first isolated to project-side Environment configuration, then the surviving flat/over-bright form problem was challenged across eight controlled camera azimuths.

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

Nonclaims remain: this is not final art direction, not state semantics, not camera quality and not Owner readiness.

## G3 — Matter granularity / edit scale

**BOUNDED PASS / CLEAN SURFACE GRID 0.14 PROMOTED**

G3 independently compared two visual languages:

- exposed-surface cell boundaries,
- per-cell surface tonal modulation.

Surface modulation was rejected because it primarily read as a material/checker pattern rather than editable cell boundaries.

The surface-grid direction was refined rather than immediately promoted:

- initial alpha `0.16` was too visually present,
- softer alpha retained scale information,
- audit then found duplicate same-plane shared-edge emission,
- a deduplicated implementation was challenged at clean alpha `0.14` and `0.18`,
- clean `0.14` won because it retained near/mid/far granularity while preserving broad form more quietly.

Production promotion is a separate `P1MatterSurfaceGrid` presentation consumer. It does not own Matter, lineage, collision, topology or provider identity. `p1/main.gd` does not know that the surface grid exists.

An executable production probe defends exact coplanar deduplication and follows edit, storage rebase, provider replacement and topology succession. Rendered production output was compared against an honest test-only clean-0.14 reference lane with production presentation disabled first.

Evidence: `docs/evidence/p1-g3-matter-granularity.md`.

Gate result: **Matter granularity PASS within the current P1 visual scale and scenario set.**

Nonclaims remain: no very-large-volume scale proof, no final renderer, no chunk architecture, no STATIC/DYNAMIC/focus/successor semantic language and no Owner readiness.

## G3-S — system-state semantics

**ACTIVE NEXT / PENDING**

Granularity now has one clear semantic channel: restrained exposed cell boundaries. Do not overload it with several unrelated meanings.

The next campaign must challenge how the world itself communicates at least:

- STATIC vs DYNAMIC Space,
- normal vs focused/edited Space,
- source relationship vs independent topology successors after split.

REMOVE / PLACE / EXPAND remains interaction-language work and should not be silently folded into the physical Space-state cue.

Principles:

- do not recolor the whole object merely because state needs “a color”,
- prefer localized/peripheral/material cues that remain readable during motion and under G2 lighting,
- focus/selection must remain conceptually different from physical provider state,
- successor independence must not be faked by artificial separation impulses or unrelated random colors,
- test at least two materially different semantic languages before promotion,
- judge static, moving, split and frozen states on the same rendered sequence.

Gate: without relying on the engineering HUD, a reviewer can distinguish physical Space state and understand that split pieces are related successors which are now independently simulated.

## G4 — camera as experiment instrument

**PENDING**

Replace “SpringArm exists” with a rendered framing contract.

Required:

- actor + relevant Space + useful world reference remain understandable,
- active Space extent influences framing/distance,
- close obstacle handling avoids long-lived useless close-ups,
- fall/recovery, provider replacement, storage rebase and split recover coherent composition,
- immediate post-split framing preserves enough relation to understand what happened.

Gate: scripted/adversarial camera sequence is reviewed from rendered output using real Matter and real presentation, not a synthetic neutral fixture.

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

**Continue G3-S system-state semantics.**

Do not merge P1 to `main`. Do not send another Owner candidate. Do not freeze a G8 candidate yet. G2 and G3 are defended bounded foundations, not a substitute for the remaining visual, interaction, rehearsal and assurance gates.
