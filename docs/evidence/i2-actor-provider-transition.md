# I2 — actor support through provider replacement

Status: **FULL PASS / integrated lifecycle evidence**

Primary commit under test: `d48ae1325d164287e8ccf0f04b8c20327c65bb71`

CI authority: `Validate research harness` run `34880047835`; fast and full research jobs both passed, including all pre-existing G3/topology/mechanics ratchets after the actor support change.

## Question

Can an actor keep one logical support relation to a `LocalMatterSpace` while the concrete support provider changes `static MatterRepresentation → dynamic ConstructBody → static MatterRepresentation`, without test-local support handoff orchestration?

## Runtime change under test

`FrameProbeCharacter` now distinguishes:

- logical support ownership: optional `support_space: LocalMatterSpace`,
- current concrete support frame/provider: `support_body`,
- local support coordinate: `support_local_center`.

When a grounded actor is supported by a `LocalMatterSpace`, the actor resolves the Space's current provider at the start of its physics tick. If that provider changed while the local Matter lattice stayed identical, it transfers the concrete support frame while preserving the same local support coordinate.

This path is deliberately limited to the current static↔dynamic provider lifecycle. Topology rebases still use explicit `transfer_support_frame(new_support, mapped_local_center)` because their local coordinates can change.

## Result

**PASS.**

Measured fast-path result:

- logical Space ID: `28672263637`,
- initial static provider ID: `28689040854`,
- dynamic provider ID: `31608276438`,
- final static provider ID: `40500200918`,
- activation local-coordinate jump: `0.0000000000`,
- activation world jump: `0.0000002384`,
- maximum dynamic local drift over the ride: `0.0000201234`,
- dynamic grounded losses: `0`,
- frames with wrong dynamic logical/concrete support: `0`,
- dynamic provider linear-velocity error caused by actor: `0.0000000000`,
- dynamic provider angular-velocity error caused by actor: `0.0000000000`,
- final pre-freeze dynamic phase advance: `0.0226680003`,
- provider pose jump at dynamic→static commit: `0.0000000000`,
- actor local-coordinate jump at freeze: `0.0000006743`,
- actor world jump attributable to the provider transition at the transaction boundary: `0.0000000000`,
- post-freeze static local drift: `0.0000000000`,
- static grounded losses: `0`,
- frames with wrong final support: `0`,
- logical provider-support transfers: `2`,
- ordinary contact acquisitions across the whole lifecycle: `1`.

## Important timing finding

The first I2 run failed only because the probe compared the actor's last scene-node-visible position with its position after the next physics boundary. The old dynamic provider legitimately advanced one final solver phase before `PhysicsServer3D.sync` exposed that state and `LocalMatterSpace` committed the static replacement.

That `0.0226680003` movement was therefore **phase advance**, not a transition teleport.

After separating those measurements, the actual provider replacement had zero provider pose jump and zero actor world-space jump at the transaction boundary.

This reinforces the existing timing model:

1. PhysicsServer sync exposes the previous solver result to scene nodes,
2. `SceneTree.physics_frame` lifecycle transactions commit,
3. node physics processing runs,
4. PhysicsServer performs the next step,
5. that new solver state becomes node-visible at the next sync.

## What this establishes

Within the tested same-local-lattice lifecycle:

- actor support can refer to logical Space ownership rather than concrete provider identity,
- static collision can be normalized from the internal `StaticBody3D` to its owning `MatterRepresentation`,
- concrete provider identity may change under a grounded actor without fresh contact acquisition,
- support velocity coherently changes from static zero to the dynamic provider velocity field and back to zero,
- the actor remains locally stable during translating/rotating dynamic motion,
- actor support logic does not apply uncontrolled kinematic impulses to the dynamic provider,
- the existing explicit topology-rebase handoff path remains valid and all old actor/topology/mechanics ratchets remain green.

## Explicit non-claims

This does **not** establish:

- arbitrary topology succession without an explicit local-coordinate map,
- a production/general character controller,
- walls/slopes/steps/ceilings or arbitrary gravity,
- finite physical actor↔construct force exchange,
- support across multiple simulation domains,
- persistence/save-load support identity,
- final `LocalMatterSpace` or actor API design.
