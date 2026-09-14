# FrameMatter Lab — adaptive roadmap

Status: **living research decision map**. This is not a fixed release plan, feature checklist or promise of implementation order.

## North star

Build an editable systemic-world substrate where local Matter, moving/static frames, actors and mechanisms can compose without logical identity collapsing into engine representation.

Long-term product pressure remains deliberately simple:

> walk → dig/build → activate a local Space → ride it → edit it while moving → use a simple mechanism → understand/debug the consequences.

This is recurring pressure, not the current sprint goal.

## Decision rules

- Evidence outranks sequence.
- PASS does not automatically unlock the next thematically similar feature.
- Every major campaign ends in re-audit before scope expands.
- Stop conditions are first-class.
- No sunk-cost protection.
- Stable intent/invariants matter more than stable class names/APIs/host mechanisms.
- Work is ranked by **information value × leverage × risk reduction / cost**.
- Interactive/playability pressure must recur so the project does not become a technology exercise detached from the intended experience.

## Evidence maturity

1. Hypothesis
2. Bounded evidence
3. Integrated evidence
4. Reusable-substrate evidence
5. Scale evidence
6. Playability/product evidence

A PASS at one level never silently implies the next.

---

# Recently closed campaign

## M-CAP — standalone mechanics expansion: **FULL PASS / CLOSED**

Bounded stateful partition↔contraction symmetry is sufficiently exercised. Longer chains, loops, breakables and mechanism catalogues are stopped until an integrated/playable consumer creates a concrete need.

Evidence: `docs/evidence/stateful-graph-contraction-capstone.md`.

## I0A — in-place static/dynamic control: **FULL PASS / CONTROL CLOSED**

Useful low-churn host control with explicit velocity-resume caveat. Not the only provider strategy.

Evidence: `docs/evidence/i0a-freeze-unfreeze-semantics.md`.

## I0B — logical Space + real provider replacement: **FULL PASS / INTEGRATED**

Persistent logical Space survives real `MatterRepresentation → ConstructBody → MatterRepresentation` provider replacement while retaining one Matter+lineage authority pair, pose continuity, motion and editing.

Evidence: `docs/evidence/i0b-provider-replacement-lifecycle.md`.

## LAB — second independent lifecycle consumer: **FULL PASS / NARROW REUSABLE-SUBSTRATE EVIDENCE**

The actual interactive LAB scene consumes the same provider/mutation lifecycle rather than owning hidden replacement orchestration.

Evidence: `docs/evidence/lifecycle-lab-consumer.md`.

## I2 — actor continuity through provider replacement: **FULL PASS / INTEGRATED**

Actor support can remain a logical Space relation while the concrete provider changes static↔dynamic↔static. Provider-preserving local coordinates need no test-local handoff; topology rebases still require explicit mapping.

Evidence: `docs/evidence/i2-actor-provider-transition.md`.

## I3 — topology mutation through shared runtime: **FULL PASS / INTEGRATED**

A moving logical Space can retire through one shared connected-component transaction into fresh compact successor Spaces while retained Matter lineage, world placement, rigid velocity field and explicit actor succession remain coherent.

The adversarial test no longer implements the split itself.

Evidence: `docs/evidence/i3-shared-topology-split.md`.

### Re-audit result after I3

The I0B→LAB→I2→I3 line established enough lifecycle coherence that another same-scale lifecycle semantic probe now has lower expected information value than measuring the present reference representation under increasing load.

The project therefore enters the **R — scalable representation frontier**, beginning with measurement rather than optimization.

---

# Active campaign — R0 representation / scale baseline

## Question

Where does the current deliberately simple truth/reference representation actually stop being cheap enough, and which cost dominates first?

## Why now

The current implementation is intentionally easy to reason about:

- full visual mesh rebuild,
- full collision teardown/recreation,
- one collision box/node per occupied cell,
- full Matter scans for mass/COM,
- full-volume connected-component scans and full-size component materialization before compaction.

Those choices are appropriate for semantic research but already suspect for scale. We now have enough integrated lifecycle evidence that their cost can be measured without simultaneously inventing lifecycle semantics.

## R0 rules

**Measure before optimizing.**

During R0 do not introduce:

- greedy collision boxes,
- chunk/region partitioning,
- dirty-region rebuilds,
- convex decomposition,
- async/threaded rebuild scheduling,
- ECS/world-manager abstraction,
- native-Jolt replacement,
- LOD/near-far modes.

Any of those may become a challenger only after baseline data shows which pressure it addresses.

## Required benchmark dimensions

Use several controlled volume extents and several occupancy patterns that separate “occupied Matter count” from “scanned bounding volume”. At minimum:

- dense solid,
- shell/surface-dominant geometry,
- sparse geometry,
- disconnected geometry for split cost.

Record at least:

- extent / total cells scanned,
- occupied cells,
- collision shape count,
- derived mesh vertex count,
- initial static-provider rebuild/build cost,
- initial dynamic-provider rebuild/build cost,
- one-cell dynamic mutation/full rebuild cost,
- connected-component extraction cost,
- shared one→many split transaction cost,
- successor count and total successor collision shapes.

Prefer repeated samples/median or another simple robust statistic where timing noise matters. Keep the benchmark small enough for CI but large enough to expose the first curve bend.

## PASS condition

R0 is **not** “performance is good”. It passes if:

- measurements are reproducible enough to compare cases,
- benchmark does not alter the implementation it measures,
- at least one meaningful scaling pressure can be ranked from evidence,
- we can choose the next R challenger because of observed cost rather than intuition.

## STOP / re-rank

After R0, stop and rank candidate interventions by measured leverage. Do not automatically implement the most obvious optimization if the dominant cost is elsewhere.

---

# Decision frontiers after R0

These are not ordered commitments.

## R1+ — representation challengers

Entry trigger: R0 identifies a dominant measurable cost.

Potential challengers include:

- greedy merged boxes / primitive regions,
- dirty/edit-local collision rebuilds,
- chunk/region representation boundaries,
- separate visual and physical partitions,
- convex clusters/decomposition when geometry warrants it,
- representation simplification for inactive/far/frozen Spaces.

Every challenger must preserve current logical Matter/lineage/lifecycle semantics unless evidence explicitly reopens them.

## A — volumetric actor + finite force exchange

Entry trigger: support/provider semantics are integrated and an interactive/playable consumer needs walls/slopes/steps/ceilings or meaningful actor mass/reaction forces.

## W — canonical world extraction/reintegration

Entry trigger: a real world consumer needs transfer between canonical lattice and independent local Space.

### W0 — lossless lattice-compatible transfer

`canonical cells → independent Space → dynamic motion → lattice-compatible pose → reintegrate`

Must address ownership transfer, occupied destination policy, lineage and dependencies crossing extraction boundaries.

### W1 — incompatible pose / bake

Treat as conversion/resampling with explicit geometry/material/provenance error policy, not ordinary reintegration.

## P — persistence / durable logical identity

Entry trigger: logical Space/Matter identity must survive process/save/load boundaries.

## M — richer mechanics

Entry trigger: integrated/playable consumer needs a relation not covered by current bounded evidence.

## S — streaming / world scale

Entry trigger: concrete world consumer exceeds a single local active region.

Large-world coordinates remain deferred until measurements require them.

## D — multiple simulation domains / migration

Entry trigger: one solver domain no longer conveniently or accurately hosts required interactions/coordinate scales.

Space ≠ simulation domain remains defended.

## N — nested/moving frames

Entry trigger: a real consumer needs dependent Spaces rather than constraint-coupled peers.

Never infer physics nesting from scene-tree parenting.

## L — spatial links / portals

Entry trigger: integrated frame/query semantics are stable enough to isolate cross-Space routing. Begin static/query-only before moving endpoints or partial-crossing physics.

## C — curved / Planet Matter providers

Entry trigger: planar/local Matter assumptions materially block a real planetary experiment. Avoid unnecessary impossibility now; do not build curved topology prematurely.

## V — JV-like vehicles / advanced mobile machinery

Entry trigger: the world substrate naturally hosts rich moving editable mechanisms strongly enough that vehicles become a consumer/donor question rather than a separate architecture.

---

# Playability pressure frontier

After sufficient lifecycle + representation + actor evidence, schedule a deliberately small Owner-facing slice:

> walk → dig/place → activate/freeze a local Space → ride/build on it → use one simple mechanism → inspect/debug consequences.

Purpose: test emergent freedom, feedback and comprehensibility — not content production.

LAB remains an earlier research workbench, not this gameplay slice.

---

# CI / evidence governance

Tests should increasingly separate into:

- **canonical invariants** — current truths protected continuously,
- **current campaign** — active adversarial/measurement work,
- **historical evidence probes** — preserved but allowed to leave every-push CI when superseded.

Retiring an old probe from live CI does not erase evidence. An old green test also must not fossilize obsolete implementation details.

A manifest/runner may replace the append-only workflow when maintenance cost becomes material.

---

# Current stop / replan rules

Replan immediately if:

- Matter/lineage authority becomes ambiguous,
- frame pose/velocity has two simultaneous authorities,
- provider replacement needs hidden compensation to remain continuous,
- transaction/solver/node observation layers are conflated in a way that breaks handoff/debug semantics,
- integrated consumers repeatedly require orchestration that belongs in shared runtime,
- R0/R1 scale evidence contradicts lifecycle assumptions,
- Owner/playability pressure shows technically correct semantics are awkward or uninteresting,
- host-engine limitations materially distort intended invariants.

The roadmap is doing its job when such findings change the plan.