# I0B/I1 — logical Space through real provider replacement

Status: **FULL PASS / first integrated lifecycle evidence**

Commit under test: `5fcc3e32dde3b74eebbaa81e848b4e56adda66a3`

## Question

Can one persistent logical local Space preserve one authoritative Matter + lineage state through a real provider lifecycle:

`MatterRepresentation (static) → ConstructBody (dynamic) → MatterRepresentation (static)`

while concrete engine identities change, dynamic motion and live editing occur, and exactly one provider owns current representation authority?

## Shared runtime under test

The challenger uses `LocalMatterSpace`, an intentionally minimal experimental runtime owner. It is **not** a final Space manager or persistence architecture.

Its bounded responsibilities are:

- own one `CellVolume` and one `MatterLineageMap`,
- expose one persistent logical Space object identity,
- maintain exactly one active static or dynamic provider,
- retire the old provider before installing its successor,
- perform provider replacement at the `SceneTree.physics_frame` lifecycle boundary,
- reuse the same authoritative Matter object rather than cloning logical truth,
- provide one mutation path that updates Matter + lineage semantics and rebuilds the active provider.

The existing providers are reused directly:

- static: `MatterRepresentation`,
- dynamic: `ConstructBody`.

## Bounded scenario

1. Create rotated/nontrivially positioned logical Space with static provider.
2. Request dynamic activation with explicit linear/angular velocity.
3. Replace static provider with a fresh `ConstructBody` through shared runtime.
4. Verify first solver-step participation through the PhysicsServer RID.
5. Translate and rotate dynamically.
6. Perform three edits through the shared Space mutation path:
   - destroy Matter and retire its lineage,
   - create Matter with fresh lineage,
   - change material of retained Matter without changing lineage.
7. Replace dynamic provider with a fresh static `MatterRepresentation` at the current arbitrary pose.
8. Observe static stability.
9. Edit retained Matter again through the same mutation path after the freeze-to-static replacement.

## Final measurements

From the fast-path PASS:

- logical Space ID: `28420605396`
- initial static provider ID: `28437382613`
- dynamic provider ID: `30970742229`
- final static provider ID: `41976595925`
- activation pose jump: `0.0000000000`
- activation occupied-Matter world-position error: `0.0000000000`
- first dynamic **PhysicsServer** step displacement: `0.0746193230`
- next-sync dynamic Node↔server transform gap: `0.0000000000`
- later dynamic translation: `1.86324084`
- later dynamic rotation: `0.21547586`
- dynamic→static replacement pose jump: `0.0000000000`
- final static orientation distance from world identity: `0.75752562`
- max final static drift: `0.0000000000`
- final occupied cells: `71`
- final collision shapes: `71`
- lineage changes relative to initial state: `2`

Assertions also established that each transition observed:

- `provider_count_after_retire == 0`,
- `provider_count_after_install == 1`.

No overlap period with two live Matter providers was accepted by the test contract.

## Important timing finding

Two initial red runs were useful measurement/timing challenges rather than discarded noise.

### First interpretation

The first challenger read `dynamic_body.global_transform` after the first solver step and observed zero displacement. Moving the shared commit from node `_physics_process` to `SceneTree.physics_frame` did not change that observation.

### Source-level ordering

Godot's main physics-loop ordering is materially more precise than the shorthand "pre-physics":

1. `PhysicsServer3D.sync()` / query flush,
2. `SceneTree.physics_frame` signal,
3. node physics processing (`_physics_process`),
4. `PhysicsServer3D.end_sync()`,
5. `PhysicsServer3D.step(...)`,
6. on the next physics tick, the next `PhysicsServer3D.sync()` makes the solver result visible through `RigidBody3D` node state.

### Correct observation

The challenger was changed to inspect the fresh dynamic provider through `PhysicsServer3D.body_get_state(RID, BODY_STATE_TRANSFORM)` after the first step, then compare the `RigidBody3D` Node to that server transform at the next physics boundary.

Result:

- first solver displacement: `0.0746193230`,
- next-sync Node↔server gap: `0.0000000000`.

Therefore the fresh provider **did participate in the first upcoming solver step**. The earlier zero was stale Node visibility, not lost solver participation.

This refines the lifecycle timing model:

- provider replacement at `physics_frame` is late relative to `PhysicsServer.sync`, but still early enough for the upcoming solver `step` in the tested case;
- PhysicsServer/RID state is the correct same-step observer;
- scene-node transform becomes authoritative/visible for that solver result only after the next sync.

Existing binding telemetry already independently showed this distinction (`server_step_displacement > 0`, `node_process_displacement == 0`, later `node_sync_gap == 0`).

## What this establishes

Within the tested scope:

- logical Space identity can survive concrete provider-class and engine-identity replacement;
- static and dynamic providers can share one authoritative Matter object without cloning logical truth;
- lineage authority can remain outside provider identity;
- old provider retirement followed by one-successor installation can avoid simultaneous provider ownership;
- static→dynamic replacement can preserve pose and occupied Matter world positions exactly within the measured tolerance;
- a fresh dynamic provider installed at the shared lifecycle boundary participates in the upcoming solver step;
- dynamic motion, arbitrary rotation and live Matter/lineage mutation compose with that lifecycle path;
- dynamic→static replacement can preserve the arbitrary current pose without snapping back to a canonical/world lattice;
- the final static provider remains editable through the same mutation path.

This is the first integrated evidence for the working semantic separation:

**logical Space ≠ current engine provider**.

## Explicit non-claims

This does **not** establish:

- that the current `LocalMatterSpace` API/class shape is final,
- scale or performance suitability,
- scalable collision representation,
- persistence/save-load identity,
- actor support continuity across provider replacement,
- mechanical-constraint succession through this shared lifecycle path,
- topology split/merge through `LocalMatterSpace`,
- canonical-world extraction/reintegration,
- nested Spaces, multiple simulation domains, portals, streaming or networking,
- product/playability quality.

## Consequence / stop condition

The basic static→dynamic→static provider-replacement question is now sufficiently defended to stop adding same-shaped automated lifecycle probes by default.

The next step should be selected by information value rather than thematic sequence. A strong candidate is a deliberately small interactive LAB consumer that exercises this **same** runtime path and makes provider/Space/lineage/timing state visible before actor-transition complexity is layered on top.
