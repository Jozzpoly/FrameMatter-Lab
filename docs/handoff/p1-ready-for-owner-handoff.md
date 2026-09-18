# FrameMatter P1 — READY_FOR_OWNER handoff checkpoint

Status: **CURRENT HANDOFF / OWNER PACKAGE NOT YET MATERIALIZED**

This document is the shortest safe entry point for a fresh continuation context after the post-R-V5 recovery campaign. It consolidates the live authority and the important failure history without asking the next agent to reconstruct hundreds of commits or the implementation conversation.

## 1. Repository / branch / PR

- Repository: `Jozzpoly/FrameMatter-Lab`
- Branch: `rebuild/p1-interactive-foundation`
- Pull request: `#1` — keep **draft/open** until the Owner test has happened and its consequences are understood.
- Base branch: `main`
- Promotion governance commit before this handoff document: `5cf96213b68083470f544738e2bffb5c731b9316`
- Final readiness audit evidence commit: `717ddc59bad92051f735fa4e2f306f254cff4a4f`

Always verify the live branch head before acting; governance may legitimately be newer than the approved runtime.

## 2. Exact approved runtime — do not drift

The one runtime approved for the next Owner test is:

`337716db303e94e459cad2b9bcdbfcb8b6c0474b`

This SHA is simultaneously:

- `candidate_runtime_commit`,
- `approved_runtime_commit`,
- the runtime bound to all required contract-v4 gates and representative scenarios,
- the runtime independently reviewed,
- the runtime the delivery workflow must materialize.

**Do not package governance HEAD as the Owner build.**

Any runtime-affecting change after this point invalidates the current candidate and requires a new freeze / exact-candidate revalidation / G8 / independent-assurance / final-audit chain.

Governance-only documentation/evidence changes may be newer without changing the approved runtime.

## 3. Current machine-readable state

Authority: `quality/p1-owner-readiness.json`.

Current intended state:

- `status = READY_FOR_OWNER`
- `candidate_state = FROZEN`
- `promotion_authorized = true`
- `candidate_runtime_commit = 337716db303e94e459cad2b9bcdbfcb8b6c0474b`
- `approved_runtime_commit = 337716db303e94e459cad2b9bcdbfcb8b6c0474b`
- Owner attention event allowed
- all required gates PASS
- all 11 contract-v4 representative scenarios PASS
- `open_blockers = []`

Authoritative readiness validation:

- workflow `Validate Owner readiness contract`
- run `35170486791` / #290
- governance head `5cf96213b68083470f544738e2bffb5c731b9316`
- conclusion: **SUCCESS**

The run explicitly emitted:

- `OWNER_READINESS_MANIFEST_VALID ... status=READY_FOR_OWNER ... pending_gates=0 pending_scenarios=0`
- `OWNER_READINESS_DELIVERY_PASS`
- `APPROVED_RUNTIME_COMMIT=337716db303e94e459cad2b9bcdbfcb8b6c0474b`
- `INDEPENDENT_ASSURANCE_DELIVERY_PASS`
- `OWNER_READINESS_READY_DELIVERY_PASS: approved runtime 337716db303e94e459cad2b9bcdbfcb8b6c0474b`

## 4. Active contract / quality authority

Read these before making any promotion/runtime decision:

1. `quality/contracts/p1-owner-facing-recovery.v4.json`
2. `quality/p1-owner-readiness.json`
3. `docs/QUALITY-SYSTEM.md`
4. `docs/evidence/p1-final-readiness-audit-v4.md`
5. `quality/assurance/p1-independent-review.json`
6. `docs/evidence/p1-independent-assurance-post-rv5.md`
7. `docs/evidence/p1-g8-post-rv5-adversarial-rehearsal.md`
8. `docs/evidence/p1-post-rv5-candidate-freeze-revalidation.md`
9. `docs/evidence/p1-rv5-chaotic-owner-surface-rehearsal.md`

`docs/p1-owner-facing-recovery-campaign.md` is useful process/history context and its current stop condition reflects the final-audit stage, but one early authority list still names historical contract v3. Treat the sealed v4 JSON and current readiness manifest as machine-readable authority.

## 5. Why contract v4 exists

The earlier frozen Owner candidate `b5050b669ec4101226095183929f5790f0a034fc` had sophisticated mechanical evidence but failed the Owner-visible surface.

Contract v4 therefore **strengthened** acceptance rather than relaxing it:

- added `base_matter_surface_integrity`,
- added `chaotic_edit_visual_stress`,
- retained all inherited gates/scenarios/invariants,
- preserved the failed Owner candidate as negative baseline.

Change record: `docs/evidence/p1-campaign-contract-v4.md`.

## 6. Critical failure/recovery chain that must not be forgotten

### Base Matter renderer failure

A historical inside-out triangle winding bug in `CellMesher` made near surfaces back-face culled and exposed the far shell, creating a false translucent/hologram read even with opaque material. Collision was independently correct enough that mechanics could stay GREEN while rendered truth was wrong.

Permanent invariant:

> Base Matter with semantic overlays disabled must visibly read as solid, opaque, coherent 3D mass on irregular geometry.

R-V0/R-V1 corrected this and separated neutral Matter surface identity from physics-provider state.

### State presentation

R-V3 rejected top-crown-only state semantics because state disappeared at low viewing angles. Side-rim state presentation became the current bounded language; focus remains separate.

### Camera

R-V4 proved that the real danger was not merely “camera inside capsule” but useful world-context loss under tight Matter obstruction. Production overhead escape/recovery passed the relevant stress sequence.

Do not misclassify every future bad composition as a camera bug; later R-V5 demonstrated why.

### R-V5 deterministic full-history failure

The full chaotic Owner rehearsal applied 26 persistent edits (12 REMOVE + 14 PLACE), accumulated irregular geometry, moved/refroze the same Space and then ended in a deterministic avatar-only/dark composition.

Initial camera metrics looked healthy. Full-history instrumentation instead showed:

- actor remained attached to the new STATIC provider for ~112 post-refreeze frames,
- then abruptly lost ground/support while the provider still existed with collision shapes,
- the actor fell through Matter/reference world,
- the camera honestly followed the falling actor, producing the apparent rendered failure.

Root cause: `SpaceQueryCharacter` ground validation used `PhysicsDirectSpaceState3D.cast_motion()` as if it also represented current overlap contact. In shallow overlap, sweep could report no obstacle; there was no current-pose overlap/rest fallback, so valid support could be dropped.

Production fix:

- downward sweep remains primary,
- if sweep says no obstacle, current-pose `get_rest_info()` is used as complementary ground-contact state,
- same ground-normal/support-frame rules apply,
- true edge release is still regression-tested,
- no grace timer / teleport / scenario special case.

Regression evidence:

- isolated shallow-overlap RED before fix,
- same gate GREEN after fix,
- existing volumetric actor suite remained GREEN,
- full-history R-V5 remained grounded through the old failure timing,
- final support error `0.00000012 m`,
- corrected final PNG hash prefix `b4d7a4b9...` versus historical bad `67b5c0f7...`.

This is a permanent escaped-failure class; do not remove its regression pressure casually.

## 7. Exact-candidate revalidation

After R-V5 closure, new frozen runtime `337716...` re-earned the active surfaces on that exact SHA rather than inheriting them from previous commits.

Important successful runs include:

- P1 rebuild/foundation: `35132498253`
- base Matter surface: `35132498172`
- R-V3 state presentation: `35132498234`
- R-V4 camera safety: `35132498517`
- G4 camera: `35132498011`
- G5 interaction: `35132498050`
- G6 world causality: `35132497927`
- UI hierarchy: `35132497938`
- cross-layer visible rehearsal: `35132498122`
- Windows/Linux rendered parity: `35132498017`
- research-harness validation: `35132498026`
- R-V5 reduced refreeze diagnostic: `35132497970`
- R-V5 full-history diagnostic: `35132498043`
- canonical R-V5: `35132497987`

Evidence: `docs/evidence/p1-post-rv5-candidate-freeze-revalidation.md`.

## 8. G8 adversarial rehearsal

Accepted post-R-V5 G8:

- run `35139873387`
- job `104941608091`
- artifact `10464632238`
- artifact digest `sha256:b3b33329160dd6ccc0129453995af39fb830db985e3ac00e0f166356954e7a40`
- frozen runtime `337716...`
- 12 checkpoint PNGs
- continuous 212-frame, 60 FPS movie

The runtime stayed alive through close-camera pressure, rapid edits, release, motion, moving edit, real storage rebase, split, sibling-only motion, mixed STATIC/DYNAMIC successor state, far-airborne state and production fall recovery.

Manual review of checkpoint frames and continuous transitions found no recurrence of the R-V5 avatar-only/dark failure or sustained hidden failure.

A workflow-integrity defect was also found and fixed without changing runtime: the candidate already tracked a byte-identical G8 harness, while the old workflow assumed the harness must be injected/untracked. Accepted mode became `tracked-byte-identical` with exact blob identity.

Evidence: `docs/evidence/p1-g8-post-rv5-adversarial-rehearsal.md`.

## 9. Independent assurance

Fresh separate read-only reviewer context:

`67f7e1a4-1fb9-49e9-8c75-ccd1c0263018`

Verdict:

- `PASS`
- `material_findings = []`
- exact reviewed runtime `337716...`
- reviewer context separated from implementation
- no candidate changes authored during review
- Owner goal and claim/evidence fit evaluated
- nominal + off-nominal scenarios inspected

Machine report: `quality/assurance/p1-independent-review.json`.

Human consolidation: `docs/evidence/p1-independent-assurance-post-rv5.md`.

The independent reviewer did not upgrade residuals into stronger claims and retained several non-material risks for final audit.

## 10. Final readiness audit

Authority: `docs/evidence/p1-final-readiness-audit-v4.md`.

Verdict:

**PASS / authorize `READY_FOR_OWNER` promotion.**

The audit checked:

- contract-v4 strengthening/integrity,
- exact frozen-object integrity,
- candidate-wide evidence binding,
- G8 mechanics + rendered continuity,
- independent assurance,
- negative-baseline closure,
- residual risks,
- promotion/delivery semantics.

Freeze → promotion governance comparison showed only workflow/self-test/evidence/review/readiness files changed after `337716...`; no runtime implementation file changed.

## 11. Residual risks / nonclaims — preserve them

These are not blockers for the bounded P1 Owner test, but must not disappear from future reasoning:

1. **Startup camera transient:** deterministic evidence recording contains a brief extreme startup/setup composition before settled canonical state.
2. **Far-airborne weak context:** deliberately adverse far-airborne interval becomes visually weak before automatic recovery; evidence shows bounded recovery without sustained oscillation.
3. **State-rim salience:** current side-rim state language is less forceful at downscaled presentation than at larger scale.
4. **Minor governance prose drift:** early authority list in the historical campaign Markdown still names v3; machine authority is v4.
5. **G8 pacing:** ~3.53 s deterministic Movie Maker capture is evidence instrumentation, not a UX/feel demonstration.
6. P1 does **not** claim final art direction, final game UI, arbitrary world/chunk architecture, save/load, arbitrary pitch/roll gravity semantics or a vehicle framework.
7. Internal evidence cannot answer Owner-only questions such as feel, desire, priorities or emergent usefulness. That is why the next step is an Owner test.

## 12. CI/process debt discovered during closure

PR workflows currently trigger very broadly on `pull_request synchronize`. Governance-only documentation/readiness commits therefore launch many expensive/redundant runtime evidence workflows.

This caused unnecessary queue churn and once cancelled an in-progress G8 due `cancel-in-progress` concurrency.

Do **not** interpret every governance-triggered duplicate run as a requirement to requalify the frozen runtime. Exact frozen-candidate evidence already exists.

After the Owner test / campaign decision, consider a bounded CI cleanup so runtime-heavy workflows run only when relevant runtime/harness paths change or are explicitly dispatched.

Do not perform that cleanup before packaging/Owner test if it risks delaying or confusing the approved candidate.

## 13. What has NOT happened yet

### No current Owner package has been materialized

The delivery workflow is:

`.github/workflows/deliver-owner-test.yml`

Display name:

`Deliver P1 Owner Candidate`

It is **manual `workflow_dispatch` only**.

The historical workflow-dispatch run `35031808856` / #17 is from the superseded earlier campaign and **must not be reused as the current package**.

At handoff time there is no post-promotion delivery run for governance `5cf962...` / approved runtime `337716...`.

The Browser ChatGPT GitHub connector available during closure did not expose workflow dispatch. A TinyFish attempt did not successfully dispatch the workflow, and the Opera connector lacked active page-navigation permission. Therefore no claim is made that packaging has occurred.

### No merge

PR #1 remains draft/open. Do not merge to `main` merely because readiness is `READY_FOR_OWNER`.

`READY_FOR_OWNER` means the evidence system authorizes scarce Owner attention to the exact candidate. It is not a substitute for the Owner's actual judgement.

## 14. First task in the next conversation

Do not start with architecture or new implementation work.

1. Verify live branch head, PR state and `quality/p1-owner-readiness.json`.
2. Confirm `approved_runtime_commit` is still exactly `337716db303e94e459cad2b9bcdbfcb8b6c0474b` and no runtime changes occurred after freeze.
3. Run / ask the Owner to run GitHub Actions workflow **`Deliver P1 Owner Candidate`** on branch `rebuild/p1-interactive-foundation`.
4. Inspect the delivery run rather than trusting SUCCESS alone. Confirm it logs:
   - readiness delivery PASS,
   - independent-assurance delivery PASS,
   - approved runtime checkout identity exactly `337716...`,
   - strict import PASS,
   - compile PASS,
   - canonical startup PASS,
   - integrated causal-loop PASS,
   - Web export PASS,
   - Windows export PASS.
5. Inspect build provenance: `P1-BUILD-INFO.txt` must distinguish approved runtime from governance/evidence SHA.
6. Retrieve the **Windows** artifact for the Owner test (and Web artifact if useful); do not substitute an artifact from an older delivery run.
7. Only after artifact-level sanity should the Owner be asked to test.
8. Treat Owner feedback as new high-value evidence. If it exposes a material runtime/Owner-surface failure, reopen the campaign rather than explaining the failure away.
9. Do not merge to `main` until the Owner-test consequences are understood and a deliberate merge decision is made.

## 15. Suggested fresh-chat opening instruction

A fresh Browser ChatGPT continuation can begin with:

> Take over FrameMatter-Lab from `docs/handoff/p1-ready-for-owner-handoff.md` on branch `rebuild/p1-interactive-foundation`. Verify the live repo state instead of trusting the handoff blindly. Preserve approved frozen runtime `337716db303e94e459cad2b9bcdbfcb8b6c0474b`; do not mutate runtime before the Owner test. Continue from the actual next boundary: materialize and independently sanity-check the authorized Owner package, then prepare a bounded Owner test. Keep PR #1 draft/open and do not merge unless later Owner evidence justifies it.

## 16. Epistemic summary

What is now strongly established:

- P1 substrate/mechanics survived the recovery campaign.
- the previous Owner-visible failure model was real and materially broader than polish,
- base Matter solidity and representation were repaired and independently pressured,
- state/camera/interaction/world/UI/cross-layer evidence was rebuilt rather than inherited,
- R-V5 exposed a new deterministic actor-support/contact failure and that class received a causal fix + regression gate,
- one exact post-R-V5 runtime re-earned candidate-wide evidence,
- that exact runtime survived G8 and fresh independent falsification,
- final audit and executable readiness governance authorize it for Owner attention.

What is **not** established until the next step:

- that a newly packaged artifact from this approved runtime actually exports/starts correctly in the delivery environment,
- that the Owner likes the feel/presentation or believes the LAB is now a useful research instrument,
- that P1 should merge to `main`,
- what the next FrameMatter research phase should be after Owner feedback.

That uncertainty is intentional. The next high-information event is no longer another internal implementation tranche. It is **artifact materialization followed by the Owner test**.
