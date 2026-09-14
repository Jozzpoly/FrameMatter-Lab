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

At `14³` in the final control rerun:

- dense: `2744` shapes, static init ~`1.88 s`, dynamic init ~`1.52 s`, full mutation/rebuild ~`2.43 s`,
- shell: `1016` shapes, full mutation/rebuild ~`340 ms`,
- skeleton: `40` shapes, full mutation/rebuild ~`8 ms`,
- topology extraction remained tens of milliseconds rather than seconds,
- disconnected split cost was dominated by successor/provider construction rather than split preflight.

Evidence: `docs/evidence/r0-representation-scale-baseline.md`.

## R1 — exact merged-cuboid collision: **FULL PASS / CLOSED**

R1 directly challenged the R0 bottleneck with an exact deterministic cuboid compiler while retaining `PER_CELL` as a reference mode.

Final `14³` A/B result:

- dense: `2744 → 1` shapes; static ~`76×`, dynamic ~`57×`, full rebuild ~`87×` faster,
- shell: `1016 → 6` shapes; static ~`18×`, dynamic ~`13×`, full rebuild ~`20×` faster,
- skeleton: `40 → 5` shapes; only ~`1.1×` faster, strengthening the diagnosis that R1 removed the shape-materialization pressure rather than producing an unrelated universal speedup,
- exact occupied coverage remained error-free in every A/B case,
- merged collision survived provider replacement, live occupancy mutation, solver mass properties, actor support and shared topology succession,
- `MERGED_CUBOIDS` is now the current provider default; collider count is explicitly not Matter identity.

The full post-promotion ratchet passed at commit `286758a9cdf895e569f8cbb1b300602005ae94e2`, workflow run `#182` / `34899262822`.

Evidence: `docs/evidence/r1-exact-collision-aggregation.md`.

---

# Active campaign — R2P post-aggregation profile / re-rank

R1 changed the cost structure enough that the R0 ranking is obsolete. Do not choose the next optimization from intuition or momentum.

## Question

After exact collision aggregation removes per-cell shape materialization, **what now dominates real provider rebuild, live edit and topology-transaction cost at representative local-Space sizes?**

## Why profile before another mechanism

The promoted runtime still rebuilds whole derived representations, but several distinct costs are currently collapsed into one timing:

- full-volume Matter scans,
- visual mesh generation,
- merged-cuboid compilation,
- engine collision-node/shape materialization,
- dynamic mass/COM/solver refresh,
- provider teardown/reconstruction,
- topology extraction,
- split successor construction.

R1 shows that a dense `14³` full rebuild is now on the order of `27 ms`, not seconds. That may still matter for interactive editing, but it is no longer self-evident that dirty collision is the highest-leverage next task.

## R2P measurement requirements

Measure under the promoted `MERGED_CUBOIDS` path across controlled dense/shell/skeleton cases and at least one disconnected split case:

- logical occupied-count / scan cost,
- visual mesh generation cost,
- merged-cuboid compilation cost,
- engine collision shape/node installation cost,
- dynamic provider full rebuild cost,
- static provider full rebuild cost,
- live **occupancy-changing** edit cost,
- retained-Matter/material-only edit cost separately,
- topology extraction cost,
- shared split preflight + commit cost,
- resulting shape counts / mesh vertices / successor shapes.

Where practical, use medians over repeated samples and preserve the same controlled patterns used by R0/R1 for causal comparability.

## Critical edit-semantics distinction

A retained-Matter material-ID edit is not automatically a physical occupancy edit.

Current physical semantics do not yet define per-cell density/friction/material boundaries. Therefore an expensive full collision rebuild triggered by a material-only edit must be reported as **current execution behavior**, not evidence that future collision semantics require that rebuild.

At least one R2P occupancy-changing case must add/remove Matter so the physical representation genuinely changes.

## R2P outcome / decision rules

R2P is a measurement campaign. It does not pass by making the runtime faster.

It succeeds when the next bottleneck is ranked strongly enough to choose among these possibilities:

### Candidate R2A — edit-local / dirty rebuild

Enter if:

- whole-provider rebuild remains materially costly at relevant sizes,
- most cost can be avoided for spatially local edits,
- the exact representation can be updated locally without disproportionate complexity or semantic risk.

### Candidate R2B — bounded region/chunk representation

Enter if:

- global greedy cuboid partitioning makes true local updates structurally awkward,
- bounded representation regions offer cleaner invalidation/update locality,
- region boundaries can remain derived implementation rather than gameplay identity.

### Candidate R2C — visual/update separation

Enter if:

- mesh generation becomes dominant while physical collision is already cheap,
- visual and physical optimal update partitions materially diverge.

### Stop representation optimization and return to consumer pressure

Prefer this if:

- representative local-Space rebuild/edit costs are already adequate for the next interactive experiment,
- remaining optimization would have lower information value than exercising volumetric interaction, finite force exchange, world transfer or the Owner-facing slice.

### Re-rank elsewhere

If topology transaction, actor/controller limitations, world transfer or another subsystem now dominates the next meaningful consumer, follow that evidence instead of forcing an R2 representation project.

## R2P non-goals

- implementing dirty regions,
- introducing a chunk/world manager,
- asynchronous job systems,
- native Jolt compounds,
- convex decomposition,
- LOD/distance modes,
- streaming architecture,
- production material boundaries.

Those remain candidate mechanisms until R2P evidence selects one.

---

# Decision frontiers after R2P

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

The slice should not be rushed merely because R1 passed. Conversely, representation research should stop when it is good enough to support a higher-information interactive challenge.

---

# CI / evidence governance

Separate tests conceptually into:

- canonical invariants,
- current campaign,
- historical evidence probes.

Retiring an old probe from every-push CI does not erase evidence. Old green probes must not fossilize obsolete implementation details.

The R1 promotion produced concrete examples: historical `shape count == occupied cells` assertions were test debt after the representation changed. The correct invariant is truth/representation coherence, not preservation of a superseded collider topology.

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