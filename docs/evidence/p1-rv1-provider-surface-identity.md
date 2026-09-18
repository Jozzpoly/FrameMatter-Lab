# P1 R-V1 — provider-independent Matter surface identity

Status: **PASS / SHARED NEUTRAL SURFACE IDENTITY PROMOTED**

Exact source: `52fd84b67a1490a8b36a873ef64333067e1f6132`

P1 rebuild workflow: `35100334658`

## Question

Should the same logical Matter change perceived material merely because its physical host changes between STATIC and DYNAMIC providers?

No. Provider kind is simulation state, not authored material identity.

Before this tranche the two providers duplicated their visual setup and used slightly different neutral materials:

- STATIC: `Color(0.72, 0.77, 0.84)`, roughness `0.82`,
- DYNAMIC: `Color(0.74, 0.79, 0.88)`, roughness `0.78`.

That difference was accidental implementation coupling, not an evidence-backed semantic language.

## Minimal correction

A small shared `MatterSurfaceStyle` source now owns only the current neutral P1 base albedo and roughness. Both `MatterRepresentation` and `ConstructBody` create their base surface material from it.

The existing STATIC appearance was retained as the canonical neutral baseline to minimize visual churn. This is deliberately **not** a generalized authored-material system or final art direction.

## Regression evidence

The new `p1_matter_surface_identity_probe.gd` constructs equivalent STATIC and DYNAMIC Matter and verifies:

- both providers expose `DerivedMesh`,
- both use the canonical shared albedo,
- both use the canonical shared roughness,
- provider kind does not change albedo or roughness identity,
- both derive identical mesh vertex counts from equivalent Matter.

Workflow log:

`P1_MATTER_SURFACE_IDENTITY_PASS: STATIC and DYNAMIC providers preserve one canonical Matter surface identity.`

The existing state-presentation lifecycle probe initially failed because it still hard-coded the historical dynamic base color as an expected property. That expectation was classified as test debt: the state presenter is supposed to express STATIC/DYNAMIC through its derived semantic overlay, not by requiring provider-owned base material recoloring.

The probe was corrected to require `MatterSurfaceStyle.BASE_ALBEDO` after provider replacement. The final exact-source foundation run then passed:

- compile graph,
- corrected front-face orientation,
- provider visual-identity parity,
- canonical startup,
- volumetric actor,
- scene foundation,
- multi-Space lifecycle,
- topology consumer,
- Matter grid lifecycle,
- state presentation lifecycle,
- storage rebase,
- camera/control separation,
- finite Space control,
- integrated causal loop,
- Windows composed-scene diagnostic.

## Verdict

**PASS.** The physical provider no longer silently changes the neutral visual substance of Matter.

This protects a core FrameMatter principle: logical/visual Matter identity remains distinct from the current physics host.

Nonclaims:

- final material/art direction,
- final state semantic language,
- contextual cell-grid policy,
- greedy/macro-surface meshing,
- camera visual safety,
- Owner readiness.

Next visual work should evaluate semantic presentation policy on real STATIC/DYNAMIC/split/freeze states rather than reintroducing provider-dependent base styling.