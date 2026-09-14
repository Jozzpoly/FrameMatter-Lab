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

## Multiple anchors partition with their Matter owners

A stronger challenger attached two persistent external bodies to opposite ends of one moving parent using two independent pin joints. Each mechanical anchor had a different owner Matter cell and lineage token. One topology cut then split the parent so the two owner lineages landed in different compact successors.

The transaction independently selected and remapped both endpoints, rebased both persistent Joint3D scene frames, and retired the old parent before the upcoming solver step.

CI evidence:

- left owner lineage: `70029 -> 70029`,
- right owner lineage: `70038 -> 70038`,
- owner lineages landed in different successor indices (`0` and `1`),
- retained lineage mismatches: `0`,
- retained Matter world-position error: `0.0000026974 m`,
- retained velocity-field error: `0.0000011151 m/s`,
- stale left/right Joint3D scene-frame distances: `3.8449842930 m / 0.9459311962 m`,
- both explicit joint-frame rebase errors: `0`,
- maximum left/right inherited anchor gaps: `0.0004723693 m / 0.0004756952 m`,
- final left/right anchor gaps: `0.0004670941 m / 0.0004648947 m`,
- the two successor mechanical islands changed their mutual separation by `4.654578 m`,
- left successor mechanical response: `Δv = 0.505029 m/s`, `Δω = 0.131351 rad/s`,
- right successor mechanical response: `Δv = 0.631687 m/s`, `Δω = 0.113661 rad/s`,
- both persistent logical joint identities survived.

Bounded result: **one topology replacement can partition a constraint graph deterministically by retained Matter ownership.** Mechanical links do not need to belong to a monolithic construct object; distinct anchors can follow distinct successor frames through one split transaction.

## Destroyed anchor Matter retires its mechanical link

A negative challenger tested whether mechanical ownership follows coordinate/material coincidence or actual retained Matter identity. A pin-jointed construct kept the same `RigidBody3D`, but the Matter cell owning the mechanical endpoint was explicitly destroyed and its lineage token was retired. The host `PinJoint3D` was retired in the same mutation transaction.

The former endpoints were then driven apart. Later, identical material was recreated at the exact same local coordinate with a fresh lineage token. No automatic rebinding was allowed.

CI evidence:

- original owner lineage token: `81030`,
- recreated lineage token at the same address/material: `910001`,
- owner and sibling physics-body identities survived the entire sequence,
- pre-destruction joint-anchor gap: `0.0001599411 m`,
- immediate gap at retirement: `0.0005088530 m`,
- former endpoints diverged to at least `1.427452 m` after link retirement,
- Matter was recreated when the former endpoints were already `1.449092 m` apart,
- post-recreation gap ranged from `1.470645 m` to `3.854979 m`,
- final host pin-joint count: `0`,
- the Matter volume returned to its full `54` occupied cells.

Bounded result: **retained Matter identity may carry mechanical ownership through frame/address replacement, but actual owner destruction ends that ownership. Same-address, same-material recreation is new Matter and does not resurrect the retired mechanical relation.** Rebinding must be explicit, or an undo system would need to restore the original logical identity rather than merely recreate equivalent material.

## One topology event can mix succession and retirement

The next challenger combined both rules in a single pre-PhysicsServer topology transaction. One parent had two independent mechanical links. The first link was owned by the exact bridge cell removed to cause the split; the second was owned by retained Matter on the far-right component.

The transaction therefore had to make two opposite per-anchor decisions at once:

- destroyed bridge-owner lineage -> retire only that mechanical link,
- retained far-right owner lineage -> compact-map the anchor, rebase the persistent `Joint3D` frame, and succeed that endpoint onto the selected child.

CI evidence (fast and full validation both passed):

- destroyed owner token: `93033`; it appeared in no successor,
- surviving owner lineage: `93038 -> 93038`,
- retained lineage mismatches: `0`,
- retained Matter world-position error: `0.0000010662 m`,
- retained velocity-field error: `0.0000003157 m/s`,
- surviving Joint3D scene frame was stale by `2.3799693584 m` before explicit rebasing,
- surviving constraint-frame rebase error: `0`,
- maximum/final surviving anchor gap: `0.0004315703 m / 0.0004280001 m`,
- retired endpoint diverged by `3.721460 m`,
- non-owning topology successor separated by `9.672719 m`,
- surviving successor mechanical response: `Δv = 0.580933 m/s`, `Δω = 0.166050 rad/s`,
- final host pin-joint count: exactly `1`.

Bounded result: **mechanical attachment lifecycle can be decided per anchor/per retained Matter owner inside one atomic topology event.** A construct does not need one global "all links survive" or "all links break" outcome.

## Rigid merge can contract a mechanical graph

A many-to-one challenger tested the inverse topology direction. Two source frames `A` and `B` were linked to each other and also had one persistent external pin-joint each. An explicit incompatible rigid bind then replaced `A+B` with one momentum-derived merged successor.

Graph rewrite semantics were deliberately asymmetric:

- both external links retained their own logical identities and converged onto the common merged successor,
- the `A <-> B` relation was retired because both of its endpoints mapped into the same rigid successor and keeping it would create a meaningless self-constraint,
- both external anchor owners retained their Matter lineage through the merge,
- both persistent host `Joint3D` frames were rebased before endpoint reconfiguration.

Fast and full validation both passed. CI evidence:

- left external owner lineage: `120017 -> 120017`,
- right external owner lineage: `120056 -> 120056`,
- lineage mismatches: `0`,
- source alignment error at bind: `0.0000063974 m`,
- source orientation error: `0`,
- linear-momentum reconstruction error: `0`,
- angular-momentum reconstruction error: `0.0000019073`,
- inelastic kinetic-energy loss: `188.184550`,
- stale left/right `Joint3D` frame distances: `1.4324222803 m / 1.4324282408 m`,
- both explicit rebase errors: `0`,
- maximum inherited external anchor gaps: `0.0000099567 m / 0.0000116411 m`,
- final inherited external anchor gaps: `0.0000081482 m / 0.0000097256 m`,
- merged-successor mechanical response after external impulses: `Δv = 0.010439 m/s`, `Δω = 0.023475 rad/s`,
- final pin-joint count: exactly `2`, with the internal source relation absent.

Bounded result: **topology replacement can contract a constraint graph as well as partition it.** External relations may preserve logical identity while multiple endpoint frames collapse into one successor, whereas relations that become internal to the same rigid frame should be explicitly retired rather than converted into self-constraints.

Within the currently tested `PinJoint3D` scope, partition and contraction therefore form a useful pair of graph-rewrite semantics driven by retained Matter ownership and successor-frame mapping rather than by source-object lifetime alone.

## Current invariant candidate

Topology replacement is becoming a multi-domain transaction rather than merely a body spawn/despawn operation. When continuity matters, one transaction may need explicit mappings for:

- retained Matter and lineage,
- successor spatial frames and local coordinates,
- dependent actor support frames,
- mechanical-anchor ownership,
- constraint-frame spatial state,
- per-anchor endpoint succession or retirement,
- graph-edge contraction/retirement when endpoint frames merge,
- pre-PhysicsServer scheduling.

These are related but must not be conflated. A retained Matter lineage may survive while local address, physics-body identity, actor support object, and constraint endpoint all change. Conversely, an address and material may be recreated while the previous lineage and its mechanical ownership remain retired. Different anchors on the same source frame may legitimately choose different lifecycle outcomes in the same transaction. Multiple source frames may also collapse into one successor while external mechanical relations remain logically continuous and newly internal relations disappear.

## Still unproven

- whether the same ownership/rebase/succession semantics generalize beyond `PinJoint3D`, especially hinges, motors and limits,
- multi-joint chains and loops under repeated topology rewrites,
- graph-level conservation semantics during more complex simultaneous topology + constraint changes,
- breakable-link policy and force/impulse thresholds,
- nested frames or arbitrary gravity,
- scalable large-construct collision/representation,
- production persistence/network identity for Matter or mechanical links.
