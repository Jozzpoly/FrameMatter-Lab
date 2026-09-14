# R1 — exact collision aggregation

Status: **FULL PASS for the tested scope**.

R1 challenged the R0 finding that one engine collision node/shape per occupied Matter cell was the dominant first scale pressure. The replacement mechanism is a deterministic derived compiler that partitions occupied unit cells into exact, non-overlapping axis-aligned integer cuboids.

This evidence record is about the tested representation mechanism and its integration. It does not make the greedy partition algorithm, current node layout or host-engine representation canonical.

## Question

Can collision representation be compressed substantially without changing logical Matter authority, Matter lineage, occupied collision volume, Matter-derived mass semantics, local-Space lifecycle behavior, actor support or topology succession?

## Tested setup

Reference and challenger were exercised on Godot 4.7.2 / built-in Jolt using the same controlled dense, shell and sparse-skeleton volumes at extents `6`, `10` and `14`.

Reference mode:

- `PER_CELL`: one unit box per occupied Matter cell.

Challenger mode:

- `MERGED_CUBOIDS`: deterministic exact occupied-volume partition into non-overlapping integer cuboids.

For each representation case the probe measured:

- occupied-cell count,
- reference and merged shape counts,
- exact coverage errors,
- static-provider initialization,
- dynamic-provider initialization,
- retained-Matter mutation / full rebuild.

A separate integration gate exercised the merged representation through provider replacement, dynamic motion, live occupancy mutation, solver mass properties, actor support and shared topology split/succession.

## Correctness result

**PASS.**

Across every R1 A/B case:

- merged cuboids covered exactly the occupied Matter cells,
- coverage error count was zero,
- cuboids did not overlap or cover empty cells,
- shape count never exceeded the per-cell reference,
- dense volumes compiled to one cuboid,
- non-dense pressure cases achieved real compression.

Logical `CellVolume` remained authoritative. Collision cuboids remained disposable derived representation.

## Scale result

The largest `14³` cases from the final gated run:

| pattern | occupied | per-cell shapes | merged shapes | static init | dynamic init | full mutation/rebuild |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| dense | 2744 | 2744 | 1 | `1870.7 ms → 24.6 ms` (**76.2×**) | `1522.1 ms → 26.8 ms` (**56.9×**) | `2349.4 ms → 27.0 ms` (**87.1×**) |
| shell | 1016 | 1016 | 6 | `265.4 ms → 14.9 ms` (**17.8×**) | `219.8 ms → 17.2 ms` (**12.8×**) | `328.3 ms → 16.3 ms` (**20.1×**) |
| skeleton | 40 | 40 | 5 | `6.0 ms → 5.5 ms` (**1.10×**) | `8.2 ms → 7.7 ms` (**1.06×**) | `8.2 ms → 7.5 ms` (**1.10×**) |

The shape-count dependence seen in R0 is therefore strongly confirmed. Large dense/shell cases improve dramatically when shape materialization collapses, while the sparse skeleton—where per-cell collision was already cheap—changes little.

This is useful causal evidence, not merely an aggregate benchmark improvement.

## Integrated lifecycle result

**PASS.**

The dedicated merged-lifecycle gate measured:

- initial Matter: `66` cells,
- final Matter: `64` cells,
- collision shapes: `3` initially, `5` after live edit, `6` after disconnection,
- split successors: `6` merged shapes versus `64` per-cell reference shapes,
- occupancy edit rebuild: `1.158 ms`,
- pre-edit actor drift: `9.0e-6`,
- post-edit actor drift: `3.5e-6`,
- post-split actor drift: `4.9e-6`,
- topology handoff world jump: `9.5e-7`,
- floor-loss frames after edit/split: `0`,
- wrong-support frames after split: `0`.

The merged representation remained semantically transparent through the tested provider replacement, dynamic motion, mass-property refresh, actor support and topology-succession path.

## Runtime promotion and full ratchet

After the challenger/integration results, `MERGED_CUBOIDS` became the default collision mode for the current static/dynamic providers while `PER_CELL` remained available as a reference mode.

The first post-promotion full research runs exposed several historical tests that encoded the obsolete implementation detail `collision shape count == occupied cell count`. Those failures were not accompanied by failures in Matter truth, mass, COM, momentum, velocity-field continuity, lifecycle timing or actor support.

Those assertions were corrected to validate the active compiled collision representation instead of fossilizing `PER_CELL` topology.

Final ratchet:

- commit: `286758a9cdf895e569f8cbb1b300602005ae94e2`,
- GitHub Actions run: `#182` / `34899262822`,
- fast invariant validation: **PASS**,
- full research validation from G0 through R1 merged lifecycle integration: **PASS**.

This closes R1 for its current scope.

## What R1 establishes

Within the tested bounded/integrated scope:

1. collision representation can change radically without redefining Matter identity;
2. exact merged-cuboid compilation removes the dominant R0 per-cell shape-materialization cost for dense/shell pressure cases;
3. Matter-derived mass/lifecycle semantics remain independent of collider identity/count;
4. lifecycle, actor-support and topology-succession invariants survive the promoted representation;
5. historical tests must validate semantic invariants rather than preserving obsolete representation details.

## Explicit non-claims

R1 does **not** establish:

- production-scale world performance,
- optimal global cuboid partitioning,
- edit-local or incremental collision updates,
- chunk/region architecture,
- asynchronous rebuild scheduling,
- production physical-material boundaries,
- best visual representation,
- appropriate far/inactive representation,
- acceptable Owner-facing playability or world scale.

The current greedy compiler still performs whole-volume work and providers still rebuild whole derived representations. Those are candidates for re-profiling, not automatically the next architecture.

## Re-audit consequence

Do not continue optimization by inertia.

R1 removed the strongest R0 bottleneck. The next step is a post-aggregation profile that decomposes remaining costs under the promoted representation and re-ranks them. Dirty/edit-local rebuild, chunk/region boundaries or another representation mechanism should be selected only if the new measurements justify them.