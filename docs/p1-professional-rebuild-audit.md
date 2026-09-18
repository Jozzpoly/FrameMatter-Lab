# P1 professional rebuild audit — interactive foundation

Status: **ACTIVE / destructive re-audit**

This document starts the post-P0.5 rebuild campaign. It is deliberately critical. The purpose is not to preserve the current Owner-facing LAB because it already exists; the purpose is to preserve only the evidence and semantics that remain useful after direct interaction falsified the presentation/consumer layer.

## Trigger

The second Owner recording is a 37.5 s desktop run of P0.5. The recording does not show a merely rough-looking prototype. It exposes several ways in which the current interactive LAB produces misleading or low-quality evidence about FrameMatter and about Godot itself.

The working rule for this campaign is therefore:

> preserve defended substrate evidence; aggressively replace the consumer, scene and interaction mechanisms when they distort the experiment.

P0/P0.5 remain historical evidence. They are not sacred executable references.

## Recording findings

### 0–12 s — edit readability is poor

The hover state frequently renders both a large red remove cube and a large green placement cube around the same surface interaction. These translucent volumes obscure the Matter geometry they are supposed to explain. A small yellow hit marker adds a third visual signal without establishing a clear priority.

Repeated edits quickly produce holes and disconnected-looking slabs, but the scene gives weak causal feedback about what was removed, what can be placed next and which pieces are still one physical/logical object.

### 13–34 s — moving-Space context is hard to read

Once the Space is dynamic, the camera follows the actor rather than framing the relationship between actor, active Space and reference world. The dark background, nearly uniform Matter material and weak world reference make translation/yaw harder to parse than it should be.

Detached-looking Matter fragments continue moving as one construct because the interactive LAB never invokes the already-proven connected-component split path after destructive editing. The result is visually and physically misleading: topology looks broken while rigid identity silently remains unified.

### 35–37.5 s — catastrophic loss of experiment context

The recording ends with only the blue capsule visible against the dark background. The moving Matter experiment has left the camera context while the camera remains actor-centric. The visible grey reference ground did not protect the actor because it is render-only geometry, not collision.

This is not an acceptable recovery model for an Owner-facing research LAB.

## Code findings

### F1 — the visible reference ground is physically fake — **MATERIAL FAILURE**

`lab/main.tscn` contains `ReferenceGround` only as `MeshInstance3D`. It has no `StaticBody3D`/collision shape. It visually promises a floor that the actor can fall through.

This is our scene-design error, not a Godot limitation.

### F2 — `FrameProbeCharacter` is not a volumetric character controller — **MATERIAL FAILURE**

The current actor extends `Node3D`. Grounding is a single world-down ray. Horizontal movement directly changes `support_local_center` and therefore `global_position`. There is no capsule/body sweep against walls, ceilings or obstacle sides.

Consequences:

- walls are not real movement constraints,
- steps/ledges/ceilings are not represented properly,
- the visible capsule is only a render proxy,
- a large part of perceived movement quality cannot legitimately be blamed on Godot's normal character facilities because they are not being used.

The support-frame work remains valuable evidence, but the current class must return to being treated as a probe, not a game-facing controller.

### F3 — naive replacement with stock `CharacterBody3D` is also not justified — **OPEN DESIGN CONSTRAINT**

Godot documents `CharacterBody3D.move_and_slide()` as capable of affecting `RigidBody3D` bodies it collides with. Earlier FrameMatter probes already measured unacceptable largely mass-insensitive actor→construct acceleration in the tested setup.

Therefore the rebuild should test a **volumetric query/sweep controller with explicit support-frame semantics and no accidental infinite-force authority**, rather than either preserving the single ray or blindly reverting to the stock baseline.

Godot/Jolt already exposes `CapsuleShape3D`, `PhysicsShapeQueryParameters3D` and `PhysicsDirectSpaceState3D.cast_motion()/collide_shape()/get_rest_info()` for this class of controlled query. That path should be challenged directly.

### F4 — camera tracks the actor, not the experiment — **MATERIAL FAILURE**

P0.5 computes a spherical offset around the actor every rendered frame. It has no camera collision, no `SpringArm3D`, no actor↔Space framing policy, no fall/recovery state and no protection against losing the moving Space entirely.

Godot provides `SpringArm3D` specifically for third-person collision-aware camera placement. Its interpolation docs also recommend manual camera interpolation against interpolated physics targets for high-quality presentation. The current LAB uses neither.

### F5 — edit preview communicates too many mutually competing states — **MATERIAL FAILURE**

When both targets are valid, P0.5 deliberately displays remove and place previews at once. The previews are almost full cell volumes, translucent and unshaded, so they cover the surface under inspection.

A professional interaction should make the current pointer target legible first and preview the chosen operation second. Remove and place must not compete visually by default.

### F6 — editing is artificially imprisoned by one fixed `8×4×8` volume — **MATERIAL LIMIT**

The LAB creates `CellVolume.new(Vector3i(8, 4, 8))`. Placement requires `_volume.in_bounds(place_cell)`. `CellVolume` itself stores a fixed dense array with coordinates `[0,size)`.

This is acceptable for bounded research probes but poor evidence for a build/edit experience. The user can encounter an invisible boundary that looks like interaction failure.

The rebuild must either introduce an explicit expandable/local-storage challenger or create a clearly bounded test region whose boundary is visible and intentional. Silent invisible bounds are rejected.

### F7 — destructive editing does not consume the proven topology split runtime — **MATERIAL SEMANTIC FAILURE**

`LocalMatterSpace` already supports queued connected-component split and successor Spaces, but the interactive LAB only calls `mutate_cell()`. Removing a bridge can therefore leave disconnected Matter islands hosted by one rigid provider.

This undermines the central systemic-world claim more than any missing shader does. P1 must make topology consequences visible and real in the interactive consumer.

### F8 — activation is an arbitrary scripted launch — **MATERIAL EXPERIENCE FAILURE**

`T` converts the whole Space to dynamic with hard-coded `DRIVE_LINEAR=(1.15,0,-0.35)` and `DRIVE_ANGULAR=(0,0.34,0)`. The motion has no visible cause, control surface or physical narrative.

It is useful for automated lifecycle evidence but weak as an Owner-facing experiment. P1 should preserve the provider transition but replace the unexplained perpetual drift with an intentional movement/impulse test surface.

### F9 — the project currently underuses Godot's scene/input tooling — **ENGINE-EVALUATION RISK**

Important actor, HUD, camera and preview nodes are created dynamically in scripts. Inputs are read from raw physical key constants. `project.godot` defines no project InputMap actions. The camera is hand-built rather than composed from a camera rig / spring arm.

This makes the project harder to inspect and tune in the Godot editor and unfairly hides some of the engine's strongest workflow advantages.

P1 should deliberately become more Godot-native where that improves clarity: scenes/resources for authorable composition, InputMap actions, collision layers/masks, SpringArm3D, physics interpolation experiments and editor-visible tuning parameters.

### F10 — P0.5 inheritance is fragile prototype glue — **CODE QUALITY DEBT**

`main_p05.gd` inherits the already-large `main.gd`, overrides lifecycle methods such as `_ready`, `_process`, `_unhandled_input`, `_reset_lab`, `_remove_cell` and `_place_cell`, and depends directly on many base variables. Base `_ready()` also calls methods that dispatch to P0.5 overrides before P0.5 setup is complete, relying on null guards.

This is functional prototype layering, not a good long-term scene architecture. P1 should replace the inheritance stack with explicit composition/roles.

### F11 — lineage-token issuance leaks into the LAB consumer — **ARCHITECTURE DEBT**

The UI/controller owns `_next_lineage_token` and passes tokens into `LocalMatterSpace.mutate_cell()` when creating Matter. The logical identity authority should not require every future consumer to reinvent token allocation.

This does not require freezing a persistence schema now, but issuance belongs below the UI layer.

### F12 — every edit still performs whole-provider derivation — **KNOWN SCALE DEBT, NOT FIRST REBUILD TARGET**

The current provider rebuild still regenerates mesh, collision and mass/COM state after every occupancy change. R2P/R2A already quantify this. P0.5's small volume hides the cost.

Do not optimize this first unless the new interactive consumer demonstrates latency. Preserve the R2A distinction: dirty/update regions are not automatically final collider partitions.

## What is still worth preserving

The destructive re-audit does **not** invalidate the following evidence:

- Matter authority is separate from render/collision representation.
- logical Space identity is separate from provider identity.
- static↔dynamic provider replacement can preserve one logical Space.
- actor support can conceptually refer to logical Space rather than provider identity.
- exact merged-cuboid collision is a strong current representation default.
- connected-component split has integrated succession evidence.
- update locality is possible without making regions logical identity.
- transaction/solver/node observation phases must not be conflated.

What is being rejected is the assumption that the current Owner-facing scene is an adequate consumer of those results.

## P1 rebuild principles

1. **No fake affordances.** Visible floors collide. Visible walls constrain the actor. Invisible hard build boundaries are either removed or made explicit.
2. **Volumetric actor first.** Movement must be spatially credible before judging feel, camera or Godot.
3. **No accidental infinite-force authority.** Actor collision must not launch dynamic constructs as a side effect of kinematic movement.
4. **Camera preserves experiment context.** It should remain useful when the actor jumps, falls, rides, edits or separates from a moving Space.
5. **One primary edit signal.** Hover, remove and place states must have a visual hierarchy.
6. **Topology consequences become real.** Disconnecting Matter must not leave magically rigid islands in the interactive LAB.
7. **Use Godot as Godot.** Prefer editor-visible scenes/resources, InputMap, collision layers, SpringArm/shape queries and interpolation features over recreating everything in one script.
8. **Historical tests do not fossilize the old consumer.** P0/P0.5 remain evidence; new canonical gates should target P1 behavior and defended substrate invariants.
9. **Architecture follows pressure.** Do not use the rebuild as an excuse to invent a final world/chunk/save schema prematurely.

## Planned destructive sequence

### P1-A — retire the old consumer as authority

- preserve P0/P0.5 evidence and tests as historical probes,
- remove them from defining the current interactive scene contract,
- create new P1 gates around the rebuilt scene.

### P1-B — Godot-native scene + camera + volumetric actor challenger

- real collision-bearing world reference,
- editor-visible Player scene and camera rig,
- capsule/shape motion queries against Matter/world,
- support-frame transport preserved without accidental rigid-body push,
- SpringArm/camera collision,
- physics-interpolation experiment with camera sampling of interpolated targets,
- clear fall/recovery behavior.

### P1-C — editing interaction and storage pressure

- single-target hover language,
- explicit remove/place mode feedback,
- remove invisible `8×4×8` interaction prison via an evidence-backed expandable or explicitly bounded mechanism,
- keep mutation authority below presentation.

### P1-D — live topology consequences

- destructive edits request connected-component split when required,
- LAB tracks active successor Spaces rather than one forever-global `_space`,
- actor/camera/selection survive source retirement,
- detached pieces visibly become independent.

### P1-E — movement/activation semantics

- remove unexplained hard-coded perpetual launch as the primary Owner interaction,
- add an intentional bounded way to make a Space move/rotate,
- preserve lifecycle evidence while making cause→effect readable.

### P1-F — owner build and adversarial test

Only after the above composes do we package another Owner test. The acceptance question is no longer "does the probe stay green?" but:

> does Godot + FrameMatter now provide a coherent, physically legible sandbox loop whose remaining failures point at real substrate questions rather than prototype neglect?

## Explicit non-goals for this rebuild

- final game art,
- inventory/crafting,
- networking,
- save/load schema,
- final chunk/streaming architecture,
- arbitrary planetary Matter,
- final vehicle framework,
- hiding the pitch/roll gravity/orientation question with adhesion hacks.
