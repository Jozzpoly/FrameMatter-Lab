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

# Recently closed work

## M-CAP — standalone mechanics expansion: **FULL PASS / CLOSED**

The stateful graph-contraction capstone closed the intended partition↔contraction symmetry: two distinct external motorized/limited hinges converged onto one inelastic merged successor while retaining separate owner lineage, full constraint frames, joint identities and active state; the relation that became internal/self-edge retired.

The mechanics-only expansion is deliberately stopped here. Longer chains, loops, breakable links and mechanism catalogues are not the next research direction. They return only when an integrated/playable consumer creates a concrete information need.

Evidence: `docs/evidence/stateful-graph-contraction-capstone.md`.

## I0A — in-place static/dynamic control: **FULL PASS / CONTROL CLOSED**

One `ConstructBody` / RID survived dynamic → `FREEZE_MODE_STATIC` → frozen live edit → dynamic → second static freeze while preserving pose, arbitrary orientation, Matter/lineage authority and derived-state coherence in the bounded probe.

Important host truth: velocity properties remained visible throughout freeze and immediately after unfreeze, but the first subsequent solver step zeroed linear/angular velocity. Therefore in-place freeze is a useful low-churn control, **not** an implicit pause/resume contract and not automatically the final provider strategy.

Evidence: `docs/evidence/i0a-freeze-unfreeze-semantics.md`.

## I0B / I1 baseline — logical Space + real provider replacement: **FULL PASS / INTEGRATED BASELINE CLOSED**

One persistent logical `LocalMatterSpace` survived:

`MatterRepresentation → ConstructBody → MatterRepresentation`

while preserving one authoritative Matter + lineage pair, exactly one live provider, world-space continuity, dynamic motion/rotation, live edits, arbitrary-orientation freeze-to-static and post-freeze editing.

The concrete provider IDs/classes changed; the logical Space ID did not. This is the first integrated evidence for **logical Space ≠ current engine provider**.

Important timing refinement: a provider installed at `SceneTree.physics_frame` can participate in the upcoming PhysicsServer step even though its `RigidBody3D` node will not expose that solver transform until the next `PhysicsServer3D.sync()`. Same-step PhysicsServer truth and scene-node visibility are distinct observation layers.

Evidence: `docs/evidence/i0b-provider-replacement-lifecycle.md`.

**STOP applied:** do not add another same-shaped provider replacement probe merely because I0B passed.

---

# Active campaign — independent interactive consumer

Only this section is ordered. Everything below it is a decision frontier or later integrated campaign, not an automatic queue.

## LAB — make the shared lifecycle path visible and interactive

**Re-rank decision:** LAB now has higher information value than immediately stacking actor-transition complexity on top of a runtime path that has only one automated integrated consumer.

**Question:** can the exact same `LocalMatterSpace` lifecycle/mutation path be exercised by an interactive visual workbench and remain understandable to a human observer?

**Why now:**

- I0B established the automated integrated baseline.
- A second independent consumer can move the lifecycle path toward reusable-substrate evidence.
- Interactive inspection can expose authority/timing/visibility mistakes that scripted assertions hide.
- It gives early ergonomics/product pressure without prematurely chasing the full gameplay slice.

**Required behavior:**

- start with one visible static local Space,
- visible controls for static→dynamic activation and dynamic→static freeze/replacement,
- visible controls for at least one Matter remove/create/material edit through `LocalMatterSpace.mutate_cell`,
- dynamic provider actually moves/rotates after activation,
- freeze preserves the current arbitrary pose,
- edits work both while dynamic and after returning static,
- debug presentation shows at minimum:
  - persistent logical Space identity,
  - current provider kind,
  - current provider instance ID,
  - occupied Matter count,
  - a small lineage/mutation indicator,
  - whether a provider transition is pending,
- visual/debug state must read from the shared runtime path, not duplicate hidden test truth.

**Interaction goal:** low ceremony. Keyboard/buttons are sufficient; no polished UX, inventory, character controller or game rules are required.

**Non-goals:**

- the long-term walk/dig/build/ride gameplay slice,
- polished world art/UI,
- actor provider handoff,
- scalable collision,
- mechanisms,
- canonical-world extraction,
- save/load.

**PASS is not purely CI:** automated parse/smoke checks can protect the lab, but this campaign ultimately needs an Owner-visible run/screenshot/manual interaction verdict before it can claim reusable-substrate or usability evidence.

**STOP / decision:** once the LAB demonstrably uses the same runtime path, pause and re-rank. Do not automatically turn it into a game prototype.

---

# Next integrated campaigns — provisional order after LAB

These remain candidates until LAB evidence is reviewed.

## I2 — actor continuity through provider transition

**Question:** can actor support refer to a logical frame relation while the concrete support provider changes static↔dynamic↔static?

**Required evidence:**

- no one-frame reacquisition slip,
- explicit support mapping/authority transfer,
- no teleport,
- grounded state preserved where geometrically valid,
- support velocity changes coherently as motion begins/ends,
- solver-state vs synchronized-node-state timing is handled explicitly,
- no return of uncontrolled kinematic actor→rigid-body impulse semantics.

**Non-goal:** production volumetric controller.

## I3 — topology mutation through the shared integrated path

**Question:** can a moving Space split through the same reusable lifecycle path instead of manually recreating successor logic inside a giant probe?

**Required reuse:**

- retained/destroyed/created Matter identity handling,
- compact local-coordinate mapping,
- physical-state/velocity-field inheritance,
- defended lifecycle timing,
- actor support succession if I2 has already earned reuse,
- at most one deliberately chosen mechanical relation if it increases information value.

**PASS condition:** the new test is primarily an adversarial client of shared runtime execution rather than the place where topology behavior is implemented.

## Re-audit gate

After the LAB and before/after substantial I2/I3 work, re-rank all frontiers. Do not assume the written sequence remains optimal if interactive evidence reveals a more fundamental risk.

---

# Decision frontiers

These are **not ordered commitments**. Each has an entry trigger.

## R — scalable representation

**Known pressure:** box-per-cell collision is already rejected as a scalable dynamic representation.

**Entry trigger:** integrated lifecycle is coherent enough that update granularity and real consumer pressure can be measured rather than guessed.

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

**Entry trigger:** local-Space lifecycle is coherent and a real world consumer needs transfer to/from a canonical lattice.

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

After sufficient integrated lifecycle + representation + actor evidence, schedule a deliberately small Owner-facing gameplay slice:

> walk → dig/place → activate/freeze a local Space → ride/build on it → use one simple mechanism → inspect/debug consequences.

Its purpose is **not** content production. It asks whether system composition produces the emergent freedom, feedback and comprehensibility that justify the long-term direction.

The current LAB is deliberately earlier and narrower: a research workbench that keeps this north star visible without pretending the substrate is ready for the slice.

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
- PhysicsServer truth and synchronized scene-node state are conflated in a way that breaks handoff/debug semantics,
- integrated consumer requires repeated test-local orchestration that should have become shared runtime,
- scalable representation needs contradict lifecycle assumptions,
- Owner/playability pressure shows technically correct semantics are awkward or uninteresting,
- host-engine limitations materially distort the intended invariants.

The roadmap is doing its job when these events cause it to change.