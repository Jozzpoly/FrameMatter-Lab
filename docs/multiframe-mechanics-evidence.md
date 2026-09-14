# Multi-frame mechanics evidence

Status: exploratory bounded evidence, not a production mechanics architecture.

This note records the first constraint-coupled frame experiments after the topology/lineage work in `FrameMatter-Lab`.

## Independent frames can be mechanically coupled

Two independent `ConstructBody` instances, each with its own authoritative `CellVolume` and physics identity, were coupled by one `PinJoint3D` without merging Matter or scene-parenting one construct under the other.

CI evidence:

- maximum pin-anchor gap: `0.0002144861 m`,
- final anchor gap: `0.0001060041 m`,
- maximum relative rotation: `2.3354654312 rad`,
- left/right Matter storage mismatches: `0 / 0`,
- body identities remained distinct.

Bounded result: **mechanical coupling does not require frame collapse.** Contact/connectivity, mechanical constraint, and rigid binding are distinct relationships.

## Actor support remains local inside a constraint graph

A `FrameProbeCharacter` rode the left construct while the right construct was pin-jointed to it and driven by torque. The left support frame therefore changed motion through constraint reaction rather than a directly prescribed transform.

CI evidence:

- maximum actor local drift: `0.0000139021 m`,
- floor-loss frames: `0`,
- erroneous support transfers to the sibling: `0`,
- maximum joint-anchor gap: `0.0001567846 m`,
- relative yaw reached `1.3186359406 rad`,
- support-frame linear velocity changed by up to `0.2851820886 m/s`,
- support-frame angular velocity changed by up to `0.0776474550 rad/s`,
- both Matter snapshots remained unchanged.

Bounded result: **actor support-frame semantics can remain local to one construct even when that construct's motion is produced by a mechanical constraint graph.**

## Live Matter mutation survives an active constraint

One constrained construct underwent 16 asymmetric remove/add mutations while the pin joint remained active. Every mutation rebuilt mesh, collision, mass, COM, and inertia on the same `RigidBody3D`.

CI evidence:

- initial/final cells: `72 / 72`,
- initial/final mass: `162 / 162 kg`,
- maximum COM shift during the mutation sequence: `0.2665425241 m`,
- mass error: `0`,
- collision-shape-count error: `0`,
- maximum joint-anchor gap: `0.0003002846 m`,
- final joint-anchor gap: `0.0002951793 m`,
- edited/sibling Matter storage mismatches: `0 / 0`,
- both physics-body identities survived.

This does **not** establish physically complete momentum semantics for material being added or removed. It establishes that G2-style representation and mass-property rebuild can coexist with an active constraint without replacing the frame or mutating its sibling.

## Mechanical-link succession through topology split

A moving parent construct was pin-jointed to a persistent sibling. The parent was then cut into two compact successor frames. The joint endpoint had an explicit owner Matter cell with retained lineage token `50038`.

The first succession attempt correctly selected the successor by Matter lineage and correctly preserved Matter world/velocity continuity, but the constraint anchor failed catastrophically:

- retained lineage mismatches: `0`,
- split world-position error: `0.0000021458 m`,
- split velocity-field error: `0.0000009485 m/s`,
- free successor separated by `12.509223 m`,
- but post-succession joint-anchor gap reached and remained `1.5169038773 m`.

Inspection of Godot 4.7 source isolated the cause. `PinJoint3D::_configure_joint()` derives body-local pin pivots from the **current global transform of the `Joint3D` node** when the joint is configured. `Joint3D::set_node_a()` / `set_node_b()` immediately reconfigure the constraint. The joint node itself had remained at its original world-space creation position while the constrained bodies moved, so changing the endpoint rebuilt the pin around a stale scene-space anchor.

The challenger therefore made joint-frame rebasing an explicit part of the topology transaction:

1. capture the current logical mechanical anchor in world space,
2. select the successor by retained anchor-owner Matter lineage,
3. map the anchor into the successor's compact local coordinates,
4. rebase the persistent `Joint3D` node to the current logical world-space anchor,
5. replace the body endpoint,
6. retire the old parent before the upcoming PhysicsServer step.

The strengthened CI run measured:

- owner lineage token: `50038 -> 50038`,
- lineage mismatches: `0`,
- split world-position error: `0.0000021458 m`,
- split velocity-field error: `0.0000009485 m/s`,
- stale Joint3D scene-anchor distance before rebasing: `1.4316229820 m`,
- explicit joint-frame rebase error: `0`,
- maximum post-succession anchor gap: `0.0005516085 m`,
- final anchor gap: `0.0005493350 m`,
- non-owning successor free separation: `12.509223 m`,
- retained successor mechanical response: `Δv = 0.785306 m/s`, `Δω = 0.237691 rad/s`,
- persistent sibling identity survived,
- logical `PinJoint3D` object identity survived,
- old parent physics identity was replaced by a new successor identity.

The first FAIL and the challenger PASS support a concrete current-host execution rule: **when topology replacement changes a constraint endpoint, the logical constraint anchor and the host `Joint3D` frame must be rebased before endpoint reconfiguration.**

## Current invariant candidate

Topology replacement is becoming a multi-domain transaction rather than merely a body spawn/despawn operation. When continuity matters, one transaction may need explicit mappings for:

- retained Matter and lineage,
- successor spatial frames and local coordinates,
- dependent actor support frames,
- mechanical-anchor ownership,
- constraint-frame spatial state,
- endpoint succession,
- pre-PhysicsServer scheduling.

These are related but must not be conflated. A retained Matter lineage may survive while local address, physics-body identity, actor support object, and constraint endpoint all change.

## Still unproven

- multiple mechanical anchors partitioning across different successors in one topology event,
- multi-joint chains, loops, motors, limits, gears, springs, or breakable links,
- graph-level conservation semantics during simultaneous topology + constraint changes,
- anchor destruction semantics when the owner Matter itself is removed,
- joint succession across incompatible rigid binding/merge events,
- nested frames or arbitrary gravity,
- scalable large-construct collision/representation,
- production persistence/network identity for Matter or mechanical links.
