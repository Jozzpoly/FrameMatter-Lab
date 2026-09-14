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

# Recently closed campaigns

## I0B → LAB → I2 → I3 lifecycle line: **CLOSED FOR CURRENT SCOPE**

The line now has integrated provider replacement, a second independent consumer, actor provider-transition continuity and shared one→many topology execution. These semantics are strong enough to serve as invariants while representation scale is challenged.

Evidence: `docs/evidence/i0b-provider-replacement-lifecycle.md`, `lifecycle-lab-consumer.md`, `i2-actor-provider-transition.md`, `i3-shared-topology-split.md`.

## M-CAP — standalone mechanics expansion: **FULL PASS / CLOSED**

Bounded stateful partition↔contraction symmetry is sufficiently exercised. More mechanics complexity waits for real consumer pressure.

## R0 — representation / scale baseline: **PASS / CLOSED**

R0 measured the unoptimized reference representation across dense, shell, sparse and disconnected cases.

Key result at `14³`:

- dense static init: `1.497 s`, dynamic init: `1.132 s`, one-cell full rebuild: `1.748 s`, topology extract: `22.5 ms`,
- shell has **more visual mesh vertices** than dense but is ~7× faster because it has far fewer collision shapes,
- sparse skeleton shares the same extent but rebuilds in only `7.3 ms`,
- disconnected split preflight is `21 ms` while commit is `558 ms`.

The dominant first scale pressure is therefore the one-node/one-shape-per-occupied-cell collision representation, not connectivity scanning or visual mesh complexity.

Evidence: `docs/evidence/r0-representation-scale-baseline.md`.

---

# Active campaign — R1 exact collision aggregation

## Question

Can the physical collision representation be compressed from one box/node per occupied Matter cell to a much smaller exact set of axis-aligned cuboids **without changing logical Matter, lineage, mass properties, lifecycle semantics or occupied collision volume**?

## Why this challenger first

R0 ranked this pressure directly. Dense provider build/rebuild cost becomes strongly superlinear in occupied-cell count in the tested range. Shell-vs-dense results specifically separate collision-shape materialization from visual mesh complexity.

## R1 mechanism hypothesis

Introduce a deterministic derived collision compiler that partitions occupied unit cells into non-overlapping axis-aligned integer cuboids.

Important semantics:

- `CellVolume` remains truth.
- Cuboids are disposable derived representation, never gameplay identity.
- Cuboids must exactly cover occupied unit-cell volume with no holes and no overlap.
- Matter-derived mass/COM/inertia remain authoritative; collider aggregation must not redefine mass semantics.
- Current material IDs are not yet a per-cell physics-material model, so R1 may merge occupied cells across visual/material IDs. Record this scope explicitly.
- Static and dynamic providers should consume the same collision-box derivation path.

## A/B requirements

Keep the current per-cell representation available as a reference during the challenger.

Measure at least dense/shell/skeleton cases for:

- occupied cells,
- reference shape count,
- aggregated cuboid count,
- compression ratio,
- static provider build,
- dynamic provider build,
- one-cell full rebuild,
- exact collision coverage verification.

Then integrate the aggregated path into lifecycle tests that exercise:

- dynamic motion,
- live mutation,
- provider replacement,
- actor support,
- shared topology split.

## R1 PASS condition

R1 passes only if both are true:

1. **semantic/correctness:** exact occupied collision volume and current mass/lifecycle invariants remain coherent;
2. **scale:** shape count and measured provider/rebuild cost improve materially on the R0 pressure cases.

A faster but approximate collider is not a PASS. A geometrically exact compiler that does not improve the dominant cost is also not sufficient.

## R1 non-goals

- dirty-region rebuild scheduling,
- chunk/world partitioning,
- convex decomposition,
- asynchronous rebuilds,
- native-Jolt custom compounds,
- LOD or distance-based representation modes,
- production physical material boundaries.

## STOP / re-rank

After R1 A/B + integrated ratchets, stop and measure again. If full rebuild cost remains material, dirty/edit-local rebuild becomes a strong R2 candidate. If provider construction becomes cheap enough and topology scanning becomes visible, re-rank instead of assuming the next optimization.

---

# Decision frontiers after R1

## R2+ — remaining representation/update pressure

Possible triggers after new measurements:

- dirty/edit-local collision/mesh rebuild,
- chunk/region representation boundaries,
- separate visual/physical partitions,
- convex clusters/decomposition,
- inactive/far/frozen simplification.

## A — volumetric actor + finite force exchange

Entry trigger: an interactive/playable consumer needs walls/slopes/steps/ceilings or meaningful actor mass/reaction forces.

## W — canonical world extraction/reintegration

Entry trigger: a real world consumer needs transfer between canonical lattice and independent local Space.

## P — persistence / durable logical identity

Entry trigger: logical Space/Matter identity must survive process/save/load boundaries.

## M — richer mechanics

Entry trigger: integrated/playable consumer needs a relation not covered by current bounded evidence.

## S — streaming / world scale

Entry trigger: a concrete world consumer exceeds a single local active region.

## D — multiple simulation domains / migration

Entry trigger: one solver domain no longer conveniently or accurately hosts required interactions/coordinate scales.

## N — nested/moving frames

Entry trigger: a real consumer needs dependent Spaces rather than constraint-coupled peers.

## L — spatial links / portals

Entry trigger: integrated frame/query semantics are stable enough to isolate cross-Space routing. Begin static/query-only before moving endpoints or partial-crossing physics.

## C — curved / Planet Matter providers

Entry trigger: planar/local Matter assumptions materially block a real planetary experiment.

## V — JV-like vehicles / advanced mobile machinery

Entry trigger: the world substrate naturally hosts rich moving editable mechanisms strongly enough that vehicles become a consumer/donor question rather than a separate architecture.

---

# Playability pressure frontier

After sufficient lifecycle + representation + actor evidence, schedule a deliberately small Owner-facing slice:

> walk → dig/place → activate/freeze a local Space → ride/build on it → use one simple mechanism → inspect/debug consequences.

Purpose: test emergent freedom, feedback and comprehensibility — not content production.

---

# CI / evidence governance

Separate tests conceptually into:

- canonical invariants,
- current campaign,
- historical evidence probes.

Retiring an old probe from every-push CI does not erase evidence. Old green probes must not fossilize obsolete implementation details.

---

# Current stop / replan rules

Replan immediately if:

- Matter/lineage authority becomes ambiguous,
- representation optimization begins defining gameplay identity,
- aggregated collision cannot preserve exact occupied geometry in the bounded voxel provider,
- mass/COM/inertia accidentally become collider-derived instead of Matter-derived,
- lifecycle timing or actor support changes merely to accommodate an optimization,
- measured R1 results show collision aggregation was not actually the dominant leverage point,
- Owner/playability pressure shows the technically correct substrate is awkward or uninteresting,
- host-engine limitations materially distort intended invariants.

The roadmap is doing its job when such findings change the plan.