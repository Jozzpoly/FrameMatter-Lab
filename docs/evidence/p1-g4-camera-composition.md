# P1 G4 — camera as experiment instrument

Status: **BOUNDED PASS / RELATIONAL + OBSTRUCTION-AWARE CAMERA PROMOTED**

Verified runtime/evidence commit: `3f1f803e41d78f5fda32c073983d3d0d7001eb51`

G4 asks a rendered-instrument question rather than a camera-feature question:

> can an informed reviewer follow actor ↔ relevant Space ↔ world causality through ordinary, obstructed and lifecycle states without mentally reconstructing important off-screen context?

The bounded answer is **yes for the current authored P1 scene, tested lifecycle set and Windows D3D12 Forward+ evidence path**.

This is not a claim that the camera is final game-quality presentation.

## Starting failure

The pre-G4 camera already had a SpringArm and followed the actor, but that was not enough.

The first rendered stress sequence exposed two material failures:

- a real authored Matter obstacle could compress the SpringArm to roughly half a metre and leave a long-lived close-up of the actor's back,
- an adversarial far-airborne state could let the camera follow the actor while effectively abandoning the experiment and relevant Space.

The initial projected-AABB metrics also overstated some normal/split problems. Large projection rectangles are not accepted as image-quality authority because behind-camera corners and perspective can produce huge values while the visible rendered relation remains understandable.

Pixel review therefore remained the acceptance authority.

## Challenged directions and rejected ideas

Several bounded challengers were tested before promotion.

### Guarded context shift

A bounded focus shift plus extent-aware distance improved some actor projection metrics, but did not solve the obstacle geometry and could still produce semantically weak far-separation frames.

**Result: rejected as the complete G4 policy.**

### Extreme group-fit / huge zoom

Trying to fit actor and distant Space by backing the camera far away demanded distances above 30 m. Real collidable world geometry prevented that distance and the result still lost the actor/experiment relation.

This falsified the idea that extreme actor↔Space separation should be solved by arbitrary group-fit zoom.

**Result: rejected.**

### Flat relation tracking

Actor-centric relation tracking correctly restored the actor and relevant Space to the same frame, but a very shallow emergency pitch (`0.12`) viewed the distant horizontal Matter almost edge-on. Final pixel review caught that the Space had collapsed to a thin bright line even though viewport metrics passed.

**Result: rejected as insufficiently legible.**

## Promoted camera policy

The promoted `P1CameraRig` treats two problem classes separately.

### Local obstruction

When the direct orbit is heavily blocked, the camera probes nearby yaw/pitch orbit candidates with a small spherical sweep and chooses a clearer collision-safe ray.

This changes presentation orientation only. It does not alter Matter, Space, collision, actor authority or solver motion.

In the final B3 obstacle stress the desired and actual camera arm were both `8.187 m` (`arm_ratio=1.000`) instead of collapsing into the near-field close-up seen in the baseline.

### Extreme actor ↔ Space separation

Extreme separation does not try to show the whole relation through unlimited zoom.

The policy instead:

- keeps actor X/Z as the hard presentation anchor,
- allows bounded vertical focus lift toward higher context,
- rotates the rendered view along the actor→Space relation,
- caps camera distance at the ordinary production maximum,
- uses an elevated emergency relation pitch of `0.32` so distant horizontal Matter remains recognizable as a surface/structure rather than a line.

The `0.32` value is a current bounded presentation choice, not a universal camera constant.

## Control-frame invariant

Automatic presentation yaw initially exposed a deeper architectural risk: player movement used the rendered yaw pivot as its camera-relative control basis. An automatic camera correction could therefore rotate movement controls without Owner input.

That coupling was removed.

- explicit user camera yaw (`_yaw`) owns planar movement forward/right,
- presentation-only recovery uses separate runtime yaw/pitch,
- automatic camera recovery cannot silently rotate the player's control frame.

`tests/p1_camera_control_frame_probe.gd` is part of the active P1 rebuild gate and executable evidence for this boundary.

## Evidence-harness corrections

G4 also found two evidence-system defects.

### Exact source provenance

The initial pull-request workflow rendered GitHub's synthetic merge commit while evidence discussion referred to the branch head SHA. The G4 workflow now explicitly checks out and verifies the PR head/source SHA and records source, checked-out and event commits separately.

### False B4 through automatic recovery

The original far-airborne fixture moved the actor to `(34.5, -7, 0)` and then waited several rendered frames. On the slow software D3D12 evidence runner, enough hidden physics ticks could occur for production automatic fall recovery (`y < -12`) to fire before the screenshot.

That produced a dangerous false frame: HUD could report the actor grounded on local Space while the evidence was being interpreted as pre-recovery airborne composition.

B4 is now explicitly a **camera-composition stress, not a gravity-timing test**:

- actor physics processing is frozen only for the B4 evidence window,
- exact world position is asserted before capture,
- `grounded == false` is asserted,
- both support references are asserted null,
- actor physics is restored immediately after capture,
- B5 then exercises the real explicit recovery path normally.

Final B4 state on the verified commit:

`actor_world=(34.500,-7.000,0.000) grounded=false support_space=false`

This makes the rendered frame semantically trustworthy.

## Final rendered stress sequence

Windows Godot 4.7.2 Forward+ / D3D12 workflow run `35002417718` checked out the exact source commit `3f1f803e41d78f5fda32c073983d3d0d7001eb51` and captured the canonical production camera.

Artifact: `FrameMatter-P1-G4-Camera-Evidence-Windows-Canonical`, artifact ID `10409882269`, SHA-256 `8d6b9baac4ef8265834947c5507dab576fbf57d80102f698717398095f266712`.

The sequence uses the real authored P1 scene and the promoted G2/G3/G3-S presentation:

- `00_default_center` — ordinary actor/Space/world framing; Space extent still supplies composition pressure near center,
- `01_actor_near_edge` — actor remains legible near the authored Space edge,
- `02_minimum_zoom_edge` — legal minimum user zoom remains usable rather than becoming a permanent near-field crop,
- `03_close_obstacle_compression` — real Matter wall no longer produces the catastrophic long-lived close-up,
- `04_far_airborne_context` — verified airborne actor, world boundary and distant relevant Space remain simultaneously distinguishable,
- `05_post_recovery` — composition returns coherently after real recovery,
- `05b_storage_rebase_continuity` — real storage-frame maintenance preserves world-space composition,
- `06_dynamic_motion` — real STATIC→DYNAMIC provider replacement plus finite translation/yaw remains followable,
- `07_immediate_split` — immediate one→many topology succession retains actor and successor relation,
- `08_post_split_context` — the relation remains coherent after additional settling.

Representative final B4 metric:

`actor_norm=(0.500,0.732) spaces_min=(0.414,0.209) spaces_max=(0.586,0.273) desired_arm=13.000 actual_arm=13.000 active_spaces=1`

The metric is a guardrail only. PASS is based on the rendered frame: actor, world boundary and relevant Space are visually distinct and the Space remains recognizable as a distant structure rather than a line.

## Rendered storage-rebase evidence

G4 deliberately added direct rendered storage-rebase evidence rather than relying only on the existing mathematical continuity probe.

The real rebase reported:

`shift=(4, 0, 0) actor_world_error=0.00000763 content_world_error=0.00000048 camera_context_error=0.00000000`

The world-render region below the HUD in `05_post_recovery` versus `05b_storage_rebase_continuity` differed at only 15 pixels by at least `2/255`, with maximum channel difference `13/255`. The HUD is expected to differ because it reports the rebase event.

This supports the intended semantic result: storage-coordinate maintenance can change local storage coordinates without visibly moving Matter, actor or camera context in world space.

## Mechanical same-source evidence

P1 rebuild workflow run `35002417336` on the same commit passed both jobs.

The foundation job remained green through:

- canonical startup,
- volumetric actor challenger,
- composed scene smoke,
- multi-Space registry,
- live topology consumer,
- promoted G3 surface-grid lifecycle,
- promoted G3-S state-presentation lifecycle,
- storage rebase,
- actor/camera storage-frame continuity,
- camera presentation/control-frame separation,
- finite Space control,
- integrated causal loop.

The Windows scene diagnostic also passed.

## What G4 establishes

Within the current authored P1 scene and tested renderer/scenario set:

- camera composition is no longer equivalent to merely having a SpringArm,
- local Matter obstacles have geometry-aware presentation recovery,
- active Matter extent influences ordinary framing without demanding full-volume fit,
- extreme actor↔Space separation preserves a legible actor, relevant Space and useful world reference,
- camera recovery does not rotate movement authority behind the Owner's back,
- fall and recovery regain coherent composition,
- storage rebase remains world-continuous both mechanically and visibly,
- STATIC→DYNAMIC provider replacement and finite motion remain framed coherently,
- immediate and settled topology succession retain enough actor/successor relation for an informed reviewer to understand what happened.

Gate result: **camera composition PASS within the current P1 authored scene, lifecycle set and Windows D3D12 evidence path.**

## Explicit nonclaims

G4 does **not** establish:

- final game camera feel or cinematography,
- arbitrary world/Space scales,
- arbitrary geometry or dense occluder environments,
- arbitrary pitch/roll gravity semantics,
- final camera smoothing/hysteresis tuning,
- final interaction targeting language,
- final UI hierarchy or HUD safe-area design,
- full world/motion/topology visual causality,
- final art direction,
- Owner readiness.

The huge projected Space AABB values in some split frames are explicitly not accepted as visual-quality metrics. Rendered pixels and causal legibility remain the authority.

## Next move

Proceed to **G5 — interaction visual hierarchy**.

The camera now provides a bounded usable observation instrument. The next question is whether REMOVE / PLACE / EXPAND targeting, occlusion and action feedback communicate interaction truth without relying on the old debug-like no-depth-test wire cube.
