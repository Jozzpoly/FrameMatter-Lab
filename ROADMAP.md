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

## P0 — first embodied consumer: **AUTOMATED PASS / FIRST OWNER RUN COMPLETE**

P0 moved the LAB from lifecycle instrumentation to a real embodied consumer. Its automated translation+yaw composition remains defended: actor support, direct Matter editing, static→dynamic ride/walk, moving edit and freeze all pass through the shared `LocalMatterSpace` path.

The first direct Owner run then supplied the missing qualitative evidence. It did **not** demonstrate a substrate failure. Instead it showed that fixed distant framing, weak cell-target feedback, low Matter readability and an always-dominant telemetry HUD contaminated the experiment strongly enough that the next test needed a better measurement surface.

Evidence: `docs/evidence/p0-interactive-consumer.md`.

---

# Active campaign — P0.5 Owner interaction baseline

P0.5 is a deliberately thin interaction/readability layer over P0. It exists to let the next Owner run pressure FrameMatter rather than mostly pressure prototype ergonomics.

## Current status

**Automated P0 regression gate: PASS.**  
**P0.5 interaction-surface gate: PASS.**  
**Windows/Web delivery: PASS.**  
**Second Owner interaction: PENDING.**

Green delivery context:

- workflow `Deliver P0.5 Owner Test`,
- run `#6`, ID `34915675303`,
- commit `9790d5b859073c3a2f7136cb14861613f3d54661`,
- Godot `4.7.2` + built-in Jolt.

The same delivery run first re-ran the defended P0 consumer and retained:

- `ride_floor_loss = 0`,
- `walk_floor_loss = 0`,
- `post_edit_floor_loss = 0`,
- stationary local drift `0.00000812`,
- local walk displacement about `0.95959`,
- fresh lineage across static and moving remove/recreate cycles.

The P0.5-specific gate then verified:

- compact Owner HUD + preserved rich debug telemetry,
- materially closer camera and deterministic zoom,
- explicit remove/place preview surfaces,
- occupied-cell grid context,
- non-destructive actor recovery that preserves logical Space/provider authority,
- shared Matter mutation path beneath the presentation layer,
- compatibility with static→dynamic activation,
- sampled grid/provider transform gap `0.00000000` after explicit presentation sync.

Evidence: `docs/evidence/p05-interaction-baseline.md`.

## First Owner finding carried forward

The original pitch/roll P0 challenger kept support (`floor_loss=0`) but produced about `0.501` local drift for a stationary rider.

That remains a real boundary in the current `FrameProbeCharacter`: support transport is frame-aware, while support validation/snap is still a single world-down ground ray. Earlier actor evidence was yaw-only, so this is not a regression inside an already defended scope.

P0.5 deliberately does **not** hide the finding by choosing local gravity, adhesion or frame-relative 'down' semantics. The Owner-facing slice remains translation+yaw bounded; arbitrary pitch/roll support remains an actor frontier.

## Question

With the largest obvious interaction/readability contamination reduced, does direct use now reveal a coherent and interesting manipulation loop for one editable static/dynamic logical Space — and which remaining limitation actually dominates the experience?

## P0.5 target experience

> walk → comfortably frame the scene → clearly preview a cell operation → remove/place Matter → activate the same logical Space → ride/walk on it → edit while moving → freeze it → inspect technical state only when useful.

A simple mechanism is still optional. Mechanics already has strong bounded evidence; it should enter only if direct use says a mechanism is the next high-information semantic pressure.

## P0.5 implementation discipline

P0.5 must remain a measurement layer rather than silently becoming architecture:

- keep `lab/main.gd` as the defended P0 consumer and layer P0.5 above it,
- keep edits routed through `LocalMatterSpace.mutate_cell`,
- keep static↔dynamic transitions on the shared lifecycle path,
- do not let presentation-grid structure define world/chunk/collision identity,
- treat `K` recovery as test continuity tooling rather than gameplay design,
- keep full telemetry available but out of the default visual path,
- stop adding UX features once another Owner run can answer the campaign question.

Do **not** build a general player framework, inventory, block catalogue, chunk manager, world manager, save system or production UI as part of P0.5.

## Remaining material evidence

The next evidence is direct Owner use of the packaged P0.5 build:

- camera orbit/zoom feel,
- pointer preview clarity before clicking,
- Matter/cell readability,
- whether moving-Space editing remains understandable,
- perceived edit latency,
- transition continuity as seen rather than merely measured,
- whether the improved loop exposes a compelling missing semantic/gameplay capability.

P0.5 is successful as a campaign even if that run says it is still awkward. The job is to identify the highest-value next pressure, not to polish until the LAB resembles a product.

## P0.5 decision outcomes

### If the loop is coherent and editing latency is acceptable

Do not optimize representation by inertia. Use Owner feedback to choose the next semantic pressure: volumetric actor behavior, finite force exchange, world transfer/reintegration, a simple mechanism, richer editing, or another clearly demanded capability.

### If editing latency materially harms the loop

Return to representation research with R2A as measured evidence. Challenge an update-local mechanism that does **not** blindly equate dirty regions with final collision partitions.

### If actor limitations dominate

Enter the volumetric/orientation/finite-force actor frontier deliberately rather than hiding the problem with movement hacks.

### If lifecycle/provider transitions dominate

Re-open the exact failing lifecycle invariant instead of building around it in the LAB.

### If interaction/readability still dominates

Improve only the highest-leverage obstacle exposed by Owner use. Do not turn P0.5 into an open-ended UI/graphics project.

### If the experiment feels technically correct but uninteresting

Treat that as strong evidence. Revisit the product pressure and semantics before expanding infrastructure.

## P0.5 non-goals

- final game controls,
- production first-person/third-person controller,
- arbitrary pitch/roll locomotion semantics,
- production UI/visual language,
- scalable grid rendering,
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

# Decision frontiers after / during P0.5

## A — volumetric / oriented actor + finite force exchange

Entry trigger: Owner interaction needs walls/slopes/steps/ceilings, arbitrary tilted support, explicit local-vs-world gravity semantics, or meaningful actor mass/reaction forces.

The pitch/roll P0 challenger already supplies one concrete reason this frontier may become important, but it is not automatically the next campaign until Owner interaction ranks it against other pressures.

## W — canonical world extraction/reintegration

Entry trigger: a real world consumer needs transfer between canonical lattice and independent local Space.

## R2 — update-local representation follow-up

Entry trigger: P0.5 or another concrete consumer demonstrates that whole-volume edit/rebuild cost materially limits the intended interaction.

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

The lightweight current-consumer path now has two explicit layers: the defended P0 smoke for substrate composition and the P0.5 interaction-surface smoke before Owner packaging. Fast invariants and the complete historical research ratchet remain separate protections.

Retiring an old probe from every-push CI does not erase evidence. Old green probes must not fossilize obsolete implementation details.

The R1 promotion produced concrete examples: historical `shape count == occupied cells` assertions were test debt after the representation changed. The correct invariant is truth/representation coherence, not preservation of a superseded collider topology.

R2A showed why current-campaign challengers should remain separable from promoted runtime invariants: a large local timing win can still expose a serious representation tradeoff and therefore remain evidence without becoming architecture.

P0 adds the complementary lesson: an integrated consumer can expose a semantic limit (pitch/roll actor support) that narrower green probes did not test, without invalidating the bounded evidence those probes actually established.

P0.5 adds another lesson: human interaction can expose measurement-surface problems that are neither substrate regressions nor mere cosmetic polish. Improving that surface is justified only insofar as it makes the next evidence cleaner.

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
- P0.5 polish begins expanding without increasing evidence quality,
- host-engine limitations materially distort intended invariants.

The roadmap is doing its job when such findings change the plan.