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

**G0 — in progress.** The initial harness is being built around `CellVolume` as the only logical source of truth.
