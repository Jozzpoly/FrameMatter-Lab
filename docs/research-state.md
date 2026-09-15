# FrameMatter Lab — current research state

Status: **live truth synthesis**. Durable measurements and failures live in `docs/evidence/`; decision order lives in `ROADMAP.md`; promotion policy lives in `docs/QUALITY-SYSTEM.md` and `quality/`.

## Evidence language

- **DEFENDED (bounded)** — strong evidence inside an explicitly limited probe.
- **DEFENDED (integrated)** — behavior survived composition through shared runtime and neighboring systems.
- **DEFENDED (reusable-substrate, narrow)** — materially different consumers exercise the same shared path.
- **DEFENDED (scale-pressure)** — controlled measurements identify/remove a bottleneck in the tested range without implying production scale.
- **PROVISIONAL** — useful current mechanism; implementation shape is not established strongly enough to freeze.
- **FALSIFIED / REJECTED** — shortcut or claim contradicted by evidence in the tested scope.
- **OPEN** — material unanswered question/debt.

For Owner-facing campaigns, evidence is also separated into six independent truth planes:

1. Owner-intent truth,
2. substrate truth,
3. composition truth,
4. observable truth,
5. interaction truth,
6. promotion/delivery truth.

A PASS on one plane never silently implies another.

---

# LIVE TRUTH

The canonical branch runtime is P1:

`application/run/main_scene = res://p1/main.tscn`

P1 is **mechanically much stronger than P0/P0.5 but not Owner-ready**.

The first P1 Owner candidate passed substantial mechanical/integration/package automation and then failed the actual Owner-facing measurement surface. The Owner recording showed catastrophic black Matter surfaces, flat white faces, weak cell granularity, debug interaction cues, destructive camera framing and telemetry-dominated presentation.

A Windows D3D12 Forward+ rendered lane reproduced the critical black-surface failure inside CI. A bounded G2-A experiment changed only the Environment ambient source SKY→COLOR and zeroed sky contribution; on the deterministic initial Windows scene it changed approximately:

- near-black coverage `52.96% → 0.00%`,
- luminance below `0.08`: `54.70% → 1.74%`,
- mean luminance `0.142 → 0.366`.

This strongly attributes the catastrophic black collapse to project configuration rather than a demonstrated Godot rendering limitation. It does **not** establish overall visual quality.

## Current stop condition — Q0

The active campaign is **Q0 quality-system hardening**, not another Owner package and not ordinary feature expansion.

Q0 exists because the previous process could accumulate extensive green hidden-system evidence while the Owner-visible instrument remained obviously broken.

Current quality machinery:

- `docs/QUALITY-SYSTEM.md` — general Owner-centered quality model,
- `quality/p1-campaign-contract.json` — versioned Owner goal, protected invariants, representative scenarios and required quality gates,
- `quality/p1-owner-readiness.json` — current evidence state,
- `ci/verify_owner_readiness.py` — contract/readiness validation and delivery enforcement,
- `.github/workflows/owner-readiness.yml` — CI validation,
- manual Owner delivery hard-blocked by exact-commit readiness.

Current readiness status is **BLOCKED**.

No new Owner candidate may be produced until every required contract gate is PASS, every gate has durable evidence, every gate is re-verified on the exact candidate commit, no blockers remain and Owner attention is explicitly authorized.

Evidence:

- `docs/evidence/p1-owner-interaction-failure.md`,
- `docs/evidence/p1-g1-rendered-baseline.md`,
- `docs/evidence/p1-quality-system-postmortem.md`,
- `docs/QUALITY-SYSTEM.md`.

---

# DEFENDED — SUBSTRATE / COMPOSITION

## Matter authority — bounded/integrated

- Logical `CellVolume` is authoritative; mesh/collision/body state is derived and reconstructible.
- Matter coordinates are local and independent of world transform.
- Moving a provider does not mutate logical Matter.
- Matter identity is not coordinate identity and not physics-body/shape identity.
- Retained Matter lineage survives tested provider replacement, storage rebase and topology succession.
- Destroy/recreate at the same address creates fresh lineage rather than resurrecting prior Matter identity.
- `LocalMatterSpace.mutate_cell()` remains the shared authority path for ordinary Matter mutation.

## Logical Space / provider separation — reusable-substrate, narrow

Defended semantic separation:

> **logical Space ≠ current engine provider**

Within tested scope:

- one logical `LocalMatterSpace` owns one authoritative Matter + lineage pair,
- static and dynamic providers are replaceable derived hosts,
- static→dynamic release and dynamic→static freeze replace concrete provider identity without redefining logical Space identity,
- live Matter mutation composes with moving providers,
- actor/camera consumers can follow current providers while retaining logical-Space relations,
- topology split is different: source Space retires and explicit successor mapping is required.

Class names, signals and tree layout remain implementation details rather than canonical architecture.

## P1 integrated causal loop — integrated automated evidence

Current integrated gate composes:

> grounded actor → zero-launch release → finite impulse/torque → ride moving Space → edit/build while moving → out-of-storage placement → storage-frame rebase → mapped placement → destructive cut → one→many topology succession → actor/camera handoff → freeze actor-owned successor.

Representative strict metrics:

- forced storage-frame shift `(3, 0, 0)`,
- linear/angular state error after rebase `0 / 0`,
- source→successor actor handoff error about `1.25e-6 m`,
- two live successor Spaces,
- moving ride anchor error about `1.35e-6 m`,
- final actor/support anchor error after successor freeze about `0.98e-6 m`.

This is meaningful composition evidence. It is not observable/interaction/Owner-readiness evidence.

## Volumetric actor — bounded + integrated in world-up translation/yaw scope

P1 uses direct-space capsule queries rather than P0's single support ray.

Defended in tested scope:

- Matter floors support the actor,
- vertical walls block it,
- low ceilings block jumping,
- actor rides/walks relative to translating/yawing dynamic Space,
- query movement does not inject implicit rigid-body linear/angular velocity,
- support remains a logical-Space relation through provider replacement,
- explicit topology mapping preserves support across succession,
- explicit coordinate maintenance preserves support across storage rebases.

Arbitrary pitch/roll, local gravity and adhesion remain open.

## Storage-frame maintenance — bounded + integrated

Current dense local storage can expand via an explicit frame-maintenance transaction.

Defended:

- rebase is coordinate maintenance, not logical Matter edit,
- retained Matter world positions remain continuous within numerical tolerance,
- retained lineage survives,
- provider identity can remain stable,
- dynamic solver state is preserved in tested cases,
- actor support-local coordinates are remapped,
- camera context is refreshed,
- mapped outside-storage placement can complete with fresh lineage.

This is not a final chunk/streaming/persistence architecture.

## One→many topology succession — integrated

When destructive editing disconnects dynamic Matter:

- source Space/provider authority retires,
- no fragment arbitrarily inherits source Space identity,
- fresh successor Spaces receive compact Matter + lineage storage,
- retained Matter world placement and rigid velocity-field continuity remain tight,
- actor support maps explicitly to an appropriate successor,
- camera/focus can follow the actor-owned successor,
- detached successors own independent dynamic providers.

## Finite Space motion semantics — bounded + integrated

Defended:

- release itself has zero hidden launch,
- explicit finite central impulse produces solver-owned translation,
- mass response is inverse-mass in the bounded challenger,
- explicit torque impulse produces solver-owned angular motion,
- Owner controls issue finite pulses rather than persistent velocity assignment.

This is not a vehicle framework.

## Exact merged-cuboid collision — scale-pressure + integrated

R1 remains provider collision default.

Defended in tested range:

- exact occupied collision coverage,
- collider topology/count remains derived rather than Matter identity,
- dense `14³`: `2744 → 1`,
- shell `14³`: `1016 → 6`,
- lifecycle/topology/actor composition remains coherent with merged collision active.

`PER_CELL` remains a historical/reference control.

## Update locality pressure — scale-pressure

R2P established that post-R1 whole-volume mesh/cuboid/COM derivation dominates representative rebuild cost.

R2A established:

> **dirty/invalidation partition ≠ final physical representation partition**

Bounded locality can reduce edit work dramatically while naive fixed regions can badly inflate collider partitions. No final chunk/locality architecture is promoted.

## Lifecycle timing / observation phases — integrated

Transaction truth, solver truth and synchronized scene-node visibility are related but not universally simultaneous.

Tests/debuggers must state which phase they sample. Old-provider phase advance must not be mislabeled as replacement teleportation.

## Mechanics / binding semantics — bounded

Still defended:

- contact, mechanical constraint and rigid bind are distinct,
- constrained frames can remain logically distinct,
- Matter lineage can own mechanical anchors through split/partition/contraction,
- destroyed anchor-owner Matter retires the relation,
- same-address recreation does not resurrect it,
- constraint graphs can partition on split and contract on merge,
- tested pin/hinge/motor/limit state survives bounded succession cases.

Standalone mechanics expansion remains closed until integrated pressure asks for it.

---

# OBSERVABLE / INTERACTION TRUTH

## Rendered parity harness — DEFENDED AS INSTRUMENTATION

G1 established real rendered capture of canonical P1 states:

- initial static,
- released dynamic,
- dynamic motion,
- storage-rebased/build state,
- split successors,
- frozen successor.

Windows D3D12 Forward+ is the current acceptance-relevant parity lane. Linux Compatibility remains a secondary renderer guardrail because it fails differently and can detect backend-specific regressions.

G1 instrumentation PASS does not mean current visuals pass.

## Lighting/environment — PARTIAL BOUNDED EVIDENCE

G2-A strongly supports that the catastrophic Windows black-collapse came from incorrect ambient-source configuration.

Overall form/depth readability is still **PENDING**. Correcting one catastrophic defect exposed remaining flat/weak presentation rather than completing the visual system.

## Matter granularity — OPEN / CURRENTLY INADEQUATE

Current P1 does not adequately communicate one-cell editing scale without debug targeting cues.

At least two bounded visual-language approaches must be challenged before promotion.

## System state semantics — OPEN / CURRENTLY INADEQUATE

STATIC/DYNAMIC, focus/edit state and topology-successor independence are not yet defended as readable from pixels without engineering telemetry.

## Camera composition — OPEN / CURRENTLY INADEQUATE

SpringArm and logical context tracking are mechanically useful but do not establish useful framing.

Camera acceptance now requires rendered stress evidence across close obstacles, Space edges, moving Space, split, freeze, falls and recovery.

## Interaction hierarchy — OPEN / CURRENTLY INADEQUATE

The default through-wall wire target is classified as engineering debug presentation.

REMOVE / PLACE / EXPAND intent and exact target must become depth-correct and visually unambiguous without obscuring Matter.

## World/motion/topology causality — OPEN

Reference world, release, translation, yaw, split and freeze are not yet defended as causally readable without HUD text.

## UI hierarchy — OPEN / CURRENT DEFAULT FAILS

The failed P1 wide telemetry/control panel is not acceptable as default Owner presentation. Deep telemetry may remain available but must be secondary.

## Cross-layer visible composition — OPEN

A major lesson from failed P1 is that individually sensible systems can compose into a disastrous image. Visible acceptance therefore requires the real Matter + camera + interaction + runtime state together, not isolated fixtures.

---

# PROMOTION / DELIVERY TRUTH

The first P1 delivery pipeline proved packageability, not Owner readiness.

The historical Windows candidate remains useful negative evidence. It is not a current recommendation.

Current Owner delivery is manual-only and hard-blocked by `ci/verify_owner_readiness.py`.

Promotion now requires:

- versioned campaign contract,
- all required gates PASS,
- durable evidence for every gate,
- exact-commit re-verification for every gate,
- zero open blockers,
- explicit Owner-attention authorization,
- exact approved commit matching the packaged commit.

This is the current promotion authority; old wording such as "Owner candidate" in historical evidence does not override it.

---

# PROVISIONAL IMPLEMENTATION SHAPES

## `LocalMatterSpace`

Semantics are better defended than current API/class/signal/tree layout. Do not turn it into a universal world manager merely because P1 passes mechanically.

## `SpaceQueryCharacter`

Credible experimental consumer, not final game controller. Step/slope feel, arbitrary orientation, force exchange and richer locomotion remain open.

## Dense expandable storage

Useful bounded mechanism for testing coordinate maintenance and removing invisible local bounds. Not persistence, streaming or final sparse world storage.

## Merged-cuboid compiler

Semantic R1 result is stronger than the current greedy deterministic algorithm. Global optimality is not claimed.

## Update-local representation mechanism

R2A supports locality under real pressure. No dirty-region/mesh/collider/world partition is canonical.

## Static/dynamic host strategy

Provider replacement remains a useful pressure on identity separation, not a final universal representation strategy.

## Physical material model

Current occupied cells use a simple equal-mass-per-cell model. `material_id` is not yet a complete physical material contract.

---

# FALSIFIED / REJECTED IN TESTED SCOPE

Technical shortcuts rejected by evidence:

- Matter truth as scene cubes/nodes,
- physics body/shape IDs as durable identity,
- coordinate identity as Matter identity,
- scene parenting as the physical model for standing on moving constructs,
- contact alone as logical support membership,
- query-only reacquisition as lossless topology handoff,
- one physics domain per construct as default architecture,
- enormous construct mass as a fix for kinematic actor→rigid interaction,
- one collider per occupied cell as scalable final representation,
- collider count as occupied-cell truth,
- automatic same-address anchor resurrection,
- arbitrary rotated Space→canonical voxel lattice as trivially lossless reintegration,
- `RigidBody3D.freeze` as velocity pause/resume guarantee,
- arbitrary source-Space identity inheritance by one split fragment,
- naive fixed update regions as automatically superior final collision partition,
- current world-up actor as arbitrary pitch/roll solution,
- hard-coded perpetual launch as meaning of Space activation,
- process exit 0 or PASS marker as sufficient evidence in presence of engine errors.

Quality/process shortcuts now explicitly rejected:

- mechanical integrated PASS as Owner-readiness evidence,
- scene-node existence as proof of Owner-visible quality,
- export success as proof of useful artifact,
- moving an original acceptance property into "nonclaim" because it is hard to test,
- using the Owner as first reviewer of obvious visible defects,
- promoting evidence from an older commit as if it certifies a changed candidate,
- allowing manual delivery action to substitute for readiness evidence.

---

# OPEN — CURRENT PRIORITIES

## Q0 — quality-system hardening

Current priority before ordinary visual recovery continues.

Must establish and validate:

- Campaign Contract ↔ Readiness Manifest consistency,
- CI validation of evidence references and gate definitions,
- hard delivery block while readiness is BLOCKED,
- exact-commit gate binding,
- synchronized README / ROADMAP / research-state truth,
- durable process postmortem,
- no automatic Owner artifact production.

## P1 Owner-facing recovery after Q0

Sequence remains:

- G2 lighting/environment truth,
- G3 Matter visual language,
- G4 camera composition,
- G5 interaction hierarchy,
- G6 world/motion/topology causality,
- G7 evidence-based Godot/host checkpoint,
- G8 adversarial rehearsal and final readiness audit.

## Arbitrary orientation / gravity semantics

World gravity vs frame-local gravity vs adhesion, walkable-surface semantics on pitch/roll supports and actor orientation remain unresolved.

## Finite actor↔construct force exchange

P1 avoids accidental push authority but does not establish a final meaningful two-way force model.

## Canonical-world extraction / reintegration

Open until a real consumer requires transfer between canonical lattice and independent local Space. Exact lattice-compatible reintegration and incompatible bake/resample remain distinct operations.

## Persistence / durable identity

Open until Matter/Space identity must survive save/load/process boundaries.

## World scale / streaming

Open until a concrete consumer exceeds one manageable active region. Do not predeclare storage regions, dirty regions, render regions, collider partitions and streaming chunks to be one ontology.

## Deferred until pressure

- richer/breakable/looped mechanics,
- multiple simulation domains/migration,
- nested frames,
- portals/spatial links,
- curved/Planet Matter providers,
- JV-like vehicle integration,
- networking/multiplayer.

---

# IMPORTANT SEMANTIC DISTINCTIONS

- **Matter identity ≠ storage coordinate ≠ provider/collider identity.**
- **logical Space ≠ current provider ≠ simulation domain.**
- **contact ≠ support relation ≠ mechanical constraint ≠ rigid bind.**
- **storage rebase ≠ logical Matter mutation.**
- **provider freeze/replacement ≠ topology split ≠ canonical reintegration ≠ incompatible bake/resample.**
- **dirty/invalidation region ≠ final collider/render/world partition.**
- **support-frame transport ≠ gravity/orientation/adhesion semantics.**
- **finite impulse controls ≠ vehicle framework.**
- **mechanical truth ≠ observable truth ≠ interaction truth ≠ promotion truth.**

When a future mechanism or campaign conflicts with a defended distinction, require stronger evidence before weakening it.
