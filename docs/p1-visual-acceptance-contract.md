# P1 Owner-visible visual acceptance contract

Status: **ACTIVE GATE / REQUIRED BEFORE G8**

This contract exists because the first P1 Owner candidate proved that strong mechanical evidence can coexist with a presentation layer that is unusable as an Owner-facing research instrument.

The Owner does not experience FrameMatter as classes, tests, lineage maps or solver metrics. The Owner experiences the pixels produced by those systems. Therefore rendered presentation is part of the observable system and must be defended explicitly.

## Core rule

> Mechanical truth that cannot be read from the screen is not sufficient Owner-facing evidence.

The next Owner candidate must pass the existing mechanical gates and every visual dimension below. A candidate may remain deliberately minimalist; it may not remain visually ambiguous, misleading, broken or debug-dominated.

## V-A — form / depth readability

Question:

> Can the Matter shape be understood immediately as three-dimensional geometry?

Required:

- ordinary visible Matter faces remain inside a useful luminance range across representative camera azimuths,
- no broad authored surface collapses into featureless near-black or clipped-white under the normal environment,
- adjacent face orientations are distinguishable without needing a debug overlay,
- concavity, wall height, holes and raised blocks remain readable,
- shadowing supports form rather than destroying it.

Rendered evidence:

- initial static,
- moving/yaw state,
- storage-expanded state,
- split-successor state,
- at least four deliberately different camera azimuth/elevation samples of the initial geometry.

Hard failure examples:

- the first P1 Owner recording's black top surface,
- broad white slabs with no form cue,
- lighting that makes geometry disappear at an ordinary camera angle.

## V-B — Matter granularity / edit scale

Question:

> Can the Owner understand that the surface is editable Matter at a one-cell granularity?

Required:

- cell scale is visible or naturally inferable near editing distance,
- the cell cue does not turn the whole object into a noisy wireframe,
- large coplanar surfaces still read as a coherent object from farther away,
- visual granularity remains derived presentation and does not become logical/collider identity.

Rendered evidence must compare at least two challenger languages before promotion.

Candidate families:

1. restrained cell-edge/grid treatment,
2. procedural/local-coordinate/vertex material treatment.

A hybrid is allowed only after the two concepts have been evaluated independently enough to understand their contribution.

## V-C — system state semantics

Question:

> Can the Owner infer important system state without reading engineering telemetry?

At minimum the screen must distinguish:

- STATIC vs DYNAMIC Space,
- normal vs currently focused/edited Space,
- REMOVE vs PLACE vs EXPAND intent,
- one Space vs independent topology successors after split.

The language may use restrained hue/value/emission/edge changes, but must not depend on garish debug colors or large labels over the world.

A split must not look like a visual accident involving unrelated white boards. Independent successors need a coherent relationship to their source plus enough differentiation to read their new independence.

## V-D — camera / composition

Question:

> Does the camera preserve the experiment rather than merely track the actor?

Required:

- actor, relevant active Space and useful world reference remain readable in the default composition,
- active Space extent influences desired framing/distance,
- standing near Space center does not reduce context pressure to effectively zero,
- ordinary orbit/zoom cannot easily create a long-lived useless frame dominated by the capsule or a nearby Matter face,
- SpringArm collision does not count as sufficient camera quality by itself,
- falls/recovery, provider replacement, storage rebase and topology succession recover coherent composition,
- topology split does not silently abandon the non-actor successor if seeing the relation matters to understanding the event.

Rendered evidence:

- default spawn,
- deliberately close obstacle stress,
- actor near Space edge,
- moving Space,
- immediate post-split,
- post-freeze.

## V-E — interaction hierarchy

Question:

> Before clicking, is the exact intended operation visually obvious without obscuring the Matter being inspected?

Required:

- one primary target cue,
- correct depth/occlusion by default,
- clear distinction between REMOVE, PLACE and outside-storage EXPAND,
- exact cell/face is unambiguous,
- feedback does not cover most of the target geometry,
- successful edit receives a brief causal confirmation that then recedes,
- invalid/rejected operations communicate failure without becoming persistent debug clutter.

The previous `no_depth_test` wire cube is classified as engineering debug presentation and cannot remain the default Owner cue.

## V-F — world / motion causality

Question:

> Can translation, rotation, release, split and freeze be read relative to the world?

Required:

- reference environment provides subdued spatial scale and motion parallax,
- release itself reads as a state change, not unexplained movement,
- finite impulses and yaw can be visually perceived relative to stable reference cues,
- freeze reads as the current pose becoming static,
- successor motion after split reads as independent physical state, not graphical detachment.

Do not fake motion with presentation effects. Visuals explain the actual physical state.

## V-G — UI hierarchy

Question:

> Is the world the dominant visual content?

Required:

- default UI is compact and action-oriented,
- engineering telemetry is hidden or secondary by default,
- persistent control instructions do not occupy a large top strip during normal use,
- state icons/labels complement world cues rather than replace them,
- reticle is subordinate to the target cue.

The failed P1 HUD is the negative baseline: a wide engineering panel is not acceptable as the default Owner presentation.

## Review protocol

Every material visual tranche must:

1. capture the unchanged baseline for the same deterministic state,
2. make one bounded hypothesis/change family,
3. capture the same rendered states afterward,
4. inspect before/after images directly,
5. record what improved, regressed or remains ambiguous,
6. keep mechanical gates green,
7. reject the tranche if it improves a screenshot while harming causal/system readability elsewhere.

Image metrics may catch obvious collapse, for example near-black/near-white coverage or framing occupancy. They are guardrails only. Human visual review remains required because the target is semantic readability, not an optimized histogram.

## G8 promotion gate

A new Owner package may be generated only when:

- mechanical P1 suite is green,
- rendered capture lane is green on the chosen parity path,
- V-A through V-G each have current rendered evidence and no material FAIL,
- a complete autonomous rehearsal video has been inspected frame-by-frame,
- the result is clearly superior to both P0.5 and the failed P1 candidate as an observable research instrument,
- remaining defects are written down before packaging.

Passing this contract does not mean final game art. It means the Owner can finally see and judge the actual FrameMatter systems without reconstructing them mentally from broken debug pixels.