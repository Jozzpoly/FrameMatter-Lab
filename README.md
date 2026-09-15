# FrameMatter Lab

Research lab for an editable systemic-world substrate where local Matter can become static or dynamic physical space **without logical identity collapsing into engine representation**.

This repository is intentionally **not** a Minecraft clone, vehicle game, portal demo or final engine architecture. It exists to produce falsifiable evidence for the smallest substrate that could later support those directions.

## North star

> Build an editable systemic-world substrate where local Matter, moving/static frames, actors and mechanisms can compose without logical identity being defined by render/physics objects.

Recurring product pressure:

> walk → dig/build → activate/release a local Space → ride it → edit it while moving → use a simple mechanism → understand/debug the consequences.

That is a pressure test, not a feature roadmap.

## Current live state

The canonical project scene is now **P1**:

`res://p1/main.tscn`

P0/P0.5 remain historical Owner/consumer evidence, but they no longer define the current executable front door.

The current defended stack includes:

- logical `CellVolume` Matter as authority with disposable mesh/collision/body representation,
- logical `LocalMatterSpace` identity separated from current static/dynamic provider identity,
- exact merged-cuboid collision as the current provider default,
- Matter-derived mass/COM/inertia in the tested rigid cases,
- a query-based volumetric P1 actor that collides with floors/walls/ceilings without implicit kinematic push authority,
- actor support as a logical-Space relation through provider replacement,
- a SpringArm camera that retains actor + Space context,
- editable moving Matter,
- bounded expandable local storage with explicit coordinate-frame rebasing,
- actor/camera relation maintenance through storage-frame rebase,
- live one→many topology succession after destructive edits,
- explicit actor/camera succession to a live topology successor,
- zero-launch static→dynamic release,
- finite solver-owned central/torque impulses rather than hidden perpetual drive,
- dynamic→static successor freeze at the current solver-owned pose.

The strongest current automated pressure is one integrated causal loop:

> grounded actor → release → finite motion → ride → edit/build while moving → cross storage edge → rebase + mapped placement → destructive cut → real successor Spaces → actor/camera handoff → freeze successor.

Representative strict metrics:

- storage-frame shift `(3, 0, 0)`,
- linear/angular state error after rebase `0 / 0`,
- topology actor handoff error about `0.00000125 m`,
- moving ride anchor error about `0.00000135 m`,
- final actor/support anchor error about `0.00000098 m`.

This is **automated integrated evidence, not playability/product evidence**.

Evidence: [`docs/evidence/p1-integrated-owner-candidate.md`](docs/evidence/p1-integrated-owner-candidate.md).

## Active campaign — P1 Owner interaction

The destructive P1 rebuild has reached a deliberate stop condition. The next highest-information evidence is direct Owner use of the packaged P1 candidate, not another autonomous feature tranche.

The question is now:

> **once the major P0/P0.5 consumer defects are removed, which remaining limitation actually dominates direct use?**

Potential outcomes intentionally remain open. Direct use may point next toward interaction/camera work, edit locality, arbitrary orientation/gravity semantics, finite actor↔construct force exchange, a mechanism/world interaction, or a deeper lifecycle/topology failure. The next campaign should be pulled by that evidence rather than by roadmap inertia.

### Current P1 controls

- `WASD` — actor movement,
- `Space` — jump,
- `T` — zero-launch release / freeze focused Space,
- `↑` / `↓` — finite forward/back central impulse pulses,
- `←` / `→` — finite yaw torque pulses,
- `E` — toggle REMOVE / PLACE,
- `LMB` — apply current edit,
- `MMB + mouse` — orbit camera,
- mouse wheel — zoom,
- `Home` — reset camera,
- `K` — recover actor for test continuity,
- `R` — reset experiment.

In PLACE mode an adjacent target outside the current dense storage can request a bounded storage expansion/rebase instead of silently behaving like an invisible wall.

## P1 Owner-candidate delivery

Workflow: **[Deliver P1 Owner Candidate](https://github.com/Jozzpoly/FrameMatter-Lab/actions/workflows/deliver-owner-test.yml)**.

Delivery run `#7` / `34964102720` independently passed before packaging:

- strict project import,
- P1 dependency graph,
- canonical startup,
- volumetric actor,
- composed scene foundation,
- multi-Space registry,
- live topology consumer,
- storage rebase,
- actor/camera storage-frame continuity,
- finite Space control,
- integrated causal loop,
- Web export,
- Windows export.

Artifacts:

- `FrameMatter-P1-Windows` — preferred Owner-test candidate,
- `FrameMatter-P1-Web` — browser export bundle for hosting/HTTP tests.

Verified Windows executable:

- PE32+ Windows GUI x86-64,
- `109740584` bytes,
- SHA-256 `9a73c77ba3a939a53541670861322ea3c27125e0df9ca20864895a1b458f88ee`,
- embedded product metadata `FrameMatter P1 Owner Candidate`.

The Web bundle exports successfully, but no permanent hosted URL is claimed merely because an export artifact exists.

## Evidence discipline

P1 experienced a deliberate evidence reset after the old harness allowed a false-green path. The current strict wrappers require the expected PASS marker **and** reject engine/script `ERROR:` output even when Godot exits with status 0.

The historical fast-invariant wrapper now uses the same zero-engine-error evidence floor. Validate research harness run `#304` / `34963534245` passed the defended fast-invariant set under that stricter rule.

Windows import is also synchronous and verifies the global script-class cache before runtime probes. Canonical startup currently passes on both Linux and Windows Godot 4.7.2.

## Important current distinctions

- **Matter ≠ mesh/collision/body identity.**
- **Space identity ≠ current representation/provider.**
- **Space ≠ simulation domain.**
- **storage coordinates ≠ Matter identity.**
- **contact ≠ mechanical constraint ≠ rigid bind.**
- **freeze/provider transition ≠ canonical-world reintegration ≠ bake/resample.**
- **dirty/invalidation region ≠ final collider/render/world partition.**
- **support-frame transport ≠ gravity/orientation/adhesion semantics.**
- **finite Space impulse controls ≠ vehicle framework.**
- **automated integrated PASS ≠ Owner/playability/product PASS.**

## Important open boundaries

P1 deliberately does **not** claim:

- arbitrary pitch/roll locomotion or frame-local gravity/adhesion,
- production character feel,
- satisfying finite actor↔construct reaction forces,
- scalable/infinite world storage,
- final chunk/streaming architecture,
- persistence/save-load identity,
- canonical-world extraction/reintegration,
- curved/planetary Matter,
- production vehicle framework,
- product-quality visuals/UI/performance.

R2A still provides useful measured evidence if edit latency becomes a real problem: update locality is possible, but dirty regions must not automatically become final collider/world chunks.

## Stack

- Godot 4.7.2
- built-in Jolt Physics
- GDScript for rapid falsification
- standard float precision + local coordinates
- integer-grid logical Matter
- exact merged-cuboid collision as current provider default

## Documentation

- **[ROADMAP.md](ROADMAP.md)** — adaptive decision map and campaign boundaries.
- **[docs/research-state.md](docs/research-state.md)** — current defended / provisional / falsified / open truth.
- **[docs/evidence/](docs/evidence/)** — durable campaign evidence and measurements.
- **[docs/evidence/p1-integrated-owner-candidate.md](docs/evidence/p1-integrated-owner-candidate.md)** — current P1 promotion/delivery evidence.
- **[docs/archive/](docs/archive/)** — historical direction checkpoints once they stop being live guidance.

## Working rule

Stabilize **intent and defended invariants**, not prematurely class names, APIs, partition schemes or implementation mechanisms.

When evidence and roadmap disagree, evidence wins.
