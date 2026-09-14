# R2A — derived-region locality challenger

Status: **PASS as a bounded challenger; NOT promoted to runtime representation**.

R2A followed the R2P finding that post-R1 live-edit cost is dominated by repeated whole-volume derivation rather than engine collision-shape installation. It tested whether disposable derived representation work can be spatially localized without changing logical Matter/Space identity, and what representation inflation that locality would cost.

Final gated context:

- commit: `3d426f19aafa441833b9b02c170b7d5cf7da656c`,
- GitHub Actions run: `#191` / `34906432308`,
- Godot: `4.7.2` / built-in Jolt,
- fast invariant validation: **PASS**,
- full research validation through all historical probes, R0, R1, R2P and R2A: **PASS**.

## Question

Can one logical `CellVolume` retain one Matter/Space identity while mesh and collision derivation are partitioned into bounded regions, so a one-cell occupancy edit recompiles only a small neighborhood rather than the full extent?

Secondary question: if yes, how much collider/surface partition inflation does fixed regionalization introduce compared with the promoted global merged-cuboid compiler?

## Setup

R2A is test-local. It does **not** alter `MatterRepresentation`, `ConstructBody`, `LocalMatterSpace` or current provider defaults.

Controlled cases:

- extents: `14³`, `24³`, `32³`,
- patterns: dense, shell, sparse skeleton,
- derived region edges: `4` and `8`,
- timing samples: 3 medians,
- collision inside each region: exact `MERGED_CUBOIDS`,
- visual faces: generated per region while querying neighbor occupancy from the same authoritative global `CellVolume`,
- one occupied target chosen to maximize region-boundary pressure,
- dirty collision recompiles only the target region,
- dirty mesh recompiles the target region plus distinct face-neighbor regions whose exposed faces can change.

The challenger verifies both before and after the occupancy deletion:

- exact collision coverage against authoritative Matter,
- covered-cell cardinality equals occupied Matter count,
- regional exposed mesh vertex count equals global `CellMesher` output,
- deterministic full regional compilation,
- bounded dirty-region neighborhood.

## Correctness result

All tested cases preserved:

- **zero collision coverage error**,
- exact occupied-cell coverage cardinality,
- exact exposed mesh vertex count relative to the global mesher,
- correctness after a real occupancy-changing edit,
- one-cell mesh invalidation bounded to at most own + three distinct face-neighbor regions in the chosen boundary cases.

This is evidence that derived update boundaries do not need to become logical Matter/Space boundaries.

## Locality result

The bounded dirty compile is substantially cheaper than recompiling every derived region, especially as extent grows.

### `14³`

Region edge `4`:

- dense: `14.98×` locality speedup,
- shell: `16.63×`,
- skeleton: `16.45×`.

Region edge `8`:

- dense: `2.26×`,
- shell: `3.06×`,
- skeleton: `2.75×`.

### `24³`

Region edge `4`:

- dense: `74.15×`,
- shell: `65.12×`,
- skeleton: `87.47×`.

Region edge `8`:

- dense: `9.53×`,
- shell: `12.01×`,
- skeleton: `17.80×`.

### `32³`

Region edge `4`:

- dense: `174.01×`,
- shell: `137.60×`,
- skeleton: `202.49×`.

Region edge `8`:

- dense: `22.32×`,
- shell: `25.65×`,
- skeleton: `30.38×`.

Representative `32³` absolute dirty timings:

- dense / edge 4: full regional compile `~485.8 ms`, dirty `~2.79 ms`,
- shell / edge 4: full `~203.4 ms`, dirty `~1.48 ms`,
- skeleton / edge 4: full `~127.2 ms`, dirty `~0.63 ms`,
- dense / edge 8: full `~487.3 ms`, dirty `~21.8 ms`.

These timings are a challenger comparison, not production frame-budget claims.

## Representation-inflation result

The locality benefit is real, but naive fixed regionalization fragments the collision partition that R1 deliberately compressed.

### Dense

Global merged collision is one cuboid before the edit.

- `14³`, edge 4: `1 → 64` regional shapes (`64×` inflation),
- `14³`, edge 8: `1 → 8` (`8×`),
- `24³`, edge 4: `1 → 216` (`216×`),
- `24³`, edge 8: `1 → 27` (`27×`),
- `32³`, edge 4: `1 → 512` (`512×`),
- `32³`, edge 8: `1 → 64` (`64×`).

After one interior cell deletion, the global compiler produces 6 cuboids. The regional edge-4 `32³` representation produces 514 (`~85.7×` inflation relative to the edited global representation).

### Shell

At `32³`:

- global: `6` shapes,
- edge 4: `384` (`64×` inflation),
- edge 8: `96` (`16×`).

### Sparse skeleton

Inflation is much smaller because the global shape set is already sparse:

- `32³` global: `5`,
- edge 4: `24` (`4.8×`),
- edge 8: `12` (`2.4×`).

## What R2A establishes

Within the tested scope:

1. **derived update locality is viable without changing logical Matter or Space identity**;
2. visual boundary correctness can be preserved by reading neighbor occupancy from the common authoritative volume;
3. a one-cell occupancy edit can reduce derivation work by one to two orders of magnitude at larger tested extents;
4. the best locality case is not automatically the best final representation;
5. naively making fixed update regions equal final collision-compilation regions can reintroduce hundreds of collider partitions into dense/shell cases where R1 reduced global collision to a handful of shapes;
6. therefore **invalidation/update partition and final physical representation partition should not be assumed identical**.

## Decision consequence

Do **not** promote the R2A test-local fixed-region representation into runtime merely because the timing PASS is large.

R2A rejects the simplistic next move:

> “R2P found whole-volume work, therefore make every provider a fixed chunk grid and keep each chunk's collider partition.”

That mechanism buys update locality by partially undoing R1's strongest representation win.

A future representation challenger, if demanded by a real consumer, should preserve the semantic lesson rather than the exact R2A mechanism. Candidate directions include decoupled dirty/invalidation regions from global or cross-region collision representation, independently optimized visual/physical partitions, or another bounded incremental compiler. None is selected by R2A.

## Consumer-pressure implication

At this point representation research has answered two important questions:

- R1 removed the demonstrated first scale bottleneck,
- R2P/R2A identified and demonstrated a viable locality direction for the next edit-scale pressure, while also exposing its naive tradeoff.

That is enough evidence to justify returning to a small interactive consumer before spending more architecture on R2B/R2C. The consumer can reveal whether current local-Space edit latency is actually the next limiting experience and what representation semantics it needs.

## Non-claims

R2A does not establish:

- production-scale chunking or streaming,
- an optimal region edge,
- persistent region objects,
- one rigid body per region,
- draw-call/rendering cost of many regional meshes,
- sustained Jolt cost of region-inflated compounds,
- asynchronous compilation,
- large-world coordinates,
- material-boundary semantics,
- save/load identity,
- that all future edits can be localized to the same neighborhood,
- that the current global cuboid compiler is the final physical representation.

The durable result is the locality/partition distinction, not a new canonical chunk architecture.