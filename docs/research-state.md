# FrameMatter Lab — current research state

Status: **live truth document**. Update when evidence materially changes what the project currently believes.

This is not a roadmap and not a historical log. See `ROADMAP.md` for decision order and `docs/evidence/` for measurements/history.

## Evidence language

- **DEFENDED (bounded)** — strong evidence inside an explicitly limited probe.
- **DEFENDED (integrated)** — behavior has survived composition through shared runtime and neighboring systems.
- **DEFENDED (reusable-substrate, narrow)** — materially different consumers exercise the same shared path successfully.
- **PROVISIONAL** — useful current mechanism/hypothesis; implementation shape is not established strongly enough to freeze.
- **FALSIFIED / REJECTED** — shortcut or claim contradicted by evidence in the tested scope.
- **OPEN** — material unanswered question/debt.

No result at one maturity level silently implies the next. In particular, integrated lifecycle evidence is not scale evidence and neither is playability/product evidence.

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

I0B established the first integrated lifecycle path; the actual interactive LAB then became a materially different consumer of the same provider/mutation execution path.

Within that scope:

- one logical `LocalMatterSpace` owns one authoritative Matter + lineage pair,
- static and dynamic engine providers are replaceable derived hosts,
- concrete provider identity/class may change without redefining logical Space identity,
- old provider authority retires before replacement authority is installed,
- static→dynamic and dynamic→static provider replacement preserve the tested arbitrary world pose,
- dynamic motion/rotation composes with live Matter mutation,
- post-freeze static Matter remains editable through the same mutation authority,
- LAB uses this shared runtime path rather than owning a parallel replacement implementation.

This is the first narrow reusable-substrate evidence in FrameMatter. It does **not** make the current class/API/layout canonical.

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
- Moving constructs survive live mesh/collision/mass/COM/inertia rebuilds in tested small sizes.
- Equal-density unit-cell mass/COM/full inertia calculations independently match solver observations tightly in tested shapes.
- Synchronous logical/topology code uses Matter-derived COM; solver-observed COM remains telemetry rather than fresh-transaction authority.

## Actor/controller semantics — bounded

- Stock `CharacterBody3D` interaction with freely simulated constructs is unsuitable in the tested setup; severe largely mass-insensitive rigid-body acceleration was observed.
- Explicit support-frame transport above the rigid solver avoids scene-tree parenting and does not grant the actor unlimited force authority.
- Ordinary query/contact reacquisition alone is not lossless for topology replacement; explicit successor mapping is required when local coordinates rebase.
- The current actor evidence is not a production volumetric controller claim.

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

The current class now owns more real execution than during I0B:

- Matter + lineage authority,
- one active provider,
- static/dynamic provider transitions,
- shared mutation path,
- bounded queued connected-component split,
- source retirement and successor creation,
- explicit split mapping result.

The semantics have materially stronger evidence than the class structure itself. Name, API, signal layout, direct parent/child ownership, scheduling mechanism and split-result representation remain provisional.

Do not expand this into a general world/Space manager merely because the current campaign passed.

## Static/dynamic host strategy

Both approaches remain useful evidence-backed tools:

- in-place rigid-host freeze — low churn, explicit velocity caveat,
- true static/dynamic provider replacement — identity/class replacement while logical Space remains stable.

A later real consumer may use one, both, or a different optimized representation.

## Matter + lineage storage

Current sidecar ownership is coherent under one mutation controller, but it is not a save schema or final data model. Persistence identity is intentionally deferred.

## Physical material model

Current mass properties assume equal mass per occupied cell. `material_id` is not yet a complete density/friction/material system.

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
- Solver-observed COM as synchronous authority inside fresh topology transactions.
- Post-step body replacement as acceptable repeated topology commit timing.
- Automatic nearest-cell resurrection of destroyed mechanical anchors.
- Arbitrary rotated local Space → canonical voxel grid as trivially lossless reintegration.
- `RigidBody3D.freeze` as an implicit automatic velocity pause/resume guarantee.
- Immediately-read node transform after a server step as proof that a fresh RID did or did not participate in that same step.
- Arbitrarily assigning retired source Space identity to one topology fragment without an explicit policy.

---

# OPEN — re-audited priorities

## Active: R0 — representation / scale baseline

The lifecycle path is coherent enough to stop guessing about representation cost.

Current reference implementation deliberately does expensive/simple work:

- `MatterRepresentation` and `ConstructBody` rebuild the entire visual mesh,
- all previous collision shapes are destroyed,
- one `BoxShape3D`/`CollisionShape3D` is created per occupied cell,
- mass properties are recomputed over Matter,
- connected-component topology scans the full volume and materializes full-size component volumes before compaction.

R0 must measure these costs across controlled sizes and occupancy patterns **before** choosing an optimization.

Required baseline dimensions include at least:

- occupied cell count,
- volume extent / scanned cell count,
- collision shape count,
- mesh vertex count,
- initial static provider build cost,
- initial dynamic provider build cost,
- dynamic one-cell mutation/full rebuild cost,
- connectivity/component extraction cost,
- shared split transaction cost for a deliberately disconnected case.

R0 is instrumentation/measurement. No greedy collision, dirty regions, chunk system or asynchronous scheduler should be introduced until the baseline identifies the dominant pressure.

## Important after R0 / consumer-triggered

- scalable dynamic collision representation,
- edit-local/dirty physical rebuild strategy,
- volumetric actor controller for walls/slopes/steps/ceilings,
- finite physically meaningful actor→construct force exchange,
- persistence identity across save/load,
- canonical-world extraction/reintegration for lattice-compatible transforms.

## Deferred until real pressure

- richer/breakable/looped mechanics,
- streaming/world scale,
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

---

# Product pressure kept in view

Long-term validation still needs a deliberately small Owner-facing slice:

> walk → dig/place → activate/freeze a local Space → ride/build on it → use one simple mechanism → inspect/debug consequences.

That is not R0. R0 exists so the substrate can reach representative size without optimizing blindly or allowing the current reference representation to become accidental architecture.