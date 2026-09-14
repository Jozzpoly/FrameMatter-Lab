# P0 — embodied interactive consumer

Status: **AUTOMATED INTEGRATED PASS in bounded translation+yaw scope; OWNER INTERACTION / PLAYABILITY PENDING**.

P0 is the first deliberate return from representation/mechanics research to a direct consumer pressure loop. It does not attempt to establish a game/player framework. It asks whether the currently defended logical-Space, actor-support, lifecycle and Matter-edit paths actually compose through the real LAB front door.

Final automated gate context:

- runtime commit: `09eb18e8e691f0f6b2ae085a931d96cf85447bc5`,
- GitHub Actions run: `#202` / `34909627371`,
- Godot: `4.7.2` / built-in Jolt,
- current-campaign validation: **PASS**,
- fast invariant validation: **PASS**,
- full research validation through historical lifecycle/topology/mechanics probes and R0/R1/R2P/R2A: **PASS**.

## Question

Can the real LAB compose an embodied actor, direct Matter editing and static↔dynamic local-Space lifecycle without introducing a parallel gameplay authority path or breaking previously defended invariants?

The bounded target loop is:

> stand/walk on Matter → remove/place Matter → activate the same logical Space → ride/walk on it while moving → edit while moving → freeze it → remain supported.

## Consumer implementation

`lab/main.tscn` / `lab/main.gd` now provides a thin consumer over existing shared systems:

- one `LocalMatterSpace` remains the logical owner of Matter + lineage,
- one `FrameProbeCharacter` is the embodied actor,
- WASD writes movement intent into the existing support-frame actor path,
- Space requests jump through the existing actor,
- `T` uses shared `LocalMatterSpace` static↔dynamic transition requests,
- pointer ray selection resolves the current active provider and maps world hits back to provider-local Matter coordinates,
- LMB removes the selected occupied cell through `LocalMatterSpace.mutate_cell`,
- RMB places Matter into the selected adjacent empty in-bounds cell through the same mutation path and allocates fresh lineage,
- no scene-node/collider identity is used as Matter identity,
- HUD telemetry exposes logical Space/provider identity, actor support, selected cells, Matter revision, occupancy, lineage, collider count and rebuild time.

Legacy fixed-cell mutation/material probes remain available as instrumentation, but P0 no longer depends on them for direct editing.

## Automated integrated result

The final P0 smoke instantiates the real `lab/main.tscn` and drives the shared consumer path rather than constructing a separate test-only world.

Final run metrics:

- logical Space ID remained stable through the whole transaction sequence,
- static provider → dynamic provider → fresh static provider replacement occurred,
- `ride_floor_loss = 0`,
- `walk_floor_loss = 0`,
- `post_edit_floor_loss = 0`,
- stationary-rider local drift during moving translation+yaw: `0.00000812`,
- actor walking changed local position by `0.95959115`,
- static remove/recreate lineage: `500001 → retired → 500077`,
- moving remove/recreate lineage: `500076 → retired → 500078`,
- final occupied cells returned to `76`.

The smoke additionally verifies:

- ordinary support acquisition on the initial static provider,
- `support_space` remains the same logical `LocalMatterSpace`,
- `support_body` follows the current provider across replacement,
- static Matter edits rebuild without replacing static provider identity,
- moving Matter edits rebuild without replacing dynamic provider identity,
- retained support survives a moving occupancy edit,
- freeze returns to a static provider while actor support remains coherent,
- the real HUD exposes the P0 telemetry surface.

## Pressure finding — pitch/roll is outside the currently defended actor semantics

The first P0 version deliberately drove the dynamic Space with angular velocity on all three axes:

`DRIVE_ANGULAR = (0.08, 0.34, 0.12)`.

That challenger did **not** lose support:

- ride floor loss: `0`,
- walk floor loss: `0`,
- post-edit floor loss: `0`.

But the supposedly stationary rider accumulated approximately `0.50085670` local-position drift, far above the unchanged `< 0.05` gate.

This was not a provider-transition or logical-Space failure. Inspection of `FrameProbeCharacter` showed a specific semantic boundary:

- support-frame transport uses `support_local_center` correctly,
- ground validation/snapping is a single **world-down** ray,
- on pitch/roll, that ray intersects a tilted support plane at a changing local point,
- `_snap_to_hit()` then writes that changing intersection back into `support_local_center`.

Earlier I2 actor-provider evidence intentionally used yaw-only angular motion (`(0, 0.45, 0)`), so P0 had expanded beyond the previously defended scope rather than exposing a regression inside it.

The first Owner-facing P0 slice was therefore bounded to translation + yaw:

`DRIVE_ANGULAR = (0, 0.34, 0)`.

With the **same strict local-drift threshold**, measured drift fell from about `0.501` to `0.00000812` and the full automated gate passed.

## Why pitch/roll was not 'fixed' here

Changing the actor to probe along support-local down, rotate to the frame, or adhere to arbitrary tilted surfaces would silently choose unresolved semantics such as:

- world gravity vs local gravity,
- walkable orientation limits,
- adhesion vs ordinary contact,
- volumetric collision/support rather than a ground ray,
- how an actor transitions between differently oriented Spaces.

P0 therefore records the finding rather than hiding it behind a LAB-specific movement hack.

The durable consequence is:

> current `FrameProbeCharacter` support evidence is strong for the tested world-up / translation+yaw use, but arbitrary pitch/roll embodied support remains an explicit actor frontier.

## What P0 automated evidence establishes

Within the tested bounded scope:

1. the real LAB can act as an embodied consumer of existing shared runtime rather than owning a parallel lifecycle;
2. direct selected-cell remove/place composes with authoritative Matter + lineage;
3. recreated Matter receives fresh lineage rather than coordinate resurrection;
4. the same logical Space survives static→dynamic→static provider replacement while actor support follows the provider;
5. actor ride + relative walk composes with dynamic translation+yaw;
6. live occupancy editing while moving does not inherently break actor support in this case;
7. the historical lifecycle/topology/mechanics/representation ratchet remains green with this consumer present;
8. direct consumer pressure successfully exposed a real actor-semantic boundary that narrower probes had not exercised.

## What remains unproven

This is **not playability/product evidence yet**.

Headless automation does not establish:

- whether WASD/camera feel natural,
- whether pointer selection is understandable or pleasant,
- whether LMB/RMB editing is spatially intuitive,
- whether visual feedback makes Matter/provider changes legible,
- whether the interaction loop is interesting or useful to the Owner,
- acceptable perceived edit latency under real repeated input,
- walls/slopes/steps/ceilings,
- arbitrary pitch/roll support,
- local gravity or adhesion semantics,
- volumetric character collision,
- finite actor→construct reaction forces,
- general building UX,
- inventory/content systems,
- world/chunk/streaming architecture,
- persistence/networking,
- a production player controller.

## Next evidence boundary

P0 now needs **Owner interaction**, not another speculative subsystem.

The immediate purpose of that test is diagnostic:

- if editing latency is materially intrusive, return to representation with R2A locality evidence;
- if actor geometry/orientation is the limiting experience, enter the actor frontier deliberately;
- if provider transitions or moving edits feel discontinuous despite automated correctness, reproduce that exact interactive case;
- if the loop works mechanically but is awkward or unclear, treat UX/interaction feedback as evidence before expanding architecture;
- if the loop is coherent, use the Owner result to select the next pressure rather than automatically extending P0.