# P1 G2 — lighting / form readability

Status: **BOUNDED PASS / BALANCED FILL PROMOTED / SSAO NOT PROMOTED**

G2 addresses the first visual question after the failed P1 Owner candidate:

> can ordinary authored Matter remain legible as volume across representative camera orientations before adding cell-language, state-language or interaction decoration?

It intentionally does not claim that P1 is visually good overall.

## Baseline failure

The failed Owner candidate and the Windows D3D12 parity capture both showed a catastrophic lighting failure: broad Matter surfaces could collapse toward black while directly lit faces became pale/white sheets.

G1 preserved that failure as rendered evidence.

## G2-A — ambient-source correction

The first bounded change altered only the Environment ambient source:

- `SKY → COLOR`,
- sky contribution explicitly `0.0`.

On the deterministic Windows D3D12 initial scene this changed approximately:

- near-black coverage `52.96% → 0.00%`,
- luminance below `0.08`: `54.70% → 1.74%`,
- mean luminance `0.142 → 0.366`.

This strongly attributes the catastrophic black collapse to the project-side Environment configuration.

G2-A removed the catastrophic defect but exposed a second problem: the remaining single-key + relatively strong ambient setup still read as flat bright boards from some orientations.

## G2-B / G2-C bounded challengers

Three Windows Godot 4.7.2 Forward+ / D3D12 variants were rendered from the same P1 states:

### canonical after G2-A

- ambient energy `0.65`,
- key energy `1.15`,
- one shadowed directional key.

### `balanced_fill`

- ambient energy `0.42`,
- key energy `0.88`,
- opposite directional fill energy `0.24`,
- fill specular `0`,
- fill shadows disabled.

### `balanced_fill_ssao`

Exact G2-B key/fill balance plus:

- SSAO enabled,
- radius `1.15`,
- intensity `1.25`,
- power `1.35`.

These were initially test-only variants; canonical runtime was not changed until rendered comparison existed.

## Azimuth-stress extension

The six state captures were insufficient to rule out orientation-specific lighting collapse because they largely shared one camera relation to the key light.

The rendered harness was therefore extended with eight static turntable views at:

`0°, 45°, 90°, 135°, 180°, 225°, 270°, 315°`.

Camera pitch and distance were held fixed while only azimuth changed.

This is a G2 evidence extension, not a production camera feature.

## Finding

Across the eight Windows D3D12 turntable views:

- canonical G2-A remained free of the old black collapse but still produced large orientation-dependent bright/flat sheets,
- `balanced_fill` kept major surfaces materially more even and preserved form more consistently,
- the fraction of very bright scene pixels (`luminance > 0.75`, HUD excluded) fell from roughly `3.9%` mean across the eight canonical views to roughly `0.1%` with balanced fill,
- the balanced fill did not reintroduce the near-black failure,
- `balanced_fill_ssao` reduced extremes similarly but its primary visible contribution was broader darkening/gradients rather than materially clearer authored form in the current geometry.

SSAO is therefore **not promoted** at this stage. This is not a general rejection of SSAO; it means the tested configuration does not currently earn its added visual/performance complexity relative to the information it contributes.

## Promotion

G2-B was promoted to canonical `p1/main.tscn`:

- ambient energy `0.42`,
- key energy `0.88`,
- opposite fill energy `0.24`,
- fill specular `0`,
- fill shadows off.

No Matter material, meshing, cell-language, camera-policy, target-cue or HUD change was included in the promotion.

Commit `e34851e48e15c70c3a75169a8af1822289c6d0bd` contains the canonical lighting promotion.

Commit `06393c1e58bc33a42eedf7f4a088700b991cba6b` rebases the visual harness so `balanced_fill` becomes a no-op equivalence control and `balanced_fill_ssao` adds only SSAO on top of the promoted canonical lighting.

## Promotion verification

Rendered workflow run `34982248451` on commit `06393c1e58bc33a42eedf7f4a088700b991cba6b` passed all Windows D3D12 and Linux Compatibility jobs.

For the deterministic initial state and the eight lighting-turntable views, promoted canonical and the no-op `balanced_fill` control are pixel-identical except for a negligible `az315` difference of at most `2/255` affecting roughly `0.01%` of pixels.

Later dynamic frames are not used for pixel-equivalence because solver/render timing can change physical state slightly between independent runs.

The full mechanical P1 validation also remained green on Linux and Windows after the lighting promotion.

## What G2 establishes

Within the tested authored P1 scene and renderer path:

- the catastrophic black-collapse defect is removed,
- broad form is more stable across camera azimuths,
- a restrained key/fill hierarchy is a better current baseline than the G2-A single-key setup,
- the promoted runtime matches the rendered challenger that justified promotion,
- no evidence currently justifies enabling the tested SSAO setup.

## Explicit nonclaims

G2 does **not** establish:

- adequate one-cell Matter readability,
- STATIC/DYNAMIC visual semantics,
- successor/focus identity language,
- good target/interaction feedback,
- good camera composition,
- good default HUD,
- final lighting/art direction,
- production performance of richer post-processing,
- Owner readiness.

Those remain later recovery questions.

## Next move

Proceed to G3 as a bounded Matter-granularity campaign on top of this promoted lighting baseline.

At least two materially different approaches must be rendered on the same canonical geometry/states before promotion. The objective is not decoration; it is to make one-cell editing scale legible at interaction distance without turning distant Matter into noisy per-cube wire geometry.