# Stateful graph contraction capstone

Status: **FULL PASS — bounded evidence**

Purpose: close the standalone mechanics-only expansion with the many→one inverse of the defended stateful graph-partition case.

## Bounded setup

Source graph:

`External L — motorized/limited Hinge — A — internal relation — B — motorized/limited Hinge — External R`

A and B are explicitly rigid-bound into one momentum-derived successor before the upcoming PhysicsServer step.

The two external hinge relations have different retained Matter owners, different full oriented constraint frames, different motor targets and different angular limits. The A↔B relation must retire because both endpoints collapse into the same rigid successor.

## Result

Full research-validation passed with the capstone as the final gate (42/42 research steps; fast path also passed).

Key capstone metrics:

- left owner lineage `170017 → 170017`,
- right owner lineage `170056 → 170056`,
- lineage mismatches `0`,
- source alignment error ~`4.79e-6 m`,
- source orientation error `0`,
- reconstructed linear-momentum error `0`,
- reconstructed angular-momentum error ~`3.26e-5`,
- inelastic kinetic-energy loss ~`133.028`,
- both external hinge frames had ~`1.183 m` stale origins before explicit rebasing,
- both origin/basis rebase errors `0` at transaction precision,
- inherited pre-solver relative hinge speeds `0 / 0`,
- first solver step produced ~`0.328 / 0.335 rad/s` from the enabled motors,
- left motor max speed ~`1.1003 rad/s`, target `1.10`,
- right motor max speed ~`1.3013 rad/s`, target magnitude `1.30`,
- final relative speeds `0 / 0`,
- left final angle ~`0.40025 rad`, configured limit `0.40`,
- right final angle ~`0.55037 rad`, configured limit `0.55`,
- final anchor gaps ~`0.00084 / 0.00094 m`,
- final hinge-axis errors ~`0.000171 / 0.000090 rad`,
- final graph contains the two external hinges and no internal self-edge.

## Harness correction during the run

The first runtime version incorrectly asserted near-zero relative hinge speed **after** the first successor solver step. Metrics showed ~`0.33 rad/s` because the enabled motors had already legitimately acted.

The contract was corrected without loosening a threshold: inherited relative speed is now checked at the actual pre-step transaction boundary. It is exactly zero there; the first-step speed remains telemetry demonstrating motor authority.

## What this establishes

In the tested Pin/Hinge/Jolt scope, a many→one rigid graph contraction can simultaneously:

- preserve distinct external Matter ownership/lineage,
- preserve two distinct full oriented constraint frames,
- preserve distinct active motor/limit state and behavior,
- converge both external relations onto one merged successor,
- retire a relation that becomes internal/self-edge,
- remain consistent with the already defended inelastic P/L/energy contract.

This closes the intended partition↔contraction symmetry at **bounded evidence** maturity.

## Explicit stop condition

This PASS **ends the standalone mechanics-probe expansion**.

Do not continue directly into longer chains, loops, breakable joints or a mechanism catalogue. Richer mechanics now return to the roadmap only when an integrated/playable consumer creates a concrete information need.

Next campaign: local-Space static/dynamic lifecycle integration, beginning with I0A host freeze/unfreeze semantics.