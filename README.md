# FrameMatter Lab

Research lab for an editable systemic-world substrate where local Matter can become static or dynamic physical space **without logical identity collapsing into engine representation**.

This repository is intentionally **not** a Minecraft clone, vehicle game, portal demo or final engine architecture. It exists to produce falsifiable evidence for the smallest substrate that could later support those directions.

## North star

> Build an editable systemic-world substrate where local Matter, moving/static frames, actors and mechanisms can compose without logical identity being defined by render/physics objects.

Recurring product pressure:

> walk → dig/build → activate/release a local Space → ride it → edit it while moving → use a simple mechanism → understand/debug the consequences.

For Owner-facing work, the visible/interactive surface is part of the research instrument. The Owner does not experience thousands of lines of substrate code; the Owner experiences the pixels, controls and causal feedback produced by that substrate.

## Current live state

The canonical branch scene is P1:

`res://p1/main.tscn`

P1 contains materially stronger mechanical foundations than P0/P0.5, including:

- logical Matter authority independent of mesh/collision/body representation,
- logical `LocalMatterSpace` identity independent of static/dynamic provider identity,
- exact merged-cuboid collision as the current provider default,
- query-based volumetric actor collision without implicit infinite-force rigid push authority,
- actor support through provider replacement,
- editable moving Matter,
- bounded expandable local storage with explicit coordinate-frame rebase,
- actor/camera relation maintenance through storage rebase,
- live one→many topology succession,
- explicit actor/camera succession to topology successors,
- zero-launch static→dynamic release,
- finite solver-owned central/torque impulses,
- dynamic→static freeze at the current physical pose.

The strongest mechanical gate composes one causal loop:

> grounded actor → release → finite motion → ride → moving edit/build → storage rebase → mapped placement → destructive split → actor/camera succession → freeze successor.

Representative strict mechanical errors remain around the micrometre scale in the tested cases.

**Those results are retained. They do not make the first P1 Owner candidate acceptable.**

## First P1 Owner candidate — FAIL

The first packaged P1 candidate passed mechanical/integration/delivery automation but failed the actual Owner-facing measurement surface severely.

The Owner recording showed, among other problems:

- large Matter surfaces collapsing toward black,
- directly lit faces becoming flat pale/white planes,
- almost no visible cell/edit granularity,
- through-wall engineering target wire,
- destructive close camera framing,
- telemetry-dominated default UI,
- weak visible STATIC/DYNAMIC and topology semantics.

A Windows D3D12 Forward+ rendered-evidence lane reproduced the critical black-surface failure in CI.

A bounded G2-A experiment changed only the Environment ambient source from SKY to COLOR and zeroed sky contribution. On the same deterministic Windows rendered scene this changed approximately:

- near-black coverage `52.96% → 0.00%`,
- luminance below `0.08`: `54.70% → 1.74%`,
- mean luminance `0.142 → 0.366`.

That strongly attributes the most severe black collapse to a project-side rendering configuration failure rather than a demonstrated Godot rendering limitation. It does **not** establish overall visual quality.

Evidence:

- `docs/evidence/p1-owner-interaction-failure.md`,
- `docs/evidence/p1-g1-rendered-baseline.md`,
- `docs/evidence/p1-quality-system-postmortem.md`.

## Q0 Owner-centered quality system — DEFENDED FOR PROMOTION BOUNDARIES

Q0 was introduced because the previous process could accumulate extensive green hidden-system evidence while the Owner-visible instrument remained obviously broken.

Q0 now has bounded process evidence and adversarial self-tests. It is **not** a guarantee of product quality; it is a defended promotion-boundary system intended to make unearned Owner delivery structurally harder.

The model separates six truth planes:

1. Owner-intent truth,
2. substrate truth,
3. composition truth,
4. observable truth,
5. interaction truth,
6. promotion/delivery truth.

A PASS on one plane never implies another.

The current promotion model is:

> OPEN development → FROZEN runtime candidate → gate × scenario evidence on that exact runtime → independent read-only assurance → authorization → delivery of exactly that frozen runtime.

Key machinery:

- `docs/QUALITY-SYSTEM.md` — general Owner-centered quality model,
- `quality/contracts/p1-owner-facing-recovery.v3.json` — sealed/versioned campaign contract,
- `quality/p1-owner-readiness.json` — current 2D gate/scenario evidence state,
- `quality/assurance/p1-independent-review.json` — independent-assurance state,
- `ci/verify_owner_readiness.py` — contract/readiness and frozen-runtime enforcement,
- `ci/verify_independent_assurance.py` — independent-review enforcement,
- `.github/workflows/owner-readiness.yml` — adversarial CI validation,
- `.github/workflows/deliver-owner-test.yml` — manual delivery that materializes only the approved frozen runtime.

The guard is adversarially tested against scope weakening, sealed-contract mutation, proxy evidence drift, moving candidates, stale runtime evidence, missing representative scenarios and missing independent assurance. Negative controls prove the current blocked campaign cannot pass delivery enforcement.

Evidence: `docs/evidence/p1-q0-owner-quality-system.md`.

## Active campaign — P1 Owner-facing recovery / G2 lighting and form

**Current P1 remains `OPEN` and `BLOCKED`. Do not treat it as Owner-ready and do not merge it to `main`.**

Feature/substrate expansion remains frozen while the visible research instrument is repaired.

Current execution sequence:

- G1 — real rendered evidence harness: **PASS as instrumentation**,
- G2 — lighting/environment/form readability: **ACTIVE**,
- G3 — Matter visual language and cell scale,
- G4 — camera as an experiment instrument,
- G5 — interaction hierarchy,
- G6 — world/motion/topology causality,
- G7 — evidence-based Godot/host viability checkpoint,
- G8 — freeze one runtime candidate, re-earn the full gate × scenario matrix, run adversarial rehearsal and independent assurance, then perform final readiness audit.

The current Windows acceptance-relevant rendered path is Godot 4.7.2 Forward+ / D3D12. Linux Compatibility remains a secondary regression lane.

G2 currently compares canonical lighting against test-only `balanced_fill` and `balanced_fill_ssao` challengers. A lighting azimuth-stress capture is used before any variant may be promoted.

The visual acceptance contract is `docs/p1-visual-acceptance-contract.md`.

No new Owner package is allowed before G8 and frozen-runtime readiness authorization.

## Important distinctions

- **Matter ≠ mesh/collision/body identity.**
- **Space identity ≠ current provider identity.**
- **Space ≠ simulation domain.**
- **storage coordinates ≠ Matter identity.**
- **contact ≠ mechanical constraint ≠ rigid bind.**
- **freeze/provider transition ≠ canonical-world reintegration ≠ bake/resample.**
- **dirty/invalidation region ≠ final collider/render/world partition.**
- **support transport ≠ gravity/orientation/adhesion semantics.**
- **finite Space impulse controls ≠ vehicle framework.**
- **mechanical integrated PASS ≠ observable PASS ≠ interaction PASS ≠ Owner readiness.**

## Important open technical boundaries

P1 still does not claim:

- arbitrary pitch/roll locomotion or frame-local gravity/adhesion,
- final character feel,
- final actor↔construct reaction-force model,
- scalable/infinite world storage,
- final chunk/streaming architecture,
- persistence/save-load identity,
- canonical-world extraction/reintegration,
- curved/planetary Matter,
- production vehicle framework,
- final production art/UI.

These open boundaries do not excuse broken presentation of the systems already being tested.

## Stack

- Godot 4.7.2
- built-in Jolt Physics
- GDScript for rapid falsification
- standard float precision + local coordinates
- integer-grid logical Matter
- exact merged-cuboid collision as current provider default

## Documentation

- **`ROADMAP.md`** — adaptive decision map and campaign boundaries.
- **`docs/research-state.md`** — defended / provisional / falsified / open technical truth.
- **`docs/QUALITY-SYSTEM.md`** — campaign quality and promotion model.
- **`docs/INDEPENDENT-ASSURANCE.md`** — final read-only red-team contract.
- **`docs/p1-owner-facing-recovery-campaign.md`** — P1 recovery execution plan.
- **`docs/p1-visual-acceptance-contract.md`** — Owner-visible acceptance dimensions.
- **`docs/evidence/`** — durable evidence, including failures and postmortems.
- **`quality/`** — machine-readable campaign contract, readiness and assurance state.

## Working rule

Stabilize **intent and defended invariants**, not prematurely class names, APIs, partition schemes or implementation mechanisms.

Explore aggressively. Promote conservatively.

When evidence and roadmap disagree, evidence wins. When hidden correctness and Owner-visible reality disagree, the candidate is not ready.