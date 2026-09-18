# P1 R-V3 — state presentation policy

Status: **PASS / SELECTIVE SIDE-RIM STATE CUE PROMOTED**

Owner-failed visual baseline: `b5050b669ec4101226095183929f5790f0a034fc`

Forensic challenger source: `67c8d5da8de1bbbfdee4a08b1e897dc92fff15e4`

Promoted production source: `80a6fb34bc9c1e0378158a5c343a3dc640072cd3`

Renderer: Windows Godot 4.7.2 Forward+ / D3D12

## Question

After correcting base Matter winding and unifying provider-independent surface identity, how much persistent world-space geometry is actually needed to communicate STATIC/DYNAMIC Space state without recreating a dense debug shell?

The previous full state contour was directionally robust but wrapped every exposed face boundary. A top-only crown was perceptually cheaper, but risked losing state identity at shallow view angles and competed with the separate focus crown for the same top-surface channel.

R-V3 therefore compared three policies on the same real runtime sequence:

1. `current_contour` — the then-production full exposed-surface contour,
2. `top_crown` — state identity only around exposed top-surface perimeter,
3. `side_rim` — state identity only on exposed vertical side-surface boundaries, while focus remains a separate top crown.

The capture sequence was:

- focused STATIC Space,
- focused DYNAMIC Space after real provider transition,
- real topology split producing two DYNAMIC successors,
- freeze the focused successor beside a still-DYNAMIC sibling,
- repeat the mixed state from a low camera angle.

HUD, player, origin marker and G5 target presentation were disabled so the state-language comparison was isolated.

## Forensic rendered evidence

Workflow run: `35106106449`

Exact source: `67c8d5da8de1bbbfdee4a08b1e897dc92fff15e4`

Artifacts:

- full `current_contour`: `10449798376`, digest `sha256:3478587e12e9939c67f5e223e5ec43177c58dda0ac3c6c0b647914a08ed4a7c5`
- `top_crown`: `10450745222`, digest `sha256:7690228c8780d132a522ab1aef570bd6ca64fa7a250d5cb036f408bf34f67154`
- `side_rim`: `10450053552`, digest `sha256:6184742359301d06d93238c52e01ee218547ff729b00fa2e0312cfa6480013d2`

All three lanes completed strict import and the full real rendered state sequence without engine/script errors.

### Geometry budget

The harness reports line segments rather than treating visual density as a vague impression.

Single Space:

- full contour: `344` state segments + `104` focus segments,
- side rim: `192` state segments + `104` focus segments,
- top crown: `104` state segments + `104` focus segments.

After split / mixed two-Space state:

- full contour: `436` state segments + `68` focus segments,
- side rim: `242` state segments + `68` focus segments,
- top crown: `124` state segments + `68` focus segments.

Relative to the full contour, `side_rim` removes about 44% of persistent state-line geometry in both representative states while preserving a separate focus channel.

## Perceptual findings

### Full contour

The full contour remains directionally robust: STATIC/DYNAMIC color survives shallow views because vertical and side boundaries continue to project strongly.

Its weakness is cost, not correctness. A large fraction of its top/bottom surface network adds line density without adding unique state information once the Matter surface and cell structure already read correctly.

### Top crown

`top_crown` is the cheapest policy, but it is rejected as the sole state language.

In mixed STATIC/DYNAMIC evidence, especially the low-angle stress frame, the DYNAMIC amber identity becomes materially weaker because top-surface perimeter has little projected area. State and focus also occupy nearly the same geometric channel on the focused Space.

This is an information-loss trade rather than a simple styling preference.

### Side rim

`side_rim` preserves the useful property of the full contour: colored state identity remains visible on vertical/silhouette boundaries from ordinary and shallow camera angles.

At the same time it removes the permanent state network from horizontal Matter surfaces. Focus remains a neutral-white top crown, so physical state and focus are expressed through separate geometric channels.

The visible result is materially quieter without giving up the mixed-state causality that motivated persistent state geometry in the first place.

## Promotion

Commit `80a6fb34bc9c1e0378158a5c343a3dc640072cd3` changes only derived presentation policy:

- production `P1MatterStatePresentation.refresh_space()` now uses `build_side_surface_contour()` for state geometry,
- STATIC/DYNAMIC colors are unchanged,
- focus remains `build_top_surface_perimeter()`,
- state/focus lifecycle and provider attachment are unchanged,
- the previous full `build_surface_contour()` remains available as a diagnostic/reference builder,
- Matter authority, Space identity, topology, collisions, storage and motion semantics are unchanged.

The production side-surface builder and the test challenger use the same face selection rule, edge construction, normal offset and color constants.

## Exact-source production re-proof

P1 rebuild workflow: `35107049899`

Exact production source: `80a6fb34bc9c1e0378158a5c343a3dc640072cd3`

Both jobs are GREEN:

- full `p1-foundation`, including the promoted Matter state-presentation lifecycle probe,
- Windows composed-scene diagnostic.

The foundation also re-proved front-face orientation, provider visual identity, canonical startup, actor, multi-Space lifecycle, topology consumer, grid lifecycle, storage rebase, camera/control separation, finite Space control and the integrated causal loop.

Rendered R-V3 re-proof: workflow `35107049826`.

Production `current_contour` artifact after promotion:

- artifact `10450697209`
- digest `sha256:5e0c55e38e7ceb7a5a70fef37c42c34d77b0e1a71ba8f0603e8368f581e4bd6f`

Same-source `side_rim` reference:

- artifact `10451320129`
- digest `sha256:6346415ab4768411013a76d90a3afb5deefcc30cf6f908cb3fc15d284f179460`

The production lane reports the promoted challenger budget exactly:

- `192 / 104` state/focus segments for the single-Space states,
- `242 / 68` state/focus segments for split/mixed states.

### Pixel equivalence

Production versus same-source `side_rim` reference:

- `00_static_focused.png` — pixel-identical,
- `01_dynamic_focused.png` — pixel-identical,
- `02_split_two_dynamic.png` — pixel-identical,
- `03_mixed_static_dynamic.png` — pixel-identical,
- `04_mixed_low_angle.png` — 4,226 of 740,160 pixels differ (`0.570958%`), mean absolute RGB delta `0.010617`, maximum channel delta `31`.

Manual difference inspection localizes the low-angle delta to the translucent state-line footprint; the base scene and focus geometry do not show a structural mismatch. Source inspection confirms that production and challenger use the same side-rim geometry rule and offsets. The bounded low-angle delta is therefore treated as translucent line raster/composition variance, not evidence of a different state policy.

The promoted production low-angle frame remains semantically equivalent: STATIC/DYNAMIC identity remains readable and no removed full-contour network reappears.

## Verdict

**PASS.**

R-V3 promotes a narrower persistent state language:

> physical state lives on exposed side boundaries; focus lives on the top perimeter.

This is a bounded presentation decision, not a claim of final art direction.

## Nonclaims / open work

R-V3 does not establish:

- final contextual/distance policy for the one-cell surface grid,
- final colors, line rendering or authored material art direction,
- that persistent state geometry is universally required in future versions,
- greedy/macro-surface meshing value,
- camera/avatar visual safety,
- accumulated chaotic-session gestalt,
- Owner readiness.

R-V2 macro-surface work remains deferred because corrected per-cell Matter is currently visually coherent and no measured pressure justifies displacing higher-value visual risks.

The next active tranche is R-V4 camera / visual safety.
