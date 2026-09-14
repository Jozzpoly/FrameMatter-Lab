# FrameMatter Lab — current research state

Status: **live truth document**. Update when evidence materially changes what the project currently believes.

This is not a roadmap and not a historical log. See `ROADMAP.md` for decision order and `docs/evidence/` for measurements/history.

## Evidence language

- **DEFENDED (bounded)** — strong evidence inside an explicitly limited probe.
- **DEFENDED (integrated)** — behavior has survived composition through shared runtime and neighboring systems.
- **DEFENDED (reusable-substrate, narrow)** — materially different consumers exercise the same shared path successfully.
- **DEFENDED (scale-pressure)** — controlled measurements identify or materially remove a scale bottleneck in the tested range without implying production scale.
- **PROVISIONAL** — useful current mechanism/hypothesis; implementation shape is not established strongly enough to freeze.
- **FALSIFIED / REJECTED** — shortcut or claim contradicted by evidence in the tested scope.
- **OPEN** — material unanswered question/debt.

No result at one maturity level silently implies the next. In particular, integrated lifecycle evidence is not production-scale evidence and neither is playability/product evidence.

---

# DEFENDED

## Matter authority — bounded/integrated

- Logical `CellVolume` is authoritative; render/collision state is derived and reconstructible.
- Matter coordinates are local and independent of world transform.
- Moving a representation does not mutate logical Matter.
- Matter identity is not coordinate identity and not physics-body/shape identity.
- Retained Matter lineage survives the tested compact rebases, split/merge replacement and provider changes.
- Destroy/recreate at the same address creates fresh lineage rather than resurrecting the old logical Matter.
- Shared `LocalMatterSpace.mutate_cell` exercises deletion, creation and retained-Matter material mutation while preserving the one authority pair.

## Logical local Space / provider lifecycle — reusable-substrate evidence in a narrow scope

The defended semantic separation is:

**logical Space ≠ current engine provider**.

I0B established the first integrated lifecycle path; the actual LAB then became a materially different consumer of the same provider/mutation execution path.

Within that scope:

- one logical `LocalMatterSpace` owns one authoritative Matter + lineage pair,
- static and dynamic engine providers are replaceable derived hosts,
- concrete provider identity/class may change without redefining logical Space identity,
- old provider authority retires before replacement authority is installed,
- static→dynamic and dynamic→static provider replacement preserve the tested arbitrary world pose,
- dynamic motion/rotation composes with live Matter mutation,
- post-freeze static Matter remains editable through the same mutation authority,
- LAB uses this shared runtime path rather than owning a parallel replacement implementation.

This is narrow reusable-substrate evidence. It does **not** make the current class/API/layout canonical.

Evidence: `docs/evidence/i0b-provider-replacement-lifecycle.md`, `docs/evidence/lifecycle-lab-consumer.md`.

## Actor support across provider replacement — integrated

I2 establishes a narrow but important relation:

**actor support can refer to a logical Space while the concrete provider underneath that relation changes.**

In the tested static→dynamic→static lifecycle:

- actor acquired support through ordinary contact once,
- provider replacement did not require test-local manual handoff,
- logical `support_space` remained stable,
- concrete support provider changed coherently,
- no grounded frame was lost,
- no wrong support frame was observed,
- dynamic local drift remained very small,
- support linear/angular velocity matched the dynamic provider,
- freeze-to-static produced no transaction jump when measured at the correct boundary.

Topology rebasing remains a different case: if local coordinates change, explicit source→successor mapping is still required.

Evidence: `docs/evidence/i2-actor-provider-transition.md`.

## P0 embodied actor/edit/lifecycle composition — integrated automated evidence

P0 turns the real LAB into an embodied consumer instead of only lifecycle instrumentation.

Within the current **world-up translation+yaw** scope, one real scene composes:

- ordinary actor support acquisition,
- relative walking on the supported Space,
- direct selected-cell Matter removal/placement,
- fresh lineage on recreated Matter,
- static→dynamic provider replacement under one logical Space,
- stationary riding and relative walking while the Space translates/yaws,
- occupancy editing while the Space is moving,
- dynamic→static provider replacement while actor support remains coherent.

Final automated P0 gate on commit `09eb18e8…` / run `#202` measured:

- `ride_floor_loss = 0`,
- `walk_floor_loss = 0`,
- `post_edit_floor_loss = 0`,
- stationary local drift `0.00000812`,
- local walk displacement `0.95959115`,
- distinct fresh lineage after both static and moving remove/recreate cycles.

The same commit passed current-campaign validation, fast invariants and the full historical research ratchet through R2A.

This is **not playability/product evidence**. Mouse-selection clarity, camera/movement feel, perceived latency and overall usefulness still require direct Owner interaction.

Evidence: `docs/evidence/p0-interactive-consumer.md`.

## One→many topology split through shared runtime — integrated

I3 moves connected-component split from giant test-local orchestration into shared lifecycle execution.

In the tested dynamic split:

- ordinary shared mutation destroys bridge Matter and retires its lineage,
- split is queued and committed at the defended lifecycle boundary,
- source Space/provider authority retires explicitly,
- the source keeps no live Matter/lineage authority after commit,
- no fragment arbitrarily inherits source Space identity,
- fresh successor Spaces receive compact Matter + lineage storage,
- retained Matter world placement is preserved within numerical tolerance,
- source rigid velocity field is inherited at retained Matter points within numerical tolerance,
- fresh successor RIDs participate in the first upcoming solver step,
- actor support consumes explicit source→successor mapping and remains grounded/stable on the compact successor.

The final I3 run measured 65/65 retained cells and 65/65 retained lineage tokens across two successors, with world-position and velocity-field errors on the order of `1e-6`, no actor floor loss and post-split local drift on the order of `1e-5`.

Evidence: `docs/evidence/i3-shared-topology-split.md`.

## Lifecycle timing / observation layers — integrated and repeatedly reproduced

The current timing model is materially important:

1. `PhysicsServer3D.sync()` exposes the prior solver result to scene nodes,
2. `SceneTree.physics_frame` is emitted,
3. node `_physics_process` callbacks run,
4. `PhysicsServer3D.end_sync()`,
5. the upcoming solver `step()` runs.

Consequences established repeatedly across provider replacement, actor lifecycle and topology split:

- a fresh RID installed at `physics_frame` can participate in the upcoming solver step,
- the corresponding `RigidBody3D` node does not expose that new solver transform until the next sync,
- transaction truth, current PhysicsServer/solver truth and synchronized consumer/node visibility are therefore related but not universally simultaneous,
- phase advance of the old provider must not be misdiagnosed as a replacement teleport,
- observer code/tests must state which layer/time they are sampling.

Both I2 and I3 produced initial false-negative assertions when two observation phases were mixed; correcting the observer without changing runtime behavior removed the apparent discontinuity.

## In-place static/dynamic lifecycle control — bounded

- One `ConstructBody` can survive dynamic → `FREEZE_MODE_STATIC` → dynamic → `FREEZE_MODE_STATIC` while keeping the same instance/RID.
- Arbitrary pose remains stable while frozen in the tested case.
- Matter/lineage and derived collision/mass state can rebuild on the frozen host.
- Freeze is not an implicit velocity pause/resume contract: properties remained visible, but the first solver step after unfreeze zeroed them in the bounded probe.

Therefore in-place freeze is a useful control, not the only or automatically preferred provider strategy.

Evidence: `docs/evidence/i0a-freeze-unfreeze-semantics.md`.

## Dynamic construct / mass properties — bounded

- Logical Matter can back a dynamic `RigidBody3D` representation.
- Moving constructs survive live mesh/collision/mass/COM/inertia rebuilds in tested sizes.
- Equal-density unit-cell mass/COM/full inertia calculations independently match solver observations tightly in tested shapes.
- Synchronous logical/topology code uses Matter-derived COM; solver-observed COM remains telemetry rather than fresh-transaction authority.

## Exact merged-cuboid collision — scale-pressure + integrated

R0 established that per-occupied-cell collision node/shape materialization dominated the first tested scale curve. R1 then replaced that reference representation with an exact derived cuboid compiler while keeping `PER_CELL` available as a control.

R1 establishes in the tested scope:

- exact occupied collision coverage with zero coverage errors across dense, shell and sparse-skeleton cases,
- collision cuboids remain disposable derived state and do not define Matter identity,
- Matter-derived mass/COM/inertia semantics do not depend on collider count,
- dense `14³` compiles from `2744` reference shapes to `1` merged shape,
- shell `14³` compiles from `1016` reference shapes to `6`,
- dense/shell provider and full-rebuild cost changes by orders of magnitude in the strongest cases,
- sparse skeleton cases improve only slightly, supporting the R0 diagnosis that shape materialization—not a universal unrelated speedup—was the dominant dense/shell pressure,
- provider replacement, live occupancy editing, solver mass properties, actor support and topology succession remain coherent with merged collision active.

`MERGED_CUBOIDS` is therefore the current provider default. `PER_CELL` remains a reference representation, not a scalability candidate.

Evidence: `docs/evidence/r0-representation-scale-baseline.md`, `docs/evidence/r1-exact-collision-aggregation.md`.

## Post-aggregation cost ranking — scale-pressure

R2P establishes the current tested cost structure after R1:

- installing the already-small merged collider set into engine bodies is negligible relative to full provider rebuild,
- full visual mesh generation is the largest measured component in dense/shell cases,
- full cuboid compilation and Matter COM scans remain visible because each still traverses the whole extent,
- material-only and true occupancy mutations currently route through essentially the same whole-provider rebuild path,
- current material-only full rebuild is execution waste under implemented semantics, not evidence that future materials can never affect rendering/physics,
- merged collision also removes most split-commit shape-materialization cost, exposing topology preflight/compaction/provider reconstruction as meaningful remaining split work.

Evidence: `docs/evidence/r2p-post-aggregation-profile.md`.

## Derived update locality — bounded scale-pressure challenger

R2A establishes a semantic/mechanical distinction without promoting a new runtime representation:

**dirty/invalidation partition ≠ final physical representation partition.**

In test-local regional derivation across `14³`, `24³` and `32³` dense/shell/skeleton volumes:

- exact occupied collision coverage remained intact,
- exposed mesh vertex count matched the global mesher before and after occupancy mutation,
- one-cell dirty derivation remained bounded to a small region neighborhood,
- locality speedups grew strongly with extent, reaching roughly `174×/138×/202×` for dense/shell/skeleton at `32³` with region edge 4,
- but dense `32³` collision partition inflated from global `1` shape to `512` regional shapes at edge 4 and `64` at edge 8,
- shell `32³` inflated from `6` global shapes to `384` / `96`.

Therefore the locality concept is defended enough to revisit under real edit pressure, but the naive fixed-region collision representation is **not** promoted. A future solution should not blindly undo R1's global collision compression merely to obtain dirty update boundaries.

Evidence: `docs/evidence/r2a-derived-region-locality.md`.

## Actor/controller semantics — bounded and now more sharply scoped

- Stock `CharacterBody3D` interaction with freely simulated constructs is unsuitable in the tested setup; severe largely mass-insensitive rigid-body acceleration was observed.
- Explicit support-frame transport above the rigid solver avoids scene-tree parenting and does not grant the actor unlimited force authority.
- Ordinary query/contact reacquisition alone is not lossless for topology replacement; explicit successor mapping is required when local coordinates rebase.
- Translation+yaw support is now exercised by the embodied P0 consumer as well as narrower actor probes.
- Arbitrary pitch/roll support is **not defended** by the current actor. A P0 challenger with pitch+roll retained grounded support but accumulated about `0.501` local drift because support validation/snapping uses a world-down single ray against a tilted support plane.
- Fixing that finding requires an explicit semantic decision about world gravity vs frame-local gravity/adhesion and likely the role of volumetric actor collision; it must not be hidden in LAB glue.
- The current actor evidence is not a production volumetric controller claim.

Evidence: `docs/evidence/p0-interactive-consumer.md`.

## Topology / binding / mechanics — bounded

- Moving rigid Matter frames can split into connected components while preserving retained-cell world position and instantaneous rigid velocity field in tested cases.
- Compact/rebased successor storage is compatible with explicit world mapping.
- Compatible frames may merge/reframe with negligible discontinuity when already sharing a rigid velocity field.
- Incompatible rigid binding can preserve total linear/angular momentum while dissipating kinetic energy under explicit inelastic policy.
- Split is not the physical inverse of later merge; released successors naturally diverge.
- Contact, mechanical constraint and rigid bind/reframe are distinct relations.
- Independent frames can remain distinct while physically coupled by joints.
- Mechanical ownership can follow retained Matter lineage through topology changes.
- Destroying anchor-owner Matter retires the relation; same-address recreation does not resurrect it.
- Constraint graphs can partition on split and contract on merge.
- Pin and oriented hinge relations, including motor/limit state, survive the bounded succession/partition/contraction cases already recorded.

The standalone mechanics expansion is deliberately stopped. More joint catalogue/graph complexity requires a real integrated consumer trigger.

## Host viability — current layer

- Godot 4.7.x + built-in Jolt remains adequate for the present research layer.
- No defended result currently requires replacing the host or moving the core research path to native C++.

---

# PROVISIONAL

## `LocalMatterSpace` implementation shape

The current class owns real shared execution for:

- Matter + lineage authority,
- one active provider,
- static/dynamic provider transitions,
- shared mutation path,
- bounded queued connected-component split,
- source retirement and successor creation,
- explicit split mapping result.

The semantics have materially stronger evidence than the class structure itself. Name, API, signal layout, direct parent/child ownership, scheduling mechanism and split-result representation remain provisional.

Do not expand this into a general world/Space manager merely because current campaigns passed.

## Merged-cuboid compiler implementation

The semantic result of R1 is stronger than the current greedy algorithm.

The current deterministic x→y→z partition is adequate as a derived exact representation in tested cases, but R1 does not establish that it is globally minimal, optimal for edit locality, appropriate for every material model or the final physical partition strategy.

## Update-local representation mechanism

R2A strongly supports bounded dirty derivation as a future direction **if a consumer demonstrates the need**, but no implementation is canonical.

In particular, do not conflate:

- logical Matter storage,
- dirty/invalidation regions,
- visual mesh partitions,
- physical collider partitions,
- streaming/world chunks.

Those may eventually overlap for pragmatic reasons, but R2A is evidence against assuming they are identical by default.

## Static/dynamic host strategy

Both approaches remain useful evidence-backed tools:

- in-place rigid-host freeze — low churn, explicit velocity caveat,
- true static/dynamic provider replacement — identity/class replacement while logical Space remains stable.

A later real consumer may use one, both, or a different optimized representation.

## Matter + lineage storage

Current sidecar ownership is coherent under one mutation controller, but it is not a save schema or final data model. Persistence identity is intentionally deferred.

## Physical material model

Current mass properties assume equal mass per occupied cell. `material_id` is not yet a complete density/friction/material system. R1 cuboids may therefore merge currently occupied cells across visual/material IDs without claiming future physical-material equivalence.

---

# FALSIFIED / REJECTED in tested scope

- Matter truth as scene nodes/cubes rather than logical data.
- Physics body/shape IDs as durable gameplay identity.
- Coordinate identity as Matter identity.
- Scene-tree parenting as the physical model for actors/vehicles merely standing on moving constructs.
- Contact alone as sufficient logical support/frame membership.
- Query-only reacquisition as lossless topology successor handoff.
- One independent PhysicsSystem/domain per construct as a default architecture.
- Artificially enormous construct mass as a fix for stock kinematic actor→rigid interaction.
- Box-per-cell collision as a **scalable final** representation.
- Collision-shape count as a semantic proxy for occupied Matter-cell count.
- Solver-observed COM as synchronous authority inside fresh topology transactions.
- Post-step body replacement as acceptable repeated topology commit timing.
- Automatic nearest-cell resurrection of destroyed mechanical anchors.
- Arbitrary rotated local Space → canonical voxel grid as trivially lossless reintegration.
- `RigidBody3D.freeze` as an implicit automatic velocity pause/resume guarantee.
- Immediately-read node transform after a server step as proof that a fresh RID did or did not participate in that same step.
- Arbitrarily assigning retired source Space identity to one topology fragment without an explicit policy.
- Naive fixed derived-region collision partition as an automatically superior replacement for global merged collision merely because dirty derivation is faster.
- Treating arbitrary pitch/roll actor support as already solved by the current world-down single-ray support probe.

---

# OPEN — current re-audited priorities

## Active: P0 Owner interaction

The embodied P0 implementation and automated integrated composition gate are now green in the bounded translation+yaw scope.

The highest-information remaining P0 question is no longer “can these systems compose at all?” but:

> does the direct loop actually feel coherent, legible and useful when the Owner uses it?

Current interactive loop:

> walk on/around Matter → point at a local cell → remove/place Matter → activate the same logical Space → ride/walk on it → edit while moving → freeze it → inspect/debug the consequences.

The LAB uses the shared runtime rather than creating parallel semantics:

- `FrameProbeCharacter` for current support-frame behavior,
- `LocalMatterSpace` for logical ownership and mutation,
- shared static↔dynamic provider replacement,
- `MERGED_CUBOIDS` as current collision default,
- minimal follow camera, pointer selection and telemetry.

What remains specifically unresolved by automation:

- movement/camera feel,
- pointer targeting clarity,
- remove/place interaction clarity,
- perceived edit latency under natural repeated use,
- visual legibility of provider/motion/edit consequences,
- whether the loop exposes a compelling next pressure.

P0 is not evidence that the current actor is a final game controller.

Decision pressure from the Owner test:

- if edit latency is material, reopen representation with R2A locality evidence but do not equate dirty regions with collider chunks;
- if arbitrary orientation, walls/steps/ceilings or reaction forces become the blocker, move deliberately to the oriented/volumetric/finite-force actor frontier;
- if provider transition/support continuity fails under direct interaction, reproduce and reopen that lifecycle invariant rather than patching around it in LAB;
- if the substrate works but interaction is awkward or uninteresting, treat Owner experience as evidence before building more infrastructure;
- if the loop is coherent, choose the next pressure from what the Owner actually wants to do next rather than automatically extending P0.

## Important consumer-triggered frontiers

- oriented/volumetric actor semantics for pitch/roll, walls/slopes/steps/ceilings and local-vs-world gravity decisions,
- finite physically meaningful actor→construct force exchange,
- persistence identity across save/load,
- canonical-world extraction/reintegration for lattice-compatible transforms,
- scalable world/streaming boundaries once a concrete consumer exceeds one local active region.

## Deferred until real pressure

- richer/breakable/looped mechanics,
- multiple simulation domains/migration,
- nested frames,
- spatial links/portals/query routing,
- curved/Planet Matter providers,
- JV-like vehicle integration,
- arbitrary bake/resample to canonical lattice,
- networking/multiplayer.

---

# Important semantic distinctions

## Freeze vs provider replacement vs split vs reintegration vs bake

- **In-place freeze:** same dynamic host changes host mode; no engine-identity replacement.
- **Provider replacement:** same logical Space retains Matter/lineage while concrete host changes.
- **Topology split:** one logical Space retires and produces one or more successor Spaces according to explicit Matter mappings; no fragment automatically inherits source Space identity.
- **Lossless lattice reintegration:** local Space is absorbed into canonical lattice only when relative transform maps cells exactly to cells.
- **Bake/resample:** incompatible pose is converted to target lattice and requires geometry/material/provenance error policy.

## Space vs representation vs simulation domain

- logical Space is not provider identity,
- provider/representation is the current engine host,
- simulation domain is the solver context for direct physical interaction,
- these may correlate in simple tests but are not defined as identical.

## Transaction vs solver vs synchronized consumer state

- lifecycle transaction records the authoritative mapping/commit state,
- PhysicsServer may already contain the result of the current solver step,
- scene nodes/consumers may still expose the prior synchronized state until the next sync or their own update phase.

Debugging and handoff logic must not collapse these into one instantaneous “current transform”.

## Contact vs constraint vs rigid bind

- contact creates forces without changing logical relation,
- constraint couples distinct frames,
- rigid bind/reframe replaces several rigid frames with one successor under explicit policy.

## Logical Matter vs derived collision

- occupied Matter is logical truth,
- collider count/topology is a replaceable compilation detail,
- exact collision coverage can be preserved while collider identity/count changes radically,
- tests must target the semantic relationship between truth and representation, not assume one shape per cell.

## Dirty update boundaries vs representation identity

- an invalidation region is a bounded unit of work,
- a visual region is a derived render partition,
- a collider partition is a derived physical representation,
- none of those is automatically a logical Space, Matter identity or world-streaming chunk.

R2A directly demonstrates why keeping these concepts separable matters.

## Support-frame transport vs gravity/orientation semantics

- preserving an actor's local coordinate on a support frame is one concern,
- deciding what direction is “down”, what surface is walkable and whether the actor adheres to a tilted frame is another,
- P0 shows these cannot be silently collapsed: frame transport can remain coherent while a world-down ground probe produces local drift on pitch/roll support.

---

# Product pressure now in view

The deliberately small Owner-facing loop is implemented and mechanically gated in its current bounded scope:

> walk → dig/place → activate/freeze a local Space → ride/build on it → inspect/debug consequences.

The next evidence must come from actual Owner use. A simple mechanism remains a possible later extension, not a prerequisite for proving actor/edit/lifecycle composition. The next major architectural decision should be pulled by what that interaction exposes, not pushed by another speculative subsystem.