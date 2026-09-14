# FrameMatter Lab — current research state

Status: **live truth document**. Update when evidence materially changes what the project currently believes.

This is not a roadmap and not a historical log. See `ROADMAP.md` for current decision order and the evidence notes/checkpoints for measurements/history.

## Evidence language

- **DEFENDED (bounded)** — strong evidence inside an explicitly limited scope.
- **PROVISIONAL** — useful current mechanism/hypothesis, not yet established by enough integrated consumers.
- **FALSIFIED / REJECTED** — a tempting shortcut or claim contradicted by evidence in the tested scope.
- **OPEN** — material unanswered question/debt.

No bounded result implies production readiness, scale readiness or product value.

---

# DEFENDED (bounded)

## Matter authority

- Logical `CellVolume` is authoritative; render/collision state is derived and reconstructible.
- Matter coordinates are local and independent of world transform.
- Moving a representation does not mutate logical Matter.
- Retained Matter can survive representation/body replacement without being redefined by engine IDs.

## Dynamic construct representation

- The same logical Matter can back a dynamic `RigidBody3D` representation.
- A moving construct can rebuild mesh/collision/mass/COM/inertia after Matter mutation while remaining numerically coherent in the tested sizes.
- Box-per-cell collision is useful as a truth/reference representation but is already rejected as scalable.

## Mass properties

- Equal-density unit-cell Matter mass/COM/full inertia can be computed independently from Jolt and matches solver observations to tight numerical tolerance in the tested shapes.
- Solver-observed COM is validation telemetry, not same-transaction authority for freshly created/rebuilt successors.

## Actor/support semantics

- Stock `CharacterBody3D` semantics are unsuitable for standing on a freely simulated construct in the tested setup; catastrophic, largely mass-insensitive rigid-body acceleration was observed.
- Support-frame transport can be represented explicitly above the rigid solver without scene-tree parenting and without granting the actor unlimited force authority over the construct.
- Query-driven ordinary contact reacquisition is not sufficient for lossless topology replacement; explicit successor mapping removes the one-tick slip observed in the tested split.

## Topology split / merge

- A moving rigid Matter frame can split into connected-component successors while preserving retained-cell world position and instantaneous rigid velocity field within numerical tolerance.
- Successors may compact/rebase local Matter storage while preserving world continuity through an explicit mapping.
- Frames already sharing one rigid velocity field can be compatibly merged/reframed with negligible discontinuity in the tested case.
- Incompatible rigid binding can preserve total linear and angular momentum while dissipating kinetic energy as an explicitly inelastic bind.
- Split is not the physical inverse of later merge: once constraints are released, successor frames naturally diverge.

## Lifecycle timing

- Destroy/recreate replacement committed after the solver step loses one simulation phase and accumulates large drift under repetition.
- Equivalent replacement committed before the upcoming PhysicsServer step preserves continuity to micrometer-scale error in the tested round trips.
- Representation-changing transactions that replace physics-body identity therefore require a defended **pre-physics commit boundary**.

## Matter lineage

- Matter identity is not coordinate identity and not physics-body identity.
- Retained Matter lineage can survive compact rebase, split, merge and body replacement.
- Destroyed/recreated Matter at the same address receives a new lineage in the tested sidecar model.
- Repeated lineage campaigns produced no duplicate live tokens or resurrection of retired tokens in the tested scope.

## Binding policy / mechanical relations

- Contact/connectivity, mechanical constraint and rigid bind/reframe are distinct relations.
- Independent Matter/frame identities can remain separate while being physically coupled by joints.
- Constraint ownership can follow retained Matter lineage through topology replacement.
- Destroying anchor-owner Matter retires that mechanical relation; recreating Matter at the same address does not resurrect it automatically.
- One topology event can make different per-anchor lifecycle decisions (`SUCCESSION` vs `RETIRE`).
- Constraint graphs can partition on split and contract on merge; a relation that becomes an internal/self-edge can retire.

## Oriented/stateful constraints

- `PinJoint3D` point constraints can survive endpoint succession when the logical joint anchor/frame is correctly rebased before endpoint replacement.
- `HingeJoint3D` succession requires preserving a full oriented constraint frame, not only an anchor position.
- In the tested hinge case, full-frame rebasing preserved axis alignment and real relative hinge motion.
- Motor and angular-limit behavior can survive topology succession.
- One split can partition two independently configured active hinges onto different successors while preserving distinct owner lineage, frame, identity, motor target and limit behavior.
- The inverse bounded contraction case also passes: two distinct external motorized/limited hinges can converge onto one inelastic merged successor while retaining separate owner lineage, full frames, joint identities and active state; the source relation that becomes an internal/self-edge retires.
- This closes the intended standalone stateful partition↔contraction research symmetry at bounded evidence maturity. It is **not** a production mechanics architecture claim.

## Host viability

- Godot 4.7.x + built-in Jolt remains adequate for the current research layer.
- No defended result currently requires replacing the host engine or moving the core research layer to native C++.

---

# PROVISIONAL

## Logical local Space / frame identity

Current working hypothesis:

- one persistent logical local Space/frame identity survives host representation changes,
- exactly one active provider owns current pose/velocity authority,
- provider replacement atomically transfers authority,
- dependents refer to logical frame/ownership relations and resolve kinematics through the current provider.

This is **not** yet a canonical class/API design and has not yet passed the integrated static↔dynamic lifecycle campaign.

## Matter + lineage mutation authority

The next integrated consumer likely needs one mutation path that makes retained/destroyed/created Matter semantics explicit and keeps `CellVolume` + lineage coherent.

It is not yet established whether lineage belongs inside a larger `MatterSpace`, beside Matter under one mutation controller, or in another representation.

## Pre-physics commit facility

The timing invariant is defended, but a reusable runtime queue/boundary does not yet exist. Tests currently orchestrate the timing manually.

A minimal shared pre-physics commit path is likely justified by the next representation lifecycle consumer.

## Static/dynamic host strategy

At least two strategies remain viable:

- in-place `RigidBody3D` freeze/mode changes,
- true replacement between distinct static and dynamic representations.

The new lifecycle campaign begins by measuring in-place host semantics before choosing a lifecycle contract, then challenges representation replacement separately.

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

---

# OPEN — high-value debts

## Immediate / active-campaign debts

- Measure same-body `RigidBody3D` freeze/unfreeze semantics before defining the in-place lifecycle contract.
- Persistent logical Space/frame identity through real representation lifecycle.
- Pose/velocity authority transfer between providers without dual truth.
- One coherent Matter+lineage mutation authority for an interactive consumer.
- Shared pre-physics commit path instead of test-local scheduling.
- Static↔dynamic lifecycle through both in-place control and true replacement.
- Interactive lab using the same lifecycle execution path as automated tests.
- Actor support relation surviving provider-class changes.
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

## Freeze vs reintegration vs bake

- **Freeze / representation transition:** same local Matter lattice and identity, static/dynamic host changes; arbitrary world orientation may remain lossless.
- **Lossless lattice reintegration:** local Space is absorbed into a canonical lattice only when the relative transform maps cells exactly to cells.
- **Bake / resample:** incompatible pose is converted to a target lattice; may create/destroy/merge/split cells and needs an explicit provenance/error policy.

Do not use the word “deactivate” to blur these operations.

## Space vs representation vs simulation domain

- Logical Space is not an engine node/body.
- Representation/provider is the current host for rendering/physics/pose authority.
- Simulation domain is the solver context in which direct interactions occur.
- These concepts may correlate in simple tests but must not be defined as identical.

## Contact vs constraint vs rigid bind

- Contact may create forces without changing logical relation.
- Constraint keeps distinct frame identities while coupling motion.
- Rigid bind/reframe replaces several rigid frames with one successor according to explicit policy.

---

# Product pressure kept in view

Long-term validation must eventually include a deliberately small Owner-facing slice:

> walk → dig/place → activate/freeze a local Space → ride/build on it → use one simple mechanism → inspect/debug consequences.

This is not the current implementation target. It is the recurring product pressure that prevents the substrate from optimizing only for elegant isolated technology.