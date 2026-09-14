# Roadmap readiness audit

Status: preparation material for the next long-term planning/documentation pass. This is **not** the roadmap itself and does not supersede evidence.

## Purpose

The next planning pass must avoid two opposite failure modes:

1. freezing today's research discoveries into a prematurely rigid architecture/roadmap,
2. keeping everything so provisional that the project has no coherent direction, stop conditions, or cumulative execution model.

The roadmap should therefore behave as a **living research decision map**: stable in intent and evidence standards, flexible in ordering, implementation mechanisms and even intermediate architecture.

## Live foundation at audit time

The latest full ratchet on `8721091` is green: fast-invariant validation and the 41-step research-validation pipeline both pass.

The repository has accumulated strong bounded evidence around:

- authoritative logical Matter independent from mesh/physics representation,
- static and dynamic derived representations,
- live geometry/mass-property mutation,
- explicit support-frame actor semantics,
- split/merge/rebase continuity,
- Matter lineage continuity across address/body replacement,
- explicit compatible versus inelastic rigid binding,
- mechanical constraints between independent frames,
- constraint ownership/succession/retirement,
- graph partition/contraction,
- full oriented hinge-frame succession,
- motor/limit state surviving topology replacement,
- multiple independently stateful constraints partitioning in one split.

This remains **bounded research evidence**, not a production architecture claim.

## Critical structural findings

### 1. Evidence has outrun reusable runtime

The core runtime remains intentionally small while large probes repeatedly reconstruct topology transactions, successor mapping, lineage transfer, physical-state calculation, actor handoff, joint rebasing and lifecycle timing.

This was the correct way to discover semantics. Continuing it indefinitely would increasingly validate probe-local orchestration rather than a shared substrate.

Future tests should increasingly become **adversarial clients of reusable execution paths**, not the primary place where the behavior itself is implemented.

### 2. Representation lifecycle and world-lattice transfer are different problems

Do not collapse these into `World -> Construct -> World`.

- **representation transition/freeze:** same local Matter lattice, same Matter identity, different host representation; arbitrary world orientation can remain lossless,
- **lossless lattice reintegration:** local Space is absorbed into a canonical lattice only under a lattice-compatible transform,
- **bake/resample:** incompatible pose is converted to another lattice and may change cell count/topology/identity.

The first integrated campaign must test representation lifecycle, not arbitrary bake-to-world-grid.

### 3. Stable frame identity and frame-state authority must be separated

The current tests pass engine-node transforms manually between predecessor/successor bodies. A real lifecycle needs something persistent to which dependents can refer, but blindly storing a second continuously updated transform in a logical object would create dual authority with the solver.

Working hypothesis:

- logical **frame identity** persists,
- exactly one current representation/provider owns live pose/velocity authority,
- a representation-changing transaction atomically transfers that authority,
- dependents refer to a logical frame/ownership relation and use the current provider for kinematics.

This is a conceptual boundary to test, not a prescribed class design.

### 4. Matter and lineage currently lack one mutation authority

`CellVolume` and `MatterLineageMap` are independent structures. Research probes manually keep them coherent.

An interactive integrated consumer must not rely on every caller remembering that:

- retained Matter keeps lineage,
- destroyed Matter retires lineage,
- created Matter receives fresh lineage.

The next logical carrier/mutation path should make inconsistent updates difficult or impossible while still keeping Matter storage simple.

Do not infer from this that lineage must become a field on every cell. The consumer should determine the smallest coherent authority boundary.

### 5. Actor support still points directly at engine representation

`FrameProbeCharacter` stores a `support_body: Node3D` and computes support kinematics from `RigidBody3D/ConstructBody`.

That is valid bounded G3 evidence but will not by itself survive a general representation lifecycle. I2 should test a separation between:

- logical support/frame relation,
- current engine representation/provider used for actual transform/velocity queries.

Do not turn this immediately into a universal frame service.

### 6. Pre-physics commit timing is a defended invariant, but not a shared runtime facility

The round-trip/timing campaigns demonstrated that destroy/recreate after a solver step accumulates a one-step phase loss, while pre-step replacement preserves continuity.

Today this timing discipline lives in test orchestration.

The integrated consumer will probably justify one very small shared mechanism: a **pre-physics commit boundary/queue** for representation-changing operations. This should remain narrower than a universal transaction framework until more consumers require more.

### 7. Static <-> dynamic has at least two valid host strategies and should be A/B tested

Godot 4.7 supports freezing a `RigidBody3D` (`FREEZE_MODE_STATIC`/`KINEMATIC`) and PhysicsServer body modes can change without changing the logical body RID.

Therefore I1 should not presuppose destroy/recreate as the only implementation.

Recommended experimental separation:

- **control A — in-place mode lifecycle:** one body changes dynamic <-> frozen/static behavior,
- **challenger B — representation replacement:** distinct static and dynamic host representations are exchanged while logical Space/frame identity survives.

A establishes baseline gameplay/lifecycle behavior with minimal host churn. B tests the stronger architecture thesis that logical Space is independent of representation/body identity.

The product may eventually use either or both depending on scale and representation needs.

### 8. Box-per-cell is truth/reference, not scalable representation

This is already established. Do not spend the next phase optimizing it before the integrated consumer reveals required update granularity.

After the first lifecycle consumer, run a dedicated representation campaign comparing candidates such as merged primitives/regions and convex approximations against the simple truth implementation.

Visual meshing and physical collision partitioning should remain separate optimization questions unless evidence shows they want the same boundaries.

### 9. The interactive lab has fallen far behind the evidence

`lab/main.gd` is still essentially the original G0 static Matter demo.

The next campaign should restore the lab as a first-class **integrated consumer and visual/debugging surface**, not just add more headless scripts.

A good rule for the next phase:

> important reusable runtime behavior should be exercised by both an automated adversarial test and the interactive lab through the same execution path.

This reduces the risk of having a green test architecture that is awkward or opaque when actually used.

### 10. CI itself must remain adaptive

The current workflow explicitly lists every test in YAML. This was simple and reliable during rapid discovery, but indefinite append-only growth will create a second form of architectural fossilization.

Future CI governance should distinguish:

- **canonical invariant tests** — permanently defend still-relevant behavior,
- **current campaign tests** — active falsification work,
- **historical evidence probes** — preserved in the repository but not necessarily run on every push once a more general test supersedes them.

A small test manifest/runner may eventually replace the duplicated hard-coded fast/full YAML lists. Do not build it solely for elegance; do it when campaign turnover starts making workflow maintenance materially costly.

Old green probes should be allowed to retire from the live ratchet **without deleting their evidence** when they are superseded. A dynamic architecture cannot be protected by an infinitely additive CI suite that silently makes every old implementation detail permanent.

## Evidence maturity should be explicit

Future documentation/roadmap items should distinguish at least these levels:

1. **Hypothesis** — useful idea, no direct evidence,
2. **Bounded evidence** — isolated probe passes a precisely scoped question,
3. **Integrated evidence** — behavior composes with a real consumer and neighboring systems,
4. **Reusable-substrate evidence** — multiple independent consumers use the same execution path,
5. **Scale evidence** — performance/stability survives representative size/load,
6. **Playability/product evidence** — the mechanism creates the intended experience in Owner testing.

A PASS at one level must never be silently promoted to the next.

This maturity ladder is more useful than version numbers for avoiding claims such as "topology is solved" when what actually exists is strong bounded evidence.

## Missing long-term pressure test: playability

The research map cannot remain purely technological forever.

After sufficient integrated lifecycle + representation evidence, the project needs a deliberately small **playable substrate slice** that forces several systems to compose under real Owner interaction, for example:

- walk in a minimal world,
- dig/place/edit Matter,
- activate/freeze a local Space,
- ride/build on it,
- use one simple mechanical relation,
- observe/debug what happened.

The purpose would not be content production. It would answer whether the substrate actually produces the systemic freedom and feedback expected from the long-term "Jozz's Minecraft" direction.

A technically elegant substrate that never receives this pressure test is a project risk.

## Roadmap design requirements

The next `ROADMAP.md` should **not** be a linear feature list or fixed sequence of quarters/releases.

It should have four layers.

### A. Stable north star

Short, rarely changed intent. Example shape:

> Build an editable systemic-world substrate where local Matter, moving frames, actors and mechanisms can compose without logical identity being collapsed into engine representation.

The north star can evolve, but it should not change because one implementation strategy failed.

### B. Active campaign

Only a small number of ordered, falsifiable gates currently being executed.

Every gate should state:

- question/hypothesis,
- why it has high information value now,
- evidence required,
- explicit non-goals,
- PASS/FAIL/STOP condition,
- what decision it unlocks or invalidates.

A material FAIL may reorder the rest of the active campaign immediately.

### C. Decision frontiers

Unordered or lightly ranked future research fronts, each with an **entry trigger**, not a promised date.

Candidate frontiers after the current integration campaign include:

- scalable dynamic representation,
- volumetric actor/controller + finite force exchange,
- canonical-world extraction/reintegration,
- persistence/logical identity across save/load,
- richer mechanics when a real consumer needs them,
- streaming/world scale,
- multiple simulation domains/migration,
- nested frames,
- spatial links/portals,
- curved/Planet Matter providers,
- later JV-like vehicle integration/donation.

Their order must be re-evaluated after major evidence rather than predetermined now.

### D. Deferred pressure tests / donors

Long-term ideas that influence architecture review but are not requirements of the current campaign.

This is where portals, Planet Matter, Create/VAW/JV lessons and other ambitious directions can remain visible without becoming accidental scope commitments.

## Roadmap mutation rules

The roadmap itself should state how it is allowed to change.

Recommended rules:

- every major campaign ends with a re-audit before automatic expansion,
- a material failure may promote, demote, split or delete future roadmap items,
- no sunk-cost protection: a mechanism can be replaced even after many green tests if a stronger consumer falsifies it,
- future frontiers are not commitments until their entry trigger is satisfied,
- stop conditions matter as much as entry conditions,
- evidence history is preserved even when direction changes,
- architecture names/API/class layouts remain provisional until multiple consumers need them,
- roadmap order is optimized for **information value × leverage × risk reduction / cost**, not thematic neatness,
- small playable/interactive consumer pressure should recur periodically so the project does not become an isolated technology exercise.

## Documentation restructuring prepared for the next pass

Do not perform this mechanically until the long-term roadmap is planned, but the current document set is ready for a clearer split:

### `README.md`

Short front door only:

- project thesis,
- current live status,
- current active campaign,
- key bounded truths/falsifications,
- links to roadmap/research state/evidence.

Do not keep appending the full history of every probe to README.

### `ROADMAP.md`

Living adaptive decision map using the four-layer model above.

It should be concise enough to reread often and expected to change.

### `docs/research-state.md`

Detailed current truth:

- defended invariants,
- provisional mechanisms,
- falsified shortcuts,
- major open debts,
- evidence maturity labels,
- current architecture hypotheses.

This is the document that should answer "what do we currently believe?".

### `docs/evidence/`

Durable measurements and campaign records. Evidence remains even when the roadmap changes.

Existing mechanics/stateful evidence can migrate here without rewriting its conclusions.

### `docs/archive/`

Historical direction checkpoints such as `0.2` and `0.2b` after their useful live guidance has been incorporated into ROADMAP/research-state.

History remains available but cannot be mistaken for current instruction.

## Candidate next execution sequence before the full long-term roadmap pass

This is only an audit recommendation, not the final roadmap:

1. **M-CAP:** stateful graph contraction as the explicit stop condition of the current mechanics expansion.
2. Re-audit the M-CAP result; do not add another mechanics graph automatically.
3. **I0A:** same-body dynamic <-> frozen/static control experiment.
4. **I0B/I1:** smallest persistent logical Space/frame identity + true representation-replacement challenger.
5. Restore the interactive lab to use this same lifecycle path.
6. **I2:** actor support continuity through representation/provider transfer.
7. **I3:** one split through the shared integrated execution path, not test-local orchestration.
8. Re-audit and choose whether representation scalability or another frontier now has highest information value.

This sequence should itself remain revisable after every material result.

## Readiness verdict

The project is ready for a real long-term roadmap/documentation planning pass, but **not** for a fixed long-term implementation plan.

The next planning task should produce:

- a concise adaptive `ROADMAP.md`,
- a current `research-state.md`,
- a slimmed README,
- an evidence/archive structure,
- an explicit active campaign with stop/re-audit conditions,
- a ranked-but-fluid set of future decision frontiers,
- a documented policy for retiring/superseding CI probes as architecture evolves.

The architecture should be treated the same way as the roadmap: stable in defended invariants and intent, fluid in mechanisms, boundaries and implementation until stronger consumers force them to become concrete.
