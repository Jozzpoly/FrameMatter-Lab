# FrameMatter Lab — adaptive roadmap

Status: **living research decision map**. This is not a fixed release plan, feature checklist or promise of implementation order.

## North star

Build an editable systemic-world substrate where local Matter, moving/static local Spaces, actors and mechanisms can compose without logical identity collapsing into engine representation.

Recurring product pressure:

> walk → dig/build → activate/release a local Space → ride it → edit it while moving → use a simple mechanism → understand/debug the consequences.

For Owner-facing work, the rendered/interactive surface is part of the research instrument. Hidden mechanical correctness does not compensate for pixels or controls that make the system unreadable.

## Decision rules

- Evidence outranks sequence.
- PASS does not automatically unlock the next thematically similar feature.
- Every major campaign ends in re-audit before scope expands.
- Stop conditions are first-class.
- No sunk-cost protection.
- Stable intent/invariants matter more than class names, APIs or current host mechanisms.
- Rank work by **information value × leverage × risk reduction / cost**.
- Interactive pressure must recur so the project does not become a detached technology catalogue.
- **Owner-visible presentation is first-class evidence whenever the Owner is asked to judge the system.**
- An acceptance property may not silently become a nonclaim merely because it lacks an automated test.
- Owner attention is a scarce validation resource, not the first-line QA surface.
- Promotion requires direct evidence for the original acceptance contract on the exact candidate commit.

## Quality truth planes

Owner-facing campaigns now track six independent truth planes:

1. Owner-intent truth,
2. substrate truth,
3. composition truth,
4. observable truth,
5. interaction truth,
6. promotion/delivery truth.

A PASS on one plane never silently implies another.

The general contract is `docs/QUALITY-SYSTEM.md`.

## Evidence maturity

1. Hypothesis
2. Bounded evidence
3. Integrated evidence
4. Reusable-substrate evidence
5. Scale-pressure / scale evidence
6. Playability/product evidence

A PASS at one level never silently implies the next.

---

# Defended historical campaigns

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

P0.5 improved some measurement cues but still exposed that the consumer itself was inadequate. It remains historical evidence, not executable authority.

---

# P1 status — mechanically defended, Owner-facing reopened

P1 replaced the old consumer aggressively while preserving defended substrate semantics.

Mechanically defended P1 composition includes:

- real collision-bearing world reference,
- query-based volumetric actor,
- SpringArm camera infrastructure,
- multi-Space registry,
- live topology consequence,
- bounded expandable local storage with explicit coordinate-frame rebase,
- actor/camera relation maintenance through storage rebase,
- fresh lineage issuance below UI,
- zero-launch static→dynamic release,
- finite solver-owned impulse/torque motion,
- dynamic→static freeze at current pose.

The integrated gate still defends one causal chain:

> actor grounded → release → finite motion → ride → moving edit/build → non-zero storage-frame rebase → mapped placement → destructive split → actor/camera succession → freeze successor.

Representative mechanical metrics remain:

- storage shift `(3,0,0)`,
- rebase linear/angular state error `0 / 0`,
- topology handoff error about `1.25e-6 m`,
- final actor/support anchor error about `0.98e-6 m`.

Canonical startup and the strict runtime suite pass on Linux and Windows.

**This does not close P1.** The first P1 Owner candidate failed the actual Owner-facing acceptance target severely. The rendered result hid or distorted the systems the Owner was meant to judge.

Evidence:

- `docs/evidence/p1-integrated-owner-candidate.md` — retained mechanical/canonical/package evidence,
- `docs/evidence/p1-owner-interaction-failure.md` — Owner-facing failure,
- `docs/evidence/p1-g1-rendered-baseline.md` — rendered parity baseline,
- `docs/evidence/p1-quality-system-postmortem.md` — process root cause,
- `docs/p1-professional-rebuild-audit.md` — original P1 acceptance intent.

---

# Active campaign — Q0 quality-system hardening

**Q0 is the current stop condition. Visual recovery G2–G8 remains planned but is not allowed to advance materially until Q0 passes.**

The reason is systemic: the previous process could accumulate extensive green technical evidence while the Owner-facing instrument remained obviously broken.

Q0 exists to make that class of failure structurally harder to repeat.

## Q0 requirements

1. versioned Campaign Contract exists,
2. machine-readable Readiness Manifest exists,
3. contract/readiness consistency validator is green in CI,
4. Owner delivery is hard-blocked unless readiness is authorized for the exact commit,
5. every required gate must be re-verified on that exact commit before delivery,
6. live project truth reflects the six-plane quality model,
7. previous process failure is preserved in a durable postmortem,
8. automatic Owner artifact production remains disabled while status is BLOCKED.

Current machinery:

- `docs/QUALITY-SYSTEM.md`,
- `quality/p1-campaign-contract.json`,
- `quality/p1-owner-readiness.json`,
- `ci/verify_owner_readiness.py`,
- `.github/workflows/owner-readiness.yml`,
- manual delivery workflow guarded by exact-commit readiness.

## Q0 promotion question

> **Can the project itself prevent us from calling a candidate ready merely because hidden systems and CI look impressive?**

Until the answer is defended, do not resume ordinary feature or presentation expansion.

---

# Queued campaign after Q0 — P1 Owner-facing recovery

Status carried into Q0:

- **strict P1 mechanical gates: PASS**
- **integrated causal-loop gate: PASS**
- **canonical startup Linux/Windows: PASS**
- **first P1 Owner interaction: FAIL**
- **first visual/readability measurement surface: FAIL**
- **G1 Windows D3D12 rendered parity lane: PASS AS INSTRUMENTATION**
- **G2-A ambient-source hypothesis: PASS AS BOUNDED FINDING**
- **Owner readiness: BLOCKED**
- **automatic Owner delivery: DISABLED**
- **P1 merge to `main`: BLOCKED**

## Recovery question

> **Can Godot + FrameMatter present the already-important systems through a professional, physically legible visual instrument, so the Owner can judge the actual system rather than reconstruct it mentally from debug pixels?**

The Owner's observable product during this campaign is the screen:

> world reference → Matter form + cell scale → state → interaction target → actor/Space/world relationship → causal motion/topology consequence.

Debug telemetry is subordinate to that hierarchy.

The authoritative detailed plan is `docs/p1-owner-facing-recovery-campaign.md` and the acceptance gate is `docs/p1-visual-acceptance-contract.md`.

## Recovery sequence after Q0

### G0 — failed baseline / mechanical freeze

**PASS / HISTORICAL BASELINE**

The failed Owner candidate and mechanical evidence are preserved. No speculative feature tranche is permitted during recovery.

### G1 — rendered evidence harness

**PASS AS INSTRUMENTATION / VISUAL BASELINE FAIL**

Windows D3D12 Forward+ reproduces the Owner-class black-surface failure and is the current acceptance-relevant parity lane. Linux Compatibility remains a secondary backend guardrail.

### G2 — lighting/environment truth

**PARTIAL BOUNDED EVIDENCE; FURTHER PROMOTION PAUSED BY Q0**

G2-A changed only Environment ambient source SKY→COLOR plus zero sky contribution. On the same deterministic Windows rendered initial state it changed approximately:

- near-black `52.96% → 0.00%`,
- luminance `< 0.08`: `54.70% → 1.74%`,
- mean luminance `0.142 → 0.366`.

This strongly attributes the catastrophic black collapse to project configuration. It does not establish final lighting/readability PASS.

Further balanced-fill/SSAO challengers may exist as unpromoted data but are not a reason to bypass Q0.

### G3 — Matter visual language

**PENDING**

Challenge at least two bounded approaches to cell-scale readability before promotion. Preserve broad form at distance and edit granularity up close. Restore meaningful static/dynamic/focus/successor semantics without noisy debug-wire aesthetics.

### G4 — camera as experiment instrument

**PENDING**

Acceptance is useful rendered composition, not possession of `SpringArm3D`. Actor, relevant Space and world reference must remain understandable across movement, close obstacles, falls, rebase, split and freeze.

### G5 — interaction visual hierarchy

**PENDING**

Replace the default through-wall debug wire cue with depth-correct, operation-specific interaction language. REMOVE / PLACE / EXPAND must be obvious before clicking without covering geometry.

### G6 — world/motion/topology causality

**PENDING**

Reference environment, state cues and successor presentation must make release, translation, rotation, split and freeze readable from pixels rather than HUD telemetry.

### G7 — renderer / host viability checkpoint

**PENDING**

Only after competent G2–G6 work may Godot itself be judged. If the simple FrameMatter scene still requires disproportionate work or hits material host limitations, build a small equivalent web reference and compare the same geometry/camera target honestly.

### G8 — adversarial visual preflight / Owner package

**BLOCKED**

Before another Owner executable:

- full mechanical suite green,
- rendered evidence green on the parity path,
- V-A through V-G have current evidence and no material FAIL,
- every Campaign Contract gate is PASS,
- every gate is re-verified on the exact candidate commit,
- autonomous rehearsal recording inspected frame-by-frame,
- result clearly superior to P0.5 and failed P1 as a research instrument,
- zero open blockers,
- Owner attention explicitly authorized,
- exact commit bound in Readiness Manifest.

Only then may manual delivery produce another Owner candidate.

---

# Hard stop while Q0 / recovery is active

Not permitted:

- speculative mechanics catalogue,
- chunk/world architecture,
- persistence framework,
- vehicle system,
- arbitrary pitch/roll adhesion hacks,
- packaging a new Owner candidate because mechanical CI is green,
- treating visual work as optional polish,
- weakening an original acceptance property because it is difficult to test,
- promoting evidence from an older commit as if it certified a changed candidate.

Permitted during Q0:

- quality/evidence infrastructure,
- contract/readiness enforcement,
- live-truth synchronization,
- process postmortem and falsification of the new quality system.

Permitted after Q0 during G2–G8:

- rendered-evidence infrastructure,
- lighting/material/camera/world/UI changes required by recovery,
- mechanical fixes only when visual work exposes a real underlying invariant failure,
- evidence/documentation/provenance work that keeps the campaign honest.

---

# Decision routing after visual recovery

## If Godot reaches the intended readable baseline with ordinary engine facilities

Continue to use Godot for the present research layer. Let the next Owner interaction choose the next semantic/system pressure.

## If competent G2–G6 still show disproportionate renderer/tooling friction

Enter G7 host comparison. Build the smallest equivalent web reference and compare evidence rather than preference.

## If edit/rebuild latency becomes visible once presentation is fixed

Reopen representation research using R2A as measured evidence.

Constraint:

> obtain locality without assuming dirty regions must become collider/render/world chunks.

## If actor orientation / slopes / steps / tilted Spaces dominate

Enter the oriented/volumetric actor frontier deliberately. Explicitly decide world gravity vs frame-local gravity vs adhesion semantics before implementation.

## If actor↔construct reaction forces dominate

Design a finite-force exchange challenger. Do not restore accidental kinematic push authority.

## If lifecycle / storage / topology continuity fails under the improved visual instrument

Reproduce the exact invariant and reopen that layer. Do not hide substrate failure in camera/presentation glue.

## If the visible loop is coherent but uninteresting

Treat that as strong evidence. Revisit product pressure and interaction semantics before infrastructure expansion.

---

# Open frontiers

## A — arbitrary orientation / gravity / actor semantics

Trigger: direct use needs pitch/roll support, slopes/steps, frame-local gravity, adhesion or richer locomotion.

## F — finite actor↔construct force exchange

Trigger: the Owner wants physical pushing, recoil, impacts or meaningful mass interaction between actor and constructs.

## R2 — update-local representation follow-up

Trigger: measured direct-use latency materially harms editing.

R2A is evidence for locality, not for fixed chunk-shaped final collision partitions.

## W — canonical world extraction / reintegration

Trigger: a real world consumer needs transfer between canonical lattice and independent local Space.

Keep exact lattice-compatible reintegration separate from incompatible bake/resample with explicit error/provenance policy.

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

“Final game art” is a non-goal. **Professional Owner-readable presentation is not.**

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
- Owner-facing PASS requires the observable instrument to expose, not conceal, the defended system.
- promotion requires evidence for every contracted quality plane on the exact candidate commit.

When a future mechanism conflicts with one of these, require stronger evidence before weakening the invariant.
