# FrameMatter Lab — current research state

Status: **live truth document**. Update when evidence materially changes what the project currently believes.

This is not a roadmap and not a historical log. See `ROADMAP.md` for current decision order and the evidence notes/checkpoints for measurements/history.

## Evidence language

- **DEFENDED (bounded)** — strong evidence inside an explicitly limited scope.
- **DEFENDED (integrated)** — behavior has survived composition through a shared runtime consumer, still without implying scale/product readiness.
- **PROVISIONAL** — useful current mechanism/hypothesis, not yet established by enough integrated consumers.
- **FALSIFIED / REJECTED** — a tempting shortcut or claim contradicted by evidence in the tested scope.
- **OPEN** — material unanswered question/debt.

No result at one maturity level silently implies the next.

---

# DEFENDED

## Matter authority — bounded

- Logical `CellVolume` is authoritative; render/collision state is derived and reconstructible.
- Matter coordinates are local and independent of world transform.
- Moving a representation does not mutate logical Matter.
- Retained Matter can survive representation/body replacement without being redefined by engine IDs.

## Dynamic construct representation — bounded

- The same logical Matter can back a dynamic `RigidBody3D` representation.
- A moving construct can rebuild mesh/collision/mass/COM/inertia after Matter mutation while remaining numerically coherent in the tested sizes.
- Box-per-cell collision is useful as a truth/reference representation but is already rejected as scalable.

## Mass properties — bounded

- Equal-density unit-cell Matter mass/COM/full inertia can be computed independently from Jolt and matches solver observations to tight numerical tolerance in the tested shapes.
- Solver-observed COM is validation telemetry, not same-transaction authority for freshly created/rebuilt successors.

## Actor/support semantics — bounded

- Stock `CharacterBody3D` semantics are unsuitable for standing on a freely simulated construct in the tested setup; catastrophic, largely mass-insensitive rigid-body acceleration was observed.
- Support-frame transport can be represented explicitly above the rigid solver without scene-tree parenting and without granting the actor unlimited force authority over the construct.
- Query-driven ordinary contact reacquisition is not sufficient for lossless topology replacement; explicit successor mapping removes the one-tick slip observed in the tested split.

## Topology split / merge — bounded

- A moving rigid Matter frame can split into connected-component successors while preserving retained-cell world position and instantaneous rigid velocity field within numerical tolerance.
- Successors may compact/rebase local Matter storage while preserving world continuity through an explicit mapping.
- Frames already sharing one rigid velocity field can be compatibly merged/reframed with negligible discontinuity in the tested case.
- Incompatible rigid binding can preserve total linear and angular momentum while dissipating kinetic energy as an explicitly inelastic bind.
- Split is not the physical inverse of later merge: once constraints are released, successor frames naturally diverge.

## Lifecycle timing — bounded, now refined by integration

- Destroy/recreate replacement performed only after the relevant solver step loses a simulation phase and accumulates large drift under repetition.
- Replacement requested/committed at the `SceneTree.physics_frame` boundary can preserve phase and install a fresh RID in time for the upcoming `PhysicsServer3D.step()` in the tested cases.
- Godot's relevant ordering is materially distinct:
  1. `PhysicsServer3D.sync()`,
  2. `SceneTree.physics_frame`,
  3. node `_physics_process`,
  4. `PhysicsServer3D.end_sync()`,
  5. `PhysicsServer3D.step()`.
- A fresh RID can already move in that upcoming solver step while its `RigidBody3D` node still exposes the pre-step transform until the next `PhysicsServer3D.sync()`.
- Same-step physical truth and same-frame scene-node visibility are therefore different authority/observation questions.
- PhysicsServer/RID state is the correct observer when validating the first solver result of a freshly installed provider; node state becomes synchronized on the next physics boundary.
- The earlier shorthand **pre-physics commit boundary** should now be read specifically as a lifecycle commit before the upcoming server `step`, not as a claim that every observer layer updates synchronously.

This distinction is independently visible in both provider-replacement evidence and earlier binding telemetry (`server_step_displacement > 0`, `node_process_displacement == 0`, later `node_sync_gap == 0`).

## In-place static/dynamic lifecycle control — bounded

- One `ConstructBody` can survive dynamic → `FREEZE_MODE_STATIC` → dynamic → `FREEZE_MODE_STATIC` while keeping the same instance and RID.
- When measured at the actual transaction boundary, freeze/unfreeze produces no synchronous pose jump in the tested case; arbitrary orientation remains stable while frozen.
- Matter, lineage and derived collision/mass state can be mutated/rebuilt while the same host body is frozen without moving its pose.
- The same host can resume active rigid motion after unfreeze when velocity is explicitly commanded again.
- Godot/Jolt freeze is **not** a general pause/resume guarantee for solver velocity state: linear/angular velocity properties remain visible through the frozen window and immediately after unfreeze, but the first subsequent solver step zeroed them in the bounded probe.
- In-place freeze is therefore a defended low-churn lifecycle control, not the only provider strategy.

Evidence: `docs/evidence/i0a-freeze-unfreeze-semantics.md`.

## Logical local Space / real provider lifecycle — integrated

I0B supplies the first integrated evidence for the semantic separation:

**logical Space ≠ current engine provider**.

In the tested shared runtime path:

- one persistent logical Space identity survives `MatterRepresentation → ConstructBody → MatterRepresentation`,
- each concrete provider has a different engine identity,
- one authoritative `CellVolume` + `MatterLineageMap` pair remains owned by the logical Space rather than cloned into provider truth,
- the old provider is retired before the new provider is installed (`0` provider nodes after retire, `1` after install),
- static→dynamic activation preserves provider pose and occupied-Matter world positions to measured zero error,
- the fresh dynamic provider participates in the first upcoming solver step (`0.0746193230` displacement observed directly through PhysicsServer),
- the dynamic Node matches that server result on the next sync (`0` measured gap),
- dynamic translation/rotation and live Matter+lineage edits compose with the lifecycle path,
- dynamic→static replacement preserves the current arbitrary orientation/pose with no measured jump,
- the replacement-backed static Space remains stable and editable through the same mutation path.

This defends the underlying ownership/lifecycle semantics at **integrated** maturity. It does **not** make the current `LocalMatterSpace` class/API canonical or establish reusable-substrate maturity; one independent second consumer is still needed.

Evidence: `docs/evidence/i0b-provider-replacement-lifecycle.md`.

## Matter lineage — bounded, with first integrated lifecycle use

- Matter identity is not coordinate identity and not physics-body identity.
- Retained Matter lineage can survive compact rebase, split, merge and body replacement.
- Destroyed/recreated Matter at the same address receives a new lineage in the tested sidecar model.
- Repeated lineage campaigns produced no duplicate live tokens or resurrection of retired tokens in the tested scope.
- I0B additionally exercised one shared runtime mutation path where deletion retired lineage, creation assigned fresh lineage and retained-Matter material mutation preserved lineage through provider changes.

## Binding policy / mechanical relations — bounded

- Contact/connectivity, mechanical constraint and rigid bind/reframe are distinct relations.
- Independent Matter/frame identities can remain separate while being physically coupled by joints.
- Constraint ownership can follow retained Matter lineage through topology replacement.
- Destroying anchor-owner Matter retires that mechanical relation; recreating Matter at the same address does not resurrect it automatically.
- One topology event can make different per-anchor lifecycle decisions (`SUCCESSION` vs `RETIRE`).
- Constraint graphs can partition on split and contract on merge; a relation that becomes an internal/self-edge can retire.

## Oriented/stateful constraints — bounded

- `PinJoint3D` point constraints can survive endpoint succession when the logical joint anchor/frame is correctly rebased before endpoint replacement.
- `HingeJoint3D` succession requires preserving a full oriented constraint frame, not only an anchor position.
- In the tested hinge case, full-frame rebasing preserved axis alignment and real relative hinge motion.
- Motor and angular-limit behavior can survive topology succession.
- One split can partition two independently configured active hinges onto different successors while preserving distinct owner lineage, frame, identity, motor target and limit behavior.
- The inverse bounded contraction case also passes: two distinct external motorized/limited hinges can converge onto one inelastic merged successor while retaining separate owner lineage, full frames, joint identities and active state; the source relation that becomes an internal/self-edge retires.
- This closes the intended standalone stateful partition↔contraction research symmetry at bounded evidence maturity. It is **not** a production mechanics architecture claim.

## Host viability — bounded/integrated current layer

- Godot 4.7.x + built-in Jolt remains adequate for the current research layer.
- No defended result currently requires replacing the host engine or moving the core research layer to native C++.

---

# PROVISIONAL

## `LocalMatterSpace` implementation shape

The current class is deliberately small and experimental:

- it owns the one Matter + lineage pair,
- points to one active static/dynamic provider,
- queues provider transitions,
- commits them on `SceneTree.physics_frame`,
- provides a minimal mutation path.

The **semantics** above now have integrated evidence. The class name, API, ownership layout, signal shape and exact scheduling mechanism remain provisional until at least one independent consumer uses the same path successfully.

Do not expand it into a general manager/framework merely because I0B passed.

## Matter + lineage mutation authority

I0B validates one coherent shared mutation path for deletion/creation/retained material changes across provider lifecycle.

Still unresolved: whether lineage ultimately belongs inside a larger Matter-space aggregate, remains a sidecar under one mutation controller, or takes another durable representation. Current storage is not a persistence schema.

## Static/dynamic host strategy

Two useful strategies are now evidenced for different purposes:

- in-place `RigidBody3D` freeze/mode switching — low-churn control with explicit velocity caveat,
- true static/dynamic provider replacement — integrated continuity across provider identity/class change.

Do not prematurely collapse them into one canonical execution mode. A real interactive/actor consumer should reveal which transitions or representations are useful in practice.

## Physics material model

Current mass-property evidence assumes equal mass per occupied cell. `material_id` is not yet a complete physical material/density model.

---

# FALSIFIED / REJECTED (tested scope)

- Matter truth as scene nodes / cubes rather than logical data.
- Physics body/shape IDs as persistent gameplay identity.
- Scene-tree parenting as the physical model for actors/vehicles merely standing on moving constructs.
- Contact alone as sufficient support/frame membership semantics.
- One independent PhysicsSystem/domain per construct as a default architecture.
- Artificially enormous construct mass as a fix for stock kinematic actor→rigid-body interaction.
- Box-per-cell as a scalable final dynamic collision representation.
- Query-only contact reacquisition as a lossless topology successor handoff.
- Solver-observed COM as synchronous authority inside fresh topology transactions.
- Post-step physics-body replacement as an acceptable repeated topology commit point.
- Coordinate identity as Matter identity.
- Automatic nearest-cell resurrection of a destroyed mechanical anchor.
- Treating arbitrary rotated `local Space → canonical world voxel grid` as a trivially lossless representation transition.
- Treating `RigidBody3D.freeze` as an implicit promise that prior dynamic velocity will automatically resume on the next solver step after unfreeze.
- Treating an immediately-read `RigidBody3D.global_transform` after a server step as proof that a fresh RID did or did not participate in that same step; node visibility lags until server sync.

---

# OPEN — high-value debts

## Immediate / active-campaign debts

- Independent second consumer of the shared local-Space lifecycle path; current highest-value candidate is the interactive LAB.
- Interactive inspection of logical Space identity, active provider identity/kind, lineage/mutation state and lifecycle timing.
- Actor support relation surviving static↔dynamic provider-class changes.
- One topology split implemented through shared runtime execution rather than giant test-local orchestration.

## Important after integration

- scalable dynamic collision representation,
- dirty/local physical rebuild strategy,
- volumetric actor controller (walls/slopes/steps/ceilings),
- finite physically meaningful actor→construct force exchange,
- persistence identity across save/load,
- canonical-world extraction/reintegration under lattice-compatible transforms.

## Deferred until consumer pressure

- richer/breakable/looped mechanics and larger mechanics graphs,
- streaming and world scale,
- multiple simulation domains and migration,
- nested frames,
- spatial links/portals and query routing,
- curved/Planet Matter providers,
- JV-like vehicle integration,
- arbitrary bake/resample back into a canonical world lattice,
- networking/multiplayer.

---

# Important semantic distinctions

## Freeze vs provider replacement vs reintegration vs bake

- **In-place freeze:** one dynamic host body changes host mode; no engine-identity replacement.
- **Provider replacement:** one logical local Space keeps its Matter/lineage truth while the concrete static/dynamic host changes; arbitrary world pose can remain lossless.
- **Lossless lattice reintegration:** local Space is absorbed into a canonical lattice only when the relative transform maps cells exactly to cells.
- **Bake / resample:** incompatible pose is converted to a target lattice; may create/destroy/merge/split cells and needs an explicit provenance/error policy.

Do not use the word “deactivate” to blur these operations.

## Space vs representation vs simulation domain

- Logical Space is not an engine node/body provider identity.
- Representation/provider is the current host for rendering/physics/pose authority.
- Simulation domain is the solver context in which direct interactions occur.
- These concepts may correlate in simple tests but must not be defined as identical.

## Solver state vs synchronized scene-node state

- PhysicsServer/RID state can already contain the result of the current solver step.
- A `RigidBody3D` node may still expose the previously synchronized transform until the next `PhysicsServer3D.sync()`.
- Debugging, actor handoff and future lifecycle observers must state which layer/time they are reading rather than treating both as one instantaneous truth.

## Contact vs constraint vs rigid bind

- Contact may create forces without changing logical relation.
- Constraint keeps distinct frame identities while coupling motion.
- Rigid bind/reframe replaces several rigid frames with one successor according to explicit policy.

---

# Product pressure kept in view

Long-term validation must eventually include a deliberately small Owner-facing slice:

> walk → dig/place → activate/freeze a local Space → ride/build on it → use one simple mechanism → inspect/debug consequences.

This is **not** the next implementation target. The immediate interactive LAB should remain a research consumer/debug workbench, not prematurely become this gameplay slice.