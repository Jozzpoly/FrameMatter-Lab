# P1 integrated Owner candidate

Status: **AUTOMATED INTEGRATED + CANONICAL + DELIVERY PASS / OWNER INTERACTION PENDING**

This record closes the destructive P1 rebuild campaign at the next human-test boundary. It does not declare P1 product/playability quality. It records that the rebuilt consumer and the defended substrate now compose strongly enough to justify a new Owner-facing executable.

## Why P1 existed

The second P0.5 Owner run showed that the old LAB was no longer an adequate measurement surface. The problem was broader than visual roughness: the visible world floor was physically fake, the actor was not volumetric, destructive editing did not consume live topology succession, storage had an invisible fixed bound, activation used unexplained hard-coded motion, camera/context and interaction semantics were weak, and P0.5 inheritance had become prototype glue.

The P1 campaign therefore preserved defended substrate evidence while replacing the consumer/scene/interaction layer aggressively.

See `docs/p1-professional-rebuild-audit.md` and `docs/evidence/p1-evidence-gate-reset.md`.

## Evidence reset and gate hardening

Early P1 work exposed a false-green path: Godot could emit script/runtime errors while a probe still printed its PASS marker and exited in a way CI accepted. All pre-strict P1 PASS claims were therefore treated as provisional until re-earned.

The current P1 evidence contract now requires:

- strict project import,
- real project-class dependency loading,
- expected PASS marker,
- process exit success,
- **no engine-level `ERROR:` or script error in the probe log**,
- bounded probes before the integrated causal loop.

The historical `run_godot_clean.sh` wrapper was also raised to the same zero-engine-error evidence floor. Validate research harness run `#304` / `34963534245` then passed both the current-campaign controls and the defended fast-invariant set under that stricter rule.

## Cross-platform import finding

The first Windows P1 diagnostic appeared to lose `class_name` registrations after a nominal editor import. The project itself was not changed to accommodate that symptom.

The cause was the CI process boundary: the Windows editor process was not synchronously awaited. `ci/run_godot_import.ps1` now waits for real process completion and verifies `.godot/global_script_class_cache.cfg` before behavioral probes.

After that correction, canonical P1 startup and the composed P1 scene pass on Godot 4.7.2 Windows as well as Linux. This is evidence against treating the earlier symptom as a P1 architecture or Godot runtime failure.

## P1 rebuilt consumer

The current P1 Owner-facing scene uses:

- a real collision-bearing world reference,
- a query-based volumetric capsule actor rather than the P0 single-ray proxy,
- logical-Space support semantics without implicit kinematic push authority,
- a dedicated SpringArm camera rig that retains actor + Space context,
- a multi-Space registry that follows provider changes and one→many succession,
- one primary edit mode/outline instead of simultaneous competing previews,
- live topology consequence after destructive edits,
- expandable bounded dense local storage through explicit storage-frame maintenance,
- fresh Matter lineage issuance below the interaction/UI layer,
- zero-launch static→dynamic release,
- finite central/torque impulse control rather than hidden perpetual velocity,
- static freeze at the solver-owned current pose.

The current scope remains world-up / translation+yaw for actor support. Arbitrary pitch/roll gravity/orientation semantics remain open.

## Material integration failure found and fixed

The bounded storage probe initially showed that storage rebasing itself preserved retained Matter world state essentially exactly, but it did not test actor/camera relations.

A dedicated actor-context challenger forced a `local_shift=(4,0,0)` and exposed a real consumer bug:

- Matter world error: about `0.00000048 m`,
- actor support-local error: `4.00000000 m`,
- latent support-anchor error: `4.00000000 m`,
- actor jump after subsequent physics: about `4.00002813 m`,
- camera-context error: about `3.99999952 m`.

The substrate was correct; consumer coordinates were stale.

The fix remained consumer-side. `SpaceQueryCharacter` gained explicit support-coordinate rebase maintenance, and P1Main consumes `storage_rebased` to remap actor support and refresh camera context. The same challenger then measured:

- support-local error `0`,
- immediate actor world error `0`,
- latent anchor error `0`,
- camera-context error `0`,
- Matter world error about `0.00000048 m`,
- post-two-frame actor displacement about `0.00012493 m` rather than four metres.

No storage/provider workaround was required.

## Sharpened actor and topology evidence

Actor telemetry originally printed wall/ceiling counters from the wrong probe instance. The corrected P1 volumetric actor run reports:

- `wall_blocks=23`,
- `ceiling_blocks=1`,
- moving-support local drift about `0.00000691`,
- moving-Space walk distance about `0.720004`,
- injected linear velocity delta `0`,
- injected angular velocity delta `0`.

Topology telemetry was also sharpened. The old `actor_world_delta` mixed instantaneous succession with later legitimate rigid motion. The current live-topology probe measures source→successor handoff at the transaction boundary separately from subsequent motion. Representative strict result:

- handoff world error about `0.00000048 m`,
- later dynamic motion about `0.195842 m` in the sampled post-handoff interval.

The defended claim is therefore exact continuity at the tested handoff, not that a dynamic successor stops moving afterward.

## Integrated causal-loop gate

The canonical P1 pressure gate is `tests/p1_integrated_causal_loop_probe.gd`.

It exercises one causal chain rather than a catalogue of isolated mechanisms:

> grounded actor → zero-launch release → finite impulse + torque → ride moving Space → edit/build while moving → force storage-edge expansion with non-zero coordinate-frame shift → mapped placement + fresh lineage → continue moving → destructive cut → one→many topology succession → exact actor/camera handoff → freeze the actor-owned successor.

P1 rebuild validation run `#78` / `34963369099` first passed this integrated chain. Representative metrics:

- forced storage shift `(3, 0, 0)`,
- mapped outside-storage cell `(2, 0, 8)`,
- linear state error after rebase `0.00000000`,
- angular state error after rebase `0.00000000`,
- topology handoff world error `0.00000125 m`,
- two live successor Spaces,
- pre-edit ride anchor error `0.00000135 m`,
- final actor/support anchor error after successor freeze `0.00000098 m`.

This is the first P1 result that defends composition of the rebuilt consumer, storage maintenance, finite control, topology succession and lifecycle replacement in one shared runtime chain.

## Canonical promotion

The branch now makes P1 the project startup contract:

`application/run/main_scene = res://p1/main.tscn`

Owner controls are persisted in the project InputMap rather than existing only as runtime fallback actions.

`tests/p1_canonical_startup_smoke.gd` reads the configured main scene from `ProjectSettings`, verifies it is P1, checks the persisted control contract, instantiates the configured scene, resolves the P1 actor/camera/registry/control/interactor roles, and verifies actor + camera acquire the authored logical Space.

P1 rebuild validation run `#85` / `34964102959` passed canonical startup and the complete P1 chain on Linux; its Windows lane independently passed synchronous import, canonical startup and composed-scene foundation.

## Owner-candidate delivery

Delivery workflow `Deliver P1 Owner Candidate` run `#7` / `34964102720` passed its own independent strict chain before export:

- project import,
- P1 dependency graph,
- canonical startup,
- volumetric actor,
- composed scene,
- multi-Space registry,
- live topology,
- storage rebase,
- actor/camera storage-frame continuity,
- finite Space control,
- integrated causal loop,
- Web export,
- Windows export.

Artifacts were produced from branch head `1aba3d50382df59a751372d66e5521dc80e92ba9`; GitHub Actions checked out the corresponding PR merge commit `13e65a7d22defa87f7af88125c7a83421566d803`, which is recorded inside `P1-BUILD-INFO.txt`.

### Windows artifact

GitHub artifact: `FrameMatter-P1-Windows`

- artifact ID `10394293441`,
- artifact ZIP SHA-256 `fcc3a4d3d2b5c650cd6c6b87b9c31e0b6ed35f8782a230b0a2e98035a6329700`,
- executable `FrameMatter-P1-Owner-Candidate.exe`,
- executable size `109740584` bytes,
- executable SHA-256 `9a73c77ba3a939a53541670861322ea3c27125e0df9ca20864895a1b458f88ee`,
- inspected as PE32+ Windows GUI x86-64,
- embedded product strings report `FrameMatter P1 Owner Candidate`.

### Web artifact

GitHub artifact: `FrameMatter-P1-Web`

- artifact ID `10394259313`,
- artifact ZIP SHA-256 `21eaa3c22fb84db931c365bb225d8fc059731fe5b75bc6d120e9f832fdde74ce`,
- contains `index.html`, `index.js`, `index.wasm`, `index.pck` and candidate provenance,
- this is an export/package PASS, not a claim that a permanent hosted URL exists.

## Current Owner controls

- `WASD` — actor movement,
- `Space` — jump,
- `T` — zero-launch release / freeze focused Space,
- `↑` / `↓` — finite forward/back central impulse pulses,
- `←` / `→` — finite yaw torque pulses,
- `E` — switch REMOVE / PLACE,
- `LMB` — apply current edit,
- `MMB + mouse` — orbit camera,
- mouse wheel — zoom,
- `Home` — reset camera,
- `K` — actor recovery for test continuity,
- `R` — reset experiment.

Out-of-storage PLACE is now actionable: the interaction requests a bounded storage-frame maintenance transaction, then the mapped Matter placement occurs after the rebase commits.

## What this establishes

Within the tested world-up / translation+yaw scope, the current P1 candidate demonstrates that:

- one logical editable Space can change static/dynamic providers without hidden launch,
- solver-owned finite motion can coexist with actor support,
- Matter can be edited while that Space moves,
- local storage can rebase/expand without moving retained Matter or breaking actor/camera relations,
- fresh Matter can be placed after that coordinate maintenance through the same authority path,
- destructive topology can retire one moving Space into independent successors,
- actor and camera context can follow the appropriate successor with near-numerical-continuity handoff,
- the successor can return to a static representation at its current pose,
- the canonical project and exported Owner candidate run this rebuilt P1 consumer rather than the historical P0/P0.5 LAB.

## Explicit nonclaims

This PASS does **not** establish:

- Owner approval or good playability,
- polished movement/camera/editing feel,
- production UI or visuals,
- arbitrary pitch/roll locomotion or local gravity/adhesion semantics,
- finite actor↔construct reaction-force gameplay,
- scalable/infinite world storage,
- final chunk/streaming architecture,
- persistence/save/load identity,
- canonical-world extraction/reintegration,
- planetary/curved Matter,
- vehicle framework,
- production performance at large Matter extents.

The dense expandable storage mechanism is bounded evidence, not a world architecture. R2A still warns that update locality must not be conflated with final collider/world partitions.

## Decision

**Stop autonomous feature expansion at this boundary.**

The next highest-information evidence is direct Owner interaction with the P1 Windows candidate. The Owner run should be exploratory rather than scripted tightly, but useful pressure includes:

- whether movement/camera now expose the world instead of fighting it,
- whether REMOVE/PLACE targeting is understandable,
- whether storage-edge building feels continuous rather than like a hidden boundary,
- whether zero-launch release + finite impulses make Space motion causally legible,
- whether riding/editing a moving Space remains understandable,
- whether destructive cuts visibly produce believable independent successors,
- whether freeze feels like the same Space/state becoming static rather than a reset,
- which limitation now dominates once the old P0/P0.5 consumer failures are removed.

A negative or awkward Owner result is useful evidence. It should route the next campaign; it must not be hidden by open-ended polish before testing.
