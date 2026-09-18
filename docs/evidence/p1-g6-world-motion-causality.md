# P1 G6 — world / motion / topology causality

Status: **BOUNDED PASS / COARSE WORLD DATUM PROMOTED**

Verified runtime/evidence commit: `5a4f9bbc57742e6bb4561a199ec5d95761e72ef9`

G6 asks an observable-causality question rather than a physics-data question:

> can an informed reviewer see real release, translation, yaw, topology succession and freeze relative to a stable world without reconstructing motion from HUD telemetry?

The bounded answer is **yes for the current authored P1 scene, finite-control sequence and Windows D3D12 Forward+ evidence path**.

This is not a claim that motion presentation, world art or camera feel are final.

## Starting failure

Before G6, the mechanical substrate already had real finite rigid motion and real topology succession, while G3-S distinguished STATIC from DYNAMIC. The rendered world did not explain those mechanics well enough.

`WorldReference` was a largely uniform grey plane plus a small origin marker. Because the camera follows the actor/relevant Space, translation and yaw could read mainly as changes against the viewport rather than motion through a stable world. The HUD velocity/angular-velocity telemetry was therefore doing explanatory work that should belong to world pixels.

The problem was not missing physics. It was missing stable spatial reference.

## Bounded hypothesis

G6 deliberately did **not** add motion streaks, arrows, trails or other effects that could fake causality.

The challenger was a presentation-only coarse world datum attached to the real authored `WorldReference`:

- 4 m minor spacing,
- stronger line every 8 m,
- subdued dark blue-grey values,
- ordinary depth testing,
- fixed to the world rather than to Matter or camera,
- no ownership of Matter, Space, provider, collision, topology or motion state.

This is intentionally much coarser than the one-cell Matter surface grid. The two grids communicate different scales: local editable Matter versus stable world distance/orientation.

## A/B result

The dedicated exact-source G6 harness captured the same real sequence with the canonical world datum hidden (`baseline`) and visible (`coarse_grid`).

Pixel review found the coarse datum materially better:

- static/release frames remain quiet rather than turning into a debug floor,
- translation gains visible parallax against fixed world lines,
- yaw becomes easier to read as the Space rotates relative to stable world axes,
- split successors retain a shared world reference while developing independent rigid motion,
- after freeze, the static successor staying on fixed world lines is distinguishable from the camera merely tracking it.

The datum therefore explains real solver motion rather than manufacturing apparent motion.

The promoted implementation is `P1WorldReferencePresentation`, a child of canonical `WorldReference`. The final A/B harness uses this exact production presenter in both lanes and changes only its visibility.

## Real causal sequence

The final G6 capture does not manufacture poses or successors. It drives the existing production APIs through:

1. authored STATIC Space,
2. STATIC → DYNAMIC release with zero requested launch velocity,
3. finite central impulse plus finite torque impulse,
4. real destructive seam edit through the production interactor,
5. real connected-component topology succession into two live Spaces,
6. additional finite impulse/torque applied to only the non-actor sibling,
7. STATIC freeze of the actor/focus successor at its current transformed pose,
8. continued simulation of the still-DYNAMIC sibling.

Final exact-source Windows D3D12 run `35018041141` on `5a4f9bbc57742e6bb4561a199ec5d95761e72ef9` passed both baseline and coarse-grid lanes.

Promoted coarse-grid artifact:

- artifact ID `10416865371`,
- SHA-256 `8fda7112a7454c2d3cea4415d1560c5723eb7b1a7ed75d3eb51ebee5fe64ad3f`.

Baseline artifact:

- artifact ID `10416522449`,
- SHA-256 `53b2608d44ab7da445250c4d05114c7c309531fa4cb52499eed8fbbcbdf97035`.

Representative causal metrics from the promoted lane:

- release: `pose_error=0.00000000`, `linear=0.000000`, `angular=0.000000`,
- late finite motion: `origin=(-8.414648, 0.047859, 0.281074)`, `yaw=1.5398`,
- post-split sibling-only drive: actor successor moved `3.9533 m`, sibling moved `6.0033 m`, producing `2.0500 m` additional relative separation,
- freeze request → commit legal phase advance: `0.01125639`,
- provider-replacement pose jump at the actual commit boundary: `0.00000000`,
- newly frozen settle drift: `0.00000000`,
- later frozen drift: `0.00000000`,
- still-DYNAMIC sibling motion during that same post-freeze window: `7.8291 m`.

The numbers defend physical truth; rendered review defends whether that truth is understandable.

## Evidence-harness correction

The first G6 run produced a useful false failure. The harness compared the dynamic pose at the instant an asynchronous freeze request was issued with the pose after provider-transition commit and treated roughly 11 mm of final legal solver advance as a reset.

That contradicted the repository's already-defended lifecycle semantics. Existing freeze evidence explicitly separates:

- legal dynamic phase advance before the physics-boundary commit,
- synchronous pose continuity at the freeze/provider-transition boundary.

`LocalMatterSpace` snapshots the outgoing provider transform at commit and installs the replacement provider at that exact transform.

The G6 harness was corrected accordingly rather than loosening a threshold or changing the product. It now records request→commit phase advance as telemetry and strictly checks outgoing→incoming provider continuity at the actual transition boundary.

The corrected result is zero transition jump and zero frozen drift.

## Same-source regression closure

The canonical promotion was re-tested on the same runtime commit `5a4f9bbc57742e6bb4561a199ec5d95761e72ef9`.

- P1 rebuild validation run `35018041119`: full foundation and Windows composed-scene diagnostic PASS.
- G4 camera run `35018041035`: PASS.
- G5 interaction run `35018041184`: PASS.
- General rendered visual evidence run `35018041103`: Windows D3D12 and Linux Compatibility PASS.
- G6 run `35018041141`: baseline and promoted coarse-grid lanes PASS.
- Owner-readiness validation and research-harness validation: PASS.

Manual spot review of the same-source G4, G5 and general rendered artifacts found the world datum subordinate to local Matter/state/target cues. It did not regress the defended G2 form, G3 cell granularity, G3-S state semantics, G4 composition or G5 interaction hierarchy.

## What G6 establishes

Within the current authored P1 scene and tested scenario/render path:

- the world now supplies a subdued stable scale/orientation/parallax reference,
- release changes representation/state without hidden launch,
- finite solver-owned translation and yaw are readable relative to the stable world,
- destructive editing produces real related-but-independent successor Spaces,
- one successor can receive additional finite drive and visibly diverge from its sibling,
- freeze preserves the current commit-boundary pose rather than visually resetting the Space,
- a frozen successor can remain fixed while its still-dynamic sibling continues through the same world.

Gate result: **world / motion / topology causality PASS within the current P1 authored scene, finite-control sequence and Windows D3D12 evidence path.**

## Explicit nonclaims

G6 does **not** establish:

- final world art or environmental scale language,
- arbitrary world/Space scales or dense environments,
- final motion-control design,
- final camera/game feel,
- final UI hierarchy,
- controller/touch/VR presentation,
- a combined moving-edit + storage-rebase Owner scenario,
- cross-layer rehearsal quality,
- Owner readiness.

The coarse world datum remains replaceable if later evidence finds a stronger low-noise language.

## Next move

Proceed to the renderer/host viability checkpoint only as an evidence-triggered decision. G2–G6 have now reached bounded professional readability using ordinary Godot facilities, so a host-switch comparison should be built only if the checkpoint finds a material renderer/host limitation rather than from historical frustration.
