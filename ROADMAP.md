# FrameMatter Lab — adaptive roadmap

Status: **living research decision map**. This is not a fixed release plan, feature checklist, or promise of implementation order.

## North star

Build an editable systemic-world substrate where local Matter, moving/static frames, actors and mechanisms can compose without logical identity collapsing into engine representation.

Long-term product pressure remains deliberately simple:

> walk → dig/build → activate a local Space → ride it → edit it while moving → use a simple mechanism → understand/debug the consequences.

This is a recurring pressure test, **not** the current sprint goal.

## How this roadmap is allowed to change

- Evidence outranks sequence. A material FAIL may reorder, split, replace or delete later work immediately.
- PASS does not automatically unlock the next thematically similar feature.
- Every major campaign ends with a re-audit before scope expands.
- Future frontiers are not commitments until their entry trigger is satisfied.
- Stop conditions are first-class. A successful research line may be deliberately stopped when information value falls.
- No sunk-cost protection. A stronger integrated consumer may falsify a mechanism with many green isolated probes.
- Stable intent/invariants are preferred over stable class names, APIs or host-engine mechanisms.
- Historical evidence is preserved even when live guidance changes.
- Work is ranked by **information value × leverage × risk reduction / cost**, not by thematic neatness.
- Interactive/playability pressure must recur periodically so the project does not become an isolated technology exercise.

## Evidence maturity

Claims should carry an implicit or explicit maturity level:

1. **Hypothesis** — useful idea, no direct evidence.
2. **Bounded evidence** — precise isolated probe passes.
3. **Integrated evidence** — behavior composes with a real consumer and neighboring systems.
4. **Reusable-substrate evidence** — multiple independent consumers use the same execution path.
5. **Scale evidence** — representative size/load remains stable and performant.
6. **Playability/product evidence** — Owner use shows the system creates the intended experience.

A PASS at one level must never be silently promoted to the next.

---

# Recently closed campaign

## M-CAP — standalone mechanics expansion: **FULL PASS / CLOSED**

The stateful graph-contraction capstone closed the intended partition↔contraction symmetry: two distinct external motorized/limited hinges converged onto one inelastic merged successor while retaining separate owner lineage, full constraint frames, joint identities and active state; the relation that became internal/self-edge retired.

The mechanics-only expansion is deliberately stopped here. Longer chains, loops, breakable links and mechanism catalogues are not the next research direction. They return only when an integrated/playable consumer creates a concrete information need.

Evidence: `docs/evidence/stateful-graph-contraction-capstone.md`.

---

# Active campaign — integrated local-Space lifecycle

Only this section is ordered. Everything below it is a decision frontier, not a queue.

## I0A — in-place static/dynamic control

**Question:** what lifecycle behavior is possible when one `RigidBody3D` keeps its engine identity and changes between dynamic and frozen/static behavior?

**Why now:** establishes a low-churn control before testing representation replacement. The first pass is a host-semantics probe: measure what Godot/Jolt actually preserves or changes before writing our lifecycle contract.

**Host-semantics measurements first:**

- RID / instance identity,
- transform/orientation continuity,
- linear/angular velocity behavior across freeze/unfreeze,
- collision/mass/COM/inertia continuity,
- sleeping/activation observations where relevant,
- edit/rebuild behavior while frozen and after unfreeze,
- lineage/Matter continuity.

**Gate evidence after host truth is known:**

- same logical Matter/lineage authority throughout,
- no unexplained world-space cell jump on mode changes,
- arbitrary orientation survives freeze,
- edits remain valid before/after transition,
- lifecycle is observable through one integrated path rather than test-local reconstruction.

**Non-goal:** proving representation independence or assuming velocity semantics the engine does not promise.

**Decision:** establishes baseline behavior and exposes which problems are intrinsic to lifecycle versus provider/body replacement.

## I0B / I1 — logical Space + real representation replacement

**Question:** can one persistent logical local Space survive `static representation → dynamic representation → static representation` while representation/body identity changes?

**Working hypothesis:** a persistent logical frame/Space identity survives while exactly one active provider owns current pose/velocity authority. This is not yet a prescribed class design.

**Required evidence:**

- one authoritative Matter + lineage state,
- one logical Space/frame identity across host replacement,
- no double ownership during commit,
- representation-changing commit occurs on the defended pre-PhysicsServer-step boundary,
- activation and freeze preserve world-space cell centers within numerical tolerance,
- dynamic translation/rotation and live Matter edits survive later freeze,
- freeze preserves arbitrary current orientation rather than snapping to a world lattice,
- post-freeze Space remains editable.

**Non-goals:** canonical-world reintegration, bake/resample, production persistence, scalable collision representation.

**Falsification trigger:** if authority becomes ambiguous or logical state must be duplicated between providers, revise the Space/frame model rather than hiding the ambiguity behind a manager class.

## LAB — restore the interactive lab as a real consumer

**Question:** can the same I0/I1 execution path be exercised interactively and inspected visually?

**Required behavior:** edit → activate → move/rotate → live-edit → freeze, with visible frame/provider/lineage/debug state.

**Rule:** important reusable runtime behavior should be exercised by both automated adversarial tests and the interactive lab through the same path.

**Non-goal:** game content or polished UX.

## I2 — actor continuity through provider transition

**Question:** can actor support refer to a logical frame relation while the concrete support provider changes static↔dynamic↔static?

**Required evidence:**

- no one-frame reacquisition slip,
- explicit support mapping/authority transfer,
- no teleport,
- grounded state preserved where geometrically valid,
- support velocity changes coherently as motion begins/ends,
- no return of uncontrolled kinematic actor→rigid-body impulse semantics.

**Non-goal:** production volumetric controller.

## I3 — topology mutation through the shared integrated path

**Question:** can a moving Space split through the same reusable lifecycle path instead of manually recreating successor logic inside a giant probe?

**Required reuse:**

- retained/destroyed/created Matter identity handling,
- compact local-coordinate mapping,
- physical-state/velocity-field inheritance,
- pre-step replacement timing,
- actor support succession,
- at most one deliberately chosen mechanical relation if it increases information value.

**PASS condition:** the new test is primarily an adversarial client of shared runtime execution rather than the place where topology behavior is implemented.

## Re-audit gate

After I3, stop and re-rank all frontiers. Do not assume representation scaling is still next if integrated evidence reveals a more fundamental risk.

---

# Decision frontiers

These are **not ordered commitments**. Each has an entry trigger.

## R — scalable representation

**Known pressure:** box-per-cell collision is already rejected as a scalable dynamic representation.

**Entry trigger:** I1 establishes actual lifecycle/update granularity.

Potential questions:

- greedy merged boxes / primitive regions,
- edit-local rebuild granularity,
- convex clusters/decomposition and geometry error,
- dirty-region physical rebuilds,
- different near/far/frozen representations without turning them into gameplay modes,
- separate visual-mesh and collision partitions unless evidence couples them.

## A — volumetric actor + finite force exchange

**Entry trigger:** support/provider semantics are integrated and a playable/interactive consumer needs walls/slopes/steps/ceilings or meaningful actor mass/reaction forces.

Questions:

- capsule/shape queries,
- slopes/steps/ceilings,
- finite actor→construct impulses,
- tilted surfaces/arbitrary gravity only when a real consumer needs them.

## W — canonical world extraction/reintegration

**Entry trigger:** local-Space lifecycle is coherent.

### W0 — lossless lattice-compatible transfer

`canonical world cells → independent Space → dynamic motion → lattice-compatible pose → reintegrate`

Must address ownership transfer, occupied destination policy, lineage continuity and dependencies crossing extraction boundaries.

### W1 — incompatible pose / bake

Not ordinary reintegration. Only enter if the product actually needs arbitrary bake-to-grid. Treat as conversion/resampling with measurable geometry/material/provenance error.

## P — persistence / durable logical identity

**Entry trigger:** logical Space/Matter identity must survive process/save/load boundaries.

Do not design production UUID semantics before this consumer exists.

## M — richer mechanics

**Entry trigger:** an integrated/playable consumer needs a relation not covered by current bounded evidence.

Possible future pressure: additional joint types, breakable links, shafts/transmission, closed loops/overconstraint. Do not explore them merely to enlarge the graph.

## S — streaming / world scale

**Entry trigger:** a concrete world consumer exceeds a single local active region.

Questions include streaming authority, sleeping/frozen Spaces, origin/precision strategy, representation simplification and save boundaries.

Large-world coordinates remain deferred until measurements require them.

## D — multiple simulation domains / migration

**Entry trigger:** one solver domain can no longer conveniently/accurately host interactions or coordinate scales required by a real consumer.

Space ≠ simulation domain remains a defended conceptual separation.

## N — nested/moving frames

**Entry trigger:** a real gameplay/research consumer needs dependent Spaces rather than mere constraint-coupled peers.

Do not infer nesting from scene-tree parenting.

## L — spatial links / portals

**Entry trigger:** integrated frame/query semantics are stable enough that cross-Space routing can be isolated rather than invented simultaneously with Space identity.

Progressive research should begin static and query-only before moving endpoint/cross-frame physics.

## C — curved / Planet Matter providers

**Entry trigger:** planar/local Matter provider assumptions materially block a real planetary experiment.

Current architecture should avoid unnecessary impossibility, but should not implement curved topology early.

## V — JV-like vehicles / advanced mobile machinery

**Entry trigger:** the world substrate can host rich moving editable mechanisms naturally enough that a vehicle system becomes a consumer/donor integration question rather than a separate minigame architecture.

---

# Playability pressure frontier

After sufficient integrated lifecycle + representation evidence, schedule a deliberately small Owner-facing slice:

> walk → dig/place → activate/freeze a local Space → ride/build on it → use one simple mechanism → inspect/debug consequences.

Its purpose is **not** content production. It asks whether system composition produces the emergent freedom, feedback and comprehensibility that justify the long-term direction.

Do not rush to this slice before the substrate can teach us something useful through it; do not postpone it indefinitely either.

---

# CI / evidence governance

Tests should gradually separate into:

- **canonical invariants** — still-relevant truths protected continuously,
- **current campaign** — active adversarial work,
- **historical evidence probes** — preserved but allowed to leave every-push CI once superseded by stronger integrated tests.

Retiring a probe from live CI does not erase its evidence. Conversely, an old green test must not make an obsolete implementation detail architecturally permanent.

A manifest/runner may replace the append-only workflow only when maintenance cost becomes material.

---

# Current stop / replan rules

Replan immediately if any of the following occur:

- logical Matter/lineage authority becomes ambiguous,
- frame pose/velocity acquires two simultaneous authorities,
- provider replacement cannot be made continuous without hidden compensation,
- integrated consumer requires repeated test-local orchestration that should have become shared runtime,
- scalable representation needs contradict lifecycle assumptions,
- Owner/playability pressure shows technically correct semantics are awkward or uninteresting,
- host-engine limitations materially distort the intended invariants.

The roadmap is doing its job when these events cause it to change.