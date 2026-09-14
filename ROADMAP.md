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

Representation research has enough leverage to stop before becoming architecture by inertia, and P0 has now produced its first integrated consumer result.

## Current status

**Automated composition gate: PASS in bounded translation+yaw scope.**

The real `lab/main.tscn` is now embodied rather than only a lifecycle console. It contains the existing `FrameProbeCharacter`, follow camera, direct provider-local Matter selection, remove/place editing and the shared static↔dynamic lifecycle path.

On commit `09eb18e8e691f0f6b2ae085a931d96cf85447bc5`, GitHub Actions run `#202` passed:

- current-campaign validation,
- fast invariant validation,
- full historical research validation through R0/R1/R2P/R2A.

The P0 automated smoke itself measured:

- zero floor-loss frames during stationary ride,
- zero floor-loss frames while walking on the moving Space,
- zero floor-loss frames after occupancy editing while moving,
- stationary local drift `0.00000812`,
- local walk displacement `0.95959115`,
- fresh lineage after static and moving Matter recreation,
- coherent static→dynamic→static provider succession under one logical Space.

This is **integrated automated evidence, not playability/product PASS**. P0 remains active until the Owner has directly used the scene and supplied interaction/feel/latency feedback.

Evidence: `docs/evidence/p0-interactive-consumer.md`.

## First consumer finding

The initial P0 challenger intentionally included pitch/roll as well as yaw. It kept support (`floor_loss=0`) but produced about `0.501` local drift for a stationary rider.

That exposed a real boundary in the current `FrameProbeCharacter`: support transport is frame-aware, while support validation/snap is still a single world-down ground ray. Earlier actor evidence was yaw-only, so this is not a regression inside an already defended scope.

P0 deliberately does **not** hide the finding by choosing local gravity, adhesion or frame-relative 'down' semantics in the LAB. The Owner-facing slice is therefore currently translation+yaw bounded; arbitrary pitch/roll support moves to the actor frontier.

## Question

Can the currently defended substrate support a small coherent interactive loop in which a real actor **stands on, moves across, edits and transitions one logical local Space** without test-local orchestration or hidden semantic shortcuts — and does that loop feel coherent when the Owner actually uses it?

## P0 target experience

The minimum pressure loop is:

> walk on/around Matter → inspect/select a local cell → remove/place Matter → activate the same logical Space → remain supported/ride it → edit while moving → freeze it → inspect what happened.

A simple mechanism is deliberately optional for P0. Mechanics already has strong bounded evidence; forcing a joint into the first slice would add scope before Owner interaction has evaluated actor/edit/lifecycle composition.

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

Automated composition requirements are now met for the bounded translation+yaw slice. The remaining material evidence is direct Owner interaction:

- movement/camera feel,
- pointer selection clarity,
- remove/place clarity,
- perceived edit latency,
- transition continuity as seen rather than merely measured,
- whether the loop is useful/interesting enough to reveal the next real pressure.

The runtime already reports:

- actor support Space/provider and grounded state,
- target cell / operation result,
- Matter revision / occupied count / lineage behavior,
- provider kind and provider transition count,
- edit rebuild timing,
- collision-shape count,
- transition/debug state.

P0 is the first campaign where **Owner interaction quality is itself material evidence**.

## P0 decision outcomes

### If the loop is coherent and editing latency is acceptable

Do not optimize representation by inertia. Use Owner feedback to choose the next semantic pressure: volumetric actor behavior, finite force exchange, world transfer/reintegration, a simple mechanism, or richer editing.

### If editing latency materially harms the loop

Return to representation research with R2A as measured evidence. Challenge an update-local mechanism that does **not** blindly equate dirty regions with final collision partitions.

### If actor limitations dominate

Enter the volumetric/orientation/finite-force actor frontier deliberately rather than hiding the problem with movement hacks.

### If lifecycle/provider transitions dominate

Re-open the exact failing lifecycle invariant instead of building around it in the LAB.

### If the experiment feels technically correct but awkward/uninteresting

Treat that as evidence. Revisit interaction semantics and product pressure before expanding infrastructure.

## P0 non-goals

- final game controls,
- production first-person controller,
- arbitrary pitch/roll locomotion semantics,
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

## A — volumetric / oriented actor + finite force exchange

Entry trigger: Owner interaction needs walls/slopes/steps/ceilings, arbitrary tilted support, explicit local-vs-world gravity semantics, or meaningful actor mass/reaction forces.

The pitch/roll P0 challenger already supplies one concrete reason this frontier may become important, but it is not automatically the next campaign until Owner interaction ranks it against other pressures.

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

The workflow now has a lightweight `current-campaign-validation` lane for the real LAB + P0 smoke, while fast invariants and the complete historical research ratchet remain separate protections.

Retiring an old probe from every-push CI does not erase evidence. Old green probes must not fossilize obsolete implementation details.

The R1 promotion produced concrete examples: historical `shape count == occupied cells` assertions were test debt after the representation changed. The correct invariant is truth/representation coherence, not preservation of a superseded collider topology.

R2A showed why current-campaign challengers should remain separable from promoted runtime invariants: a large local timing win can still expose a serious representation tradeoff and therefore remain evidence without becoming architecture.

P0 adds the complementary lesson: an integrated consumer can expose a semantic limit (pitch/roll actor support) that narrower green probes did not test, without invalidating the bounded evidence those probes actually established.

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