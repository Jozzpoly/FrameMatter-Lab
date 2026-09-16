# P1 R-V0 — base Matter surface forensics

Status: **PASS / ROOT CAUSE CONFIRMED AND MINIMAL CORRECTION PROMOTED**

Owner-failed runtime baseline: `b5050b669ec4101226095183929f5790f0a034fc`

Pre-fix forensic source: `25b303bdfaf512e2bd2df822de8f6a11bc6566df`

Canonical corrected source: `f01375e4e6fe09f5f559167d8be4d13e7bab01b0`

## Question

Why did opaque Matter in the delivered Owner build read as transparent/hollow, especially after accumulated irregular editing?

R-V0 deliberately isolated **base Matter only** before changing art direction, lighting, material color, greedy meshing or semantic presentation.

The capture disabled the Matter surface-grid and state presenters, hid the player/HUD/origin marker, and retained the canonical Windows Forward+ / D3D12 environment and shadows.

## Pre-fix A/B/C

Workflow run: `35039526850`

Exact source: `25b303bdfaf512e2bd2df822de8f6a11bc6566df`

Artifacts:

- current: `10424980993`, digest `sha256:5eff6509610424806b432922fb8de325709a3430f36810703dcab0c0ebbb8f8c`
- cull-front diagnostic: `10425015280`, digest `sha256:77df8db8abb5ee62c76f575564bb1925d0a1a117fb8e57f7ebb3a815f28c7e13`
- corrected-winding challenger: `10425130318`, digest `sha256:3588a52aef03bf3b1b9ecc4c0f53a543d94ebfedd8bad5c8e5a076d43861331d`

Each lane captured the same four states:

- clean default angle,
- clean opposite angle,
- deterministic accumulated irregular geometry at default angle,
- the same irregular geometry from the opposite angle.

### Current baseline

The baseline reproduces the Owner failure even with all semantic overlays disabled:

- large nearest horizontal Matter surfaces disappear,
- farther/opposite walls remain visible,
- the construct reads as an open/hollow shell,
- irregular geometry makes the false interior/far-shell reading more severe.

This proves that the primary transparency failure was below G3/G3-S/G5 presentation.

### `cull_front` diagnostic

Changing only material culling does not produce a valid exterior surface. It exposes back/interior-facing geometry and remains visually hollow/dark. It is therefore rejected as a product fix.

### Corrected winding

Reversing the order of each emitted Matter triangle while preserving authored outward normals immediately restores:

- the nearest exterior deck surface,
- coherent wall exteriors,
- opaque holes/concavities with understandable boundaries,
- solid pillars/protrusions under accumulated geometry entropy.

No material alpha, lighting-energy or shadow setting changed.

The visual delta is not subtle: depending on state, roughly half of the rendered pixels differ materially between the pre-fix current surface and the corrected-winding challenger.

## Engine-native orientation proof

A permanent regression probe now compares procedural Matter triangle orientation relative to authored normals against Godot's built-in `BoxMesh`.

Canonical corrected run `35040068058` reported:

`P1_CELL_MESHER_FRONT_FACE_STATS: reference_triangles=12 reference_sign=-1 matter_triangles=12 matter_sign=-1`

followed by:

`P1_CELL_MESHER_FRONT_FACE_PASS`

The full P1 foundation and Windows composed-scene diagnostic also passed on the corrected source.

This is stronger than inferring winding from screenshots alone: the corrected procedural mesh now agrees with the engine's own primitive-mesh orientation convention.

## Minimal canonical correction

`CellMesher.FACE_VERTICES` remains unchanged because presentation consumers use that shared face template to derive corners/edges.

Only `CellMesher.build_mesh()` reverses each stored triangle at render-mesh emission time. Logical Matter, collisions, topology, mass, lifecycle and presentation face-corner assumptions are unchanged.

## Post-fix exact-source closure

R-V0 workflow run: `35040068092`

Exact source: `f01375e4e6fe09f5f559167d8be4d13e7bab01b0`

Artifacts:

- canonical `current`: `10424822653`, digest `sha256:4e0f335a325ef2f4840951cb212adaf43625ae629f5b6c0bf344f044ac8f12f8`
- cull-front diagnostic: `10424827525`, digest `sha256:735e9cfeb4a137536918576c57c00e31c2ade3fc29bb18392943656143d71c77`
- test-only corrected reference: `10424538776`, digest `sha256:4f4c580b07fc80ad824a329b899cc27e415e95f780e1c7ec9e53b8d4f9b3df66`

The four canonical `current` PNG files are **byte-for-byte SHA-256 identical** to the four test-only `corrected_winding` PNG files:

- `00_clean_default.png` — `4f4613b0fc757b28473aa773d7a68cc3439ce4ab09dbac4699e03f3fae1a5c12`
- `01_clean_opposite.png` — `94c6e381d6ab013e0adc540a0c217531f116f99afc4991047317a1e4c9225247`
- `02_chaos_default.png` — `e7b81545a3d4d321cacbd5fafafa3a94380225c6c5c503ee8a09d8629791d9a1`
- `03_chaos_opposite.png` — `0d5329c0efd9e273e8f879182b1a823360a06cc91e1e7cb5a849d7e6ad8a4c2c`

This proves that the promoted production path exactly reproduces the accepted corrected-winding challenger for the R-V0 corpus.

## Shadow hypothesis disposition

Canonical directional shadows remained enabled throughout the corrected-winding captures. The old hollow/triangular transparency failure disappeared without changing shadow configuration.

Therefore shadow bias/self-shadowing is **not supported as the primary root cause** and R-V0b shadow tuning is not justified as the next tranche.

Normal cast shadows remain visible and useful. Shadow-specific forensics should only reopen if a distinct artifact survives later chaotic full-stack evidence.

## Full-stack first look after correction

Existing exact-source rendered workflows also passed on `f01375e...`:

- general rendered parity `35040068022`,
- G4 camera `35040068053`,
- G5 interaction `35040068071`,
- G6 world causality `35040067964`,
- UI hierarchy `35040068093`,
- cross-layer visible rehearsal `35040068204`.

Manual inspection shows a major qualitative change: with correct exterior faces present, the existing surface grid and state contour sit on a visibly solid object rather than floating over a missing front shell. They remain replaceable and still require chaotic-geometry re-evaluation, but they are no longer supported as the primary cause of the Owner's transparency failure.

## R-V0 verdict

**PASS.**

The principal Owner-visible hollow/transparent Matter failure was caused by incorrect procedural triangle front-face ordering in `CellMesher`.

The correction is intentionally minimal and now protected by an engine-native front-face regression probe.

R-V0 does **not** claim that current Matter is visually finished. Remaining open work includes:

- composed presentation under accumulated geometry entropy,
- permanent-vs-contextual cell/state cue policy,
- duplicated static/dynamic visual material ownership,
- potential macro-surface/greedy-meshing challenger,
- camera-to-avatar visual safety,
- interaction composition and less debug-like target language,
- full chaotic Owner-surface rehearsal.

The next tranche is R-V1: re-evaluate the presentation layers on the corrected base surface before replacing them.