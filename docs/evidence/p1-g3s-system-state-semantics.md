# P1 G3-S — system-state semantics

Status: **BOUNDED PASS / SOFT CONTOUR + NEUTRAL FOCUS CROWN PROMOTED**

G3-S asks a different question from G3 granularity:

> can the rendered world communicate physical Space state and current focus without rewriting Matter material identity, overloading the cell grid, or relying on the engineering HUD?

The tested scope covers STATIC vs DYNAMIC state, focused vs non-focused Space, and post-split successor independence within the current P1 causal sequence.

## Constraint inherited from G3

G3 already assigned one semantic channel to restrained exposed-cell boundaries. G3-S therefore deliberately did not encode physical state by strengthening, recoloring or otherwise overloading the cell grid.

The state language also had to remain derived presentation:

- no Matter authority,
- no provider authority,
- no topology authority,
- no collision or mass authority,
- no new material identity,
- no artificial split/separation physics.

## Challenger family 1 — whole-material state tint

The first family encoded STATIC/DYNAMIC by changing the entire visible Matter material.

It was readable, especially after split/freeze, but it failed a deeper semantic test: the simulated state became visually entangled with what the Matter appeared to be made from. Even after a second, subtler tint pass, DYNAMIC Matter still read as a materially different beige/khaki object rather than the same Matter in a different simulation state.

That coupling is unacceptable as a foundation because future Matter may carry actual wood, metal, earth or other authored material identities. Physical simulation state must not silently replace those identities.

**Result: REJECTED as the canonical direction.**

## Challenger family 2 — derived surface contour

The second family preserved the base Matter material and added a separate derived perimeter/crease contour generated from exposed surfaces.

First round:

- STATIC: cyan-family contour,
- DYNAMIC: amber-family contour,
- focus: AABB corner brackets.

The contour separated state from material identity successfully, but its initial alpha was too strong and approached debug/Tron-outline presentation. The AABB focus brackets also failed visually: after normal depth occlusion they often reduced to floating disconnected marks unrelated to the visible Matter surface.

The AABB brackets were therefore rejected rather than polished.

## Focus refinement — surface-derived crown

Focus was moved to a separate neutral cue derived from the perimeter of actual exposed top Matter surfaces.

This avoids several false meanings:

- it does not visualize dense-storage bounds,
- it does not invent a second object envelope,
- it does not imply physical state,
- it follows the real focused successor after topology succession.

A pale-blue crown improved substantially over AABB brackets, but could visually merge with the cyan STATIC contour. The final crown therefore became neutral-white.

## Final contour intensity A/B

The final comparison held focus semantics constant with the neutral crown and tested only state-contour intensity:

- `state_contour_neutral_focus`: STATIC alpha `0.42`, DYNAMIC alpha `0.46`,
- `state_contour_soft_neutral_focus`: STATIC alpha `0.32`, DYNAMIC alpha `0.36`.

Both remained readable across the real rendered causal sequence. The softer profile won because it continued to distinguish STATIC/DYNAMIC at near, mid and far observation scales and in split/freeze states while competing less with the promoted G3 cell-granularity language.

Promoted semantic channels:

- STATIC contour: `Color(0.22, 0.56, 0.72, 0.32)`,
- DYNAMIC contour: `Color(0.86, 0.53, 0.20, 0.36)`,
- focused Space crown: neutral `Color(0.96, 0.98, 1.0, 0.62)`.

These values are current bounded presentation choices, not final art-direction constants.

## Production promotion

Production implementation: `p1/matter_state_presentation.gd` / `P1MatterStatePresentation`.

It is a sibling presentation consumer in `p1/main.tscn`. It does not alter `LocalMatterSpace`, `ConstructBody`, `MatterRepresentation`, lineage, collision, topology or the P1 causal orchestrator.

Provider, storage, split and edit changes are observed through the existing `P1SpaceRegistry` / `P1MatterInteractor` consumer contracts. Current focus is observed from the P1 scene's existing `get_space()` current-focus accessor; the presenter does not become a second selection authority.

A larger focus-bus refactor was considered and deliberately not introduced without broader consumer pressure. If later camera/UI/interaction work requires one shared focus contract, that should be extracted from evidence then rather than pre-designed here.

## Executable lifecycle evidence

`tests/p1_matter_state_presentation_probe.gd` is part of the active P1 rebuild gate.

It verifies that production presentation:

- begins with one STATIC state contour and exactly one focus crown,
- can be disabled/re-enabled without changing base Matter material,
- rebuilds after a committed Matter edit,
- follows real STATIC→DYNAMIC provider replacement,
- survives storage-frame rebase,
- follows one→many topology succession,
- gives both dynamic successors their own state contours,
- preserves exactly one focused successor crown,
- after freezing the focused successor, simultaneously represents one focused STATIC successor and one non-focused DYNAMIC sibling,
- never needs to recolor the authoritative/provider-owned base material.

P1 rebuild run `34992469599` passed the production probe and the surrounding P1 suite.

Observed metric:

`P1_MATTER_STATE_PRESENTATION_METRIC static_alpha=0.32 dynamic_alpha=0.36 focus_alpha=0.62 successors=2 state_overlays=2 focus_overlays=1 shift=(3, 0, 0)`

The integrated causal-loop gate also remained green after promotion.

## Rendered production equivalence

An honest promotion-equivalence lane was added after production existed:

- canonical lane uses production `P1MatterStatePresentation`,
- `state_contour_soft_neutral_reference` disables only the production state presenter and then recreates the accepted test-only soft-contour + neutral-crown challenger,
- the already-promoted G3 cell grid remains active in both lanes.

Windows Godot 4.7.2 Forward+ / D3D12 workflow run `34992731545` on commit `860dbe6789ff6acc6eb6f4c78a691d217f0d7695` passed canonical, reference and Linux Compatibility jobs.

For deterministic/static-equivalent captures, production and reference matched as follows:

- `00_initial_static`: pixel-identical,
- turntable `0°` through `270°`: pixel-identical,
- turntable `315°`: only 3 pixels differed by at least `2/255`, maximum channel difference `2/255`,
- near granularity: only 2 pixels differed by at least `2/255`, maximum `4/255`,
- mid granularity: maximum `1/255`, no pixels differed by at least `2/255`,
- far granularity: pixel-identical,
- released-dynamic capture: maximum `1/255`, no pixels differed by at least `2/255`.

Later moving/rebase/split/freeze screenshots from separate CI jobs are intentionally **not** used as pixel-equivalence proof because solver/render timing can place the physical world at slightly different poses between jobs. Their lifecycle correctness is defended by the executable production probe instead. This avoids manufacturing false image determinism.

## What G3-S establishes

Within the current authored P1 scene and tested renderer/scenario set:

- STATIC vs DYNAMIC has a restrained world-space semantic channel independent of Matter base material,
- focus has a separate neutral semantic channel,
- topology successors can be read as related Matter that now carry independent physical states,
- the promoted production implementation follows the actual Space/provider/edit/rebase/split lifecycle,
- production rendering reproduces the accepted challenger on deterministic states.

## Explicit nonclaims

G3-S does **not** establish:

- final colors or art direction,
- accessibility across all color-vision conditions,
- final interaction REMOVE / PLACE / EXPAND language,
- adequate camera composition,
- adequate world/motion causality,
- adequate default UI hierarchy,
- final focus/selection architecture,
- arbitrary-scale performance of the derived contour,
- Owner readiness.

Those remain later campaign questions.

## Next move

Proceed to **G4 — camera as experiment instrument**.

The next question is no longer whether a SpringArm exists. The camera must be challenged against real authored Matter, real state presentation and real lifecycle events: close obstacles, actor near Space edge, moving Space, fall/recovery, storage rebase, provider replacement and topology succession. The objective is to preserve the experiment and its causal context rather than merely follow the actor.
