# FrameMatter Lab — current research state

Status: **live truth document**. This is intentionally a synthesis, not a historical log. Durable measurements live in `docs/evidence/`; decision order lives in `ROADMAP.md`.

## Evidence language

- **DEFENDED (bounded)** — strong evidence inside an explicitly limited probe.
- **DEFENDED (integrated)** — behavior survived composition through shared runtime and neighboring systems.
- **DEFENDED (reusable-substrate, narrow)** — materially different consumers exercise the same shared path.
- **DEFENDED (scale-pressure)** — controlled measurements identify/remove a bottleneck in the tested range without implying production scale.
- **PROVISIONAL** — useful current mechanism; implementation shape is not established strongly enough to freeze.
- **FALSIFIED / REJECTED** — shortcut or claim contradicted by evidence in the tested scope.
- **OPEN** — material unanswered question/debt.

No result silently promotes itself to the next maturity level. In particular, automated integrated evidence is not Owner/playability/product evidence.

---

# LIVE TRUTH

The canonical branch runtime is now **P1**, not the historical P0/P0.5 LAB:

`application/run/main_scene = res://p1/main.tscn`

P1 rebuild validation, cross-platform canonical startup, historical fast invariants and the P1 Owner-candidate delivery pipeline are green under strict wrappers that reject engine/script `ERROR:` output even when Godot exits successfully.

The current highest-information next step is **direct Owner interaction with the packaged P1 candidate**. Autonomous feature expansion stops at this boundary until that interaction supplies new pressure.

Evidence: `docs/evidence/p1-integrated-owner-candidate.md`, `docs/evidence/p1-evidence-gate-reset.md`.

---

# DEFENDED

## Matter authority — bounded/integrated

- Logical `CellVolume` is authoritative; mesh/collision/body state is derived and reconstructible.
- Matter coordinates are local and independent of world transform.
- Moving a provider does not mutate logical Matter.
- Matter identity is not coordinate identity and not physics-body/shape identity.
- Retained Matter lineage survives tested provider replacement, storage rebase and topology succession.
- Destroy/recreate at the same address creates fresh lineage rather than resurrecting prior Matter identity.
- `LocalMatterSpace.mutate_cell()` remains the shared authority path for ordinary Matter mutation.

## Logical Space / provider separation — reusable-substrate, narrow

The defended semantic separation remains:

> **logical Space ≠ current engine provider**

Within tested scope:

- one logical `LocalMatterSpace` owns one authoritative Matter + lineage pair,
- static and dynamic providers are replaceable derived hosts,
- static→dynamic release and dynamic→static freeze can replace concrete provider identity without redefining logical Space identity,
- live Matter mutation composes with moving providers,
- actor/camera consumers can follow the current provider while retaining a logical-Space relation,
- topology split is different: the source Space retires and explicit successor mapping is required.

Class names, direct parent/child layout, signals and scheduling remain implementation details rather than canonical architecture.

Evidence: I0B, lifecycle LAB, I2, I3 and P1 records.

## P1 integrated causal loop — integrated automated evidence

The current P1 gate composes one causal chain through the shared runtime:

> grounded actor → zero-launch release → finite impulse/torque → ride moving Space → edit/build while moving → out-of-storage placement → storage-frame rebase → mapped placement → destructive cut → one→many topology succession → actor/camera handoff → freeze actor-owned successor.

Representative strict integrated metrics:

- forced storage-frame shift `(3, 0, 0)`,
- linear state error after rebase `0.00000000`,
- angular state error after rebase `0.00000000`,
- source→successor actor handoff error `0.00000125 m`,
- two live successor Spaces,
- moving ride anchor error `0.00000135 m`,
- final actor/support anchor error after successor freeze `0.00000098 m`.

This is stronger than the previous catalogue of isolated bounded probes because storage maintenance, solver motion, actor support, topology succession and lifecycle replacement now survive one composed runtime sequence.

It is **not** evidence of good Owner feel or production quality.

Evidence: `docs/evidence/p1-integrated-owner-candidate.md`.

## Volumetric actor in world-up / translation+yaw scope — bounded + integrated

The P1 actor uses Godot/Jolt direct-space capsule queries rather than the P0 single world-down support ray as its collision model.

Defended in the tested scope:

- Matter floors support the actor,
- vertical Matter walls block it,
- low ceilings block jumping,
- the actor rides and walks relative to a translating/yawing dynamic Space,
- query-based movement does not inject implicit linear/angular velocity into the supporting `ConstructBody`,
- support remains a logical-Space relation through provider replacement,
- explicit mapping preserves support across topology succession,
- explicit local-coordinate maintenance preserves support across storage-frame rebases.

Representative actor metrics:

- wall blocks `23`,
- ceiling blocks `1`,
- moving-support local drift about `0.00000691`,
- local moving-Space walk distance about `0.720004`,
- injected linear velocity delta `0`,
- injected angular velocity delta `0`.

**Arbitrary pitch/roll is not defended.** World gravity vs frame-local gravity/adhesion remains an explicit semantic frontier.

## Storage-frame maintenance — bounded + integrated

The current dense local storage can expand beyond its current coordinate extent through a physics-boundary maintenance transaction.

Defended properties:

- rebase is coordinate-frame maintenance, not a logical Matter edit,
- retained Matter world positions remain continuous within numerical tolerance,
- retained lineage is preserved,
- active provider identity can remain stable through the rebase,
- dynamic linear/angular state is preserved in the tested case,
- actor support-local coordinates are explicitly remapped,
- camera context is refreshed into the rebased frame,
- an out-of-storage PLACE can complete afterward as an ordinary authoritative Matter creation with fresh lineage.

A deliberately unfixed challenger first demonstrated the missing consumer remap with a clean `4 m` actor/camera discontinuity while Matter itself remained correct. The consumer-side fix reduced the corresponding actor/camera frame errors to zero in the same challenger.

This mechanism is **not** a final world/chunk/streaming/storage architecture.

## One→many topology succession — integrated

When destructive editing disconnects a dynamic Matter Space:

- the source Space/provider authority retires explicitly,
- no fragment arbitrarily inherits the source logical Space identity,
- fresh successor Spaces receive compact Matter + lineage storage,
- retained Matter world placement and rigid velocity-field continuity remain numerically tight,
- actor support maps explicitly to an appropriate successor,
- camera/focus can follow the actor-owned successor,
- detached successors own independent dynamic providers.

Sharpened P1 telemetry separates the instantaneous handoff from later legitimate solver motion. Representative handoff error is about `0.00000048 m`; later successor motion is measured separately rather than mislabeled as teleportation.

## Finite Space motion semantics — bounded + integrated

P1 deliberately rejects the old unexplained hard-coded perpetual launch as the Owner-facing motion model.

Current defended behavior:

- release to dynamic representation has zero hidden launch,
- explicit local central impulse produces solver-owned finite translational motion,
- identical impulse produces inverse-mass velocity response in the bounded mass challenger,
- explicit torque impulse produces solver-owned angular motion,
- Owner controls issue discrete pulses rather than setting persistent velocity.

This is causal research pressure, **not** a vehicle framework or final control scheme.

## Real world reference + camera composition — integrated

P1's visible reference ground is a real collision-bearing `StaticBody3D`, not decorative geometry. The actor can leave Matter, fall and physically land on the visible world reference.

The camera is a dedicated SpringArm-based rig that tracks the actor while retaining contextual pressure from the active/focused Space. Camera quality remains an Owner-test question; the defended claim is composition/collision/context behavior, not good feel.

## Canonical startup and delivery — automated package evidence

The branch's persisted project contract now points to P1 and stores the Owner InputMap actions explicitly.

`p1_canonical_startup_smoke.gd` verifies the configured main scene from `ProjectSettings`, persisted controls and composed P1 roles. Canonical startup passes on Linux and Windows Godot 4.7.2.

`Deliver P1 Owner Candidate` run `#7` / `34964102720` independently re-ran the strict P1 chain before exporting Web and Windows artifacts.

Verified Windows artifact:

- PE32+ Windows GUI x86-64,
- executable size `109740584` bytes,
- executable SHA-256 `9a73c77ba3a939a53541670861322ea3c27125e0df9ca20864895a1b458f88ee`,
- embedded product metadata `FrameMatter P1 Owner Candidate`.

This establishes packageability and canonical consistency, not human playability.

## Evidence harness — defended process property

A PASS marker is no longer sufficient evidence by itself.

Current P1 and historical fast-regression wrappers reject engine/script `ERROR:` lines even if Godot returns exit code 0. The prior false-green P1 evidence was explicitly reset and the P1 layers were re-earned under the strict contract.

Windows import also synchronously waits for the editor process and verifies the global script-class cache before runtime probes.

Validate research harness run `#304` / `34963534245` passed the current-campaign controls and defended fast-invariant set under the stricter historical wrapper.

## Exact merged-cuboid collision — scale-pressure + integrated

R1 remains the current provider collision default.

Defended in tested range:

- exact occupied collision coverage,
- collider topology/count remains derived rather than Matter identity,
- dense `14³`: `2744 → 1` reference-to-merged shape,
- shell `14³`: `1016 → 6`,
- large dense/shell provider/rebuild improvements,
- lifecycle/topology/actor composition remains coherent with merged collision active.

`PER_CELL` remains a historical/reference control, not a scalability candidate.

## Post-R1 cost ranking and locality pressure — scale-pressure

R2P still establishes that full mesh/cuboid/COM derivation dominates representative post-R1 whole-provider rebuild cost rather than installation of the already-small merged shape set.

R2A still establishes:

> **dirty/invalidation partition ≠ final physical representation partition**

Bounded dirty derivation can reduce one-cell edit work by orders of magnitude at larger tested extents, while naive fixed regions can badly inflate dense/shell collider partitions. The locality principle is useful; the fixed-region mechanism remains unpromoted.

Do not optimize this next unless Owner interaction demonstrates that edit/rebuild latency is materially limiting.

## Lifecycle timing / observation phases — integrated and repeatedly reproduced

Transaction truth, current PhysicsServer/solver truth and synchronized scene-node visibility are related but not universally simultaneous.

Fresh provider RIDs can participate in the upcoming solver step before the corresponding node exposes that new transform at the next synchronization. Tests/debuggers must state which phase they sample; phase advance of an old provider must not be mislabeled as replacement teleportation.

## Mechanics / binding semantics — bounded

Still defended:

- contact, mechanical constraint and rigid bind are distinct relations,
- mechanically constrained frames can remain logically distinct,
- Matter lineage can own mechanical anchors through split/partition/contraction,
- destroyed anchor-owner Matter retires the relation; same-address recreation does not resurrect it,
- constraint graphs can partition on split and contract on merge,
- tested pin/hinge/motor/limit state survives bounded succession cases.

Standalone mechanics expansion remains closed until a real integrated consumer asks for another relation.

## Host viability — current layer

Godot 4.7.2 + built-in Jolt remains adequate for the current research layer. No defended result currently requires replacing the host or moving the core research path to native C++.

---

# PROVISIONAL

## `LocalMatterSpace` implementation shape

Its semantics are materially better defended than its current class/API/signal/tree layout. Do not turn it into a universal world manager merely because P1 passes.

## Query-based `SpaceQueryCharacter`

The actor is now a much more credible experimental consumer than P0's probe, but it is not a final game controller. Step/slope feel, arbitrary orientation, reaction-force semantics and broader locomotion design remain open.

## Dense expandable storage

Useful bounded mechanism for removing invisible local bounds and testing coordinate maintenance. Not a persistence model, streaming scheme, sparse world database or final chunk system.

## Merged-cuboid compiler implementation

The semantic R1 result is stronger than the current deterministic greedy x→y→z algorithm. It is not claimed globally minimal or optimal for future materials/local update economics.

## Update-local representation mechanism

R2A supports locality if real pressure requires it, but no dirty-region/mesh/collider/world partition is canonical.

## Static/dynamic host strategy

In-place freeze and true provider replacement both remain useful evidence-backed tools. The current P1 Owner loop uses provider transitions because they pressure the defended identity separation; that does not make this the final representation strategy.

## Physical material model

Current occupied cells use a simple equal-mass-per-cell model. `material_id` is not yet a complete density/friction/material contract.

---

# FALSIFIED / REJECTED IN TESTED SCOPE

- Matter truth as scene cubes/nodes rather than logical data.
- Physics body/shape IDs as durable gameplay identity.
- Coordinate identity as Matter identity.
- Scene-tree parenting as the physical model for merely standing on moving constructs.
- Contact alone as sufficient logical support/frame membership.
- Query-only reacquisition as lossless topology handoff.
- One independent PhysicsSystem/domain per construct as a default architecture.
- Artificially enormous construct mass as a fix for stock kinematic actor→rigid interaction.
- One box/collider per occupied cell as a scalable final representation.
- Collider count as semantic occupied-cell count.
- Solver-observed COM as synchronous authority inside fresh topology transactions.
- Automatic nearest-cell resurrection of destroyed mechanical anchors.
- Arbitrary rotated local Space → canonical voxel lattice as trivially lossless reintegration.
- `RigidBody3D.freeze` as an implicit velocity pause/resume guarantee.
- Immediately-read node transform after a server step as universal solver truth.
- Arbitrarily assigning retired source Space identity to one topology fragment.
- Naive fixed update-region collision partition as automatically superior to global merged collision.
- Treating arbitrary pitch/roll actor support as solved by the current world-up P1 actor.
- Hard-coded perpetual launch velocity as the primary Owner-facing meaning of “activate Space”.
- Treating a PASS marker or process exit code 0 as sufficient evidence when Godot logged an engine/script error.

---

# OPEN — CURRENT PRIORITIES

## Active: P1 Owner interaction

The P1 automated campaign has reached a deliberate stop condition. The next evidence must come from the Owner candidate, not another autonomous feature tranche.

Current Owner loop:

> walk → remove/place → release the logical Space with no hidden launch → apply finite motion → ride/build while moving → cross storage bounds → cut Matter into real successors → freeze a successor → observe what is coherent and what still feels wrong.

The key question is now:

> **once the major P0/P0.5 consumer defects are removed, which remaining limitation actually dominates direct use?**

Useful routing after Owner test:

- **interaction/camera/targeting dominates** → fix only the highest-leverage obstacle before another test;
- **edit latency dominates** → reopen update-local representation using R2A evidence without equating dirty regions with collider chunks;
- **orientation/steps/slopes/ceilings dominate** → enter the actor/orientation frontier deliberately;
- **reaction forces / physically meaningful actor↔construct exchange dominate** → design a finite-force interaction challenger rather than granting kinematic authority;
- **provider/storage/topology continuity fails** → reproduce and reopen the exact invariant, do not hide it in presentation glue;
- **loop is coherent but uninteresting** → revisit semantic/product pressure before adding infrastructure;
- **loop is coherent and naturally asks for a mechanism/world interaction** → let that concrete desire select the next integrated subsystem.

## Arbitrary orientation / gravity semantics

Still unresolved: world gravity vs frame-local gravity vs adhesion, walkable-surface semantics on pitch/roll supports, and how actor orientation should respond. P0's pitch/roll failure remains valid pressure; P1 has not silently solved it.

## Finite actor↔construct force exchange

P1 avoids accidental push authority; it does not yet establish a satisfying physically meaningful two-way character/construct force model.

## Canonical-world extraction/reintegration

Open until a real world consumer requires moving Matter between canonical lattice and independent local Space. Exact lattice-compatible reintegration and incompatible bake/resample must remain distinct operations.

## Persistence / durable logical identity

Open until Matter/Space identity must survive save/load/process boundaries.

## World scale / streaming

Open until a concrete consumer exceeds one manageable local active region. Do not predeclare storage regions, dirty regions, render regions, collider partitions and streaming chunks to be the same thing.

## Deferred until real pressure

- richer/breakable/looped mechanics,
- multiple simulation domains/migration,
- nested frames,
- portals/spatial links,
- curved/Planet Matter providers,
- JV-like vehicle integration,
- networking/multiplayer.

---

# IMPORTANT SEMANTIC DISTINCTIONS

## Freeze vs provider replacement vs split vs reintegration vs bake

- **In-place freeze:** same dynamic host changes host mode.
- **Provider replacement:** same logical Space retains Matter/lineage while concrete host changes.
- **Topology split:** source logical Space retires into fresh successor Spaces through explicit mappings.
- **Lossless lattice reintegration:** local Space maps exactly into canonical cells under a compatible transform.
- **Bake/resample:** incompatible pose converts to another lattice and therefore needs an error/provenance policy.

## Space vs representation vs simulation domain

- logical Space is not provider identity,
- provider is the current engine host,
- simulation domain is the solver context for direct interaction,
- these may correlate in small tests but are not defined as identical.

## Transaction vs solver vs synchronized consumer state

- transaction records authoritative mapping/commit state,
- PhysicsServer may already contain a solver result,
- scene nodes/consumers may expose the prior synchronized state until the next sync/update phase.

## Contact vs constraint vs rigid bind

- contact creates forces,
- constraint mechanically couples distinct frames,
- rigid bind/reframe replaces several rigid frames with one successor under explicit policy.

## Logical Matter vs derived collision

- Matter occupancy is logical truth,
- collider count/topology is disposable compilation state,
- exact coverage can survive radical representation changes.

## Storage coordinates vs Matter identity

- storage coordinate frame may rebase,
- retained Matter lineage remains the logical identity relation,
- consumers holding local coordinates must explicitly participate in frame maintenance.

## Dirty boundaries vs representation/world identity

- invalidation region = work unit,
- render region = presentation partition,
- collider partition = physical representation,
- streaming/world chunk = world-management policy,
- none is automatically logical Matter/Space identity.

## Support transport vs gravity/orientation

Keeping an actor at a local support coordinate is not the same as deciding what “down”, adhesion or walkability mean for a tilted frame.

---

# CURRENT STOP CONDITION

**Do not autonomously expand P1 with more features before the Owner candidate is used.**

P1 has earned the right to be tested, not the right to be called good. The next major architectural decision should be pulled by direct interaction evidence.
