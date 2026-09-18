# P1 R-V5 chaotic Owner-surface rehearsal

Status: **PASS AFTER MATERIAL FINDING / ROOT-CAUSE REPAIR QUALIFIED**

Qualified runtime commit: `5b16759d0c5dbfda36f7f48a80e3498c5db8719e`

Production contact-semantics repair: `d6f798ca760ac8c1cee85a4e541d0e0d3bd8511e`

Acceptance renderer: **Godot 4.7.2 Forward+ / D3D12 on windows-latest**

Canonical qualified R-V5 workflow: run `35131429145`, artifact `10461343616`

Full-history diagnostic workflow: run `35131429394`, artifact `10460904022`

Reduced refreeze diagnostic workflow: run `35131429143`

Foundation qualification: P1 rebuild run `35131429202`

## Purpose

R-V5 was introduced because tidy, isolated presentation gates had not proved that the composed P1 research instrument remained truthful after sustained Owner-like entropy. The canonical rehearsal accumulates 26 non-restored edits (12 REMOVE + 14 PLACE), retains holes, concavities, protrusions, steps and narrow features, exercises near/mid camera composition and real REMOVE/PLACE targeting, then releases the already-irregular Space to DYNAMIC motion and finally refreezes it without resetting the authored session.

The rehearsal succeeded as an adversarial instrument by finding a material runtime defect that the shorter orderly gates had not exposed.

## Initial material finding

The original full R-V5 scenario completed its mechanical script but the final `09_refrozen_irregular_final.png` rendered the actor against an effectively empty/dark scene instead of the irregular Matter world.

The failure was deterministic rather than a CI or solver flake:

- the pre-refreeze `08_dynamic_irregular_near.png` remained pixel-identical across reruns,
- the failed final `09_refrozen_irregular_final.png` also remained pixel-identical across reruns,
- failed final SHA256: `67b5c0f73b781569844108ba9608a7399b670efc6a9e98a868c33a2607cf0417`.

R-V5 therefore became **FAIL / material finding** and Owner readiness remained blocked.

## Falsified hypotheses

### Provider refreeze continuity

A reduced diagnostic reproduced the same dirty geometry, DYNAMIC motion and DYNAMIC→STATIC replacement while measuring provider transforms, actor support and camera context.

Provider replacement preserved pose exactly at the transaction boundary, the actor rebound to the new STATIC provider, support reconstruction error remained effectively zero and the final camera reset remained readable.

Conclusion: provider replacement itself was not the root cause.

### Movie Maker cadence

The same reduced diagnostic was rerun under `--write-movie` / fixed 30 FPS. Its state metrics and final readable frame were unchanged.

Conclusion: Movie Maker cadence was not the root cause.

### Camera policy

Full-history telemetry showed that the camera was following the actor consistently. At the failed final state the Matter provider remained near its expected world pose while the player had fallen to approximately `y=-11.21`, was no longer grounded and had no support relation.

Conclusion: the bad image was an honest presentation of a physical actor-support failure, not a camera-composition failure. R-V4 was not reopened by this finding.

## Root cause

Frame-by-frame monitoring after the final refreeze localized the failure to `SpaceQueryCharacter` persistent-ground semantics.

The controller used `PhysicsDirectSpaceState3D.cast_motion()` as its sole ground validator. Godot's shape-cast contract does not report shapes that already overlap the query shape. As tiny contact drift moved the capsule from a near-zero sweep contact into a shallow current overlap, the downward sweep changed to `(1, 1)` — interpreted by the controller as “no floor”. The controller detached support and entered free fall. The same blind spot later allowed the falling capsule to pass through the world reference floor after entering overlap there as well.

In the original full-history trace the actor stayed coherent for more than one hundred frames after refreeze before this classification boundary was crossed. That explains why shorter provider-transition checks did not expose the defect.

## Minimal RED regression

`tests/p1_actor_overlap_ground_regression.gd` isolates the failure from R-V5 presentation complexity.

A capsule starts only `1 mm` inside an ordinary static Matter floor. Before the repair it fell through the floor and ended ungrounded with no logical support. Existing volumetric actor tests remained GREEN, proving that the new gate isolated a missing contact state rather than broadly invalidating actor movement.

The same regression also walks the actor beyond a finite floor edge and requires support to release. This prevents the overlap repair from becoming sticky-ground authority.

## Production repair

Commit `d6f798ca760ac8c1cee85a4e541d0e0d3bd8511e` makes ground validation overlap-aware without introducing a timer, teleport, depenetration hack or R-V5 special case.

The normal downward `cast_motion()` path still has priority. Only when the sweep reports no future ground contact does the controller query `get_rest_info()` at the current capsule pose. A current intersection is accepted as ground only when it has a valid collider/support frame and the returned normal satisfies the existing `ground_normal_min_y` contract.

A true floor edge still releases support because there is neither a sweep hit nor a current ground-like overlap.

## Post-repair full-history evidence

The exact full-history diagnostic on the qualified runtime remained grounded through the old failure boundary.

At frame `119` after refreeze:

- `short_cast=(1.000000,1.000000)` — the exact class of condition that previously detached the actor,
- `grounded=true`,
- logical `support_space` still equals the irregular Space,
- `support_body` still equals the current STATIC provider,
- provider still owns 23 collision shapes.

At frame `143` the same relation remained coherent.

Final `09_refrozen_irregular_final` telemetry:

- player `y=1.902329`,
- `grounded=true`,
- `support_space_same=true`,
- `support_equals_provider=true`,
- `support_world_error=0`,
- Matter center remains visible in the viewport at approximately `(0.5342, 0.5873)`,
- camera desired and actual arm both `8.1311 m`.

The diagnostic monitor now terminates cleanly at scene teardown instead of producing a post-PASS freed-instance error.

## Canonical promoted guard

The canonical R-V5 rehearsal now checks the actor after the complete final interval: 90 refreeze dwell frames followed by camera reset and another 60 frames. It requires:

- grounded actor,
- unchanged logical Space support,
- support on the current STATIC provider,
- actor/support anchor error below `1 mm`.

On exact runtime `5b16759d0c5dbfda36f7f48a80e3498c5db8719e`, canonical run `35131429145` reports:

`final_support_error=0.00000012 m`

and completes with `P1_RV5_CHAOTIC_OWNER_SURFACE_PASS`.

The full P1 rebuild on the same runtime (`35131429202`) is GREEN, including the new shallow-overlap/edge-release regression, the existing volumetric actor challenger, storage/frame continuity, camera-control separation, finite control and the integrated causal loop.

## Rendered qualification

The repaired final frame was manually reviewed as a readable wide view of the accumulated irregular Matter world with the actor remaining on the surface. The old avatar-only/dark failure is absent.

The canonical exact-head artifact and the independent full-history diagnostic produce the same final image.

Qualified final `09_refrozen_irregular_final.png` SHA256:

`b4d7a4b9ce06b1e8aa4cd02696b7df1214d65752c997228f3c5fc528d31156ac`

The pre-refreeze `08_dynamic_irregular_near.png` remains unchanged from the failed scenario:

`7487f826e2b4373486cc85fa990761f542d256bce345f74299953ee11e6eece9`

This is important causally: the same full authored history reaches the same pre-refreeze rendered state, while the contact-semantics repair changes the formerly failed final outcome into the coherent world view.

## Verdict

**R-V5 PASS within the current P1 authored corpus and Windows Forward+ / D3D12 acceptance path.**

The material finding was not hidden or reclassified as presentation noise. R-V5 exposed a missing physical contact state, that state received a minimal RED regression, the production semantics were repaired without scenario-specific authority, and the complete chaotic rehearsal was re-qualified mechanically and visually.

R-V0/R-V1/R-V3/R-V4 remain defended within their existing scopes. In particular, R-V4 camera policy is not reopened by this finding because the camera was shown to be reporting the actor's real fall rather than causing it.

## Nonclaims

R-V5 does not prove:

- arbitrary planetary-scale geometry or world sizes,
- a universal character controller for every penetration/contact topology,
- controller/touch/VR interaction,
- final art direction,
- final authored-material architecture,
- large-scale renderer/streaming performance,
- final Owner readiness by itself.

Per the active visual rebuild sequence, the next governance stage is candidate freeze on one exact runtime followed by exact-candidate reruns, independent assurance and final readiness audit before Owner delivery.