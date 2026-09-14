# Evidence index

This directory is the durable home for research measurements and campaign records.

Evidence is **historical truth about what was tested**, not automatically live architectural guidance. A result can remain valid evidence while a later integrated consumer changes the preferred mechanism or roadmap order.

## Current evidence records

The repository predates this directory, so the first evidence files still live directly under `docs/` and are indexed here until a later cleanup moves them without rewriting history:

- `i0b-provider-replacement-lifecycle.md` — first integrated logical-Space lifecycle evidence: one authoritative Matter+lineage pair survives real `MatterRepresentation → ConstructBody → MatterRepresentation` provider replacement, live motion/editing and arbitrary-orientation freeze-to-static.
- `i0a-freeze-unfreeze-semantics.md` — in-place `RigidBody3D` dynamic↔`FREEZE_MODE_STATIC` lifecycle control, frozen live edit, identity/pose continuity and measured host velocity semantics.
- `stateful-graph-contraction-capstone.md` — standalone mechanics capstone closing the bounded stateful partition↔contraction campaign.
- `../multiframe-mechanics-evidence.md` — constraint coupling, actor+constraint composition, live mutation under joints, split succession, graph partition/contraction, anchor destruction/mixed lifecycle and related measurements.
- `../stateful-constraint-graph-evidence.md` — oriented hinge-frame succession, motor/limit state, multi-edge stateful partition results.
- `../research-state.md` — **not evidence archive**; current synthesized truth built from evidence.
- `../../README.md` historical git revisions — early G0–G3/topology measurements before documentation was split into layers.

Future campaigns should prefer adding focused evidence records here rather than expanding README.

## Evidence record convention

A useful evidence record should state:

- question / hypothesis,
- exact bounded setup,
- PASS / FAIL / unresolved status,
- important measurements,
- what the result actually establishes,
- explicit non-claims / scope limits,
- relevant commit or CI context when useful.

Do not rewrite old evidence merely because terminology or architecture later changes. Add a new synthesis in `research-state.md` or a new evidence record instead.

## Maturity reminder

Evidence levels used by the project:

1. Hypothesis
2. Bounded evidence
3. Integrated evidence
4. Reusable-substrate evidence
5. Scale evidence
6. Playability/product evidence

Most older FrameMatter results are strong **bounded evidence**. I0B begins the integrated-evidence layer by exercising provider replacement and mutation through shared runtime rather than test-local reconstruction. Reusable-substrate evidence still requires an independent second consumer of that same path.