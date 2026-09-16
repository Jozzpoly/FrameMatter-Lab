# Q0 — Owner-centered quality-system hardening

Status: **PASS FOR PROMOTION-BOUNDARY USE / BOUNDED PROCESS EVIDENCE**

Q0 was triggered after the first P1 Owner candidate demonstrated that strong hidden implementation and green CI could coexist with an obviously unacceptable Owner-visible result.

The Q0 goal was not to improve the renderer. It was to make that class of unearned promotion materially harder before FrameMatter resumes presentation work.

## Failure class being addressed

The failed P1 campaign exposed several coupled process defects:

- mechanically measurable work accumulated much stronger gates than Owner-visible work,
- acceptance scope drifted from a physically legible consumer toward a mechanically coherent consumer with visuals treated as a nonclaim,
- old evidence could be read as stronger than the surface it actually measured,
- the implementation context was also the primary promotion judge,
- packaging success and internal test count created false confidence,
- evidence was not organized around one frozen final runtime,
- component-oriented PASS did not require every representative Owner scenario to be observed,
- Owner attention was used to discover obvious defects that internal rendered evidence could have found first.

## Defended Q0 model

Q0 introduces six independent truth planes:

1. Owner intent,
2. substrate,
3. composition,
4. observable truth,
5. interaction truth,
6. promotion truth.

PASS does not inherit between planes.

The promotion model is now:

> OPEN development → FROZEN runtime candidate → final quality-plane + scenario evidence on that runtime → adversarial rehearsal → independent read-only assurance → explicit authorization → exact-runtime delivery.

Governance/evidence commits may be newer than the runtime candidate. Delivery materializes the approved frozen runtime SHA rather than governance HEAD.

## Executable ratchets

### Sealed Campaign Contract

Active contract:

`quality/contracts/p1-owner-facing-recovery.v3.json`

V3 is the first contract intentionally sealed after creation. The guard validates:

- predecessor path and exact Git blob hash,
- immediate version/campaign relationship,
- active version filename,
- active contract has only one distinct Git blob in repository history,
- inherited required gates/evidence types are not silently removed/changed,
- protected invariants, representative scenarios and negative baselines do not silently shrink,
- new explicit non-goals cannot silently relax scope,
- Owner goal / Owner-visible surface cannot silently change.

Material contract change requires a new version rather than editing the active snapshot.

### Two-dimensional readiness matrix

`quality/p1-owner-readiness.json` tracks both:

- required quality gates,
- every representative scenario contracted for P1.

Current campaign remains deliberately `BLOCKED` and `OPEN`; no final runtime is frozen.

A future final candidate cannot promote if a component/system gate is green while any representative scenario remains PENDING/FAIL or belongs to a different runtime SHA.

### Frozen candidate lifecycle

The readiness guard distinguishes:

- `OPEN` — implementation may move; no final candidate claim,
- `FROZEN` — one exact runtime SHA is the object being judged,
- `READY_FOR_OWNER` — all final evidence is bound to that frozen runtime and promotion is explicitly authorized.

A changed runtime after freeze requires a new candidate/evidence cycle.

### Independent assurance

Protocol:

`docs/INDEPENDENT-ASSURANCE.md`

Machine report:

`quality/assurance/p1-independent-review.json`

Final PASS requires a separate read-only falsification context, one frozen runtime SHA, Owner-goal and claim/evidence review, nominal + off-nominal coverage, no candidate edits during review and zero material findings.

This is practical epistemic separation for an Owner+AI R&D project, not a claim of external organizational certification.

### Exact-runtime delivery

`.github/workflows/deliver-owner-test.yml` is manual but a manual click is insufficient.

It must first pass readiness and independent-assurance enforcement, obtain the approved runtime SHA, then separately checkout and package that exact runtime. Build provenance records both the runtime SHA and later governance/evidence SHA.

## Adversarial evidence

Latest Owner-readiness workflow on the current Q0 state completed successfully.

The main readiness self-test proves the guard rejects:

- in-place mutation of a sealed versioned contract,
- predecessor hash tampering,
- inherited acceptance weakening,
- OPEN/moving-target runtime claims,
- missing contracted gates,
- evidence-type / Owner-goal drift,
- stale gate evidence from another runtime,
- missing independent assurance,
- a representative scenario left unproven,
- scenario evidence from another runtime.

It also includes a positive control proving a fully consistent frozen candidate can be accepted; the system is not a permanently-red blocker.

The independent-assurance self-test separately rejects:

- review of the wrong runtime,
- review not separated from implementation context,
- review that mutates the candidate,
- any material finding in a PASS report,
- happy-path-only review,
- omission of the Owner goal.

The real current P1 state is used as a negative control: delivery enforcement correctly rejects it because it is OPEN/BLOCKED with unresolved gates/scenarios and no assurance.

## Current underlying project state

Q0 changed governance/evidence machinery, not the defended FrameMatter mechanics.

On the same Q0 HEAD:

- strict Linux P1 mechanical suite remains PASS,
- Windows canonical/composed-scene diagnostic remains PASS,
- Windows D3D12 rendered evidence capture remains PASS as instrumentation,
- Linux Compatibility rendered capture remains PASS as secondary instrumentation,
- visual challenger capture jobs remain operational.

This does not promote current visuals. It only confirms Q0 did not accidentally destroy the object/instrumentation the recovery campaign will resume using.

## What Q0 does NOT prove

Q0 does **not** prove:

- that the next candidate will be visually good,
- that an AI review is independent in an external-certification sense,
- that a file reference proves the semantic adequacy of its evidence,
- that every future failure mode is anticipated,
- that process can replace Owner judgment,
- that more gates automatically mean better work.

Machine checks defend structure, provenance and promotion boundaries. Semantic quality still requires rendered/interactive review and a falsification-oriented independent reviewer.

## Anti-bureaucracy boundary

Q0 heavy gates apply at freeze/promotion boundaries, not continuously to exploratory implementation.

Each major rule has a concrete failure class:

- contract sealing → scope drift,
- evidence typing → proxy evidence,
- candidate freeze → moving-target evidence,
- scenario matrix → happy-path/component bias,
- independent assurance → self-certification,
- exact-runtime delivery → runtime/governance mismatch,
- negative controls → non-functional safety gate.

No additional ceremony should be added without a similarly concrete failure class or new evidence demonstrating the need.

## Remaining process debt

GitHub `pull_request.paths` evaluates the PR-wide diff, so governance/documentation commits can still retrigger heavy P1/render workflows. This creates queue noise and attention cost but does not currently weaken promotion correctness because final evidence is runtime-bound.

Optimize this trigger economics separately; do not weaken evidence semantics merely to reduce CI load.

## Decision

**Q0 PASS for bounded promotion-boundary use.**

FrameMatter may resume the Owner-facing recovery campaign under this quality model.

This does not authorize an Owner build. P1 readiness remains BLOCKED/OPEN.

The next implementation work returns to G2 lighting/form readability using existing rendered A/B instrumentation. G2/G3/etc must accumulate evidence during OPEN development, then all final acceptance/scenario evidence will be re-earned after a candidate runtime is frozen for G8.
