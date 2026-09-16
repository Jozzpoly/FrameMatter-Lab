# P1 G8 candidate freeze revalidation

Status: **PASS / PROPOSED RUNTIME REVALIDATED ON ONE EXACT COMMIT**

## Frozen runtime candidate

Proposed runtime commit:

`b5050b669ec4101226095183929f5790f0a034fc`

This commit introduces `p1/CANDIDATE-FREEZE.md`, a runtime-neutral markdown marker whose location under `p1/` deliberately triggers the active P1 exact-source workflows. Godot does not load the marker.

A Git compare from the previously accepted cross-layer runtime `35f8cae44e36d3bb5e1ad2451259fece28605b0f` to the proposed candidate found only:

- `docs/evidence/p1-cross-layer-visible-composition.md` added,
- `quality/p1-owner-readiness.json` governance state updated,
- `p1/CANDIDATE-FREEZE.md` added.

No runtime script, scene, resource, physics, interaction, camera or presentation implementation changed.

## Exact-candidate mechanical and rendered closure

Every active P1 evidence surface was rerun against the same candidate SHA `b5050b669…`:

- Owner-readiness contract validation: run `35022042990` — **SUCCESS**,
- P1 rebuild validation: run `35022042985` — **SUCCESS**, including full foundation and Windows composed-scene diagnostic,
- G6 world causality: run `35022042983` — **SUCCESS**,
- G5 interaction: run `35022042895` — **SUCCESS**,
- UI hierarchy: run `35022042896` — **SUCCESS**,
- G4 camera: run `35022043026` — **SUCCESS**,
- cross-layer visible rehearsal: run `35022043017` — **SUCCESS**,
- research-harness validation: run `35022043157` — **SUCCESS**,
- general rendered evidence: run `35022043031` — **SUCCESS** on both Windows D3D12 and Linux Compatibility.

The P1 rebuild candidate run passed strict import, dependency compile, canonical startup, volumetric actor, composed scene, multi-Space registry, live topology consumers, promoted surface-grid and state-presentation lifecycle probes, storage rebase, actor/camera storage continuity, camera presentation/control-frame separation, finite Space control and the integrated causal-loop pressure gate.

## Candidate-native artifacts

All listed artifacts below report `head_sha=b5050b669ec4101226095183929f5790f0a034fc`.

### G4 camera

- artifact `10418560018`
- `sha256:d4184c844f9cd543855f84f0a213c7ec3626562ca4333be2160b7372933f2fff`

Manual review covered default center, actor-near-edge, legal minimum zoom, close Matter obstruction, far-airborne relation, recovery, storage-rebase continuity, dynamic motion and immediate/post-split context. The difficult far-airborne frame still shows the remote Matter structure as a readable structure rather than the old thin-line failure; actor and reference world remain relationally understandable. No catastrophic SpringArm close-up returned.

### G5 interaction

- artifact `10417827172`
- `sha256:1b2a9f570e10394707cf7f7106d3963e5b3f7e1d5df4af8c407e7bf6d622e416`

Manual review confirmed the production face-led language on the candidate: REMOVE target, causal `REMOVED`, real `BLOCKED`, PLACE and out-of-storage EXPAND remain readable and depth-correct. The compact HUD does not steal pointer ownership outside its actual small region.

### G6 world / motion / topology causality

Canonical coarse-grid artifact:

- artifact `10417069630`
- `sha256:45be92a9eff2ad8326bddd55f06714099e34bfd95a8068423f1292143194c82c`

Historical-comparison baseline artifact:

- artifact `10418465428`
- `sha256:0c3f3645533fda1715b1ea483a0fe97f2a13bed6314ca1a7695be898a9f4f401`

Candidate pixel review confirmed zero-motion release, finite translation/yaw against the world datum, split relation/independence and freeze-at-current-pose remain visually coherent.

### UI hierarchy

- artifact `10418395100`
- `sha256:d7f9d6943f9f868bda52d287c6a5f79d6f09b4fe5445a1421cceb57beed1d174`

All four candidate frames preserve the compact hierarchy through STATIC, zero-motion DYNAMIC, finite motion and two-Space split states. World pixels remain dominant; engineering telemetry does not return.

### Cross-layer composed rehearsal

- artifact `10418012419`
- `sha256:64e814fa9a701cd6469afa77abee41008c72394ebe69cb6837724d20955905c7`

Manual review of all ten candidate frames reconfirmed the accepted composed history:

- real pointer target and edit feedback,
- zero-launch release,
- visibly distinct finite translation/yaw,
- edit while moving,
- non-zero storage rebase with mapped placement and no visible world jump,
- topology split,
- materially visible sibling-only motion,
- final frozen actor-owned STATIC successor beside still-DYNAMIC sibling.

### General rendered parity

Windows canonical:

- artifact `10418241396`
- `sha256:26600db251d334f831a97877004ca3898d9fcf46aae7014a1748452e2339a8ad`

Linux Compatibility:

- artifact `10417278941`
- `sha256:ef010ef9dc6b473bc26402ff0dd4dd88c7dad1dc6b1f59ab37ad63af8c9efd02`

Manual Windows review covered initial/release/motion/rebase/split/freeze, eight lighting azimuths and near/mid/far granularity. No previously rejected black/white collapse, HUD-dominant presentation or material/state ambiguity returned. Linux remains the secondary backend guardrail and completed successfully.

## Representative scenario revalidation

The exact candidate re-earned every contract representative scenario through the candidate-native workflows above:

- `default_static_matter` — UI/general rendered/cross-layer,
- `edit_target_remove_place_expand` — G5 + cross-layer REMOVE,
- `zero_launch_release` — G6 + cross-layer,
- `dynamic_translation_and_yaw` — G6 + cross-layer,
- `moving_edit_and_storage_rebase` — cross-layer,
- `topology_split_and_successor_relations` — G6 + cross-layer,
- `freeze_at_current_pose` — G6 + cross-layer,
- `close_camera_obstacle_stress` — G4,
- `actor_near_space_edge` — G4,
- `fall_and_recovery` — G4.

This is the first P1 candidate for which those scenario claims are all re-earned on one exact runtime commit rather than inherited from different historical commits.

## Freeze decision

**The proposed runtime `b5050b669ec4101226095183929f5790f0a034fc` is suitable to become the formal FROZEN candidate for G8 adversarial preflight.**

This does **not** authorize Owner delivery or promotion. After governance binds the readiness manifest to this runtime, the candidate still requires:

1. recorded adversarial rehearsal on the frozen runtime,
2. independent read-only assurance attempting falsification,
3. final cross-plane readiness audit,
4. explicit final promotion/Owner-attention authorization only if no blocker remains.

Any subsequent runtime-affecting P1 change invalidates this freeze and requires a new candidate SHA and revalidation cycle.
