# FrameMatter Lab — adaptive roadmap

Status: **living research decision map**. This is not a fixed release plan, feature checklist or promise of implementation order.

## North star

Build an editable systemic-world substrate where local Matter, moving/static frames, actors and mechanisms can compose without logical identity collapsing into engine representation.

Long-term product pressure remains deliberately simple:

> walk → dig/build → activate a local Space → ride it → edit it while moving → use a simple mechanism → understand/debug the consequences.

This is recurring pressure, not a product-sprint commitment.

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
5. Scale-pressure / scale evidence
6. Playability/product evidence

A PASS at one level never silently implies the next.

---

# Recently closed campaigns

## I0B → LAB → I2 → I3 lifecycle line: **CLOSED FOR CURRENT SCOPE**

The line has integrated provider replacement, a second independent consumer, actor provider-transition continuity and shared one→many topology execution. These semantics are strong enough to act as invariants while representation/update strategies are challenged.

Evidence: `docs/evidence/i0b-provider-replacement-lifecycle.md`, `lifecycle-lab-consumer.md`, `i2-actor-provider-transition.md`, `i3-shared-topology-split.md`.

## M-CAP — standalone mechanics expansion: **FULL PASS / CLOSED**

Bounded stateful partition↔contraction symmetry is sufficiently exercised. More mechanics complexity waits for real consumer pressure.

## R0 — representation / scale baseline: **PASS / CLOSED**

R0 measured the intentionally naive reference representation and ranked one-node/one-shape-per-occupied-cell collision materialization as the dominant first scale pressure.

Evidence: `docs/evidence/r0-representation-scale-baseline.md`.

## R1 — exact merged-cuboid collision: **FULL PASS / CLOSED**

R1 directly challenged the R0 bottleneck with an exact deterministic cuboid compiler while retaining `PER_CELL` as a reference mode.

Within the tested range it reduced dense/shell collider counts and provider/rebuild costs by orders of magnitude in the strongest cases while preserving Matter authority, Matter-derived mass properties and lifecycle/topology semantics. `MERGED_CUBOIDS` is now the provider default; collider count is explicitly not Matter identity.

Evidence: `docs/evidence/r1-exact-collision-aggregation.md`.

## R2P — post-aggregation profile: **PASS / CLOSED**

R2P re-profiled the promoted merged-collision path instead of inheriting R0's old ranking.

It establishes that:

- engine installation of the now-small merged shape set is no longer the dominant update cost,
- full visual mesh generation is the largest measured component in dense/shell provider rebuilds,
- global cuboid compilation and Matter COM scans are also visible,
- material-only and true occupancy edits currently pay almost identical whole-provider rebuild cost despite different implemented physical semantics,
- split-commit economics improved enough that topology preflight/compaction/provider reconstruction are now visible instead of hidden by thousands of collision shapes.

Evidence: `docs/evidence/r2p-post-aggregation-profile.md`.

## R2A — bounded derived-region locality: **PASS AS CHALLENGER / NOT PROMOTED**

R2A tested local derivation without changing runtime representation.

It establishes that:

- one logical Matter volume can preserve exact collision coverage and exposed mesh semantics while derivation work is partitioned into bounded update regions,
- a one-cell edit can reduce derivation work by one to two orders of magnitude at larger tested extents,
- naive fixed regions can simultaneously inflate dense/shell collider partitions by tens to hundreds of times relative to the global R1 compiler,
- therefore **dirty/invalidation partition and final physical representation partition must not be assumed identical**.

The fixed-region test mechanism is deliberately **not** promoted into `MatterRepresentation`/`ConstructBody`.

Evidence: `docs/evidence/r2a-derived-region-locality.md`.

---

# Active campaign — P0 interactive consumer pressure

Representation research now has enough leverage to stop before becoming an architecture exercise.

The current `lab/main.tscn` is useful lifecycle instrumentation, but it is still primarily a keyboard-driven representation/lifecycle console. It does not yet expose the north-star loop as an embodied experiment.

## Question

Can the currently defended substrate support a small coherent interactive loop in which a real actor **stands on, moves across, edits and transitions one logical local Space** without test-local orchestration or hidden semantic shortcuts?

## P0 target experience

The minimum pressure loop is:

> walk on/around Matter → inspect/select a local cell → remove/place Matter → activate the same logical Space → remain supported/ride it → edit while moving → freeze it → inspect what happened.

A simple mechanism is deliberately optional for P0. Mechanics already has strong bounded evidence; forcing a joint into the first slice would add scope before the actor/edit/lifecycle composition itself is proven usable.

## P0 implementation discipline

Prefer composition of existing defended systems over new architecture:

- reuse `LocalMatterSpace` as the logical owner,
- reuse `FrameProbeCharacter` support-frame semantics rather than falling back to stock `CharacterBody3D` rigid interaction,
- keep edits routed through shared `LocalMatterSpace.mutate_cell`,
- keep static↔dynamic transitions on the shared lifecycle path,
- keep the current merged-cuboid provider default,
- add only the minimum interactive input/camera/selection/feedback required to exercise the loop.

Do **not** build a general player framework, inventory, block catalogue, chunk manager, world manager, save system or production UI for P0.

## P0 evidence requirements

The slice is useful when an Owner can exercise it directly and the runtime can report at least:

- actor support Space/provider and grounded state,
- target cell / operation result,
- Matter revision / occupied count / lineage behavior,
- provider kind and provider transition count,
- edit rebuild timing,
- collision-shape count,
- obvious discontinuities or support loss through activate/edit/freeze.

Automated smoke evidence should cover the new shared interactive path where practical, but P0 is the first campaign where **Owner interaction quality is itself material evidence**.

## P0 decision outcomes

### If the loop is coherent and editing latency is acceptable

Do not optimize representation by inertia. Use Owner feedback to choose the next semantic pressure: volumetric actor behavior, finite force exchange, world transfer/reintegration, a simple mechanism, or richer editing.

### If editing latency materially harms the loop

Return to representation research with R2A as measured evidence. Challenge an update-local mechanism that does **not** blindly equate dirty regions with final collision partitions.

### If actor limitations dominate

Enter the volumetric/finite-force actor frontier rather than hiding the problem with movement hacks.

### If lifecycle/provider transitions dominate

Re-open the exact failing lifecycle invariant instead of building around it in the LAB.

### If the experiment feels technically correct but awkward/uninteresting

Treat that as evidence. Revisit interaction semantics and product pressure before expanding infrastructure.

## P0 non-goals

- final game controls,
- production first-person controller,
- content pipeline,
- inventory/crafting,
- world streaming,
- network/multiplayer,
- persistence,
- arbitrary canonical-world reintegration,
- curved/planetary Matter,
- general vehicle system,
- architectural commitment to R2A fixed regions.

---

# Decision frontiers after / during P0

## A — volumetric actor + finite force exchange

Entry trigger: the interactive consumer needs walls/slopes/steps/ceilings or meaningful actor mass/reaction forces.

## W — canonical world extraction/reintegration

Entry trigger: a real world consumer needs transfer between canonical lattice and independent local Space.

## R2 — update-local representation follow-up

Entry trigger: P0 or another concrete consumer demonstrates that whole-volume edit/rebuild cost materially limits the intended interaction.

Constraint: preserve R2A's distinction between update locality and final physical partition; do not promote fixed region collision topology by default.

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

# CI / evidence governance

Separate tests conceptually into:

- canonical invariants,
- current campaign,
- historical evidence probes.

Retiring an old probe from every-push CI does not erase evidence. Old green probes must not fossilize obsolete implementation details.

The R1 promotion produced concrete examples: historical `shape count == occupied cells` assertions were test debt after the representation changed. The correct invariant is truth/representation coherence, not preservation of a superseded collider topology.

R2A also showed why current-campaign challengers should remain separable from promoted runtime invariants: a large local timing win can still expose a serious representation tradeoff and therefore remain evidence without becoming architecture.

---

# Current stop / replan rules

Replan immediately if:

- Matter/lineage authority becomes ambiguous,
- representation optimization begins defining gameplay identity,
- mass/COM/inertia accidentally become collider-derived instead of Matter-derived,
- lifecycle timing or actor support changes merely to accommodate an optimization,
- profiling shows whole-volume representation work is no longer the important next pressure,
- an optimization requires disproportionate architecture before a real consumer demonstrates the need,
- Owner/playability pressure shows the technically correct substrate is awkward or uninteresting,
- host-engine limitations materially distort intended invariants.

The roadmap is doing its job when such findings change the plan.