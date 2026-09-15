# P1 Owner-facing recovery campaign

Status: **P1 REOPENED / EXECUTION PAUSED AT Q0 QUALITY HARDENING**

This campaign exists because the first P1 Owner candidate passed mechanical/integration gates but failed the actual Owner-facing acceptance target: a coherent, physically legible sandbox loop.

The goal is not to add “graphics polish” after the real work. The rendered/interactive layer is part of the research instrument. If Matter shape, cell structure, edit intent, motion, topology and actor↔Space relationships are not readable, the LAB cannot provide trustworthy Owner evidence.

## Core correction

P1 previously optimized for hidden correctness and treated rendered quality as a secondary nonclaim. That is rejected.

The current rule is stronger:

> **a candidate is not Owner-ready unless every contracted quality plane has direct evidence on the exact candidate commit.**

The general process authority is `docs/QUALITY-SYSTEM.md`.

The P1-specific machine-readable authorities are:

- `quality/p1-campaign-contract.json`,
- `quality/p1-owner-readiness.json`,
- `ci/verify_owner_readiness.py`.

## Q0 — quality-system hardening before ordinary recovery continues

**ACTIVE / HARD STOP**

The visual recovery campaign is intentionally paused at Q0 because the first P1 failure exposed a process defect larger than one renderer bug.

Q0 must prove that the project itself can distinguish:

- technically sophisticated work in progress,
- observable/interaction quality,
- an actually promotable Owner candidate.

Q0 requires:

1. a versioned Campaign Contract,
2. a machine-readable Readiness Manifest,
3. CI validation that contract and readiness cannot silently drift apart,
4. delivery rejection while readiness is BLOCKED,
5. exact-commit verification for every required gate before delivery,
6. synchronized README / ROADMAP / research-state truth,
7. a durable process postmortem,
8. no automatic Owner artifact production while blocked,
9. adversarial self-tests proving the readiness guard rejects malformed/stale states and can accept a synthetically valid exact-commit READY state.

No ordinary G2/G3/G4 implementation tranche should be promoted until Q0 passes.

Already-running rendered challengers may remain as unpromoted data; they do not advance campaign status by themselves.

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

Do **not** protect the current P1 Environment, materials, mesh appearance, camera policy, HUD, target outline or scene composition merely because they already exist.

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

# Recovery sequence after Q0

## G0 — failed baseline / mechanical freeze

**PASS / HISTORICAL BASELINE**

- failed first P1 Owner candidate retained as negative evidence,
- mechanical substrate evidence retained,
- speculative feature/substrate expansion stopped,
- automatic Owner delivery disabled.

Evidence: `docs/evidence/p1-owner-interaction-failure.md`.

## G1 — rendered evidence harness

**PASS AS INSTRUMENTATION / CURRENT VISUAL BASELINE FAILS**

The project now captures real rendered pixels from deterministic P1 states:

1. initial static,
2. released dynamic,
3. dynamic motion,
4. storage-rebased/build state,
5. split successors,
6. frozen successor.

Windows D3D12 Forward+ is the current acceptance-relevant parity lane and reproduces the Owner-class black-surface failure. Linux Compatibility remains a secondary backend guardrail.

Evidence: `docs/evidence/p1-g1-rendered-baseline.md`.

## G2 — lighting/environment truth

**PARTIAL BOUNDED FINDING / PROMOTION PAUSED BY Q0**

G2-A changed only the Environment ambient source SKY→COLOR and set sky contribution to `0.0`.

On the same deterministic Windows D3D12 initial state it changed approximately:

- near-black coverage `52.96% → 0.00%`,
- luminance below `0.08`: `54.70% → 1.74%`,
- mean luminance `0.142 → 0.366`.

This strongly supports that the catastrophic black collapse came from project configuration.

It **does not** complete G2. Remaining form/depth presentation is still weak and flat.

After Q0:

- compare canonical, balanced key/fill and restrained SSAO/contact-depth challengers on the same parity states,
- inspect all representative camera azimuths,
- promote only the bounded winner,
- record regressions on both Windows D3D12 and Compatibility.

Gate: authored Matter remains readable from representative orientations without black-face or clipped-white collapse and without destroying shape through flat over-lighting.

## G3 — Matter visual language

**PENDING**

Challenge at least two approaches independently enough to understand their contribution, for example:

- restrained derived cell-edge/grid treatment,
- procedural/local-coordinate/vertex material treatment.

A later hybrid is allowed only after causal comparison.

Chosen language must preserve coherent broad form at distance while exposing one-cell edit granularity near interaction distance. Avoid noisy every-cube wire aesthetics.

Static/dynamic/focused/successor states require coherent, restrained visual semantics.

Gate: without HUD text, reviewer can read Matter form, cell scale and important state changes.

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
- every gate re-verified on the exact candidate commit,
- autonomous real-time rehearsal includes close camera, rapid edits, motion, rebase, split, freeze, fall/recovery,
- rehearsal recording inspected frame-by-frame,
- result clearly superior to P0.5 and failed P1 as an observable research instrument,
- remaining defects documented before packaging,
- zero open blockers,
- Owner attention explicitly authorized,
- `approved_commit` exactly bound in readiness manifest.

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
- Evidence from an older commit does not certify a changed candidate at promotion time.
- A lot of accumulated work does not create readiness.

## Current stop condition

**Q0 first.**

Do not merge P1 to `main`. Do not send another Owner candidate. Do not resume normal feature expansion. Do not promote further G2/G3/G4 work until the new quality system itself is validated.
