# Convergence C2 Structural Law — qualification 2026-09-18

Status: **PASS / BOUNDED DERIVED-RIGID-CONNECTIVITY FINDING**

Qualified source:

`9e226f9eadd3037485244ae80ce227be9dd70fad`

Workflow:

`35366287194`

## Claim

C2 asked only:

> can Matter remain materially continuous while one local interface stops transmitting full rigid connectivity?

No authority composition, dynamic-body creation, joint or runtime mechanism was in scope.

## Experiment

The control Matter fixture is one ordinary six-cell bar.

Ordinary `MatterTopology` remains unchanged:

`occupied axial neighbor => materially connected`

The C2 challenger adds a derived traversal question:

> may rigid connectivity cross this specific occupied adjacency?

The experiment-local seam is keyed by the opaque lineage tokens of its two Matter endpoints. This is not promoted as a final Bond/MaterialAnchor schema.

## Result

Workflow metric:

`material_components=1 rigid_control=[6] rigid_seam=[3, 3] rigid_bypass=[8] rigid_restored=[3, 3]`

Meaning:

- ordinary material connectivity: one component;
- rigid control with no seam: one six-cell rigid component;
- same occupancy + same lineage + one blocked adjacency: two three-cell rigid components;
- adding an alternate rigid Matter path around the seam: one eight-cell rigid component;
- removing the bypass: two three-cell components again;
- a seam referring to a non-live lineage adjacency fails closed.

The derived view does not mutate `CellVolume` or `MatterLineageMap`.

## Protected Spark

The same exact branch re-passed:

`W0D_RECOVERY_CAUSAL_LOOP_PASS`

and the exported release executable re-passed:

`C0_EXPORTED_SPARK_BASELINE_PASS`

with representative final-artifact metrics:

- target fall: `0.415761`;
- actor fall: `0.415761`;
- handoff error: `0.00000000`;
- active Spaces after causal detachment: `2`.

Exact C2 executable SHA-256:

`e581f5193170ea28f0a2e9e364982c4cabaed538684da6228ef52019d5c13011`

## Bounded conclusion

C2 earns:

> **material continuity != rigid connectivity**

for the current cubic/lineage experimental dialect.

C2 does **not** establish:

- a final interface ontology;
- a generic relation graph;
- authority decomposition from the rule;
- a joint or rotational DOF;
- interaction/UI authoring;
- representation-independent anchors.

Those are later gates.

## Next gate

C3 — Authority Composition:

> feed the derived rigid decomposition into the existing W0 authority transaction so a local structural law can cause ordinary WORLD Matter to become WORLD + dynamic island without deleting/recreating Matter.
