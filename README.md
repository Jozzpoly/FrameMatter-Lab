# FrameMatter Lab

Research lab for an editable systemic-world substrate where local Matter can become static or dynamic physical space **without logical identity collapsing into engine representation**.

This repository is intentionally **not** a Minecraft clone, vehicle game, portal demo, or final engine architecture. It exists to produce falsifiable evidence for the smallest substrate that could later support those directions.

## North star

> Build an editable systemic-world substrate where local Matter, moving/static frames, actors and mechanisms can compose without logical identity being defined by render/physics objects.

Long-term product pressure remains deliberately simple:

> walk → dig/build → activate a local Space → ride it → edit it while moving → use one simple mechanism → inspect/debug the consequences.

That is a recurring pressure test, not a promise to build those features in sequence.

## Current live state

The repository now has defended evidence across several layers:

- logical `CellVolume` Matter regenerates disposable mesh/collision representation,
- the same logical Matter can be hosted by static or dynamic providers while logical `LocalMatterSpace` identity remains stable,
- moving constructs survive live occupancy edits with Matter-derived mass/COM/inertia refresh,
- actor support can remain a logical-Space relation through static↔dynamic provider replacement,
- one logical moving Space can retire into compact topology successors with retained Matter lineage/world/velocity-field continuity,
- independent frames can remain distinct while mechanically constrained; bounded joint state can survive split/partition/contraction cases,
- exact merged-cuboid collision removed the demonstrated one-shape-per-cell scale bottleneck in dense/shell cases,
- post-R1 profiling shows full mesh/cuboid/COM derivation—not installing a handful of merged shapes—now dominates representative full rebuilds,
- bounded derived-region experiments prove strong edit locality is possible without making regions logical identity, but naive fixed regions can badly inflate final collider partitions,
- the real LAB composes an embodied actor, direct selected-cell Matter remove/place, static→dynamic ride/walk, moving edit and freeze through the shared runtime,
- the first direct Owner run confirmed that this loop can be exercised but exposed severe prototype interaction/readability friction rather than a demonstrated substrate failure,
- P0.5 now wraps the same defended consumer with a closer orbit/zoom camera, explicit remove/place previews, Matter grid context, compact/debug HUD split and non-destructive test recovery.

These are not production architecture, world-scale or product-quality claims.

## Current active campaign

The project deliberately stopped representation optimization before it became architecture by inertia.

Active pressure is **P0.5 — direct Owner interaction through a less contaminated measurement surface**:

> walk on/around Matter → point at a clearly previewed local cell → remove/place Matter → activate the same logical Space → ride/walk on it → edit while moving → freeze it → inspect/debug only when useful.

The defended P0 composition gate remains **PASS in a bounded translation+yaw scope**. P0.5 adds a separate structural interaction-surface gate and does not replace the underlying Matter/lifecycle test. The green P0.5 delivery run `#6` / `34915675303` passed both gates and exported Windows + Web packages.

The first pitch/roll P0 challenger also exposed a useful boundary: the current actor transports support in frame coordinates but validates/snaps with a world-down single ray. It remained grounded but drifted locally on tilted support. Arbitrary pitch/roll therefore remains an explicit actor/gravity/orientation frontier rather than being hidden by a LAB-specific adhesion hack.

The next material evidence must again come from direct Owner use. P0.5 exists specifically so camera/movement feel, pointer targeting, remove/place clarity, perceived edit latency and the underlying moving-Matter loop can be judged with less prototype friction.

If edit latency becomes limiting, R2A already provides measured locality evidence. If actor geometry/orientation dominates, the actor frontier should move next. If lifecycle/topology semantics fail under interaction, those exact invariants should be reopened instead of hidden behind consumer glue. If interaction is still the dominant problem, improve only the highest-value obstacle instead of turning P0.5 into an endless polish campaign.

### Current P0.5 controls

- `WASD` — move relative to the current view/support,
- `Space` — jump,
- `T` — activate static Space / freeze dynamic Space,
- `LMB` — remove the previewed occupied Matter cell,
- `RMB` — place Matter in the previewed adjacent empty in-bounds cell,
- `MMB + mouse` — orbit camera,
- mouse wheel — zoom,
- `Home` — reset camera view,
- `K` — recover actor onto the current active Space for test continuity,
- `F1` — compact Owner HUD / full engineering telemetry,
- `R` — reset LAB,
- `M`, `C`, `F` — retained legacy instrumentation probes.

### Owner-test builds

P0.5 has a dedicated gated delivery workflow: **[Deliver P0.5 Owner Test](https://github.com/Jozzpoly/FrameMatter-Lab/actions/workflows/deliver-owner-test.yml)**.

Every delivery run first executes the defended P0 smoke and the P0.5 interaction-baseline smoke. Packaging only proceeds when both pass. A successful run publishes two 30-day downloadable artifacts:

- `FrameMatter-P05-Windows` — standalone Windows x86-64 executable with embedded PCK; this is the preferred Owner-test build,
- `FrameMatter-P05-Web` — browser export bundle for hosting/HTTP testing.

The web bundle itself exports successfully with Godot 4.7.2 + built-in Jolt. A permanent GitHub Pages URL is intentionally not claimed until Pages is enabled in repository settings; delivery artifacts do not depend on that setting.

## Important current distinctions

- **Matter ≠ mesh/collision/body identity.**
- **Space/frame identity ≠ current representation/provider.**
- **Space ≠ simulation domain.**
- **contact ≠ mechanical constraint ≠ rigid bind.**
- **freeze/static transition ≠ canonical-world reintegration ≠ bake/resample.**
- **dirty/invalidation region ≠ final physical representation partition.**
- **support-frame transport ≠ gravity/orientation/adhesion semantics.**
- **P0.5 presentation grid ≠ world/chunk/physics partition.**
- **test recovery ≠ gameplay recovery design.**
- **bounded/integrated automated PASS ≠ playability/product proof.**

## Stack

- Godot 4.7.2
- built-in Jolt Physics
- GDScript for rapid falsification
- standard float precision + local coordinates
- minimal custom integer-grid Matter model
- exact merged-cuboid collision as current provider default
- intentionally simple truth/reference visuals and interaction surfaces

`PER_CELL` collision remains as a historical/reference control, not a scalability candidate.

## Documentation

- **[ROADMAP.md](ROADMAP.md)** — living adaptive decision map: active campaign, stop conditions and future frontiers.
- **[docs/research-state.md](docs/research-state.md)** — current defended / provisional / falsified / open truth.
- **[docs/evidence/](docs/evidence/)** — durable campaign evidence and measurements.
- **[docs/archive/](docs/archive/)** — historical direction checkpoints once they stop being live guidance.
- **[docs/roadmap-readiness-audit.md](docs/roadmap-readiness-audit.md)** — audit that motivated the current roadmap/documentation model; transitional historical material.

## Evidence standard

A gate is not a PASS because it looks correct once. We seek explicit correctness, stability and performance evidence, and we distinguish:

**Hypothesis → bounded evidence → integrated evidence → reusable-substrate evidence → scale evidence → playability/product evidence.**

A failure is useful evidence. Representations, controllers, execution mechanisms and even the host engine remain replaceable if stronger consumers falsify current assumptions.

## Working rule

The project should stabilize **intent and defended invariants**, not prematurely stabilize class names, API layouts or implementation mechanisms.

When evidence and roadmap disagree, update the roadmap.