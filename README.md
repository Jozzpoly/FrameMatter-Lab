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
- bounded derived-region experiments prove strong edit locality is possible without making regions logical identity, but naive fixed regions can badly inflate final collider partitions.

These are not production architecture, world-scale or product-quality claims.

## Current active campaign

The project has deliberately stopped representation optimization before it becomes architecture by inertia.

Active pressure is **P0 — a deliberately small interactive consumer**:

> walk on/around Matter → inspect/select a local cell → remove/place Matter → activate the same logical Space → ride it → edit while moving → freeze it → inspect/debug the result.

The goal is not to make a game. It is to force the current substrate to compose under direct Owner interaction and reveal which pressure actually matters next.

If edit latency becomes limiting, R2A already provides measured locality evidence. If actor limitations dominate, the actor frontier should move next. If lifecycle or topology semantics fail under interaction, those exact invariants should be reopened instead of hidden behind LAB-specific hacks.

## Important current distinctions

- **Matter ≠ mesh/collision/body identity.**
- **Space/frame identity ≠ current representation/provider.**
- **Space ≠ simulation domain.**
- **contact ≠ mechanical constraint ≠ rigid bind.**
- **freeze/static transition ≠ canonical-world reintegration ≠ bake/resample.**
- **dirty/invalidation region ≠ final physical representation partition.**
- **bounded PASS ≠ integrated/scale/product proof.**

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