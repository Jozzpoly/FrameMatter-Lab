# P1 cross-layer visible composition rehearsal

Status: **BOUNDED PASS / COMPOSED RUNTIME REHEARSAL**

## Question

> Do the separately defended P1 presentation and mechanics layers still form one readable causal reality when they are exercised together in a single live runtime?

This gate exists because isolated G2–G7/UI PASSes are not enough. A camera can pass in one fixture, interaction in another, motion in a third and UI in a fourth while their composition still becomes confusing when the same Space is edited, released, moved, rebased, split and frozen without resetting the experiment.

## Canonical rehearsal

The rehearsal instantiates the production `res://p1/main.tscn` once and keeps that runtime alive through one causal history:

1. default STATIC authored Space,
2. real off-center production pointer REMOVE target,
3. real REMOVE mutation and local `REMOVED` feedback,
4. zero-launch STATIC→DYNAMIC release,
5. explicit finite translation + yaw,
6. additional Matter edits while the same Space is moving,
7. real out-of-storage PLACE causing a non-zero storage-frame rebase and mapped placement,
8. topology cut on the already moving/rebased Space,
9. two live DYNAMIC successors,
10. sibling-only finite impulse producing independent motion,
11. freeze of only the actor-owned successor while the sibling remains DYNAMIC.

The harness does not replace production mechanics or presentation. It drives existing `P1MatterInteractor`, `P1SpaceControl`, registry, actor, camera, state/grid/target presenters, interaction feedback and compact HUD.

## First rehearsal: mechanically green, visually insufficient

Workflow run `35021063365`, exact source `7fbe60275f2875e47a6905baa710d1c11eb7141e`, passed the whole sequence with zero engine/script errors. Artifact `10417443177`, digest `sha256:ca73def7ab62f85cb3cc4be36e54b96388a6645573825261d123e276be79bb51`.

Mechanically it was valid, including:

- storage rebase shift `(3, 0, 0)`,
- zero linear/angular solver-state error across rebase,
- split handoff world error `0.00000061 m`,
- two successors,
- sibling-only displacement `0.6092 m`.

It was **not accepted as visual PASS**. Human pixel review found that the observation window was too short: released-zero-motion and finite-motion frames were almost indistinguishable, and the sibling-only displacement was too subtle for the sequence itself to carry strong causal meaning.

That was classified as an evidence-fixture weakness rather than a product defect. Runtime/presentation code was left untouched.

## Evidence-fixture correction

The second fixture uses the production-scale Owner torque impulse (`180`) instead of the weaker test torque (`90`), observes the main motion for 36 physics frames instead of 12, and gives the sibling a production-scale finite impulse with a 30-frame observation window. No production/runtime/presentation file changed.

## Accepted exact-source evidence

Workflow run `35021573342`, exact source `35f8cae44e36d3bb5e1ad2451259fece28605b0f`, passed on Windows Godot 4.7.2 Forward+ / D3D12.

Artifact `10418071201`, digest `sha256:f0887db86cdc56263aedf49c929c8c6f608bc97eddc35502bc1f1923ca4b0a7e`.

Mechanical metrics:

- storage rebase shift `(3, 0, 0)`,
- mapped edge cell `(2, 0, 8)`,
- linear solver-state error across rebase `0.00000000`,
- angular solver-state error across rebase `0.00000000`,
- actor handoff world error at topology split `0.00000072 m`,
- sibling-only displacement `1.1929 m`,
- live successors `2`.

Human review of all ten rendered frames found:

- pointer intent and the resulting REMOVE remain locally understandable before lifecycle changes,
- zero-launch release changes state language to DYNAMIC without implying hidden movement,
- finite translation/yaw is visibly different from release and reads against the fixed world grid,
- moving edge edits remain legible while the actor/camera continue riding the Space,
- the non-zero storage-frame rebase does not create a visible world jump; the mapped placement appears as a physical edit rather than a coordinate-system reset,
- immediate topology succession remains understandable as one prior structure becoming two related Spaces,
- the sibling-only impulse produces materially visible relative separation while both successors remain framed,
- freezing the actor-owned successor produces a clear STATIC vs DYNAMIC two-Space endpoint: the actor successor switches to the static/focus language while the sibling retains dynamic amber state,
- compact HUD remains subordinate throughout and does not take over causal explanation.

## Same-source regression closure

The accepted `35f8cae…` source also passed:

- P1 rebuild validation run `35021573353`,
- G4 camera evidence run `35021573293`,
- G5 interaction evidence run `35021573309`,
- G6 world causality evidence run `35021573285`,
- UI hierarchy evidence run `35021573288`,
- general rendered evidence run `35021573431` on Windows D3D12 and Linux Compatibility,
- Owner-readiness verifier run `35021573305`,
- research-harness validation run `35021573299`.

## Gate result

**Cross-layer visible composition PASS within the current P1 authored desktop scenario and deterministic Windows D3D12 rehearsal.**

This gate also closes the previously PENDING representative scenario `moving_edit_and_storage_rebase`: the same dynamic Space is visibly edited, forced through a real non-zero storage rebase, receives its mapped placement, retains actor/camera continuity and then continues into topology succession.

## Explicit nonclaims

This is not yet G8 adversarial rehearsal. It does not claim:

- rapid or intentionally abusive user input,
- close-camera obstacle stress inside the same long sequence,
- fall/recovery inside the same long sequence,
- arbitrary geometry/scales or long-duration stability,
- a frozen final Owner candidate,
- independent assurance,
- final readiness approval.

The next step is adversarial preflight on a deliberately frozen candidate, not another isolated presentation subsystem.
