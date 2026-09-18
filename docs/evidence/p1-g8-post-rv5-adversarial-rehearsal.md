# P1 post-R-V5 G8 adversarial rehearsal

Status: **PASS / FROZEN RUNTIME SURVIVED MECHANICAL + RENDERED ADVERSARIAL REVIEW**

Frozen runtime:

`337716db303e94e459cad2b9bcdbfcb8b6c0474b`

Active contract:

`quality/contracts/p1-owner-facing-recovery.v4.json`

This is a new post-R-V5 evidence record. It does not rewrite the historical G8 evidence for the superseded `b5050b...` candidate.

## Why G8 was rerun

R-V5 exposed a deterministic rendered/session failure that the old candidate-wide campaign had not caught: after accumulated geometry entropy and a DYNAMIC→STATIC refreeze, actor support could be lost even while the camera arm metric looked mechanically healthy, producing an avatar-only / dark final composition. The root cause was repaired in actor contact semantics, promoted into a regression gate, and requalified through R-V5 before a new candidate was frozen.

G8 therefore had to be re-earned on the new exact runtime rather than inherited from the superseded candidate.

## Frozen-runtime integrity

Authoritative accepted run:

- workflow run: `35139873387`
- job: `104941608091`
- artifact: `10464632238`
- artifact digest: `sha256:b3b33329160dd6ccc0129453995af39fb830db985e3ac00e0f166356954e7a40`
- governance harness commit: `828f8ff873e40909056c32b9f7d11fcf00854bde`
- frozen runtime checkout: `337716db303e94e459cad2b9bcdbfcb8b6c0474b`
- renderer: Godot 4.7.2 Forward+ / D3D12 on Windows

The frozen runtime already tracked `tests/p1_g8_adversarial_rehearsal_capture.gd`. Governance and runtime copies had identical Git blob SHA `94d0c0078c424abf6955d67181c12b1da34f8ba8`; the corrected workflow therefore used `harness_mode=tracked-byte-identical` rather than pretending the harness was untracked. The runtime working tree remained clean and HEAD remained the exact frozen SHA before and after execution.

An earlier post-freeze attempt (`35133682929`) was rejected before Godot because the workflow incorrectly assumed the harness must always be injected as an untracked file. That was an evidence-workflow defect, not a runtime result. A subsequent run (`35139781451`) reached the real rehearsal but was cancelled by PR concurrency when a governance-only commit started a newer run; it is not acceptance evidence.

## Executed adversarial history

One live canonical runtime was kept alive through:

1. default STATIC Matter,
2. real close-Matter camera pressure,
3. rapid remove/restore edit burst while still in difficult composition,
4. zero-launch STATIC→DYNAMIC release,
5. finite translation + yaw,
6. moving edge edits,
7. non-zero storage-frame rebase while motion remained active,
8. topology succession into two live Spaces,
9. sibling-only finite motion proving independent successors,
10. freeze of only the actor-owned successor while sibling remained DYNAMIC,
11. exact far-airborne state with no fake support,
12. production automatic fall recovery and reacquisition.

The accepted run produced 12 checkpoint PNGs plus a continuous 212-frame, 60 FPS MJPEG recording (`3.533333 s`).

## Mechanical result

The accepted metric was:

- close-Matter camera arm ratio: `1.0000`,
- storage-frame shift: `(3, 0, 0)`,
- linear solver-state error across rebase: `0.00000000`,
- angular solver-state error across rebase: `0.00000000`,
- topology handoff world error: `0.00000061`,
- sibling finite pulses: `3`,
- sibling displacement: `0.9484 m`,
- automatic recovery: `46` frames,
- final live successors: `2`.

The runtime emitted `P1_G8_ADVERSARIAL_REHEARSAL_PASS` and the workflow completed SUCCESS.

## Rendered review

The implementation context independently reviewed all 12 candidate-native checkpoints and sampled the complete continuous movie densely enough to inspect every transition class, including per-few-frame review around startup/near-wall pressure and the full far-airborne→recovery interval.

Findings:

- base Matter remains opaque and spatially coherent; the old hollow/debug-shell failure does not return,
- settled close-Matter stress retains useful world context instead of catastrophic SpringArm compression,
- rapid edit pressure does not destabilize form/state presentation,
- zero-launch release and finite motion remain visually causal,
- moving rebase does not create a visible world jump,
- split succession remains continuous and both successors stay legible,
- sibling-only motion is materially visible rather than merely a telemetry claim,
- mixed STATIC/DYNAMIC successor state remains understandable,
- no R-V5-style avatar-only/dark refreeze failure occurs at or after freeze,
- the far-airborne interval intentionally provides weak remote context but still retains a visible remote world/Matter relation,
- automatic recovery reacquires a useful third-person composition without sustained oscillation or a blank-world interval.

No hidden sustained rendered failure was found between the checkpoint frames.

## Residuals retained explicitly

Two transient weaknesses remain visible in the continuous recording:

1. **startup camera transient** — the very first movie frame, before the canonical `00_start_static` checkpoint settles, is an extreme close composition. It clears within the first few frames and does not recur in the evaluated production-driven sequence.
2. **far-airborne weak context** — during the deliberately exact far-airborne fixture and subsequent fall, the actor is separated from the remote world by a large dark field for roughly the bounded pre-recovery interval. The remote world remains visible as a distant strip/structure and production recovery restores the normal relation without oscillation. This is not being claimed as final cinematography.

These are preserved for independent assurance to judge rather than silently classified away.

## Verdict

**G8 PASS for frozen runtime `337716db303e94e459cad2b9bcdbfcb8b6c0474b`.**

This closes the implementation-context adversarial rehearsal gate only. It does **not** authorize Owner delivery. Campaign state must remain BLOCKED until a fresh separate read-only independent assurance review under contract v4 and a subsequent final cross-plane readiness audit both pass on this exact frozen runtime.
