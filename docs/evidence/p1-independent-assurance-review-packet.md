# P1 independent assurance review packet — contract v4 / post-R-V5 candidate

## Purpose

This packet is the entry point for the **fresh separate read-only independent assurance context** required by the P1 Owner-facing recovery campaign.

The reviewer is **not** asked to confirm the implementation context's conclusion. The mandate is to falsify the claim that the frozen P1 runtime has sufficient evidence to proceed toward Owner delivery.

Do not author candidate changes, patch tests, relax acceptance, or turn a material finding into a polish note. If a material issue is found, the correct outcome is `FAIL` / `BLOCKED`; implementation must create and requalify a new candidate.

## Frozen object under review

- Repository: `Jozzpoly/FrameMatter-Lab`
- Source / governance branch: `rebuild/p1-interactive-foundation`
- Pull request: `#1`
- **Frozen runtime commit:** `337716db303e94e459cad2b9bcdbfcb8b6c0474b`
- Active campaign contract: `quality/contracts/p1-owner-facing-recovery.v4.json`
- Candidate state: `FROZEN`
- Current campaign state: `BLOCKED`
- Current promotion authorization: `false`
- Approved runtime: none
- Independent assurance machine report: currently `PENDING`

Later governance commits contain evidence, workflow and reporting changes and must not be mistaken for a newer runtime candidate. Contract v4 explicitly permits governance state to be newer than the frozen runtime; delivery is still required to materialize the exact approved runtime.

Any material runtime change after `337716...` would invalidate this packet and require a new freeze/review cycle.

## Owner-visible goal

Use the exact active Campaign Contract wording:

> Provide a professional, physically legible sandbox research surface where the Owner can directly see and judge editable Matter, moving/static local Spaces, actor relations, editing, topology consequences and motion without reconstructing hidden mechanics from debug output.

Owner-visible surface:

> Windows desktop P1 runtime, rendered scene, camera, interaction feedback and default UI.

## Mandatory protocol and authority

Read these first:

1. `docs/INDEPENDENT-ASSURANCE.md`
2. `quality/contracts/p1-owner-facing-recovery.v4.json`
3. `quality/p1-owner-readiness.json`
4. `docs/p1-visual-representation-rebuild.md`
5. `docs/p1-visual-acceptance-contract.md`
6. `docs/QUALITY-SYSTEM.md`
7. `docs/evidence/p1-post-rv5-candidate-freeze-revalidation.md` if present under that name, otherwise locate the post-R-V5 freeze-revalidation record by content/current branch history.
8. `docs/evidence/p1-g8-post-rv5-adversarial-rehearsal.md`

`docs/p1-owner-facing-recovery-campaign.md` contains valuable historical campaign reasoning but predates the current post-R-V5 authority in places. Treat history as evidence, not as a substitute for the active v4 contract/current manifest.

## Negative baseline and failure history that must be inspected

Do not judge only the final green state. At minimum understand these failure classes:

- `docs/evidence/p1-owner-interaction-failure.md`
- `docs/evidence/p1-g1-rendered-baseline.md`
- `docs/evidence/p1-owner-test-visual-failure-and-rebuild.md`
- `docs/evidence/p1-rv0-base-surface-forensics.md`
- `docs/evidence/p1-rv5-chaotic-owner-surface-rehearsal.md`

The most important new failure since the previous independent review is R-V5: the old candidate could remain mechanically plausible while a full accumulated session ended in a deterministic avatar-only / dark rendered state after refreeze. The implementation context claims that this was traced to actor contact/support semantics, fixed, regression-gated, and re-earned on the new frozen candidate. Falsify that claim rather than assuming it from the PASS record.

## Current evidence claims to challenge

Use these as indexes, not authority merely because they say PASS:

- `docs/evidence/p1-rv0-base-surface-forensics.md`
- `docs/evidence/p1-rv1-presentation-stack-forensics.md`
- `docs/evidence/p1-rv1-provider-surface-identity.md`
- `docs/evidence/p1-rv3-state-presentation-policy.md`
- `docs/evidence/p1-rv4-camera-visual-safety.md`
- `docs/evidence/p1-rv5-chaotic-owner-surface-rehearsal.md`
- post-R-V5 candidate-freeze revalidation evidence
- `docs/evidence/p1-g4-camera-composition.md`
- `docs/evidence/p1-g5-interaction-hierarchy.md`
- `docs/evidence/p1-g6-world-motion-causality.md`
- `docs/evidence/p1-ui-hierarchy.md`
- `docs/evidence/p1-cross-layer-visible-composition.md`
- `docs/evidence/p1-g8-post-rv5-adversarial-rehearsal.md`

Historical G8/final-audit/assurance files for `b5050b669...` are useful only as superseded comparison evidence and must not certify the new runtime.

## Exact frozen-candidate revalidation set

The post-R-V5 candidate `337716...` re-earned the active pre-G8 surfaces on one exact runtime SHA:

- full P1 rebuild/foundation: run `35132498253` — SUCCESS
- G4 camera: run `35132498011` — SUCCESS
- G5 interaction: run `35132498050` — SUCCESS
- G6 world causality: run `35132497927` — SUCCESS
- canonical UI: run `35132497938` — SUCCESS
- cross-layer visible rehearsal: run `35132498122` — SUCCESS
- general rendered parity: run `35132498017` — SUCCESS on Windows D3D12 and Linux Compatibility
- R-V3 state policy: run `35132498234` — SUCCESS
- R-V4 camera visual-safety: run `35132498517` — SUCCESS
- base Matter surface forensics: run `35132498172` — SUCCESS
- research-harness validation: run `35132498026` — SUCCESS
- R-V5 reduced refreeze diagnostic: run `35132497970` — SUCCESS
- R-V5 full-history diagnostic: run `35132498043` — SUCCESS
- canonical R-V5 chaotic Owner-surface rehearsal: run `35132497987` — SUCCESS

Selected candidate-native artifacts from that closure include:

- G4 camera: artifact `10460889801`, digest `sha256:a70718c9e5608047268bbca3d766145a30605bd3411afee7aa98337ae2f9c5a1`
- G5 interaction: artifact `10461990003`, digest `sha256:6976f304554ce41ece8bb0a713c6b690e548e697e01150a3228c9b93b30ff392`
- G6 promoted coarse world datum: artifact `10461654420`, digest `sha256:e115d5332391d38fe46471a210c37ae0f08bad8a05d56aceb4c656ecb8c597c4`
- UI hierarchy: artifact `10461843602`, digest `sha256:00efbbc44a9af8a6dd21518033ec57e66df4e54871bf9b26dec1d55f7155a96b`
- cross-layer rehearsal: artifact `10461940109`, digest `sha256:e9358e013999177bca00064951ced2b95863746d6ff15827c05559274d93994d`
- general rendered Windows: artifact `10461828757`, digest `sha256:fe347cafdaff1c6535efabaa1cd2f0c2ae0796f82fb5c1877aea664de1385a40`
- general rendered Linux Compatibility: artifact `10461274417`, digest `sha256:07489578569c306f26c131a06a7d152f5023ebb1928e5e57bf47245864cee578`
- R-V4 camera safety: artifact `10461733880`, digest `sha256:d20957359176df67b4d5aefbb62de88e40c6efda0d116b416c5d55c28e40b920`
- canonical R-V5: artifact `10461809888`; workflow upload digest `sha256:5f68c8a02ff8ae7c15f9ed8b5d546c9f2c21e25fb6cf242b7eba760f714fca68`
- R-V5 full-history diagnostic: artifact `10461724807`, digest `sha256:08d51dac5b867e539961d46eea3714cd8be115788afecd3e6a7660e6f2721992`

The final canonical R-V5 frozen-candidate frame remained byte-identical to the accepted fixed result (`09_refrozen_irregular_final.png` SHA256 prefix `b4d7a4b9...`); the known bad historical final had prefix `67b5c0f7...`.

## Accepted post-R-V5 G8 adversarial session

Authoritative accepted G8:

- run `35139873387` — SUCCESS
- job `104941608091`
- artifact `10464632238`
- artifact digest `sha256:b3b33329160dd6ccc0129453995af39fb830db985e3ac00e0f166356954e7a40`
- frozen runtime: exact `337716db303e94e459cad2b9bcdbfcb8b6c0474b`
- governance harness commit: `828f8ff873e40909056c32b9f7d11fcf00854bde`
- harness mode: `tracked-byte-identical`
- 12 raw checkpoint PNGs
- continuous 212-frame MJPEG AVI at 60 FPS (`3.533333 s`)

Mechanical metrics:

- close-Matter camera arm ratio `1.0000`
- real storage rebase shift `(3, 0, 0)`
- linear rebase solver-state error `0.00000000`
- angular rebase solver-state error `0.00000000`
- topology handoff world error `0.00000061`
- three legal sibling pulses
- sibling displacement `0.9484 m`
- production automatic recovery in `46` frames
- two final live successors

Implementation-context rendered review sampled the whole movie and found no sustained hidden failure, but that judgement is precisely one of the things this independent review must challenge.

### G8 evidence-workflow history

Do not confuse harness/process failures with runtime failures, but inspect them if relevant:

- run `35133682929` stopped before Godot because the workflow incorrectly required the G8 harness to be untracked; the frozen candidate already tracked a byte-identical harness. Candidate and governance harness shared Git blob `94d0c0078c424abf6955d67181c12b1da34f8ba8`. The workflow was corrected without changing frozen runtime.
- run `35139781451` reached the real rehearsal but was cancelled by PR `cancel-in-progress` after a newer governance-only commit; it is not acceptance evidence.
- run `35139873387` is the completed authoritative session.

## Known residuals that must not be hidden

The accepted post-R-V5 continuous movie contains at least these implementation-context observations:

1. **startup transient:** the very first movie frame, before canonical `00_start_static` settles, is an extreme close composition; it clears within the first few frames.
2. **far-airborne weak context:** the deliberately exact far-airborne fixture and subsequent fall keep the actor separated from a small remote world/Matter strip for a bounded interval before automatic recovery. Recovery restores ordinary composition without sustained oscillation in implementation review.
3. **compressed evidence pacing:** the G8 movie is only ~3.53 s because it is deterministic evidence running at Movie Maker cadence, not a standalone UX demonstration.

Do not inherit the implementation context's classification of these as non-material. Decide independently whether any contradicts the Owner goal/current contract, especially in combination with the previous R-V5 camera/support failure history.

## Required falsification questions

At minimum answer these explicitly:

1. Does the evidence directly support the Owner-visible goal, or has the claim narrowed into mechanical correctness plus selected attractive frames?
2. Is any important acceptance property being deferred to “polish”, “later”, or a non-goal without Owner-authorized contract change?
3. Is any quality plane supported only by telemetry/mechanical probes when the claim is inherently rendered or interactive?
4. Are every required gate and every representative scenario actually bound to exact frozen runtime `337716...` rather than inherited from another SHA?
5. Did the post-R-V5 actor-contact repair actually close the deterministic full-history/refreeze failure class, or can support/render composition still fail under equivalent accumulated state?
6. Can composition between camera, interaction, Matter state, motion, topology, storage maintenance and recovery still generate an embarrassing first-minute failure although isolated gates are green?
7. Is base Matter truly solid/readable without overlays under irregular geometry?
8. Is STATIC vs DYNAMIC / split-successor state language readable from pixels rather than only labels/telemetry?
9. Is editing legible enough to understand remove/place/expand and rejection without reconstructing hidden mechanics?
10. Does camera behavior preserve the experiment under real obstruction, edge/min-zoom, far-airborne, split, refreeze and recovery conditions?
11. Does cross-layer/G8 evidence demonstrate causality rather than a disconnected collection of stable endpoints?
12. Is the tracked-byte-identical G8 harness arrangement epistemically sound, and did the workflow correction preserve frozen runtime integrity?
13. Are the startup and far-airborne transients genuinely bounded residuals, or evidence of a broader camera continuity problem?
14. Is there any material defect/evidence gap understated by `quality/p1-owner-readiness.json` or the implementation evidence records?
15. Would you accept this evidence if submitted by another team whose implementation narrative you did not trust?

## Minimum nominal review

Review a non-empty subset including at least:

- default static Matter / form / granularity
- pointer edit target + remove/place/expand feedback
- zero-launch release followed by explicit finite motion
- moving edit + real non-zero storage rebase
- topology split + successor relations
- freeze at current pose / mixed successor state
- accumulated R-V5 irregular geometry through dynamic motion and final refreeze

## Minimum adverse/off-nominal review

Review a non-empty subset including at least:

- real close-Matter obstruction / camera escape
- actor near Space edge / legal minimum zoom
- R-V5 historical deterministic rendered failure and corrected frozen-candidate replay
- far-airborne composition
- production fall/recovery
- topology succession after prior motion and storage rebase
- G8 startup transient and recovery boundary
- G8 workflow/harness integrity correction

## Reviewer output

Do **not** edit the repository or candidate during the review. Return two things to the Owner/implementation context.

### A. Human review

A concise falsification report containing:

- verdict: `PASS` or `FAIL`
- material findings, if any
- non-material observations / residual risks
- exact evidence actually inspected
- explicit judgement of Owner-goal / evidence fit
- explicit judgement of nominal and off-nominal coverage
- whether exact frozen runtime remained the reviewed object
- whether reviewer stayed read-only and separate from implementation

### B. Machine-readable report candidate

Return a complete JSON object compatible with `quality/assurance/p1-independent-review.json`:

```json
{
  "schema_version": 1,
  "campaign_id": "p1-owner-facing-recovery",
  "campaign_contract_version": 4,
  "status": "PASS_OR_FAIL",
  "disposition": "PASS_OR_FAIL",
  "reviewed_runtime_commit": "337716db303e94e459cad2b9bcdbfcb8b6c0474b",
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

If there is any material finding, use `FAIL`; do not produce PASS with the finding hidden in `notes`.

If raw evidence access is insufficient to falsify the claim, the correct result is **not PASS**. State what is missing rather than inferring readiness from implementation summaries.

## Fresh-context instruction

Start a fresh Browser ChatGPT conversation with GitHub access and send only:

> Act as the separate read-only independent assurance reviewer for FrameMatter P1. Read `docs/evidence/p1-independent-assurance-review-packet.md` on branch `rebuild/p1-interactive-foundation`, follow it literally, independently falsify the frozen candidate, do not modify the repo, and return the human review plus the complete machine-readable report candidate it requests.

No implementation-context coaching should be added. The reviewer should retrieve the evidence itself and remain read-only.
