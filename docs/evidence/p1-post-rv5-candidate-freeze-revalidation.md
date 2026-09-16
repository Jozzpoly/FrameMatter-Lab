# P1 post-R-V5 candidate freeze revalidation

Status: **PASS / PROPOSED RUNTIME REVALIDATED ON ONE EXACT COMMIT**

Proposed frozen runtime candidate:

`337716db303e94e459cad2b9bcdbfcb8b6c0474b`

Pre-freeze qualified runtime:

`5b16759d0c5dbfda36f7f48a80e3498c5db8719e`

Active contract: `quality/contracts/p1-owner-facing-recovery.v4.json`

R-V5 evidence: `docs/evidence/p1-rv5-chaotic-owner-surface-rehearsal.md`

## Freeze construction

The proposed candidate updates the runtime-neutral `p1/CANDIDATE-FREEZE.md` marker after R-V5 closure. A Git compare from the pre-freeze qualified runtime `5b16759d...` to the proposed candidate `337716db...` is two commits ahead and contains only:

- `docs/evidence/p1-rv5-chaotic-owner-surface-rehearsal.md` — added evidence documentation,
- `p1/CANDIDATE-FREEZE.md` — runtime-neutral freeze marker revision.

No Godot runtime script, scene, resource, actor, physics, interaction, camera, Matter, Space or presentation implementation changed between the already-qualified pre-freeze runtime and the proposed candidate.

The candidate nevertheless does not inherit PASS by diff inspection. The active exact-source evidence surfaces were rerun on `337716db...` itself.

## Exact-candidate workflow closure

The following workflows completed successfully on candidate SHA `337716db303e94e459cad2b9bcdbfcb8b6c0474b`:

- Owner-readiness contract validation — run `35132498084` — **SUCCESS** while governance intentionally remained `OPEN`,
- P1 rebuild validation — run `35132498253` — **SUCCESS**,
- P1 base Matter surface forensics — run `35132498172` — **SUCCESS**,
- P1 presentation stack forensics — run `35132498062` — **SUCCESS**,
- P1 R-V3 state policy evidence — run `35132498234` — **SUCCESS**,
- P1 R-V4 camera visual-safety evidence — run `35132498517` — **SUCCESS**,
- P1 G4 camera evidence — run `35132498011` — **SUCCESS**,
- P1 G5 interaction evidence — run `35132498050` — **SUCCESS**,
- P1 G6 world causality evidence — run `35132497927` — **SUCCESS**,
- P1 UI hierarchy evidence — run `35132497938` — **SUCCESS**,
- P1 cross-layer visible rehearsal — run `35132498122` — **SUCCESS**,
- P1 rendered visual evidence — run `35132498017` — **SUCCESS** on Windows canonical and Linux Compatibility lanes,
- Validate research harness — run `35132498026` — **SUCCESS**,
- P1 R-V5 refreeze continuity diagnostic — run `35132497970` — **SUCCESS**,
- P1 R-V5 full-history diagnostic — run `35132498043` — **SUCCESS**,
- P1 R-V5 chaotic Owner-surface evidence — run `35132497987` — **SUCCESS**.

The G8 adversarial workflow run `35132498063` stopped at `Resolve frozen candidate from readiness` because the readiness manifest intentionally still had `candidate_state=OPEN`. Runtime checkout and adversarial recording were skipped. This is the expected pre-freeze governance stop described by the active rebuild plan and is **not runtime evidence or a candidate regression**.

## Candidate-native artifact provenance

All artifacts below report `head_sha=337716db303e94e459cad2b9bcdbfcb8b6c0474b`.

### Base surface

Run `35132498172`:

- current: artifact `10460974778`, `sha256:8328099b47bee076b174b1ca24144ba40d03d01f325a3865e9e157417431a6dc`,
- corrected winding: artifact `10461289357`, `sha256:d574ebe98eea4c201357c7edb18b9a073c6ce9494e7d8e398a17934a9b7d7c58`,
- cull-front diagnostic: artifact `10461439401`, `sha256:fa38356addbee63e2fb0acaeab41c3f98c3fad1d638820f72d9e5633cd288cb7`.

### R-V3 state presentation

Run `35132498234`:

- promoted side-rim: artifact `10461214601`, `sha256:52bc89981c0f6f1eba562030fd16f8cc1cc4929938d6b3967257b54a9c0c3e04`,
- current full-contour comparison: artifact `10461244476`, `sha256:408d8445124b8298fc7e2c852d9a4c71bc6f1747e740988f3ebf97ce47beced9`,
- top-crown comparison: artifact `10461449223`, `sha256:81b0840a774d94bf6dede8e5b6fec43b14a754ee15c89dbb328272433b70f269`.

### R-V4 / G4 camera

R-V4 production artifact `10461733880`, `sha256:d20957359176df67b4d5aefbb62de88e40c6efda0d116b416c5d55c28e40b920`.

G4 canonical artifact `10460889801`, `sha256:a70718c9e5608047268bbca3d766145a30605bd3411afee7aa98337ae2f9c5a1`.

### G5 interaction

Artifact `10461990003`, `sha256:6976f304554ce41ece8bb0a713c6b690e548e697e01150a3228c9b93b30ff392`.

### G6 world causality

Run `35132497927`:

- canonical coarse-grid artifact `10461654420`, `sha256:e115d5332391d38fe46471a210c37ae0f08bad8a05d56aceb4c656ecb8c597c4`,
- baseline comparison artifact `10462040118`, `sha256:2f6f784b45b873918db120a2a479bc9e4438e99bb629962a3c104f1c2b6b548d`.

### UI hierarchy

Artifact `10461843602`, `sha256:00efbbc44a9af8a6dd21518033ec57e66df4e54871bf9b26dec1d55f7155a96b`.

### Cross-layer composition

Artifact `10461940109`, `sha256:e9358e013999177bca00064951ced2b95863746d6ff15827c05559274d93994d`.

### General rendered parity

Run `35132498017`:

- Windows canonical artifact `10461828757`, `sha256:fe347cafdaff1c6535efabaa1cd2f0c2ae0796f82fb5c1877aea664de1385a40`,
- Linux Compatibility artifact `10461274417`, `sha256:07489578569c306f26c131a06a7d152f5023ebb1928e5e57bf47245864cee578`.

### R-V5

Canonical chaotic rehearsal artifact `10461809888`, uploaded archive digest `sha256:5f68c8a02ff8ae7c15f9ed8b5d546c9f2c21e25fb6cf242b7eba760f714fca68`.

Full-history diagnostic artifact `10461724807`, `sha256:08d51dac5b867e539961d46eea3714cd8be115788afecd3e6a7660e6f2721992`.

Canonical R-V5 reports:

- `persistent_edits=26`,
- `removes=12`,
- `places=14`,
- `initial_solid=161`,
- `final_solid=163`,
- `revision_delta=26`,
- `final_support_error=0.00000012 m`,
- 1382 Movie Maker frames at 30 FPS / 46.02 s nominal duration.

Candidate-native pixel hashes:

- `08_dynamic_irregular_near.png`: `7487f826e2b4373486cc85fa990761f542d256bce345f74299953ee11e6eece9`,
- `09_refrozen_irregular_final.png`: `b4d7a4b9ce06b1e8aa4cd02696b7df1214d65752c997228f3c5fc528d31156ac`.

These are exactly the already-qualified pre-freeze fixed pixels. In particular, the final frame remains the repaired wide, readable irregular-Matter composition rather than the superseded avatar-only/dark failure.

## Cross-plane rendered review

Candidate-native G4, G5, UI and cross-layer artifacts were manually reviewed together rather than accepted only from workflow status.

Findings:

- base Matter remains visually solid and coherent rather than returning to the old hollow/debug-shell failure,
- camera evidence preserves actor/world context through center, edge, minimum-zoom, close-obstruction recovery, storage rebase, dynamic motion and split states,
- the G4 far-airborne state remains a deliberately bounded weak-context extreme already documented by its earlier gate; it is not a new candidate regression and is not upgraded into a stronger claim here,
- REMOVE / PLACE / EXPAND cues remain face-led, local and depth-aware,
- compact UI does not take visual ownership away from the world,
- the cross-layer sequence remains causally readable through REMOVE, release, finite motion, moving edit, storage rebase, topology split, successor independence and freeze,
- no cross-plane contradiction was found between physical Matter, state presentation, interaction cues, camera framing and default UI in the reviewed candidate corpus.

R-V5's candidate-native final frame was separately hash-verified against the already accepted repaired frame.

## Freeze decision

**Candidate `337716db303e94e459cad2b9bcdbfcb8b6c0474b` has re-earned the pre-freeze runtime/rendered evidence required to become the formal FROZEN post-R-V5 P1 candidate.**

This decision does **not** authorize Owner delivery, promotion or merge.

After governance binds `quality/p1-owner-readiness.json` to this runtime, the remaining required stages are:

1. recorded G8 adversarial rehearsal executed against this exact frozen runtime,
2. independent read-only assurance attempting falsification under contract v4,
3. final cross-plane readiness audit,
4. explicit promotion / Owner-attention authorization only if no material blocker remains.

Any runtime-affecting change after this point invalidates the candidate and requires a new freeze/revalidation cycle.