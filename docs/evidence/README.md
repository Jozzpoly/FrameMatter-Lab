# Evidence index

This directory is the durable home for research measurements and campaign records.

Evidence is **historical truth about what was tested**, not automatically live architectural guidance. A result can remain valid evidence while later integrated or scale work changes the preferred mechanism.

## Current evidence records

- `p05-interaction-baseline.md` — owner-facing interaction/readability layer added after the first direct P0 recordings exposed strong camera, targeting, Matter-readability and telemetry friction. Dedicated P0.5 smoke plus the defended P0 regression gate are green; Windows/Web packaging succeeds. This is an improved measurement instrument for the next Owner run, **not playability/product PASS**.
- `p0-interactive-consumer.md` — first embodied LAB consumer composing actor support, direct selected-cell remove/place, static→dynamic ride/walk, moving edit and freeze through shared `LocalMatterSpace`. Automated integrated PASS is bounded to translation+yaw; first human use confirmed the loop was operable but exposed severe interaction/readability roughness. The first pitch/roll attempt exposed the current world-up single-ray actor boundary rather than being hidden by a LAB-specific fix.
- `r2a-derived-region-locality.md` — bounded A/B challenger showing that one logical Matter volume can keep exact collision/mesh semantics while derivation work is localized to bounded update regions. Local one-cell work improves dramatically at larger extents, but naive fixed regions inflate dense/shell collider partitions enough to argue against promoting the test mechanism directly.
- `r2p-post-aggregation-profile.md` — post-R1 decomposition of provider/edit/split cost. Shows that engine shape installation is no longer dominant; full mesh, cuboid compilation, COM and repeated whole-volume work now dominate. Separates material-only from occupancy-changing edit cost.
- `r1-exact-collision-aggregation.md` — exact deterministic merged-cuboid compiler and integrated promotion. Preserves occupied collision coverage and lifecycle semantics while reducing dense/shell collider count and provider/rebuild cost by orders of magnitude in the strongest cases.
- `r0-representation-scale-baseline.md` — first controlled scale baseline across dense/shell/sparse Matter and disconnected splits. Ranks per-occupied-cell collision node/shape materialization as the dominant first scale pressure in the original reference representation.
- `i3-shared-topology-split.md` — moving `LocalMatterSpace` retires through one shared one→many topology transaction into fresh compact successors while retained Matter lineage, world placement, rigid velocity-field continuity and explicit actor succession remain coherent. Records the transaction/solver/node observation-phase trap found by the first gated run.
- `i2-actor-provider-transition.md` — actor support remains a logical `LocalMatterSpace` relation through static→dynamic→static provider replacement without test-local handoff; records the sync/phase-advance distinction discovered by the first challenger run.
- `lifecycle-lab-consumer.md` — the original LAB front door consumes the shared local-Space lifecycle for activation, motion, live mutation, freeze and post-freeze edit; second independent consumer shape for the lifecycle substrate before P0 made it embodied.
- `i0b-provider-replacement-lifecycle.md` — first integrated logical-Space lifecycle evidence: one authoritative Matter+lineage pair survives real `MatterRepresentation → ConstructBody → MatterRepresentation` provider replacement, live motion/editing and arbitrary-orientation freeze-to-static.
- `i0a-freeze-unfreeze-semantics.md` — in-place `RigidBody3D` dynamic↔`FREEZE_MODE_STATIC` lifecycle control, frozen live edit, identity/pose continuity and measured host velocity semantics.
- `stateful-graph-contraction-capstone.md` — standalone mechanics capstone closing the bounded stateful partition↔contraction campaign.
- `../multiframe-mechanics-evidence.md` — constraint coupling, actor+constraint composition, live mutation under joints, split succession, graph partition/contraction, anchor destruction/mixed lifecycle and related measurements.
- `../stateful-constraint-graph-evidence.md` — oriented hinge-frame succession, motor/limit state and multi-edge stateful partition results.
- `../research-state.md` — **not evidence archive**; current synthesized truth built from evidence.
- `../../README.md` historical git revisions — early G0–G3/topology measurements before documentation was split into layers.

Future campaigns should add focused evidence records here rather than expanding README.

## Evidence record convention

A useful evidence record states:

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

Most older FrameMatter results are strong **bounded evidence**. I0B established the first integrated local-Space lifecycle consumer. The original LAB exercised the same provider/mutation lifecycle through a materially different consumer shape, supplying narrow **reusable-substrate evidence** for that path. I2 adds integrated actor-support evidence across provider replacement. I3 adds integrated one→many topology execution through shared runtime rather than test-local orchestration.

R0 is the first explicit **scale-pressure baseline**. R1 removes the demonstrated first bottleneck in the tested range and survives integrated lifecycle/topology consumers. R2P re-ranks the resulting cost structure. R2A supplies bounded evidence that edit locality is achievable without making update regions logical identity, while showing that naive fixed regional collision partitions can undo much of R1's collider compression.

P0 is the first automated embodied consumer that composes direct Matter editing, actor support and provider lifecycle through the real LAB. It is **integrated consumer evidence, not playability/product evidence**. The first human run then provided qualitative evidence that prototype interaction friction was too dominant for a clean assessment of the underlying idea.

P0.5 therefore improves the measurement surface without claiming a new substrate result. Its automated gate proves the presentation shell coexists with the defended P0 path and survives packaging; camera feel, targeting ergonomics, overall legibility and perceived latency remain human-test questions.

## Current re-audit consequence

The representation campaign reached a useful stop point and the first embodied consumer now exists:

- `PER_CELL` remains a historical/reference control, not a scalability candidate,
- `MERGED_CUBOIDS` remains the current provider default,
- post-R1 edit cost is dominated by repeated whole-volume derivation rather than installing merged shapes,
- bounded locality can attack that cost if a consumer needs it,
- the R2A fixed-region mechanism is **not** promoted because locality benefit and final physical partition quality are separate concerns,
- P0 automated composition remains green in a translation+yaw scope,
- first direct Owner use exposed interaction/readability friction rather than a demonstrated substrate failure,
- P0.5 now provides a closer orbit/zoom camera, explicit cell previews, Matter grid context, compact/debug HUD split and test recovery without replacing the P0 authority path,
- arbitrary pitch/roll support remains a real unresolved actor-semantic frontier.

The next highest-information evidence should come from direct Owner use of the P0.5 LAB. That result should decide whether representation latency, actor semantics, lifecycle continuity, interaction/visual UX or another semantic pressure deserves the next campaign.