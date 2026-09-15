# P1 G3 — Matter granularity / edit-scale readability

Status: **BOUNDED PASS / CLEAN SURFACE GRID 0.14 PROMOTED**

G3 addresses one visual question on top of the promoted G2 lighting baseline:

> can the Owner read one-cell Matter scale near interaction distance without turning the whole object into a noisy per-cube wireframe or confusing a visual material pattern with logical structure?

This evidence deliberately separates Matter granularity from STATIC/DYNAMIC state, focus/selection semantics, interaction intent, camera quality and UI hierarchy.

## Baseline problem

After G2, broad Matter form was substantially more legible, but canonical Matter still did not communicate that the object was built from editable one-cell units. The old P0.5 solution was not accepted as a default merely because it exposed a grid: it drew all edges of occupied cells and tended toward a dense wire-cage as Matter grew.

G3 therefore compared materially different visual languages before promotion.

## Challenger A — exposed surface cell boundaries

`surface_cells` built a depth-tested line mesh only from edges of exposed cell faces:

- no internal Matter edges,
- no x-ray/no-depth-test behavior,
- a small `0.006` normal offset from the real surface,
- dark restrained line color,
- one derived mesh rather than one Node per cell.

The intent was to say “this visible surface is composed of editable cells” while leaving broad object form dominant.

## Challenger B — surface modulation

`surface_modulation` removed explicit lines and instead applied a restrained alternating per-cell tonal modulation to exposed faces.

It survived the same real P1 lifecycle sequence, so rejection was not caused by a broken harness. The visual problem was semantic: the checker-like result read primarily as a material/texture pattern. It communicated regular repetition, but less clearly communicated editable cell boundaries.

`surface_modulation` was therefore **not promoted**.

## First surface-grid refinement

The initial surface grid materially improved granularity readability but was too present on broad horizontal surfaces at alpha `0.16`.

A controlled comparison against alpha `0.10` showed that the softer version retained the near/mid/far cell-scale signal while reducing the impression that the platform itself was a drawn grid.

This was not promoted immediately because audit of the challenger found a geometry defect: a boundary shared by two adjacent exposed coplanar faces could be emitted twice, making some lines accidentally stronger and making alpha an unreliable semantic parameter.

## Coplanar deduplication

The grid builder was corrected so that:

- identical same-orientation coplanar line segments collapse to one segment,
- face orientation remains part of the dedupe key,
- therefore a real perpendicular crease may still retain one slightly normal-offset segment for each surface.

After deduplication the previous alpha values were not treated as directly transferable. Two clean challengers were rendered:

- `surface_cells_clean`: alpha `0.14`,
- `surface_cells_clean_strong`: alpha `0.18`.

Rendered workflow run `34986781028` completed successfully for canonical, both clean Windows D3D12 challengers and Linux Compatibility.

Direct near/mid/far, turntable and split review selected **clean `0.14`**. The stronger `0.18` variant increased grid presence without adding material structural information.

As a supporting image metric, the static-frame pixel footprint materially changed from canonical was roughly `1.2–1.5%` for clean `0.14` versus roughly `2.2–2.5%` for clean `0.18` at the previously used `>=5/255` threshold. This metric was not the promotion criterion; it only supports the qualitative observation that `0.14` carried the needed signal with less visual occupation.

## Production promotion architecture

The accepted challenger was **not** copied into Matter authority or collision representation.

Production promotion introduced `P1MatterSurfaceGrid`, a sibling presentation consumer in `p1/main.tscn`.

It:

- observes `P1SpaceRegistry` lifecycle events,
- observes committed edits from `P1MatterInteractor`,
- builds one derived `MeshInstance3D` surface-grid child on each current provider,
- rebuilds after Matter edit and storage-frame rebase,
- follows static↔dynamic provider replacement,
- follows one→many topology succession,
- can be disabled and reconstructed entirely from current authoritative Space/Matter state.

`p1/main.gd` required no surface-grid knowledge. This is intentional evidence that the cue remains replaceable presentation rather than becoming logical Matter identity.

Production parameters match the accepted challenger:

- normal offset `0.006`,
- line alpha `0.14`,
- unshaded dark-blue line material,
- depth testing enabled,
- shadow casting disabled.

## Executable production evidence

`tests/p1_matter_surface_grid_probe.gd` is part of the active P1 rebuild gate.

It checks both geometry and lifecycle behavior.

### Exact dedupe probe

For a solid `2×1×1` prism:

- ten faces are exposed,
- naive independent face-edge emission would create 40 line segments,
- four same-plane shared edge duplicates must collapse,
- production output is asserted to contain exactly **36 segments**.

This protects the specific defect found during challenger audit rather than merely checking that “a mesh exists”.

### Lifecycle probe

The probe then composes the real P1 scene through:

1. initial static Space,
2. committed Matter edit,
3. storage-frame rebase,
4. static→dynamic provider replacement,
5. destructive topology cut and split,
6. two live successor Spaces,
7. presentation disable and reconstruction.

Workflow run `34988816951`, job `104447931302`, completed successfully.

Production metric:

`P1_MATTER_SURFACE_GRID_METRIC clean_alpha=0.14 successors=2 overlays=2 shift=(3, 0, 0)`

The same job also kept the existing actor, scene, registry, live-topology, storage, finite-control and integrated causal-loop gates green.

## Rendered production-equivalence verification

A temporary honest reference lane was added because canonical already contained the production grid. Simply applying the old challenger on top of canonical would have produced a false grid+grid comparison.

The reference lane therefore:

1. disables `P1MatterSurfaceGrid`,
2. applies the accepted test-only deduplicated clean `0.14` challenger,
3. captures the same Windows D3D12 sequence.

Rendered workflow run `34988816989` on branch head `97efd1483716ca9f4019630b14099624ae7578e7` completed successfully.

Artifacts:

- production canonical: artifact `10404796414`, archive digest `sha256:d41d0e6a61d59461fd188aef44faf4300ad7c53fdc48df7e9c3068b58cc39e2d`,
- clean `0.14` reference: artifact `10404513444`, archive digest `sha256:c7d1621f5d64dd93fbf96a33af5ad9907c16d94954ff841e47393efb2fecfe42`.

For deterministic static presentation states:

- initial static was pixel-identical,
- seven of eight lighting-turntable views were pixel-identical,
- after excluding the HUD region, the remaining turntable view differed by only 9 pixels at `>=2/255`,
- granularity near differed by 5 gameplay pixels at `>=2/255`,
- granularity mid by 4,
- granularity far by 9, with maximum far gameplay difference only `5/255`.

These differences are negligible relative to the 740,160-pixel frame and do not form a structural presentation difference.

Dynamic/motion/split frames from independent CI jobs are **not** used as pixel-equivalence evidence because solver/render timing allows physical/camera state to diverge slightly between runs. Their lifecycle correctness is instead covered by the executable production probe on one run.

This separation prevents temporal physics nondeterminism from being misclassified as renderer/presentation inequivalence.

## What G3 establishes

Within the current P1 authored scene and tested renderer paths:

- Matter one-cell edit scale is legible near and mid interaction distances,
- broad Matter remains a coherent form at far distance,
- the selected cue communicates cell boundaries more clearly than the tested modulation language,
- coplanar duplicate line strength is eliminated,
- the production implementation reproduces the accepted clean `0.14` challenger,
- presentation follows edit, storage maintenance, provider replacement and topology succession without becoming authority,
- disabling presentation does not mutate logical Matter/Space state.

## Explicit nonclaims

G3 does **not** establish:

- final renderer or material language,
- final scale/performance behavior for very large Matter volumes,
- chunking/streaming architecture,
- STATIC vs DYNAMIC visual semantics,
- focused/selected Space semantics,
- successor identity language beyond cell granularity following the real successor providers,
- REMOVE/PLACE/EXPAND interaction hierarchy,
- camera quality,
- world/motion causality quality,
- default UI quality,
- Owner readiness.

The line cue remains derived and replaceable if later evidence finds a better language.

## Next move

Proceed to the next visual question as a separate semantic channel.

Granularity is now carried by exposed cell boundaries. G4/state-language work must not overload that same cue with unrelated meaning. STATIC/DYNAMIC state, focus/selection and successor independence should be challenged as distinct concepts so one color or line treatment does not silently become several different meanings at once.
