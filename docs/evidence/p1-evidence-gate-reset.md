# P1 evidence-gate reset

Status: **ACTIVE — pre-strict P1 PASS claims are provisional until re-proven**

## Why this reset exists

During the destructive P1 rebuild, GitHub Actions run `34921251795` exposed a failure in the research harness itself, not only in the runtime under test.

On Linux/Godot 4.7.2, `space/local_matter_space.gd` and `p1/main.gd` produced GDScript parse/compile errors caused by implicit Variant inference. Dependent P1 scripts therefore did not load correctly. Despite that, the old `p1_volumetric_actor_challenger.gd` process emitted runtime `Invalid call` errors and still printed its `P1_VOLUMETRIC_ACTOR_PASS` marker before exiting successfully enough for the workflow step to appear green.

The composed scene smoke then failed for the same dependency-load problem and was terminated by its watchdog at `phase=resolve composed roles`.

A contemporaneous Windows diagnostic job appeared green, but its captured Actions output did not provide an equivalent positive runtime transcript. It is therefore not treated as counter-evidence to the Linux compile failure.

## Evidence decision

This does **not** falsify the design hypotheses behind the P1 volumetric actor, camera, registry, topology, storage or finite-control challengers. It does falsify the assumption that the previous P1 test harness was sufficient to prove them.

Therefore:

- historical defended pre-P1 substrate evidence remains historical evidence;
- P0/P0.5 remain historical Owner/consumer evidence;
- all P1 PASS claims produced before the strict gate are **provisional**;
- no P1 mechanism is promoted solely from those earlier runs;
- every P1 mechanism must pass again under the strict compile/runtime gate before it becomes defended current evidence.

## Gate hardening

P1 now has three layers of protection:

1. `tests/p1_compile_gate.gd` explicitly loads the critical P1/substrate scripts and scenes and requires scripts to be valid/instantiable resources.
2. `ci/run_godot_probe.sh` and `ci/run_godot_probe.ps1` require the expected PASS marker **and** reject script/load/failure output even when Godot returns process exit code 0.
3. The P1 workflow runs the compile gate before behavioral probes on both Linux and the Windows diagnostic lane.

The broader historical validation workflow is also being hardened so script parse/compile/load errors cannot silently coexist with nominal probe success.

## Current proof order

The next defended P1 state must be earned in this order:

1. strict dependency compile/load PASS;
2. volumetric actor PASS;
3. composed scene PASS;
4. multi-Space registry/succession PASS;
5. live topology consumer PASS;
6. storage-frame rebase PASS;
7. finite mass-driven Space-control PASS.

A failure at an earlier layer blocks promotion of later layers. We do not infer later PASS from old runs.

## Nonclaim

This reset is not evidence that Godot or Jolt is unsuitable. The material finding is that our earlier evidence harness was permissive enough to allow a false-green path. Correcting that is part of giving Godot a fair evaluation rather than attributing our test/consumer defects to the engine.
