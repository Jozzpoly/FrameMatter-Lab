# P1 R-V4 — camera visual safety

Status: **PASS / COLLISION-CLEAR HIGH-PITCH ESCAPE PROMOTED**

Owner-failed visual baseline: `b5050b669ec4101226095183929f5790f0a034fc`

Final production source: `ee810585184680c5f6de975ecbd8945c845885aa`

Production camera-policy implementation commit: `6a71c55527f45a8874ae58e8742becac3c6bdf46`

Renderer: Windows Godot 4.7.2 Forward+ / D3D12

## Owner-visible failure

The Owner recording showed a camera failure under close obstruction: the view collapsed onto the local avatar and ceased to be a useful third-person representation of the world.

The first working hypothesis was stronger than the evidence warranted: that `Camera3D` was physically entering the visible avatar capsule. R-V4 explicitly tested that hypothesis rather than encoding it as the acceptance contract.

## Deterministic real-Matter reproducer

R-V4 uses the canonical P1 scene and creates a tight open-top Matter ring around the actor through the normal P1 PLACE edit path. The actor is held at a fixed point only to isolate the camera/presentation question; the obstruction itself is real P1 Matter and therefore uses the normal representation/collision path.

The harness measures the final Camera3D position rather than only requested SpringArm distance:

- actual final SpringArm length,
- camera-to-visible-CapsuleMesh signed distance,
- sustained visual-unsafe frames,
- avatar visibility,
- Owner pitch intent versus presentation-only runtime pitch,
- movement/control forward frame.

The stress fixture intentionally distinguishes world-collision safety from visual safety.

## Baseline acquisition and hypothesis correction

### First falsification run

Workflow run: `35112752651`

Exact source: `f2c995d3f8373e128b94bddf0ead569e38aa9bae`

Artifact: `10452609167`

Digest: `sha256:4742c77434b5e973cc97ba3afff46df931035d2e7566779f4c4304ca9a99c60a`

Open reference:

- desired / actual arm: `8.1869 m / 8.1869 m`,
- avatar signed distance: `+7.8995 m`.

Tight Matter enclosure:

- desired arm: `8.2603 m`,
- actual arm: `0.4792 m`,
- avatar signed distance: `+0.1953 m`,
- Camera3D-inside-avatar frames: `0 / 30`.

This run correctly failed the original test assertion that the camera must cross the CapsuleMesh surface. The product failure was nevertheless visibly reproduced: the opaque blue avatar occupied almost the entire frame.

Therefore the original geometric hypothesis was rejected.

The corrected R-V4 failure model is:

> a camera can remain world-collision-safe and geometrically outside the avatar while still becoming visually unusable because severe SpringArm compression destroys third-person context.

### Corrected perceptual baseline

Workflow run: `35113206984`

Exact source: `e6ea363b25d907a555d68e5024589470421b5a88`

Artifact: `10452858200`

Digest: `sha256:869f246474c727b16b5f013a8a28e1bba4dd1e7ef6b4de5b805887657609e882`

The same enclosure produced:

- `30 / 30` visual-unsafe frames,
- actual arm fixed at `0.4792 m`,
- avatar signed distance fixed at `+0.1953 m`,
- no geometric penetration.

The corrected baseline therefore reproduces the Owner-observed failure without requiring a false penetration claim.

## Rejected challenger — near-avatar hide

A bounded `near_hide` diagnostic tested whether hiding only the local avatar would be sufficient while preserving the exact same camera/world state.

Same-source A/B workflow: `35113678863`

Exact source: `f9b3aa8801bbe017ef4e7b439189609fb851e776`

Artifacts:

- baseline: `10453636677`, digest `sha256:fadf513ef8a8344cb64af3ca8da08ed1d0670c653c497e2c8c1fbed744bd7879`,
- near-hide: `10453915161`, digest `sha256:2db91b0ccf0545ab0d49e06318543df04b56da29efaf4faab14fe0dd9b970a90`.

Mechanically, near-hide reduced visible-avatar hazard from `30 / 30` to `0 / 30` while keeping the same `0.4792 m` camera compression.

Manual rendered review rejected it. Removing the blue capsule exposed only the immediately adjacent Matter wall/corner; orientation and useful world context were still absent.

**Verdict: REJECTED.** Hiding the avatar removes one occluder but does not solve the actual composition failure.

## Accepted diagnostic challenger — overhead collision-clear escape

Source: `614c00ec70f6f1ffa30de773eee05ab9762141e8`

Workflow run: `35116119034`

Job: `104862169477`

Artifact: `10455597521`

Digest: `sha256:973bf1eff95db631fac9b13f1cf80355d51b1098e1b6ffe0689fc02cfcbb82bd`

The diagnostic challenger forced a high presentation pitch only to answer one bounded question: does the real Matter fixture contain a collision-clear camera route that can recover useful context without passing through geometry?

Result under the same tight enclosure:

- actual arm: `8.2603 m`,
- recovered-arm frames: `30 / 30`,
- visual-unsafe frames: `0 / 30`,
- inside-avatar frames: `0 / 30`,
- avatar remained visible,
- camera body-local position rose above the open ring rather than passing through its walls.

Manual rendered review showed a readable overhead view of the local Matter layout, the actor inside the ring, and surrounding geometry. This materially restored orientation, unlike near-hide.

The challenger therefore established that the existing collision geometry permits a safe open-top escape route.

## Production policy

The production fix is intentionally smaller than the diagnostic challenger.

P1 already had a presentation-only escape-orbit search that tests nearby yaw/pitch candidates using a real collision probe while keeping Owner control yaw separate from `_runtime_yaw` / `_runtime_pitch`.

Commit `6a71c55527f45a8874ae58e8742becac3c6bdf46` extends only that existing candidate space:

- low/side escape candidates remain available and are still preferred by the existing scoring when sufficiently clear,
- additional higher pitch candidates are eligible when ordinary routes remain heavily obstructed,
- presentation pitch may reach `1.50 rad` during collision recovery,
- Owner `_pitch` is not mutated,
- movement/control yaw remains derived from Owner `_yaw`,
- no teleport, collision bypass, new gameplay authority or separate camera mode is introduced.

This keeps the solution within the existing camera architecture: search for the best collision-clear presentation orbit, but allow the search to look upward when the local geometry demands it.

## Exact-source production proof

Workflow run: `35116766161`

Job: `104864285838`

Exact source: `ee810585184680c5f6de975ecbd8945c845885aa`

Artifact: `10455503692`

Digest: `sha256:c111e2bbc8e153e0b9c684d527e8149b475a0f5dfda490cd5a779d62d57eb070`

### Open reference

- desired / actual arm: `8.1869 / 8.1869 m`,
- Owner pitch: `0.4800 rad`,
- runtime pitch: `0.4800 rad`,
- avatar visible,
- visual-unsafe: false.

### Tight real-Matter obstruction

Production policy automatically selected the high collision-clear route; the test does not force pitch.

- desired / actual arm: `8.2603 / 8.2603 m`,
- recovered-arm frames: `30 / 30`,
- visual-unsafe frames: `0 / 30`,
- visible-hazard frames: `0 / 30`,
- inside-avatar frames: `0 / 30`,
- avatar signed distance: `+8.0100 m`,
- Owner pitch remained `0.4800 rad`,
- presentation-only runtime pitch reached `1.4800 rad`,
- movement/control frame remained unchanged.

### Obstruction removal / return

The Matter ring is then removed through the normal P1 REMOVE edit path and the production camera is observed for 30 additional frames.

Final state:

- desired / actual arm: `8.1869 / 8.1869 m`,
- Owner pitch: `0.4800 rad`,
- runtime pitch: `0.4800 rad`,
- avatar visible,
- movement/control frame unchanged.

The automatic escape therefore does not mutate Owner camera intent or leave the camera stuck in the emergency presentation.

## Rendered production review

Production artifact frames were manually inspected.

`01_tight_matter_enclosure.png` shows the same readable overhead composition established by the accepted diagnostic challenger: the actor remains visible inside the ring and the surrounding Matter layout is legible.

`02_post_obstruction_recovery.png` returns to the ordinary third-person composition rather than remaining overhead.

Quantitative pixel comparison:

### Production tight obstruction vs accepted overhead challenger

- changed pixels: `215 / 740,160` (`0.029048%`),
- pixels with any RGB channel delta > 2: `0`,
- mean absolute RGB delta: `0.000127`,
- maximum RGB channel delta: `1`.

This is effectively raster-equivalent.

### Production post-recovery vs production open reference

- changed pixels: `733 / 740,160` (`0.099033%`),
- pixels with any RGB channel delta > 2: `16` (`0.002162%`),
- mean absolute RGB delta: `0.000483`,
- maximum RGB channel delta: `14`.

Manual inspection finds no structural composition difference. The post-recovery view has returned to the ordinary reference framing.

## Wider regression evidence at the production source

Exact `ee810585184680c5f6de975ecbd8945c845885aa` also passed:

- P1 rebuild workflow `35116765977` — both `p1-foundation` and Windows composed-scene diagnostic GREEN,
- historical G4 camera evidence workflow `35116766031` — GREEN.

The P1 foundation re-proved canonical startup, procedural Matter orientation, provider visual identity, actor behavior, multi-Space lifecycle, topology consumer behavior, grid/state-presentation lifecycle, storage rebase, actor/camera storage continuity, camera/control-frame separation, finite Space control and the integrated causal loop.

The G8 frozen-candidate workflow at this source does not provide runtime regression evidence because it stops before runtime execution while the visual-rebuild campaign is intentionally not in a frozen/approved-candidate readiness state. That governance lane must not be misread as a camera failure.

## Verdict

**PASS.**

R-V4 replaces the overly narrow invariant “camera must not enter avatar geometry” with the stronger practical requirement:

> under real obstruction, production camera policy must preserve a useful world composition; severe collision compression may trigger a presentation-only collision-clear escape without mutating Owner camera intent or movement/control authority, and the presentation must return when the obstruction clears.

The promoted policy satisfies that contract for the deterministic open-top real-Matter stress case and preserves prior G4 behavior.

## Nonclaims / open work

R-V4 does not establish:

- that every future arbitrary enclosed geometry has a recoverable third-person route,
- a general solution for fully sealed spaces where no collision-clear distant camera position exists,
- final camera art direction or preferred overhead angle,
- that high-pitch escape must remain the long-term answer if later geometry/world design changes,
- accumulated chaotic-session gestalt,
- Owner readiness or candidate freeze.

A genuinely sealed-space case may require a different bounded fallback, but it is not justified to build that mechanism without evidence that the active P1 Owner surface needs it.

The next active visual-rebuild tranche is R-V5 accumulated chaotic Owner-surface rehearsal.
