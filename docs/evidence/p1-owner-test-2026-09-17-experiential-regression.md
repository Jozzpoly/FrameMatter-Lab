# P1 Owner test — 2026-09-17 experiential regression

Status: **MATERIAL OWNER FAIL / PROMOTION REVOKED / CAMPAIGN REOPENED**

Runtime tested:

`337716db303e94e459cad2b9bcdbfcb8b6c0474b`

Delivery run:

`35224171396`

Governance state that authorized the test:

`2e5b63564a9586e1fdee09ecae89cffb2e908c99`

## Executive finding

The packaged contract-v4 P1 candidate passed the frozen-runtime mechanical, rendered, adversarial, assurance and delivery chain, but the direct Owner test materially falsified the promotion judgement.

The failure is not limited to visual polish. The candidate regresses the intended FrameMatter sandbox pressure and does not satisfy the existing G8 requirement that a new Owner candidate be clearly superior to P0.5 as an observable research instrument.

Promotion is therefore revoked. PR #1 remains unmerged. The runtime remains useful historical substrate evidence but is not an acceptable Owner candidate or current product direction.

## Owner-facing failures observed

The direct test exposed the following material problems:

1. **Experiential regression versus the earlier baseline.** The current surface feels less alive and less immediately manipulable than earlier demos/P0.5. Earlier work visibly demonstrated moving Matter; the current default starts as an inert special Matter island and requires laboratory controls before motion becomes apparent.
2. **The visible world is split into two incompatible affordance classes.** The large grey `WorldReference` looks and collides like ordinary terrain, but it is not Matter and cannot be removed from or built onto. The interaction ray only accepts colliders that resolve through `P1SpaceRegistry` to a live `LocalMatterSpace`.
3. **The scene ontology is backwards relative to the recurring product pressure.** The research target is ordinary editable Matter from which local moving/static Spaces can emerge while preserving Matter identity. P1 instead presents one special `LocalMatterSpace` beside a separate non-Matter reference floor.
4. **Directness regressed.** P0.5 exposed direct `LMB` remove / `RMB` place and an immediately understandable moving-Space loop. Current P1 uses modal `E` REMOVE/PLACE plus `LMB` apply and separate state/motion controls. That may be defensible for a laboratory sequence, but in direct use it increases ceremony and weakens sandbox immediacy.
5. **The candidate is not clearly superior to P0.5.** The current visual-acceptance contract explicitly required this before G8 promotion. The final readiness audit authorized the candidate without a persuasive direct side-by-side experiential comparison establishing that condition.

## Code-level confirmation

The normal-looking terrain is intentionally outside Matter authority:

- `p1/main.tscn` defines `WorldReference` as a separate `StaticBody3D` with mesh and collision.
- `p1/world_reference_presentation.gd` explicitly states that the reference owns no Space or Matter state.
- `p1/matter_interactor.gd` resolves a raycast collider through `P1SpaceRegistry.find_space_for_node()` and clears/returns when no live `LocalMatterSpace` owns the hit.

Therefore the inability to build on the visible reference terrain is not an incidental pointer bug. It follows from the current scene model.

## What remains valid

This Owner FAIL does **not** erase bounded technical evidence already earned on `337716...` for:

- logical Matter identity independent of engine representation,
- logical Space/provider separation,
- static/dynamic provider replacement,
- volumetric actor/support work,
- moving Matter edits,
- bounded storage rebase,
- topology succession,
- refreeze/support recovery,
- mesh/render correctness findings,
- exact frozen-runtime delivery provenance.

Those results remain candidate donor mechanisms. They no longer justify the current Owner-facing composition or promotion judgement.

## Process finding

This is a second-order quality-system failure.

The first P1 Owner failure showed that hidden mechanical correctness could coexist with a visibly broken Owner surface. Q0 then strengthened rendered and promotion evidence. The second Owner test shows that the corrective system overfit those visible failure classes while still allowing **experiential/product-pressure regression**.

Two distinct failures occurred:

- contract-v4 representative scenarios did not directly encode ordinary-world editability or positive regression pressure against the best earlier Owner baseline;
- the visual acceptance contract *did* require clear superiority to P0.5, but the final audit treated that judgement as satisfied without performing a convincing direct comparison.

The remedy is not another large governance campaign. The immediate priority is to recover the product-pressure loop and use the existing substrate as subordinate machinery.

## Recovery constraint

Before another Owner candidate is considered, internal work must demonstrate a bounded vertical slice that is plainly more FrameMatter-like from first contact:

> ordinary editable Matter world → direct dig/build → visible moving Matter/Space → ride/interact → edit while moving → understandable topology/motion consequence.

The slice may remain small and authored. It may not present a large world-looking surface that is outside the Matter interaction rules, and it may not regress the immediacy or visible life already present in earlier experiments.

A future readiness judgement must include an actual side-by-side experiential comparison against the strongest earlier Owner baseline, not merely a checklist of current-candidate gates.
