# P1 G1 — rendered visual baseline

Status: **PASS AS EVIDENCE HARNESS / VISUAL BASELINE ITSELF FAILS**

This record closes G1 of the P1 Owner-facing recovery campaign: the project can now capture and inspect actual rendered pixels before changing presentation.

It does **not** claim the current presentation is acceptable. The captures exist specifically because the current presentation is materially bad.

## Source Owner evidence

The first packaged P1 Owner recording is about 35.8 seconds and is retained as the primary human-environment negative baseline.

Across the recording the dominant failures include:

- large horizontal Matter surfaces collapsing toward black,
- directly lit vertical faces reading as flat pale/white planes,
- almost no visible cell/edit granularity,
- through-wall debug target wire,
- actor-centric close framings that can consume the view,
- wide persistent telemetry/control HUD,
- weak world/motion reference,
- weak STATIC/DYNAMIC state language.

Evidence record: `docs/evidence/p1-owner-interaction-failure.md`.

## Capture harness

`tests/p1_visual_capture.gd` instantiates the real P1 scene and records deterministic PNGs for:

1. `00_initial_static`,
2. `01_released_dynamic`,
3. `02_dynamic_motion`,
4. `03_storage_rebase_build`,
5. `04_split_successors`,
6. `05_frozen_successor`.

The sequence uses the same shared P1 mechanisms exercised by the integrated causal-loop gate rather than constructing presentation-only mock geometry.

The capture waits for a rendered frame and saves the actual viewport texture.

## Linux Compatibility lane

The first reliable rendered lane uses:

- Godot 4.7.2,
- Ubuntu GitHub Actions runner,
- Xvfb,
- Mesa llvmpipe,
- `gl_compatibility`,
- explicit Dummy audio driver,
- strict rejection of engine/script `ERROR:` output.

Rendered-evidence run `#3` / `34969638626` passed and uploaded artifact `FrameMatter-P1-Rendered-Evidence` / artifact ID `10396492476`.

The resulting images are already visibly unacceptable even though they do not reproduce the Windows black-face failure exactly:

- broad Matter surfaces read as flat pale/white boards,
- cell scale is effectively absent,
- the wire target is engineering debug language,
- split successors do not visually communicate the topology event clearly,
- the persistent HUD competes strongly with the world.

This lane is useful as a stable cross-renderer guardrail, not as Owner-platform parity.

## Linux Forward+ attempt — rejected as parity evidence

A Forward+ capture was attempted under Xvfb. Godot emitted:

`Required Vulkan instance extension VK_KHR_surface not found.`

It then fell back to Compatibility and rendered frames. The strict evidence wrapper rejected the run because an engine `ERROR:` had occurred.

Therefore Xvfb Forward+ is not used as a parity claim on this hosted runner.

## Windows desktop parity lane

The Windows lane uses:

- Godot 4.7.2 Windows,
- Windows GitHub Actions runner,
- a real non-headless rendering process,
- Forward+,
- explicitly selected Direct3D 12 rendering driver,
- Dummy audio,
- strict error rejection.

Selecting D3D12 explicitly was necessary because the hosted runner lacks a Vulkan surface; allowing Godot to first fail Vulkan and fall back to D3D12 would contaminate strict evidence with engine errors.

The D3D12 Forward+ path successfully renders the six deterministic frames without engine/script errors.

## Material baseline finding

The Windows D3D12 capture reproduces the critical visual character of the Owner failure:

- the large top Matter surface is essentially black,
- selected vertical surfaces are pale/white,
- the object reads as disconnected high-contrast sheets rather than an editable coherent volume,
- cell structure is absent except for the target debug wire,
- topology split reads weakly because successor identity/state is not visually explained.

This makes the Windows lane the current closest CI parity instrument for G2–G6.

## Why the two lanes both remain useful

Windows D3D12 is the acceptance-relevant visual lane.

Linux Compatibility is intentionally retained as a secondary renderer guardrail because it fails differently: the same scene tends toward flat bright boards rather than the Owner's black-collapse. A visual change should not accidentally trade one backend catastrophe for another.

Backend differences must remain explicit in evidence.

## G1 decision

**G1 PASS as instrumentation. Current P1 visuals remain FAIL.**

The project now has a rendered evidence surface strong enough to begin bounded presentation experiments.

Next move is G2-A only:

- correct the P1 Environment ambient source from SKY to COLOR,
- explicitly set sky contribution to `0.0`,
- make no simultaneous changes to DirectionalLight energy/rotation, Matter materials, cell language, camera or UI,
- rerun the exact Windows + Compatibility capture states,
- accept or reject the lighting hypothesis from rendered A/B evidence.
