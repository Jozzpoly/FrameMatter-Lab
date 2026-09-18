# P1 G5 — interaction visual hierarchy

Status: **BOUNDED PASS / POINTER + FACE-LED INTERACTION PROMOTED**

Verified runtime/evidence commit: `8e6431d7a64c9f80f0c70b81d4d486e066d8496e`

G5 asks an interaction-language question rather than an edit-mechanics question:

> can an informed reviewer point at visible Matter and understand the exact hit face, the intended REMOVE / PLACE / EXPAND consequence, and the immediate success or rejection without relying on a center reticle, through-wall debug geometry or persistent engineering telemetry?

The bounded answer is **yes for the current authored P1 scene, pointer/mouse interaction model and Windows D3D12 Forward+ evidence path**.

This is not a claim that the complete UI, input model or interaction feel is final.

## Starting failure

The pre-G5 interaction surface used a center-reticle ray and a full-cell wire cube whose material explicitly disabled depth testing.

That design had two material problems:

- target geometry could draw through the actor or other occluding world geometry,
- the full cube described a debug volume more strongly than the exact visible face and operation consequence.

The center reticle also made off-center visible surfaces unnecessarily hard to acquire. A particularly useful EXPAND fixture showed a physically visible top face in the viewport while the center ray selected a different in-storage cell.

The old `no_depth_test` wire cube is therefore retained only as negative design evidence. It has been removed from the canonical interactor.

## Challenged directions

### Depth-tested full destination prism

The first face-led challenger anchored to the real hit face and obeyed world depth, but PLACE / EXPAND still extruded a nearly full destination-cell prism.

That materially improved occlusion truth, yet the EXPAND cue could extend high enough to compete with the HUD or leave the useful viewport. It also continued to read too much like a debug destination box.

**Result: rejected as the promoted geometry.**

### Face-led presentation with center acquisition

The compact surface cue was already cleaner, but center acquisition kept REMOVE near the actor and could make the correct depth-tested cue disappear behind the actor. Restoring through-wall visibility would have repeated the original failure.

**Result: center-reticle acquisition rejected as the default interaction model.**

### Pointer + compact face-led prediction

The surviving direction changed acquisition and presentation together:

- pointer screen position is the production ray source,
- the same existing physics ray → Space → face → cell resolver remains the targeting authority,
- HUD ownership is checked before the world ray so the pointer cannot target Matter through the top panel,
- the old central `+` reticle is absent because it would lie about the acquisition source,
- target presentation is a sibling consumer of the interactor rather than a second targeting authority.

**Result: promoted.**

## Promoted target language

`P1MatterTargetPresentation` is now the sole target presenter.

It derives geometry only from the existing resolved `target_space`, `remove_cell`, `place_cell`, edit mode and storage relation. It owns no Matter, topology, provider, collision or target-selection authority.

All target cue materials obey normal depth testing.

### REMOVE

REMOVE uses a restrained red-family square on the exact shared hit face plus an `X` mark.

The cue is physically occluded when the target face is occluded; it cannot draw through the actor or world geometry.

### PLACE

PLACE keeps the source face as the visual anchor and adds only a shallow directional extrusion and a small creation `+` on the cap.

This communicates “create the adjacent cell on this side of this face” without requiring a full ghost cube.

### EXPAND

Out-of-storage PLACE uses the same operation family in cyan and adds a second cap ring. The storage-boundary consequence is therefore related to PLACE but still visually distinct.

The shallow geometry remains local to the visible face instead of extending a full future cell into HUD/off-screen space.

## Acquisition and UI ownership

Production `P1MatterInteractor` defaults to pointer acquisition.

`update_target_from_pointer_position()` checks UI ownership before entering the shared physics-ray resolver. The current HUD panel is a concrete blocker, and hovered visible controls are also treated as UI-owned.

The final evidence explicitly probes `(50, 50)`, confirms that this point lies inside the HUD blocker, and proves that the world target is cleared.

The central reticle was removed from the production HUD because a fixed center marker would falsely imply center-ray authority after pointer promotion.

## Causal transient feedback

`P1InteractionFeedback` is a presentation consumer of existing `edit_applied` and `edit_rejected` signals.

Successful edits show a short local `REMOVED` or `PLACED` confirmation. Rejected edits show `BLOCKED`. Feedback fades automatically instead of becoming permanent telemetry.

The final evidence sequence performs real mutations rather than manually emitting signals:

1. acquire a real visible REMOVE target,
2. execute the real REMOVE mutation,
3. capture `REMOVED`,
4. attempt to REMOVE the same now-empty cell again,
5. prove the second mutation is actually rejected,
6. capture `BLOCKED`,
7. advance 96 frames and prove the feedback is no longer visible.

Success feedback is projected from the resolved world face when available. Rejection without a live target falls back to the real pointer position, preserving causal locality.

## Evidence-harness corrections

G5 found two important evidence defects. Neither was solved by changing product semantics.

### False rejection locality failure

The first deterministic rejection capture drove an explicit screen-point ray but left the OS/window mouse at the viewport center. Production rejection fallback correctly used the live mouse position, so the evidence screenshot placed `BLOCKED` near the center and falsely suggested a product bug.

The harness now warps the live pointer to the exact attempted screen point, waits a frame, asserts pointer agreement, then performs the real rejected edit.

The corrected screenshot places `BLOCKED` at the attempted surface. This is a harness correction, not a runtime workaround.

### Stale general visual camera helper

After G4 refactored camera presentation/control separation, the older general rendered harness still called removed private helper `_apply_orbit`. It captured many frames and even printed its PASS marker before the wrapper correctly rejected the emitted script errors.

The harness now uses the current immediate explicit-user-orbit path, `_apply_user_orbit_immediately()`.

At the same time, the general rendered workflow was hardened to check out the exact PR head/source SHA instead of GitHub's synthetic pull-request merge commit and to record source, checked-out and event commits separately.

## Final exact-source interaction evidence

Windows Godot 4.7.2 Forward+ / D3D12 workflow run `35015880416` checked out the exact source commit `8e6431d7a64c9f80f0c70b81d4d486e066d8496e`.

Artifact: `FrameMatter-P1-G5-Interaction-Evidence-Windows-Production`, artifact ID `10415129402`, SHA-256 `eebc6ecc3e48b774f2672f9d7b61ce4c8adeaaba6fff2d4ff4670f37e35b8a33`.

Final truth states include:

- REMOVE: pointer norm `(0.322, 0.383)`, source `(3, 2, 8)`, destination-side cell `(3, 3, 8)`, exact face `+Y`, in storage,
- PLACE: pointer norm `(0.322, 0.456)`, source `(3, 1, 8)`, destination `(3, 2, 8)`, exact face `+Y`, in storage,
- EXPAND: pointer norm `(0.671, 0.258)`, source `(8, 5, 8)`, destination `(8, 6, 8)`, exact face `+Y`, out of storage,
- HUD exclusion: `(50, 50)` clears world targeting,
- success feedback: real REMOVE produces `REMOVED`,
- rejection feedback: repeated REMOVE is rejected and produces `BLOCKED` at the attempted pointer location,
- feedback expiry: hidden after 96 advanced frames,
- retired `TargetOutline`: required to be absent from the production interactor.

Manual full-resolution review accepted the final REMOVE / PLACE / EXPAND and success/rejection frames. The final post-cleanup interaction captures are pixel-identical to the accepted pre-cleanup captures for REMOVE, REMOVE-success, REMOVE-rejection and PLACE. EXPAND differs only at 131 pixels with maximum channel delta 7/255, consistent with tiny independent render/solver variation and no semantic change.

## General rendered parity regression check

General rendered workflow run `35015880448` on the same exact source commit passed both renderer lanes after the stale-helper/provenance correction.

Windows artifact: `FrameMatter-P1-Rendered-Evidence-Windows-canonical`, artifact ID `10415468200`, SHA-256 `1811bc4e24616b448b9e10d9dcce21fcaf844f709d68e963daa4b841a4faee98`.

Linux compatibility artifact: `FrameMatter-P1-Rendered-Evidence-Linux-Compatibility`, artifact ID `10415697261`, SHA-256 `d7328fb318c02c5a81293341b4fce3853ef5fdfc387e633409121d209f75dd29`.

The sequence again covered canonical static, eight lighting azimuths, near/mid/far granularity, release, dynamic motion, storage-rebase build, split successors and freeze. Manual spot-check of the Windows initial/static, far-granularity, dynamic-motion and split frames found no material regression attributable to G5.

This is a regression check, not a claim that G6 world/motion/topology causality is already adequate.

## Same-source mechanical and camera evidence

P1 rebuild workflow run `35015880447` on the same source passed the full foundation job and Windows composed-scene diagnostic, including canonical startup, volumetric actor, registry/topology, promoted presentation lifecycles, storage rebase, actor/camera continuity, camera control-frame separation, finite Space control and integrated causal loop.

G4 camera workflow run `35015880440` on the same source also passed its exact-source Windows D3D12 stress sequence.

This removes the possibility that G5 was accepted only on an interaction-specific fixture while breaking the defended mechanical or camera substrate.

## What G5 establishes

Within the current authored P1 scene, pointer/mouse interaction model and tested renderer path:

- visible pointer position owns world acquisition rather than a misleading center reticle,
- HUD-owned screen regions cannot silently target Matter behind UI,
- target authority remains the existing physical ray/Space/face/cell resolver,
- target presentation obeys world depth and no longer draws through occluders,
- REMOVE / PLACE / EXPAND form one related but distinct visual language,
- the exact hit face and operation side are readable before action,
- real success and rejection receive brief local causal confirmation,
- transient feedback recedes automatically,
- the old `no_depth_test` target cube and its `TargetOutline` node are absent from production,
- broader rendered and mechanical regression surfaces remain green on the same source.

Gate result: **interaction hierarchy PASS within the current P1 authored scene, pointer input model and Windows D3D12 evidence path.**

## Explicit nonclaims

G5 does **not** establish:

- final game/editor interaction feel,
- controller, touch, VR or accessibility input design,
- final colors, typography or art direction,
- broad color-vision accessibility proof,
- final HUD hierarchy or safe-area design,
- arbitrary dense geometry / arbitrary occluder layouts,
- arbitrary Matter scale or very large edit distances,
- G6 world/motion/topology visual causality,
- cross-layer composed rehearsal,
- adversarial G8 readiness,
- Owner readiness.

The top HUD remains engineering-heavy and is intentionally not smuggled into this PASS; `ui_hierarchy` remains a separate pending gate.

## Next move

Proceed to **G6 — world / motion / topology causality**.

G5 now provides a bounded trustworthy edit instrument. The next question is whether release, finite translation/yaw, storage-frame maintenance, split succession and freeze are visually understandable from the actual world and state change rather than primarily from the HUD text or prior engineering knowledge.
