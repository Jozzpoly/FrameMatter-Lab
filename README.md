# FrameMatter Lab

Research lab for an editable 3D world substrate where local matter can become a dynamic physical construct without losing its identity as editable matter.

This repository is intentionally **not** a Minecraft clone, vehicle game, portal demo, or final engine architecture. Its first job is to produce evidence about the smallest substrate that could later support those directions.

## 0.1 research thesis

An editable local space should be able to preserve its logical matter state while its render and physics representations are destroyed, rebuilt, moved, and eventually changed in fidelity.

Early invariants under test:

- Matter is the source of truth; mesh and physics are derived representations.
- Matter coordinates are local and do not depend on world transforms.
- Logical identity is not a physics body/shape identity.
- A spatial frame is not equivalent to scene-tree parenting.
- Contact does not imply parenting.
- A construct is editable local space with a dynamic representation, not a vehicle type.
- Space and physics/simulation domain are separate concepts.

All of these remain falsifiable by evidence.

## First campaign

| Gate | Question |
| --- | --- |
| **G0 — Matter Truth** | Can a minimal local editable matter model regenerate its mesh and collision representation from logical data alone? |
| **G1 — Dynamic Construct** | Can the same matter become a stable dynamic physical construct without changing data model? |
| **G2 — Live Mutation** | Can a moving construct rebuild geometry/collision/mass properties safely after matter edits? |
| **G3 — Relative Actor** | Can an actor stand, walk, jump, and re-contact reliably relative to translating and rotating constructs? |

G0–G3 are now closed as bounded research gates. The architecture review below is the checkpoint before expanding scope.

## 0.1 stack

- Godot 4.7.2 stable
- built-in Jolt Physics
- GDScript for fast falsification
- standard float precision / local coordinates
- custom minimal integer-grid matter model
- intentionally simple derived mesh/collision representations

Voxel plugins, C++, portals, procedural terrain, streaming, multiplayer, Planet Matter, Create-like machinery, and JV/VAW-grade vehicle systems remain outside the first campaign unless later evidence makes one necessary.

## Evidence standard

A gate is not a PASS because it looks correct once. We seek:

1. **Correctness** — expected behavior can be checked against explicit truth.
2. **Stability** — repeated mutations/motion do not accumulate hidden failure.
3. **Performance evidence** — costs and cliffs are measured before optimization.

A local failure is useful evidence. The repository is allowed to replace representations, controller strategies, or even the host engine if the experiment justifies it.

## Current state

### G0 — PASS (bounded)

Validated on Godot 4.7.2 in headless CI:

- known geometry truth cases pass (isolated cell, adjacent pair, full 4³ cube),
- mesh and collision representations regenerate from `CellVolume` after destruction,
- moving a representation in world space does not mutate local Matter,
- 500 deterministic Matter mutations preserve representation consistency,
- baseline rebuild costs were measured before optimization.

Baseline CI measurements for the intentionally naive box-per-cell representation:

| Full cube | Cells / collision shapes | Mesh rebuild | Full representation rebuild |
| --- | ---: | ---: | ---: |
| 4³ | 64 | ~1.0 ms | ~1.5 ms |
| 8³ | 512 | ~4.9 ms | ~7.1 ms |
| 12³ | 1728 | ~16.5 ms | ~26.2 ms |

These are one-run CI baselines, not performance targets. Later runs vary substantially with runner load. The scaling cliff is the useful result.

### G1 — PASS (bounded)

The same `CellVolume` is used by a real dynamic `RigidBody3D` under Jolt without changing the logical Matter model.

Validated in headless CI:

- a 2×1×2 construct falls, collides, settles, receives a mass-normalized impulse, and preserves its Matter snapshot,
- settling horizontal drift for the symmetric smoke case was ~0.000065 world units,
- an asymmetric 8-cell construct remains bounded through translation, rotation, collision and a torque impulse while preserving Matter truth,
- a deliberately naive full 8³ construct with 512 independent collision shapes remains numerically stable and preserves Matter truth.

The 512-shape probe exposes the expected representation cliff: across CI runs, rebuild and physics costs vary materially with runner load but are already far beyond a reasonable realtime budget. This is sufficient evidence that box-per-cell cannot be the scalable dynamic representation.

This is **not** evidence for large voxel constructs, nested frames, live mutation, or actor-relative locomotion. It only closes G1's bounded question.

### G2 — PASS (bounded)

Live Matter edits rebuild a moving construct's mesh, collision representation, mass, center of mass and inertia while keeping the logical `CellVolume` authoritative.

Validated in headless CI:

- analytic equal-density Matter COM matches Jolt's observed local COM before and after asymmetric removals/additions,
- mass and inverse mass follow solid-cell count after rebuilds,
- inertia is refreshed and remains numerically bounded,
- a deterministic 120-mutation campaign runs while the construct continuously translates and rotates,
- every campaign step keeps mesh topology, collision-shape count, mass and solver COM coherent with current Matter,
- the campaign's maximum COM error was ~0.00000122 and maximum inverse-mass error was effectively zero,
- small-construct rebuilds remain in the low-millisecond range in CI, while the intentionally naive larger compound representation already shows a clear scaling cliff.

G2 deliberately **does not solve momentum semantics** for physical attachment/detachment of material. A newly added cell's prior momentum and the momentum carried away by removed material remain a separate assembly/mechanics question. G2 only establishes bounded representation/mass-property coherence during live mutation.

### G3 — PASS (bounded support-frame semantics)

G3 produced both a useful failure and a successful replacement strategy.

**Controlled moving-frame baseline.** Stock `CharacterBody3D` behaved well on a controlled Matter-derived `AnimatableBody3D`: translation, rotation and combined motion maintained floor contact for the complete probes. Measured construct-local horizontal drift was roughly 2–3 cm in the original sampling setup, and Godot reported the expected platform linear/angular velocities.

**Free-dynamic failure.** The same stock kinematic character semantics were unsuitable when the support was a freely simulated `ConstructBody` (`RigidBody3D`). In the probe, the actor never acquired stable floor contact and the construct was accelerated to roughly 277 m/s. Increasing total construct mass from 49 kg through 4,900 kg to 490,000 kg barely changed the failure. This rules out "make the construct heavier" as an acceptable fix for this research case.

**Frame-aware challenger.** A minimal query-based `FrameProbeCharacter` separates support-frame transport from physical actor→construct force exchange. While grounded it maintains an explicit construct-local support anchor; while airborne it moves in world space and can only re-enter a frame through a new physics query. It is not scene-tree parented to the construct and it intentionally applies no reaction force to the rigid body.

The first challenger case passed ride → walk → jump → re-contact on a freely simulated construct with:

- maximum ride local drift ~0.000016 m,
- zero grounded-frame loss,
- ~0.9 m × 0.5 m local walking displacement,
- jump re-contact after 34 physics frames,
- post-recontact local drift ~0.000010 m,
- no measurable change to the construct's commanded linear or angular velocity in the test precision.

A follow-up campaign varied translation, rotation, actor offset and construct mass:

| Case | Construct motion | Total mass | Max ride drift | Jump re-contact | Velocity perturbation |
| --- | --- | ---: | ---: | ---: | ---: |
| `linear_fast` | 5 m/s, -3 m/s | 121 kg | 0.00000000 m | 34 frames | 0 |
| `spin_offset` | 0.9 rad/s yaw | 121 kg | 0.00001775 m | 34 frames | 0 |
| `combined_reverse` | -2.5/+2.0 m/s, -0.8 rad/s | 6,050 kg | 0.00001614 m | 34 frames | 0 |
| `combined_heavy` | 3.5/-1.5 m/s, 1.1 rad/s | 121,000 kg | 0.00001628 m | 34 frames | 0 |

All cases kept support during riding/walking, completed a bounded jump/re-contact, stayed below the 2 mm drift contract by a wide margin, and did not perturb the free construct's prescribed linear/angular velocity.

G3 therefore establishes a narrower but important result: **support-frame locomotion can be represented explicitly above the rigid-body solver without transform parenting and without conflating contact transport with physical force exchange.**

G3 does **not** establish a production character controller. `FrameProbeCharacter` currently uses a downward ray and does not solve capsule volume, walls, slopes, steps, ceilings, arbitrary gravity, tilted walk surfaces, actor–actor collision, physical pushing, or nested frames. Those remain separate questions.

## Post-G3 architecture review — 0.1

### Defended foundations

- **Logical Matter remains independent of representation.** G0–G2 repeatedly reconstruct render/physics state from `CellVolume` without changing Matter identity.
- **A construct can be treated as dynamic local space.** The same Matter can move, rotate and mutate while retaining coherent local coordinates and derived mass properties.
- **Frame relationships should be explicit state, not scene-tree parenting.** G3's successful actor stores a support-local anchor and crosses between support-frame and world-space states deliberately.
- **Support transport and force exchange are separate problems.** A body can carry an actor kinematically relative to its frame without granting the actor unlimited authority over the body's rigid-body motion.
- **Godot + Jolt remains viable for the current research layer.** No first-campaign result currently justifies replacing the host engine or introducing native code merely to preserve the core invariants.

### Falsified or rejected as scalable foundations

- **One collision box per solid cell is not a scalable dynamic representation.** It remains useful as a truth/reference implementation only.
- **Stock `CharacterBody3D` directly standing on a free `RigidBody3D` is not accepted as our actor/construct interaction model.** The bounded probe produced catastrophic, mass-insensitive rigid-body acceleration.
- **Making constructs artificially enormous in mass is not an architectural fix** for actor/support semantics.
- **Contact alone is insufficient to define frame membership.** Support-frame acquisition and release need explicit semantics.

### Open debts before a broader substrate claim

- scalable mesh/collision representations for larger editable constructs,
- topology changes: splitting one Matter volume into multiple constructs and merging constructs back together,
- momentum semantics for matter attachment/detachment and construct split/merge,
- finite, physically meaningful actor→construct force exchange,
- a volumetric actor controller (capsule/shape queries, walls, slopes, steps and ceilings),
- nested/moving frames and frame transitions beyond one actor→construct relationship,
- larger-coordinate/origin-management questions,
- performance and stability under multiple simultaneous constructs and actors.

The first campaign therefore does **not** define a final architecture. It establishes a small set of defended invariants and rejects several tempting shortcuts. The next campaign should be chosen from the open debts by information value, rather than by automatically adding game features.

## Exploratory topology evidence — after G3

Topology work has started as a separate exploratory line. These probes are **not yet a topology gate PASS**; they establish narrower semantics that can now be challenged by merge, incompatible motion, repeated fragmentation and larger-scale cases.

### Moving split continuity

A moving 66-cell Matter construct was cut into two 6-connected components containing 28 and 37 retained cells. The two new free `ConstructBody` instances inherited the parent's instantaneous rigid velocity field at their own centers of mass.

Measured in CI:

- all 65 retained cells survived the split,
- maximum retained-cell velocity-field error was ~`5.46e-7 m/s`,
- maximum child COM error was ~`1.03e-6 m`,
- child angular-velocity error was zero at test precision,
- summed child linear momentum matched retained-Matter linear momentum to float precision.

This establishes a bounded split rule: when material removal partitions a rigid Matter frame, each successor can preserve the parent's instantaneous velocity field without preserving the parent's physics-body identity.

### Actor support across frame replacement

Query-only contact reacquisition was deliberately tested first when the actor's support parent was destroyed and replaced by two successor frames. It reacquired the correct child in one frame, but produced ~`7.21 cm` of one-tick local slip. That failure rejected ordinary contact reacquisition as a lossless topology-transition mechanism.

An explicit **topology frame handoff** was then introduced. The topology transaction supplies the actor with the successor frame and mapped support-local point before the old frame disappears. In the same split case this reduced the handoff world discontinuity to ~`2.38e-7 m`, horizontal local-coordinate error to zero, later ride drift to ~`5.74e-6 m`, and preserved support without perturbing either successor rigid body's commanded motion.

Current invariant candidate: **ordinary contact transitions may be query-driven, but topology replacement needs an atomic frame-successor mapping when continuity matters.**

### Compact frame rebasing

The next probe removed an accidental assumption from the first split implementation: successors no longer keep the parent's full sparse Matter address range. Each connected component is cropped into a compact `CellVolume` with an explicit source-origin offset, and its frame transform is shifted so retained Matter stays in the same world-space locations.

For the actor-side successor, the source origin was `(5, 0, 0)` and its compact size became `(5, 3, 3)`. The actor's support coordinate therefore changed non-trivially from approximately `(7.552, 3.902, 1.514)` in the parent to `(2.552, 3.902, 1.514)` in the compact child.

Measured in CI:

- retained-cell world-position error ~`2.70e-6 m`,
- retained-cell velocity-field error ~`2.02e-6 m/s`,
- actor handoff world discontinuity ~`1.91e-6 m`,
- mapped horizontal local-coordinate error `0`,
- post-handoff ride drift ~`7.46e-6 m`,
- zero support loss,
- zero measured child linear/angular velocity perturbation,
- jump/re-contact completed after 34 physics frames.

An earlier version of this probe used a tilted parent with three-axis angular velocity and failed before the topology transaction because the bounded G3 ray-based actor does not establish tilted-frame/arbitrary-gravity locomotion. The probe was corrected rather than broadening the controller implicitly. Tilted walk surfaces remain explicitly unproven.

The rebased result is important because it separates **Matter storage coordinates from spatial continuity**: a successor frame may choose a new compact local origin while world-space Matter, velocity field and actor support remain continuous through an explicit mapping.

### Topology questions still open

- merging multiple construct frames into one,
- incompatible pre-merge velocity fields and the resulting momentum/energy policy,
- repeated fragmentation/reassembly and identity/provenance semantics,
- actor and other dependent-frame handoff during merge or multi-successor events,
- topology cost and representation cost at larger cell counts,
- arbitrary frame orientation/gravity and nested frame succession.
