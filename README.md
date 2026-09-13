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

After G3 the architecture is reviewed before automatically expanding scope.

## 0.1 stack

- Godot 4.7.2 stable
- built-in Jolt Physics
- GDScript for fast falsification
- standard float precision / local coordinates
- custom minimal integer-grid matter model
- intentionally simple derived mesh/collision representations

Voxel plugins, C++, portals, procedural terrain, streaming, multiplayer, Planet Matter, Create-like machinery, and JV/VAW-grade vehicle systems are deliberately outside G0–G3 unless evidence makes one necessary.

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

These are one-run CI baselines, not performance targets. The 12³ result already demonstrates the expected scaling cliff and is evidence for later collider-region/merging work, not a reason to optimize before G1–G3.

### G1 — in progress

Next evidence target: use the same `CellVolume` as a real dynamic `RigidBody3D` under Jolt, verify falling/collision/settling and confirm that physical world motion does not alter logical local Matter.
