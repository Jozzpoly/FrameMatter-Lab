# R0 — representation / scale baseline

Status: **PASS / scale-pressure baseline established**

Benchmark commit: `e28183b7b22e44d6b109c9d1467983a79ae91f7c`

CI authority: `Validate research harness` run `34892939474` — full workflow PASS, including the dedicated R0 research step after all prior invariant/evidence ratchets.

## Question

Where does the current deliberately simple reference representation begin to become expensive, and does cost track full volume extent, visual mesh complexity, occupied Matter/collision materialization, or topology connectivity work most strongly?

R0 deliberately measured the existing implementation without optimizing it.

## Setup

Extents: `6³`, `10³`, `14³`.

Occupancy patterns:

- **dense** — every cell occupied,
- **shell** — only boundary cells occupied; relatively high exposed-face/mesh complexity,
- **skeleton** — three connected orthogonal cell axes; very low occupancy while retaining the same bounding extent.

Each representation timing is the median of three samples.

Measured:

- full bounding-volume cells scanned,
- occupied cells,
- collision shape count,
- derived mesh vertex count,
- static-provider initialization,
- dynamic-provider initialization,
- one retained-Matter material mutation causing the current full derived rebuild,
- connected-component extraction,
- disconnected shared split preflight and transaction commit.

The reference collision path still creates one `BoxShape3D` / `CollisionShape3D` per occupied cell.

## Representation measurements

| Pattern | Extent | Scanned | Occupied / shapes | Mesh vertices | Static init | Dynamic init | One-cell full rebuild | Topology extract |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| dense | 6³ | 216 | 216 | 1,296 | 11.853 ms | 9.550 ms | 13.059 ms | 1.723 ms |
| shell | 6³ | 216 | 152 | 1,872 | 6.798 ms | 5.803 ms | 7.472 ms | 1.219 ms |
| skeleton | 6³ | 216 | 16 | 396 | 0.992 ms | 1.115 ms | 0.858 ms | 0.303 ms |
| dense | 10³ | 1,000 | 1,000 | 3,600 | 198.771 ms | 150.972 ms | 228.924 ms | 8.145 ms |
| shell | 10³ | 1,000 | 488 | 5,904 | 51.743 ms | 41.875 ms | 59.996 ms | 4.107 ms |
| skeleton | 10³ | 1,000 | 28 | 684 | 2.461 ms | 3.138 ms | 2.959 ms | 0.997 ms |
| dense | 14³ | 2,744 | 2,744 | 7,056 | 1,496.582 ms | 1,131.670 ms | 1,748.200 ms | 22.474 ms |
| shell | 14³ | 2,744 | 1,016 | 12,240 | 207.457 ms | 160.180 ms | 241.886 ms | 8.953 ms |
| skeleton | 14³ | 2,744 | 40 | 972 | 5.512 ms | 7.500 ms | 7.327 ms | 2.424 ms |

## Shared split measurements

| Extent | Scanned | Retained occupied / successor shapes | Connectivity preflight | Transaction commit | Total synchronous split work |
|---|---:|---:|---:|---:|---:|
| 6³ | 216 | 180 | 1.458 ms | 8.416 ms | 9.874 ms |
| 10³ | 1,000 | 900 | 7.372 ms | 89.239 ms | 96.611 ms |
| 14³ | 2,744 | 2,548 | 21.048 ms | 557.546 ms | 578.594 ms |

Each split produced exactly two successors and the successor collision-shape total exactly matched retained occupied Matter.

## Material findings

### 1. Full-volume scanning is real, but not the dominant current scale failure

At `14³`, dense connected-component extraction costs only `22.474 ms`, compared with:

- `1,496.582 ms` static initialization,
- `1,131.670 ms` dynamic initialization,
- `1,748.200 ms` for one retained-Matter material edit because it triggers a full rebuild.

The sparse skeleton uses the same `2,744`-cell bounding extent yet one-cell rebuild costs only `7.327 ms`. Extent scanning alone cannot explain the dense cost.

### 2. Visual mesh complexity also fails to explain the dominant cost

At the same `14³` extent:

- dense: `2,744` collision shapes, `7,056` mesh vertices, `1,496.582 ms` static init,
- shell: `1,016` collision shapes, **`12,240` mesh vertices**, `207.457 ms` static init.

The shell emits about 73% more mesh vertices but initializes about 7.2× faster. The dominant scaling pressure therefore tracks occupied-cell collision materialization far more strongly than emitted visual vertices.

The same relationship appears in one-cell full rebuild (`1,748.200 ms` dense vs `241.886 ms` shell).

### 3. Current per-cell physical representation becomes strongly superlinear in this tested range

Dense occupied count grows from `216 → 1000 → 2744` (~12.7× overall), while:

- static init grows ~126×,
- dynamic init grows ~119×,
- one-cell full rebuild grows ~134×.

A simple log/log fit over only these three bounded samples is around exponent `1.9`; this is **not claimed as a universal asymptotic law**, but it clearly rejects “roughly linear and merely somewhat expensive” as a description of the current active-tree node/shape-per-cell representation.

### 4. Single-cell mutation currently pays almost the full representation cost

Changing retained Matter material does not alter occupied-cell topology, yet the current provider path rebuilds the full mesh/collision/mass representation. At `14³` dense this costs `1.748 s`, even more than initial provider construction in the same run.

This establishes a second pressure — rebuild granularity — but the rebuild is currently expensive largely because it reconstructs the same pathological collision representation. Optimizing dirty scheduling before reducing representation cost would attack the symptom while retaining the largest per-rebuild cost.

### 5. Shared split is also dominated by successor representation construction, not connectivity discovery

For the `14³` disconnected case:

- public preflight connectivity scan: `21.048 ms`,
- actual shared transaction commit: `557.546 ms`.

The preflight is under 4% of measured synchronous split work. Although the current split performs repeated/full connectivity work and can later be improved, it is not the first scale target. Successor derived-representation materialization dominates the transaction at this size.

## R0 verdict

**PASS: the dominant next scale pressure is sufficiently ranked.**

The first R challenger should target the reference collision representation, specifically the one-shape/one-node-per-occupied-cell materialization, while preserving Matter, lineage, lifecycle and exact occupied geometry semantics.

A suitable first challenger is **exact merged cuboid collision aggregation**:

- partition occupied unit cells into a much smaller set of axis-aligned boxes,
- preserve the exact union of occupied-cell collision volume,
- keep Matter-derived mass/COM/inertia authoritative rather than deriving physical identity from boxes,
- compare per-cell vs aggregated representation A/B on dense, shell and sparse cases,
- then rerun live mutation/lifecycle/actor/topology invariants against the aggregated path before considering it a replacement.

## Explicit non-conclusions

R0 does not establish:

- final chunk/region size,
- optimal greedy-cuboid algorithm,
- that collision aggregation alone solves large-world scaling,
- that full-volume scanning is permanently acceptable,
- that full rebuilds are acceptable once collision representation improves,
- asynchronous/threaded rebuild design,
- production LOD/near-far modes,
- persistence or streaming architecture.

It only establishes the correct **first measured target**.