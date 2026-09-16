# P1 G8 adversarial rehearsal — PASS

## Verdict

**PASS** for frozen runtime candidate `b5050b669ec4101226095183929f5790f0a034fc`.

G8 was executed as an external governance harness against an exact checkout of the frozen runtime rather than against the moving branch head. The workflow verified the candidate SHA before execution, injected only one untracked test script, and verified that no tracked candidate byte changed after the rehearsal.

This gate is intentionally stronger than the earlier isolated quality planes. One live canonical `p1/main.tscn` runtime was kept alive while close-camera pressure, rapid Matter edits, static→dynamic release, finite translation/yaw, edit-under-motion, non-zero storage rebase, topology succession, independent successor motion, mixed STATIC/DYNAMIC successor state, far-airborne composition and production automatic fall recovery were composed in one recorded session.

## Accepted evidence

- Frozen runtime: `b5050b669ec4101226095183929f5790f0a034fc`
- Governance harness: `5f900335ce664bd069d0c21418984b5a134fc431`
- Workflow: `P1 G8 adversarial rehearsal`
- Accepted workflow run: `35023685435`
- Artifact: `FrameMatter-P1-G8-Adversarial-Frozen-Candidate-Windows`
- Artifact ID: `10419060205`
- Artifact SHA-256: `8ff548dffffe71a5aca73a248066e3a1aac61b2db9361df418c94554503e0ccb`
- Platform: Windows Server 2025
- Engine: Godot 4.7.2
- Renderer: Forward+ / D3D12 / Microsoft Basic Render Driver
- Continuous recording: MJPEG AVI, 1280×720, 60 FPS, 212 frames, 3.533 s, 8,029,032 bytes
- Checkpoints: 12 rendered PNGs spanning the complete evaluated sequence

## Mechanical/runtime result

The accepted run emitted `P1_G8_ADVERSARIAL_REHEARSAL_PASS` and `P1_G8_MOVIE_PASS`, with no engine/script error floor violation.

Measured state:

- close-Matter SpringArm ratio: `1.0000`
- real storage-frame shift: `(3, 0, 0)`
- linear solver-state error across moving rebase: `0.00000000`
- angular solver-state error across moving rebase: `0.00000000`
- actor world handoff error across topology succession: `0.00000061`
- sibling finite pulses: `3`
- independent sibling displacement: `0.9484 m`
- production automatic recovery: `46` frames
- final live successors: `2`

The frozen runtime remained at the exact candidate SHA before and after execution. The only runtime working-tree addition was the injected untracked G8 capture script.

## First-run falsification and why acceptance was not relaxed

The first G8 attempt, workflow run `35023279772`, was **not accepted**. It completed the rest of the session but produced only `0.1395 m` of sibling displacement after one legal finite pulse, below the existing `> 0.75 m` material-independence criterion. Pixel review confirmed that the immediate-split and sibling-driven checkpoints were visually too similar.

The criterion was not weakened. Instead, the test stimulus was strengthened without changing the frozen runtime: the accepted harness applies three repetitions of the same legal production-scale finite pulse with bounded gaps and a longer observation window. The accepted run then reached `0.9484 m`, making successor independence materially visible while preserving the original threshold.

This is treated as a harness/stimulus correction, not a product fix and not an acceptance relaxation.

## Manual rendered review

All 12 accepted checkpoint PNGs were reviewed at artifact resolution together with dense temporal samples from the 212-frame movie.

Findings:

- The real Matter near-wall state remains readable and does not collapse into sustained SpringArm close-up.
- Rapid remove/restore edits do not destabilize the settled near-wall composition or produce a topology accident.
- Zero-launch release remains visually and mechanically distinct from the later finite-motion phase.
- Moving edge edits and the subsequent real non-zero storage rebase preserve world continuity; there is no visible rebase jump.
- Immediate topology succession remains understandable as two related successors rather than an unexplained replacement.
- The strengthened finite-pulse phase creates visibly meaningful successor separation before the mixed-state endpoint.
- The mixed endpoint is readable: the actor-owned successor freezes to STATIC presentation while the sibling remains DYNAMIC.
- The far-airborne checkpoint keeps both the actor and relevant world/Space relation readable rather than reducing the context to the historical thin-line failure.
- Production automatic fall recovery triggers after 46 frames and reacquires the frozen actor-owned successor and coherent camera composition without oscillation.

### Temporal-review qualification

The continuous movie also exposed a short extreme close-up during deterministic **test-only relocation** used to place the actor into the near-wall fixture. Inspection of the exact frames showed that this transient occurs during the harness's instantaneous actor repositioning, before the evaluated settled near-wall stress checkpoint. It is not produced by a production movement/control path and does not recur during the evaluated rapid-edit, finite-motion, rebase, split, mixed-state, fall or automatic-recovery phases.

That interval is therefore recorded as a fixture artifact, not silently omitted and not treated as evidence of acceptable production camera behavior. The accepted claim is bounded to the production/runtime transitions actually under test. A future test that wants to claim arbitrary teleport-camera continuity would need a separate contract rather than inheriting this PASS.

Near the automatic-recovery threshold, the movie contains one boundary frame where remote context is nearly lost as the actor reaches the recovery depth. Recovery then fires and camera context is reacquired smoothly over the following frames. Given that this occurs at the production recovery boundary and does not produce oscillation or sustained unusable framing, it is not material to the current G8 contract.

## Gate scope and remaining boundaries

This PASS establishes that the frozen P1 candidate survives the required composed adversarial session with rendered and temporal evidence. It does **not** authorize Owner delivery by itself.

The campaign must remain `BLOCKED` until both remaining independent governance gates pass:

1. `independent_assurance_review`
2. `final_readiness_audit`

No runtime change is authorized by this evidence. Any change to the frozen candidate invalidates the current candidate-bound review chain and requires a new freeze/revalidation cycle.
