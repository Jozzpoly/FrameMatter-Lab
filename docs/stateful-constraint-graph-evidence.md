# Stateful constraint-graph evidence

Status: bounded exploratory evidence; this note extends `multiframe-mechanics-evidence.md` without replacing its broader history.

## Two independent stateful hinges can partition in one topology split

One moving parent frame carried two independent `HingeJoint3D` relations at opposite ends. Each hinge had its own retained owner-Matter lineage, full oriented constraint frame, motor target and angular limit. Immediately before the topology transaction all three involved rigid bodies were reset onto one instantaneous rigid velocity field, so both hinge relative angular speeds were effectively zero. The stateful motion measured afterward therefore had to be created by the inherited motors rather than inherited relative spin.

The parent was then cut into two compact successors before the upcoming PhysicsServer step. Each mechanical relation independently:

1. selected its successor by its own retained owner-Matter lineage,
2. mapped its full logical hinge transform into that successor,
3. rebased the persistent host `HingeJoint3D` scene frame,
4. replaced only its own endpoint,
5. retained its own motor/limit configuration and logical joint identity.

Fast and full validation both passed. Full-ratchet result: **PASS**.

CI evidence:

- left owner lineage: `160029 -> 160029`,
- right owner lineage: `160038 -> 160038`,
- lineage mismatches: `0`,
- retained Matter world-position error: `0.0000021851 m`,
- retained velocity-field error: `0.0000009003 m/s`,
- pre-transaction relative angles: `0.0171419183 / 0.0213290071 rad`,
- pre-transaction relative hinge speeds: `0 / 0`,
- stale hinge-origin distances before rebasing: `2.7324264050 / 0.8558853865 m`,
- stale hinge-basis errors before rebasing: `0.3253901899 / 0.3071632385`,
- all origin/basis rebase errors: `0`,
- left motor target magnitude: `1.10 rad/s`; measured maximum relative speed: `1.099984 rad/s`,
- right motor target magnitude: `1.30 rad/s`; measured maximum relative speed: `1.299980 rad/s`,
- left angular limit magnitude: `0.40 rad`; maximum/final angle: `0.394110 / 0.382875 rad`,
- right angular limit magnitude: `0.55 rad`; maximum/final angle: `0.579535 / 0.571789 rad` (bounded host-solver compliance beyond the nominal limit),
- final relative angular speeds: `0 / 0`, showing both limits arrested sustained motor motion,
- maximum left/right anchor gaps: `0.0017542269 / 0.0027105701 m`,
- final left/right anchor gaps: `0.0004481379 / 0.0006744797 m`,
- maximum hinge-axis errors: `0.0000602523 / 0.0002465427 rad`,
- final hinge-axis errors: `0.0000364134 / 0.0001033979 rad`,
- successor-mechanism separation changed by `6.013950 m`, demonstrating two independent post-partition mechanical islands,
- both persistent logical hinge identities survived.

Bounded result: **stateful mechanical succession is per relation/per retained owner, not a single global state attached to the source construct.** One topology transaction can partition multiple oriented, motorized, limited constraints onto different successor frames while each relation preserves distinct configuration and active behavior.

## What this does not yet prove

- the inverse stateful graph rewrite: multiple active external hinges converging onto one merged successor while newly internal relations retire,
- multi-joint serial chains where motion/loads propagate through more than one active relation before and after topology replacement,
- loops and overconstrained mechanisms,
- graph-level energy/work accounting for motors during simultaneous topology changes,
- breakable-link thresholds or failure propagation,
- persistence/network identity for a production mechanical graph.
