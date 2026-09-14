# R2P — post-aggregation representation/update profile

Status: **PASS as a measurement/re-ranking campaign**.

R2P was run after R1 promoted exact merged-cuboid collision to the normal provider path. Its purpose was not to make anything faster. It decomposed the new cost structure so the next optimization, if any, would be selected from evidence rather than inherited from the pre-R1 bottleneck.

Final gated context:

- commit: `dddd42a4c870c0256409363924e0498dcd2deb91`,
- GitHub Actions run: `#187` / `34905221108`,
- fast invariant validation: **PASS**,
- full research validation including R0 control, R1 A/B, R1 lifecycle integration and R2P: **PASS**.

## Question

After merged cuboids remove the dominant one-shape-per-cell materialization cost, what now dominates full provider rebuilds, live edits and topology split work at the tested local-Space sizes?

## Setup

R2P retained the controlled R0/R1 patterns and extents:

- extents: `6³`, `10³`, `14³`,
- patterns: dense, shell, sparse skeleton,
- three timing samples per case, reported as medians,
- active collision mode: `MERGED_CUBOIDS`.

The probe timed separately:

- `CellVolume.count_solid()`,
- full `CellMesher.build_mesh`,
- full merged-cuboid compilation,
- Matter COM scan,
- installation of already-compiled collision shapes into static/dynamic bodies,
- full static/dynamic provider construction,
- retained-Matter material-only mutation through the current shared path,
- real occupancy-removal mutation through the same path,
- disconnected split preflight and commit.

## Largest controlled cases

### Dense `14³`

- scanned / occupied: `2744 / 2744`,
- merged shapes before edit: `1`,
- shapes after one interior occupancy deletion: `6`,
- visual vertices: `7056`,
- occupied-count scan: `0.071 ms`,
- full visual mesh generation: `19.010 ms`,
- full merged-cuboid compilation: `7.462 ms`,
- Matter COM scan: `2.671 ms`,
- precompiled static-shape installation: `0.033 ms`,
- precompiled dynamic-shape installation: `0.007 ms`,
- full static provider: `26.864 ms`,
- full dynamic provider: `29.604 ms`,
- material-only edit through current full path: `29.354 ms`,
- occupancy deletion through current full path: `29.415 ms`.

For the dynamic provider, the independently timed mesh + collision compiler + COM account for roughly `98%` of the measured provider-build time. Engine shape installation is negligible at the promoted merged shape count.

### Shell `14³`

- occupied: `1016`,
- merged shapes: `6`, after surface deletion: `9`,
- visual vertices: `12240`,
- mesh: `11.095 ms`,
- collision compiler: `4.378 ms`,
- COM: `2.528 ms`,
- dynamic shape installation: `0.042 ms`,
- dynamic provider: `18.402 ms`,
- material-only edit: `18.014 ms`,
- occupancy edit: `17.996 ms`.

### Sparse skeleton `14³`

- occupied: `40`,
- merged shapes: `5`,
- visual vertices: `972`,
- mesh: `2.975 ms`,
- collision compiler: `2.535 ms`,
- COM: `2.420 ms`,
- dynamic shape installation: `0.034 ms`,
- dynamic provider: `8.418 ms`,
- material-only edit: `8.017 ms`,
- occupancy edit: `8.073 ms`.

The sparse case is especially useful: even with only `40` occupied cells, the full-volume mesh/compiler/COM passes over a `14³` extent remain visible. The post-R1 cost is therefore increasingly tied to scanned extent and repeated whole-volume derivation, not only occupied-cell count.

## Material-only vs occupancy-changing mutation

This is a material finding.

Under current semantics:

- a non-empty material-ID change retains Matter lineage,
- `CellMesher` currently treats every non-empty material identically for geometry,
- `CellCollisionBoxer` currently treats every non-empty material identically for collision coverage,
- equal-density mass semantics do not currently derive different mass from material ID.

R2P verified that the merged collision compilation is unchanged by the tested material-only edit.

Despite that, `LocalMatterSpace.mutate_cell` currently routes material-only and occupancy-changing mutations through the same complete provider rebuild. Their measured costs are correspondingly almost identical at every tested size.

This establishes **current execution waste**, not a permanent rule that material changes can never affect render/physics state. Future physical/visual material semantics may require selective updates. The current result only says the present full geometry/collision/mass rebuild is not justified by the semantics currently implemented.

## Split re-profile

R1 aggregation also changed topology-split economics substantially.

Same-run comparison at `14³` disconnected dense slabs:

- R0 / per-cell reference:
  - occupied: `2548`,
  - successor shapes: `2548`,
  - preflight: `26.658 ms`,
  - commit: `778.888 ms`,
  - synchronous work: `805.546 ms`.
- R2P / merged default:
  - occupied: `2548`,
  - successor shapes: `2`,
  - preflight: `26.220 ms`,
  - commit: `77.586 ms`,
  - synchronous work: `103.806 ms`.

The total split path improved about `7.8×`, while preflight stayed essentially unchanged and commit improved about `10×`.

This is an important ranking shift: topology scanning/compaction that was previously hidden behind provider shape construction is now a meaningful fraction of the remaining split cost.

## What R2P establishes

Within the tested range:

1. **engine collision-shape installation is no longer the dominant provider/update cost** after R1;
2. full visual mesh generation is the largest single measured component in dense/shell cases;
3. full merged-cuboid compilation remains material because the compiler still scans the whole volume even when the final shape count is tiny;
4. full Matter COM calculation becomes visible once shape materialization is cheap;
5. current live-edit cost is dominated by repeated whole-volume derivation, not by installing a handful of merged shapes;
6. material-only edits currently pay essentially the same full-path cost as true occupancy edits despite leaving the tested collision compilation unchanged;
7. merged collision dramatically reduces split-commit cost, exposing topology preflight/compaction/provider reconstruction as the next split-side pressures.

## Decision consequence

A narrow **collision-only dirty rebuild is not the strongest next challenger**. It would attack only one part of the new cost structure while the visual mesh is larger and COM/full-volume work remains.

The stronger next hypothesis is **bounded derived-region update locality**:

- keep one logical `CellVolume` / Matter identity authority,
- partition only disposable derived representation work into bounded regions,
- rebuild collision only for the edited region,
- rebuild visual geometry for the edited region plus any face-neighbor regions whose exposed surfaces can change,
- keep the dynamic object one physical frame/body rather than turning representation regions into logical Spaces,
- measure the tradeoff between update locality and extra cuboids/mesh surfaces/nodes before integrating it into runtime.

This should begin as an A/B challenger, not as a new world/chunk architecture.

## Why not immediately implement a chunk system

A fixed derived region is a candidate compiler/update boundary, not gameplay identity and not yet a streaming/world partition.

R2P does not establish:

- an optimal region size,
- that regions should be persistent objects,
- that world chunks and provider regions should be the same thing,
- that one region should own one rigid body,
- that the global greedy cuboid compiler must be replaced,
- that current `14³` performance is already insufficient for every intended consumer.

The next challenger must quantify locality benefit, shape/surface inflation and boundary correctness before any of those decisions are made.

## Secondary debt: material-only fast path

Skipping irrelevant full rebuild work for current material-only edits is a high-confidence, low-complexity opportunity, but it should remain semantically scoped:

- current collision geometry does not change,
- current visual geometry topology does not change,
- current equal-density mass properties do not change,
- future material rendering/physics may require their own selective invalidation.

Do not turn this local execution cleanup into a general material architecture before a real material consumer exists.

## Non-claims

R2P is not production-scale evidence and does not establish acceptable frame-time budgets. It does not benchmark rendering draw-call cost, sustained physics cost of region-inflated compounds, streaming, asynchronous work, large-world coordinates or save/load persistence.