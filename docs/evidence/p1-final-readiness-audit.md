# P1 final cross-plane readiness audit — PASS

## Verdict

**PASS / AUTHORIZE READY_FOR_OWNER PROMOTION** for frozen runtime candidate:

`b5050b669ec4101226095183929f5790f0a034fc`

This audit is the final governance gate after candidate-wide exact-SHA revalidation, recorded G8 adversarial rehearsal and separate read-only independent assurance. It does not introduce or approve any runtime change.

## Question audited

The final question from the recovery campaign is:

> Would this build honestly demonstrate the system we claim to be researching, or would the Owner still need to mentally reconstruct it from broken/debug pixels?

Final audit judgement: **the frozen candidate now directly demonstrates the contracted P1 research surface well enough for a high-information Owner test.** The Owner is no longer being asked to debug obvious presentation failures that the project could have found autonomously.

This is a bounded P1 Owner-candidate judgement, not a claim of final game art, final UI styling, arbitrary-scale planetary architecture, persistence, arbitrary gravity semantics or vehicle-framework readiness.

## Frozen-object integrity

Frozen runtime: `b5050b669ec4101226095183929f5790f0a034fc`.

Candidate freeze revalidation already showed that all active P1 evidence surfaces were rerun on that exact SHA. A fresh Git compare from the frozen candidate to governance head `387bac9290b04173c5239acd94c6b9a13b84f42b` found 15 later commits but **no post-freeze runtime implementation change**.

Post-freeze changes are limited to:

- G8 workflow/runner and injected test-only harness,
- readiness/assurance verifier and adversarial selftests,
- G8/freeze/assurance evidence,
- campaign/readiness/assurance governance records.

No `p1/*.gd`, scene, resource, physics, camera, interaction or presentation implementation changed after freeze. The added `tests/p1_g8_adversarial_rehearsal_capture.gd` is a governance harness injected as untracked evidence code into a separate exact frozen-runtime checkout; G8 verified tracked runtime bytes before and after execution.

Any future runtime-affecting change invalidates this audit and requires a new frozen candidate/revalidation/assurance chain.

## Contract integrity

Active contract remains immutable v3:

`quality/contracts/p1-owner-facing-recovery.v3.json`

The Owner goal and Owner-visible surface are unchanged. No acceptance property was removed or silently reclassified as polish/non-goal to obtain this PASS. The explicit non-goals remain the same bounded exclusions defined before final promotion.

The quality-system verifier and adversarial selftests are GREEN with the campaign still BLOCKED before this final promotion update. The independent-assurance verifier was corrected before review completion so a genuine completed review can be stored while the campaign remains BLOCKED, without weakening delivery enforcement: final delivery still requires a fully authorized `READY_FOR_OWNER` manifest, approved frozen runtime, PASS assurance gate and zero blockers.

## Exact-candidate evidence closure

Candidate-wide freeze revalidation on `b5050b669…` recorded SUCCESS for:

- Owner-readiness validation: run `35022042990`,
- full P1 rebuild/foundation: run `35022042985`,
- G6 world causality: run `35022042983`,
- G5 interaction: run `35022042895`,
- UI hierarchy: run `35022042896`,
- G4 camera: run `35022043026`,
- cross-layer visible rehearsal: run `35022043017`,
- research-harness validation: run `35022043157`,
- general rendered evidence: run `35022043031` on Windows D3D12 and Linux Compatibility.

The candidate-native evidence re-earned the contracted planes rather than inheriting historical PASSes from different commits:

- mechanical integrated runtime,
- rendered parity,
- form/depth readability,
- Matter granularity,
- STATIC/DYNAMIC state semantics,
- camera composition,
- interaction hierarchy,
- world/motion/topology causality,
- compact UI hierarchy,
- cross-layer visible composition.

## Representative scenarios

Every v3 representative scenario is directly covered on the frozen runtime:

- `default_static_matter`,
- `edit_target_remove_place_expand`,
- `zero_launch_release`,
- `dynamic_translation_and_yaw`,
- `moving_edit_and_storage_rebase`,
- `topology_split_and_successor_relations`,
- `freeze_at_current_pose`,
- `close_camera_obstacle_stress`,
- `actor_near_space_edge`,
- `fall_and_recovery`.

Coverage is composed as well as isolated. Cross-layer evidence keeps one runtime alive through edit → release → finite motion → moving edit → storage rebase → split → sibling drive → freeze. G8 extends the same principle through close-camera pressure, rapid edits and production automatic fall recovery.

## G8 adversarial closure

Accepted recorded G8 evidence:

- run `35023685435`,
- artifact `10419060205`,
- digest `sha256:8ff548dffffe71a5aca73a248066e3a1aac61b2db9361df418c94554503e0ccb`,
- 12 checkpoint PNGs,
- 212-frame continuous MJPEG AVI.

The first G8 attempt `35023279772` was rejected when one legal sibling pulse produced only `0.1395 m` of displacement and failed to demonstrate materially readable independence. The retry did not lower the existing `>0.75 m` acceptance criterion or alter the frozen runtime. It used three repetitions of the same legal production-scale finite impulse and a longer bounded observation window, reaching `0.9484 m`.

Accepted metrics also showed:

- close-Matter camera arm ratio `1.0000`,
- real storage shift `(3, 0, 0)`,
- zero measured linear/angular solver-state error across rebase,
- topology handoff world error `0.00000061`,
- production automatic recovery in 46 frames,
- two final live successors.

Manual temporal review did not reveal a sustained production transition failure hidden between checkpoints.

## Independent assurance

Separate read-only falsification context:

`p1-ia-browser-20260915T2321+0200-b5050b66`

Independent verdict: **PASS**, zero material findings.

Authority:

- `quality/assurance/p1-independent-review.json`
- `docs/evidence/p1-independent-assurance.md`

The reviewer independently inspected raw candidate-native artifacts, both G8 attempts, both harness versions and the full accepted 212-frame movie. It explicitly evaluated Owner-goal/evidence fit, nominal and off-nominal scenarios, exact frozen-runtime provenance, the G8 retry, near-wall fixture transient and recovery-boundary weak-context frames.

The reviewer remained read-only and authored no candidate/repository changes during review.

## Residual risks retained, not hidden

The final audit preserves the independent review's non-material residuals:

1. **Recovery margin:** a few frames immediately before production automatic recovery approach the limit of remote-context readability, but do not become sustained failure; recovery reacquires context without visible oscillation.
2. **Instant relocation continuity:** arbitrary teleport-camera continuity is not currently defended. The G8 fixture relocation demonstrates that instantaneous relocation can create a brief extreme close-up. If teleportation becomes a production mechanic, this becomes a new explicit camera contract rather than inheriting the current PASS.
3. **G8 pacing:** the 3.53 s scripted movie is compressed evidence, not a standalone UX demonstration. Its evidential value depends on the staged G4/G5/G6/UI/cross-layer captures and mechanical corroboration.

None contradicts the current v3 Campaign Contract.

## Governance drift reconciliation

Independent assurance correctly identified stale historical wording in `docs/p1-owner-facing-recovery-campaign.md` that still described UI work as next and said not to freeze G8.

That live-document contradiction was removed before this audit was concluded. The campaign now states the actual state: frozen candidate, G8 PASS, independent assurance PASS, final readiness audit active. No historical evidence record was rewritten to pretend those stages happened earlier.

## Negative-baseline comparison

The first P1 Owner candidate demonstrated that mechanically green does not imply a trustworthy Owner research instrument. The current candidate materially addresses the failure classes that made that candidate unacceptable:

- catastrophic black/white form collapse,
- missing cell-scale edit language,
- through-wall/debug target presentation,
- telemetry-dominated default HUD,
- weak STATIC/DYNAMIC semantics,
- visually weak motion/world reference,
- catastrophic local camera compression,
- insufficient cross-layer causal evidence.

The final candidate is not being promoted because those issues were reclassified as polish. They received direct rendered/interactive evidence on the exact frozen runtime.

## Final promotion decision

No material cross-plane contradiction, stale runtime binding, contract relaxation, representative-scenario gap, unresolved required gate defect or understated known blocker remains.

Therefore the final audit authorizes the governance manifest to:

- set `independent_assurance_review` to PASS on `b5050b669…`,
- set `final_readiness_audit` to PASS on `b5050b669…`,
- set `approved_runtime_commit` exactly to the frozen candidate SHA,
- clear `open_blockers`,
- set `promotion_authorized=true`,
- authorize the Owner attention event,
- set campaign status to `READY_FOR_OWNER`.

The branch/PR remains separate from `main`; `READY_FOR_OWNER` authorizes an Owner candidate/test, not an automatic merge.
