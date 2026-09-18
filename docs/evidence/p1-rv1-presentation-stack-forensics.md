# P1 R-V1 — corrected-surface presentation stack forensics

Status: **PASS AS FORENSICS / NO DEFAULT-PRESENTATION PROMOTION YET**

Exact source: `d378a6759ae993ab4f05edc6a4e0e1cd21ac8c38`
Workflow run: `35040479176`
Renderer: Windows Godot 4.7.2 Forward+ / D3D12

## Evidence

Artifacts:
- base `10424917683` (`sha256:d1c209dd342cbfbfaa331e4c46053a6edecc3b3b95cd3bc8fae027abc38c62f6`)
- grid `10425042260` (`sha256:bfd433473975aed3f10edbbfed4d33c22885ca8e5ffa95d676db6a28c1db52a8`)
- state `10425141926` (`sha256:789689d43974c01ff43aed01de45d20fb2ca1ebfbeddb6624beeeb82b85fa80c`)
- grid+state `10424478305` (`sha256:6e6e656eee1217ade9b86ef77defee8849cc3c6af5af9d1404ca69aafe7c5091`)

All lanes use the corrected canonical Matter surface and the same clean/near plus deterministic accumulated-chaos geometry. Player/HUD/origin instrumentation is hidden.

## Findings

1. **Base remains solid under geometry entropy.** Holes, concavities and protrusions remain opaque/coherent without semantic overlays. R-V0's winding correction is therefore the material fix for the Owner's hollow/transparent failure.

2. **The current cell grid remains viable.** It adds one-cell edit scale without recreating the former ghost-shell failure. This does not prove it should remain permanently visible at every distance; contextual/distance policy remains open.

3. **Permanent state/focus geometry has weaker return.** It remains readable but adds edge density while contributing limited information in a single focused STATIC state. `grid+state` is coherent but visibly busier than `grid` alone. State semantics must be challenged in actual STATIC/DYNAMIC/split/freeze contexts before either preserving or replacing the permanent contour.

4. **Greedy/macro-surface meshing is not the immediate visual priority.** Corrected per-cell meshing is solid in this corpus. Greedy meshing remains a future challenger for rebuild cost, shading seams or representation decoupling, but should not displace higher-value work without evidence pressure.

5. **Provider-owned material duplication is now the clearest R-V1 architecture debt.** STATIC and DYNAMIC providers use slightly different albedo/roughness for the same logical Matter. Provider replacement should not silently change material identity.

## Verdict

**PASS as forensic evidence only.** No Owner-readiness FAIL is cleared by this tranche.

Next bounded step: one shared neutral Matter surface-style source for STATIC and DYNAMIC providers, preserving the current STATIC look as the least-disruptive baseline, plus an executable provider-parity regression probe. This is not a general material system and not final art direction.