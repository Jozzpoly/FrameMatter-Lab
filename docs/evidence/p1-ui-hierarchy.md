# P1 V-G UI hierarchy

Status: **BOUNDED PASS / COMPACT OWNER INSTRUMENT PROMOTED**

## Question

> Is the world the dominant visual content?

This tranche addressed the remaining V-G defect after G2–G6: the default HUD was still a wide engineering strip containing actor/support state, target coordinates, velocity/angular velocity, a full control legend and the latest runtime event. That information was useful diagnostically, but it competed directly with the world and repeated the presentation pattern of the failed P1 Owner candidate.

## Bounded hypothesis

Keep only persistent information that is immediately actionable and not already better communicated by world presentation:

- STATIC / DYNAMIC state,
- REMOVE / PLACE edit mode,
- live Space count,
- a short four-action reminder.

Engineering telemetry remains available to tests/runtime diagnostics but is not the default Owner-facing surface.

## A/B evidence

A deterministic Windows Godot 4.7.2 Forward+ / D3D12 lane compared the unchanged legacy HUD against the compact challenger across:

- default static,
- zero-motion release,
- finite translation/yaw,
- topology split with two successors.

The first compact run was correctly rejected by the strict runner because the challenger attempted to read host state before `P1Main` had entered the SceneTree. All requested PNGs had rendered, but the run contained a real `SCRIPT ERROR`; the gate remained red. The presenter lifecycle ordering was fixed rather than weakening the error floor.

The clean exact-source A/B is workflow run `35019353162` on commit `a3a02180ebfebbfa3c464eca8c29a836d770d95f`:

- compact artifact `10417181230`, digest `sha256:2a840f562b6fc417c43ac45959078a0bd7f43818f71f8fb9643ad1ad295f6a6d`,
- baseline artifact `10416283536`, digest `sha256:2cc45410cbdacb4d97a5bab8e492f5cfb25d8e9b0322f7f93878f184fa825dd1`.

The compact panel remained approximately `330 x 61 px` and did not expand in DYNAMIC or two-Space states. Direct pixel review found that it restored world dominance while preserving the minimal state needed to orient the experiment. The legacy strip was rejected.

## Production promotion

The winning hierarchy was promoted as the canonical `P1HudPresentation` consumer. The authored scene starts at compact dimensions so there is no one-frame wide-HUD flash. The legacy `_update_hud()` writer was removed from `p1/main.gd`; the new presenter is the only default HUD writer rather than a later layer that merely overwrites old telemetry.

The resolved baseline/compact matrix was then retired from active CI. Historical A/B artifacts preserve the comparison; the active lane now tests only canonical production presentation.

## Final exact-source closure

Final production source: `fb3dd5c898ed288a4a264aace088cc89433b640e`.

Canonical UI workflow run `35019781304` passed on Windows Forward+ / D3D12. Artifact `10417047660`, digest `sha256:9bdacfb195f7c731682df4a3d96ff4aedda4dddf5a3a6144a39dc3753bf29c54`.

Human pixel review of all four canonical frames found:

- STATIC remains clear while the panel occupies only a small top-left region,
- zero-motion release changes the compact state label to DYNAMIC without implying movement,
- finite motion remains readable from world/grid cues rather than velocity telemetry,
- split remains a world event; the HUD only changes to `2 SPACES` and does not grow or explain the event for the pixels.

The same commit also passed:

- P1 rebuild validation run `35019780961`,
- G4 camera evidence run `35019780966`,
- G5 interaction evidence run `35019781002`,
- G6 world causality evidence run `35019781022`,
- general rendered parity run `35019780965` on Windows D3D12 and Linux Compatibility,
- Owner-readiness verifier run `35019780980`,
- research-harness validation run `35019781040`.

Targeted same-source G5 pixel review confirmed that the smaller UI-owned region did not regress pointer-owned REMOVE / rejection feedback / out-of-storage EXPAND behavior. General rendered spot checks likewise showed no return to HUD-dominated composition.

## Gate result

**V-G UI hierarchy PASS within the current P1 desktop/mouse Owner-facing surface and tested representative states.**

The world is now the dominant visual content. Persistent engineering telemetry is no longer part of the default presentation, and the control reminder no longer occupies a wide top strip.

## Explicit nonclaims

This does not claim:

- final typography or art direction,
- controller/touch/VR UI,
- complete discoverability of every advanced control,
- accessibility validation,
- cross-layer composed rehearsal,
- adversarial G8 readiness,
- final Owner candidate approval.

The next question is not another isolated HUD refinement. It is whether G2–G6 plus this UI hierarchy remain jointly understandable during one continuous composed rehearsal.
