# FrameMatter Lab — adaptive roadmap

Status: **living research decision map**. This is not a fixed release plan, feature checklist or promise of implementation order.

## North star

Build an editable systemic-world substrate where local Matter, moving/static local Spaces, actors and mechanisms can compose without logical identity collapsing into engine representation.

Recurring product pressure:

> walk → dig/build → activate/release a local Space → ride it → edit it while moving → use a simple mechanism → understand/debug the consequences.

## Decision rules

- Evidence outranks sequence.
- PASS does not automatically unlock the next thematically similar feature.
- Every major campaign ends in re-audit before scope expands.
- Stop conditions are first-class.
- No sunk-cost protection.
- Stable intent/invariants matter more than class names, APIs or current host mechanisms.
- Rank work by **information value × leverage × risk reduction / cost**.
- Interactive pressure must recur so the project does not become a detached technology catalogue.

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

## I0B → LAB → I2 → I3 lifecycle line — **CLOSED FOR CURRENT SCOPE**

Defended semantics include logical-Space/provider separation, actor support through provider replacement and shared one→many topology succession with explicit mapping.

## M-CAP standalone mechanics expansion — **FULL PASS / CLOSED**

Bounded stateful partition↔contraction symmetry is sufficiently exercised. More mechanics complexity waits for real consumer pressure.

## R0 representation baseline — **PASS / CLOSED**

Established one-shape-per-occupied-cell collision materialization as the first dominant tested scale bottleneck.

## R1 exact merged-cuboid collision — **FULL PASS / PROMOTED CURRENT DEFAULT**

Removed the demonstrated dense/shell shape-materialization bottleneck while preserving logical Matter/lifecycle/topology semantics. `PER_CELL` remains only a reference control.

## R2P post-aggregation profile — **PASS / CLOSED**

After R1, whole-volume visual mesh / cuboid / COM derivation dominates representative rebuild cost rather than installation of the already-small collision shape set.

## R2A derived-region locality — **PASS AS CHALLENGER / NOT PROMOTED**

Established that bounded dirty derivation can reduce edit work dramatically, while naive fixed regions can badly inflate final collider partitions.

Durable distinction:

> **dirty/invalidation partition ≠ final physical representation partition**

## P0 first embodied consumer — **AUTOMATED PASS / OWNER RUN COMPLETE**

The bounded translation+yaw loop worked mechanically, but first Owner interaction exposed severe measurement contamination from actor/camera/targeting/presentation limitations.

## P0.5 interaction shell — **AUTOMATED + DELIVERY PASS / OWNER RUN COMPLETE**

Improved camera/readability enough to reveal that the old consumer itself—not merely presentation—was inadequate. P0/P0.5 remain historical evidence, not executable authority.

## P1 destructive professional rebuild — **AUTOMATED INTEGRATED + CANONICAL + DELIVERY PASS / CLOSED AT OWNER BOUNDARY**

P1 replaced the old consumer aggressively while preserving defended substrate semantics.

The current canonical P1 scene now composes:

- real collision-bearing world reference,
- query-based volumetric actor,
- SpringArm camera with actor + Space context,
- multi-Space registry,
- live topology consequence,
- bounded expandable local storage with explicit coordinate-frame rebase,
- actor/camera relation maintenance through storage rebase,
- fresh lineage issuance below UI,
- zero-launch static→dynamic release,
- finite solver-owned impulse/torque motion,
- dynamic→static freeze at current pose.

The integrated gate exercises one chain:

> actor grounded → release → finite motion → ride → moving edit/build → non-zero storage-frame rebase → mapped placement → destructive split → actor/camera succession → freeze successor.

Representative metrics:

- storage shift `(3,0,0)`,
- rebase linear/angular state error `0 / 0`,
- topology handoff error about `1.25e-6 m`,
- final actor/support anchor error about `0.98e-6 m`.

Canonical startup passes on Linux and Windows. Owner-candidate delivery run `#7` / `34964102720` passed the complete strict P1 chain and exported Windows + Web candidates.

Evidence: `docs/evidence/p1-integrated-owner-candidate.md`.

---

# Active campaign — P1 Owner interaction

Status:

- **strict P1 bounded gates: PASS**
- **integrated causal-loop gate: PASS**
- **canonical startup Linux: PASS**
- **canonical startup Windows: PASS**
- **historical fast-invariant ratchet under zero-engine-error wrapper: PASS**
- **Windows/Web delivery: PASS**
- **direct P1 Owner interaction: PENDING**

## Campaign question

> **Once the major P0/P0.5 consumer defects are removed, which remaining limitation actually dominates direct use?**

P1 has earned the right to be tested. It has not earned the right to be called good.

## Owner-facing loop to pressure

The Owner does not need to follow a rigid script. The candidate should support chaotic experimentation around:

> walk → remove/place → release the same logical Space → give it finite motion → ride/edit while moving → build beyond prior storage bounds → cut it into real successor Spaces → freeze a successor → keep experimenting.

Useful observations include:

- movement/camera quality and whether context is easy to retain,
- targeting clarity and whether REMOVE/PLACE feels predictable,
- whether storage-edge building feels continuous rather than like an invisible implementation bound,
- whether zero-launch release and finite pulses make motion causally legible,
- whether riding/editing a moving Space is understandable,
- whether topology cuts visibly become believable independent successors,
- whether freeze reads as the current Space/state becoming static rather than a reset,
- perceived edit latency under natural repeated use,
- what the Owner naturally wants to do next but cannot.

## Hard stop

**Do not autonomously add another feature tranche before this Owner interaction.**

Permitted before/around the test:

- fix a packaging/startup blocker,
- fix a reproduced regression that prevents the intended P1 loop,
- clarify misleading test instructions or telemetry,
- preserve evidence/provenance.

Not permitted by roadmap inertia:

- speculative mechanics catalogue,
- chunk/world architecture,
- persistence framework,
- arbitrary pitch/roll adhesion hack,
- polish campaign without Owner evidence,
- vehicle system.

---

# Decision routing after P1 Owner interaction

## If interaction / camera / targeting dominates

Improve only the highest-leverage obstacle. Keep P1 as a research surface, not an open-ended UI/graphics project.

## If edit/rebuild latency dominates

Reopen representation research using R2A as measured evidence.

Constraint:

> obtain locality without assuming dirty regions must become collider/render/world chunks.

## If actor orientation / slopes / steps / tilted Spaces dominate

Enter the oriented/volumetric actor frontier deliberately. Explicitly decide world gravity vs frame-local gravity vs adhesion semantics before implementation.

## If actor↔construct reaction forces dominate

Design a finite-force exchange challenger. Do not restore accidental kinematic push authority.

## If lifecycle / storage / topology continuity fails

Reproduce the exact invariant and reopen that layer. Do not hide substrate failure in camera/recovery/UI glue.

## If the loop is mechanically coherent but uninteresting

Treat that as strong evidence. Revisit product pressure and interaction semantics before infrastructure expansion.

## If the loop naturally asks for a mechanism/world interaction

Let the specific Owner desire select the next bounded integrated subsystem. Existing mechanics evidence is available as donor knowledge; do not resume the old standalone catalogue automatically.

---

# Open frontiers

## A — arbitrary orientation / gravity / actor semantics

Trigger: direct use needs pitch/roll support, slopes/steps, frame-local gravity, adhesion or richer locomotion.

Known pressure: earlier pitch/roll work retained support but accumulated large local drift because support transport and world-down validation semantics disagreed. P1 does not silently resolve that semantic question.

## F — finite actor↔construct force exchange

Trigger: the Owner wants physical pushing, recoil, impacts or meaningful mass interaction between actor and constructs.

P1 currently avoids infinite-force authority; it does not yet provide a final two-way force model.

## R2 — update-local representation follow-up

Trigger: measured direct-use latency materially harms editing.

R2A is evidence for locality, not for fixed chunk-shaped final collision partitions.

## W — canonical world extraction / reintegration

Trigger: a real world consumer needs transfer between canonical lattice and independent local Space.

Keep separate:

- exact lattice-compatible reintegration,
- incompatible bake/resample with explicit error/provenance policy.

## P — persistence / durable logical identity

Trigger: Matter/Space identity must survive save/load/process boundaries.

## M — richer mechanics

Trigger: current Owner/world interaction asks for a relation not covered by existing bounded mechanics evidence.

## S — streaming / world scale

Trigger: a concrete world consumer exceeds one manageable local active region.

Do not assume logical storage, dirty regions, render partitions, collider partitions and streaming chunks are one ontology.

## D — multiple simulation domains / migration

Trigger: one solver domain no longer conveniently/accurately hosts required interactions or coordinate scales.

## N — nested/moving frames

Trigger: a concrete consumer needs dependent Spaces rather than constraint-coupled peers.

## L — spatial links / portals

Trigger: frame/query semantics are stable enough to test cross-Space routing. Start static/query-only before moving endpoints or partial-crossing physics.

## C — curved / Planet Matter providers

Trigger: planar/local Matter assumptions materially block a real planetary experiment.

---

# Persistent non-goals until pressure changes

- final game art,
- inventory/crafting,
- networking,
- save/load framework,
- final chunk/streaming architecture,
- arbitrary planetary Matter,
- final vehicle framework,
- forcing arbitrary rotated local Matter into a canonical voxel lattice,
- hiding orientation semantics with ad-hoc adhesion.

---

# Core invariants to protect while future mechanisms change

- Matter identity is independent of engine representation.
- logical Space identity is independent of current provider identity.
- Space is not defined as simulation domain.
- contact, constraint and rigid binding are distinct relations.
- storage coordinate maintenance is not logical Matter mutation.
- topology succession uses explicit mappings rather than arbitrary identity inheritance.
- freeze/provider replacement is not canonical-world reintegration.
- dirty/update locality is not automatically final physical/world partitioning.
- bounded/integrated PASS is not scale/playability/product PASS.

When a future mechanism conflicts with one of these, require stronger evidence before weakening the invariant.
