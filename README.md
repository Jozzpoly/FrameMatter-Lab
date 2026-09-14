# FrameMatter Lab

Research lab for an editable systemic-world substrate where local Matter can become static or dynamic physical space **without logical identity collapsing into engine representation**.

This repository is intentionally **not** a Minecraft clone, vehicle game, portal demo, or final engine architecture. It exists to produce falsifiable evidence for the smallest substrate that could later support those directions.

## North star

> Build an editable systemic-world substrate where local Matter, moving/static frames, actors and mechanisms can compose without logical identity being defined by render/physics objects.

Long-term product pressure remains deliberately simple:

> walk → dig/build → activate a local Space → ride it → edit it while moving → use one simple mechanism → inspect/debug the consequences.

That is a recurring pressure test, **not the current feature target**.

## Current live state

The first campaign (**G0–G3**) is closed as bounded evidence:

- logical Matter regenerates derived mesh/collision state,
- the same Matter can back a dynamic Jolt `RigidBody3D`,
- moving constructs can live-edit geometry/collision/mass/COM/inertia,
- explicit support-frame actor semantics work on freely simulated constructs without scene parenting or uncontrolled kinematic pushing.

Post-G3 bounded probes additionally established useful split/merge/rebase, lineage, pre-physics replacement timing, explicit binding, mechanical constraint succession/retirement, graph partition/contraction, oriented hinge succession and stateful motor/limit continuity.

These results are **not** production architecture or scale claims. Most are bounded evidence; the next campaign is designed to force them to compose through shared runtime paths.

## Current active campaign

Standalone mechanics expansion is ending deliberately.

1. **M-CAP** — one final stateful graph-contraction capstone, then stop mechanics-only expansion.
2. **I0A** — same-body dynamic ↔ frozen/static control lifecycle.
3. **I0B / I1** — persistent logical local Space/frame identity across real static ↔ dynamic representation replacement.
4. **LAB** — restore the interactive lab as a consumer of the same lifecycle path.
5. **I2** — actor support continuity through representation/provider transfer.
6. **I3** — one topology split through the shared integrated execution path.
7. **Re-audit** — re-rank representation, actor, world-transfer and other frontiers from fresh evidence.

The sequence is intentionally revisable. A material FAIL can reorder or invalidate later gates immediately.

## Important current distinctions

- **Matter ≠ mesh/collision/body identity.**
- **Space/frame identity ≠ current representation/provider.**
- **Space ≠ simulation domain.**
- **contact ≠ mechanical constraint ≠ rigid bind.**
- **freeze/static transition ≠ canonical-world reintegration ≠ bake/resample.**
- **bounded PASS ≠ integrated/scale/product proof.**

## Stack

- Godot 4.7.2
- built-in Jolt Physics
- GDScript for rapid falsification
- standard float precision + local coordinates
- minimal custom integer-grid Matter model
- intentionally simple truth/reference render + collision representations

Box-per-cell dynamic collision is already rejected as scalable; optimization is deferred until the integrated lifecycle exposes the representation/update granularity actually required.

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