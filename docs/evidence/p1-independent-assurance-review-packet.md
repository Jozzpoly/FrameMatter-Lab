# P1 independent assurance review packet

## Purpose

This packet is the entry point for the **separate read-only independent assurance context** required by the P1 Owner-facing recovery campaign.

The reviewer is **not** asked to confirm the implementation context's conclusion. The reviewer is asked to falsify the claim that the frozen P1 runtime is ready to proceed toward Owner delivery.

The reviewer must not author candidate changes, patch tests, relax acceptance, or turn a material finding into a polish note. If a material issue is found, the correct outcome is `FAIL` / `BLOCKED` and the implementation context must create a new candidate.

## Frozen object under review

- Repository: `Jozzpoly/FrameMatter-Lab`
- Source branch / governance branch: `rebuild/p1-interactive-foundation`
- Pull request: `#1`
- **Frozen runtime commit:** `b5050b669ec4101226095183929f5790f0a034fc`
- Candidate state: `FROZEN`
- Current campaign state: `BLOCKED`
- Current promotion authorization: `false`
- Approved runtime: none

Candidate runtime must be reviewed as that exact SHA. Later governance commits contain evidence/harness/reporting changes and must not be mistaken for a newer runtime candidate.

## Owner-visible goal

Use the exact Campaign Contract wording, not a narrower mechanical proxy:

> Provide a professional, physically legible sandbox research surface where the Owner can directly see and judge editable Matter, moving/static local Spaces, actor relations, editing, topology consequences and motion without reconstructing hidden mechanics from debug output.

Owner-visible surface:

> Windows desktop P1 runtime, rendered scene, camera, interaction feedback and default UI.

## Mandatory protocol and contract

Read these first:

1. `docs/INDEPENDENT-ASSURANCE.md`
2. `quality/contracts/p1-owner-facing-recovery.v3.json`
3. `quality/p1-owner-readiness.json`
4. `docs/p1-owner-facing-recovery-campaign.md`
5. `docs/p1-visual-acceptance-contract.md`
6. `docs/QUALITY-SYSTEM.md`

Also inspect the negative baseline rather than judging the candidate without knowing what the recovery campaign was intended to prevent:

- `docs/evidence/p1-owner-interaction-failure.md`
- `docs/evidence/p1-g1-rendered-baseline.md`

## Evidence claims to challenge

Do not treat the following documents as authority merely because they say PASS. Use them as indexes into claims, then inspect the underlying source/runtime/run evidence where material.

- `docs/evidence/p1-integrated-owner-candidate.md`
- `docs/evidence/p1-g2-lighting-form.md`
- `docs/evidence/p1-g3-matter-granularity.md`
- `docs/evidence/p1-g3s-system-state-semantics.md`
- `docs/evidence/p1-g4-camera-composition.md`
- `docs/evidence/p1-g5-interaction-hierarchy.md`
- `docs/evidence/p1-g6-world-motion-causality.md`
- `docs/evidence/p1-ui-hierarchy.md`
- `docs/evidence/p1-cross-layer-visible-composition.md`
- `docs/evidence/p1-g8-candidate-freeze-revalidation.md`
- `docs/evidence/p1-g8-adversarial-rehearsal.md`

## Exact frozen-candidate run set

These runs were used to re-earn the previously isolated claims on the same frozen candidate `b5050b669...`:

- full P1 rebuild/foundation: run `35022042985`
- G4 camera: run `35022043026`
- G5 interaction: run `35022042895`
- G6 world causality: run `35022042983`
- canonical UI: run `35022042896`
- cross-layer visible rehearsal: run `35022043017`
- general rendered parity: run `35022043031`
- research harness validation: run `35022043157`
- readiness/governance validation at candidate freeze stage: run `35022042990`

The accepted G8 adversarial session was deliberately run later through a separate governance/runtime checkout arrangement so the harness could evolve without changing candidate bytes:

- accepted G8 run: `35023685435`
- accepted G8 artifact ID: `10419060205`
- accepted artifact digest: `sha256:8ff548dffffe71a5aca73a248066e3a1aac61b2db9361df418c94554503e0ccb`
- accepted G8 harness governance commit: `5f900335ce664bd069d0c21418984b5a134fc431`
- runtime under that harness: still exact frozen `b5050b669ec4101226095183929f5790f0a034fc`

Also inspect the rejected first G8 attempt rather than only the successful retry:

- rejected G8 run: `35023279772`
- rejected run reason: one legal sibling pulse produced only `0.1395 m` displacement; rendered `07→08` was judged too weak to prove materially readable successor independence.
- acceptance threshold (`> 0.75 m`) was **not lowered**. The retry used three legal production-scale finite pulses and a longer bounded observation window, reaching `0.9484 m`.

The reviewer should independently decide whether that is a legitimate evidence-stimulus correction or an unacceptable test adaptation.

## Known limitation / evidence qualification that must not be hidden

The accepted G8 continuous movie contains a short extreme camera close-up during deterministic **test-only instantaneous relocation** used to place the actor into the real near-wall fixture. The implementation review classified this as a fixture artifact because it occurs during test setup, before the settled near-wall stress checkpoint, and does not recur during evaluated production-driven edit/motion/rebase/split/fall phases.

Near the production automatic-recovery threshold, the same movie also contains one boundary frame where remote context is almost lost immediately before recovery fires; context is then reacquired without sustained oscillation.

Do not inherit those classifications automatically. Decide independently whether either is material to the actual Campaign Contract.

## Required falsification questions

At minimum answer these explicitly:

1. Does the evidence directly support the Owner-visible goal, or has the claim narrowed into mechanical correctness plus attractive screenshots?
2. Is any important acceptance property being deferred to “polish”, “later”, or a non-goal without Owner-authorized contract change?
3. Is any quality plane supported only by telemetry/mechanical probes when the claim is inherently rendered or interactive?
4. Are all representative scenarios genuinely evidenced on the exact frozen runtime rather than inferred from older commits?
5. Can composition between camera, interaction, Matter state, motion, topology, storage maintenance and recovery still generate an embarrassing first-minute failure even though isolated gates are green?
6. Is state language actually readable from pixels, especially STATIC vs DYNAMIC and split-successor relations, rather than only from HUD text?
7. Is editing legible enough to understand remove/place/expand and rejection without reconstructing hidden mechanics?
8. Does camera behavior preserve the experiment under near-obstacle, edge, far-airborne, split and recovery conditions?
9. Does the cross-layer/G8 evidence demonstrate causality rather than merely showing a sequence of stable end states?
10. Are the first failed Owner candidate and negative baseline failures actually prevented, or merely bypassed by deterministic fixtures?
11. Did the G8 retry strengthen legitimate user-available stimulus while preserving acceptance, or did it overfit the evidence fixture?
12. Is the test-only near-wall relocation transient immaterial to the current claim, or evidence that camera continuity remains too fragile?
13. Is there any material defect or evidence gap understated by `quality/p1-owner-readiness.json`?
14. Would you accept this evidence if it were submitted by another team whose implementation narrative you did not trust?

## Minimum nominal review

Review a non-empty subset that includes at least:

- default static Matter / form and granularity
- pointer edit target + remove/place/expand feedback
- zero-launch release followed by explicit finite motion
- moving edit + real storage rebase
- topology split + successor relations
- freeze at current pose / mixed successor state

## Minimum adverse/off-nominal review

Review a non-empty subset that includes at least:

- real close-Matter camera obstruction
- actor near Space edge / minimum zoom pressure
- far-airborne composition
- production fall/recovery
- topology succession after prior motion and storage rebase
- the rejected first G8 run and accepted retry
- the test-only relocation transient in the accepted G8 movie

## Reviewer output

Do **not** edit the repository or candidate during the review. Return two things to the Owner/implementation context:

### A. Human review

A concise falsification report containing:

- verdict: `PASS` or `FAIL`
- material findings, if any
- non-material observations / residual risks
- exact evidence actually inspected
- explicit judgement of Owner-goal / evidence fit
- explicit judgement of nominal and off-nominal coverage
- whether candidate runtime remained frozen and reviewer stayed read-only

### B. Machine-readable report candidate

Return a complete JSON object compatible with `quality/assurance/p1-independent-review.json`:

```json
{
  "schema_version": 1,
  "campaign_id": "p1-owner-facing-recovery",
  "campaign_contract_version": 3,
  "status": "PASS_OR_FAIL",
  "disposition": "PASS_OR_FAIL",
  "reviewed_runtime_commit": "b5050b669ec4101226095183929f5790f0a034fc",
  "review_mode": "read_only_falsification",
  "reviewer_role": "independent_assurance",
  "review_context_id": "A_UNIQUE_IDENTIFIER_FOR_THIS_FRESH_REVIEW_CONTEXT",
  "reviewer_context_separated_from_implementation": true,
  "runtime_was_frozen": true,
  "candidate_changes_authored_during_review": false,
  "owner_goal_evaluated": true,
  "claim_evidence_fit_evaluated": true,
  "nominal_scenarios_reviewed": ["..."],
  "off_nominal_scenarios_reviewed": ["..."],
  "evidence_examined": ["..."],
  "material_findings": [],
  "notes": "..."
}
```

If there is any material finding, use `FAIL`; do not produce a PASS with a finding hidden in `notes`.

If the reviewer cannot access enough raw evidence to falsify the claim, the correct result is **not PASS**. State what is missing and stop rather than inferring readiness from the implementation context's summaries.

## Suggested fresh-context instruction

The Owner can start a fresh Browser ChatGPT conversation with GitHub access and send only:

> Act as the separate read-only independent assurance reviewer for FrameMatter P1. Read `docs/evidence/p1-independent-assurance-review-packet.md` on branch `rebuild/p1-interactive-foundation`, follow it literally, independently falsify the frozen candidate, do not modify the repo, and return the human review plus the complete machine-readable report candidate it requests.

No additional implementation-context coaching should be necessary.
