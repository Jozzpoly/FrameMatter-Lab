# P0.5 — interaction/readability baseline

Status: **AUTOMATED INTERACTION-SURFACE PASS; OWNER UX/PLAYABILITY PENDING**

P0.5 is deliberately not a new substrate campaign. It is a thin owner-facing presentation and interaction layer over the defended P0 embodied consumer, added after the first direct Owner recordings showed that the experiment was too visually and ergonomically raw to provide high-quality product-pressure evidence.

## Question

Can the existing P0 consumer become materially easier to read and operate without changing the logical Matter / LocalMatterSpace / provider lifecycle path that P0 already defended?

The purpose is to reduce measurement contamination from prototype friction. The desired next Owner test should tell us more about manipulating editable Matter on a moving/static local Space and less about fighting a fixed camera, tiny target marker or always-open telemetry wall.

## Owner observation that motivated P0.5

The first human P0 run did not produce a clear substrate failure. It did expose strong interaction/readability limits:

- fixed far camera made the scene feel observational rather than embodied,
- Matter surfaces and individual cells were difficult to read,
- edit intent was under-signaled before clicking,
- the full engineering HUD competed with the scene,
- recovery from leaving the useful test area was unnecessarily expensive,
- the resulting experience looked like a physics test bench even when the underlying lifecycle/edit loop remained coherent.

This is qualitative Owner evidence, not an automated PASS/FAIL claim.

## Implementation boundary

P0.5 is implemented as `lab/main_p05.gd`, which extends the existing `lab/main.gd` P0 consumer instead of replacing its Matter/lifecycle implementation.

P0.5 adds only LAB-facing interaction/presentation mechanisms:

- closer orbit camera,
- middle-mouse orbit and wheel zoom,
- camera reset,
- translucent remove-cell and place-cell previews,
- a lightweight occupied-cell grid overlay,
- stronger visual distinction between static and dynamic provider presentation,
- compact default HUD while retaining the full P0 telemetry behind `F1`,
- explicit `K` actor recovery onto the current active provider for test continuity.

Ordinary remove/place still delegates to the inherited P0 path and therefore reaches `LocalMatterSpace.mutate_cell`. The presentation layer does not define a second Matter authority.

The grid is a small-LAB visualization only. It is **not** a world chunk, save partition, collision partition, streaming unit or proposed production representation.

`K` recovery is a test utility, not a gameplay teleport design.

## Automated gate

Dedicated gate: `tests/p05_interaction_baseline_smoke.gd`.

Green delivery run:

- workflow: `Deliver P0.5 Owner Test`
- run: `#6`, ID `34915675303`
- commit: `9790d5b859073c3a2f7136cb14861613f3d54661`
- Godot: `4.7.2` + built-in Jolt

The delivery workflow executes the defended P0 smoke first and then the P0.5 interaction baseline smoke before either export is allowed.

### Defended P0 regression gate

PASS in the same delivery run:

- `ride_floor_loss = 0`
- `walk_floor_loss = 0`
- `post_edit_floor_loss = 0`
- `max_stationary_local_drift = 0.00000812`
- `walk_local_delta ≈ 0.95959`
- static and moving remove/recreate cycles still receive fresh lineage.

This matters more than the presentation checks: P0.5 did not buy usability by weakening the previously defended lifecycle/edit composition.

### P0.5 gate

PASS:

- scene exposes the same logical `LocalMatterSpace` and embodied actor,
- compact HUD exists and is visible by default,
- rich P0 telemetry remains alive but hidden by default,
- explicit remove/place preview nodes exist,
- occupied-cell grid exists,
- initial camera framing is materially closer than P0,
- programmatic zoom changes camera distance deterministically,
- compact/debug HUD modes switch coherently,
- actor recovery does not replace logical Space or provider and reacquires the same logical support Space,
- remove/place still change authoritative occupancy through the shared path,
- grid survives occupancy rebuild,
- static→dynamic activation remains compatible,
- sampled grid/provider transform gap after explicit presentation sync is `0.00000000`.

Measured camera values in the final green run:

- initial focus distance: `8.326`
- zoomed focus distance: `6.200`

## Packaging evidence

The same green delivery run successfully produced:

- `FrameMatter-P05-Web`
- `FrameMatter-P05-Windows`

The Windows artifact contains a standalone x86-64 executable with embedded PCK. Successful export and binary inspection are delivery evidence, not human-launch/playability proof.

## What this establishes

P0.5 establishes only that:

1. a materially richer interaction/readability shell can remain above the defended P0 substrate rather than invading Matter/lifecycle authority;
2. the original P0 automated composition still passes beneath that shell;
3. the added camera/HUD/recovery/grid surfaces satisfy their bounded structural behavior and can be packaged for Owner testing;
4. the project now has a cleaner instrument for obtaining the next human evidence.

## Non-claims

P0.5 does **not** establish:

- good camera feel,
- good mouse targeting feel,
- good visual design,
- product-quality controls,
- acceptable perceived edit latency,
- compelling gameplay,
- production UI architecture,
- scalable grid rendering,
- world/chunk architecture,
- arbitrary pitch/roll actor support,
- a production recovery mechanic,
- browser deployment availability.

Those require direct use or later dedicated evidence.

## Remaining actor boundary

The P0 world-up translation+yaw boundary is unchanged. Current support transport is frame-aware, but arbitrary pitch/roll support/gravity/orientation semantics remain unresolved. P0.5 intentionally does not hide that frontier with local adhesion or gravity assumptions.

## Decision after this gate

**Stop coding and return to Owner interaction.**

The next high-information input is another direct Owner run of the packaged P0.5 build. That run should determine whether the highest-value next campaign is driven by:

- interaction/camera/visual feedback,
- actor geometry/orientation,
- edit latency/locality,
- lifecycle/topology discontinuity,
- or a new semantic/gameplay pressure that the improved loop finally makes visible.

Do not interpret this PASS as a reason to continue polishing P0.5 indefinitely.