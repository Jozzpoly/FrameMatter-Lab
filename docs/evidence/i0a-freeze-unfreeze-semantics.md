# I0A — in-place freeze/unfreeze host semantics

Status: **FULL PASS / bounded evidence**

Commit under test: `2dbd6381f3901b52a23e4546e9ddf5d3fabdc82a`

## Question

What lifecycle behavior does Godot 4.7.2 + built-in Jolt provide when one `RigidBody3D` keeps the same engine identity while switching between dynamic and `FREEZE_MODE_STATIC`, including a live Matter rebuild while frozen?

This is a control experiment. It does **not** prove representation independence and does not prescribe the final FrameMatter lifecycle policy.

## Bounded setup

One `ConstructBody` / one RID / one `CellVolume` / one `MatterLineageMap` was exercised through:

1. active translation + rotation,
2. dynamic → static freeze at the pre-step physics-frame boundary,
3. frozen observation,
4. Matter + lineage mutation and derived rebuild while frozen,
5. unfreeze without manually restoring velocity,
6. explicit new dynamic velocity command and resumed motion,
7. a second freeze at the arbitrary pose reached by simulation.

The probe is prioritized immediately after G2 in both CI paths.

## Final measurements

From the fast-path PASS:

- dynamic translation before freeze: `1.20155334`
- dynamic rotation before freeze: `0.16509652`
- final legal dynamic phase advance before the freeze boundary: `0.0706328899`
- synchronous freeze toggle pose jump: `0.0000000000`
- max frozen pose drift: `0.0000000000`
- frozen rebuild pose jump: `0.0000000000`
- synchronous unfreeze toggle pose jump: `0.0000000000`
- first unfreeze server displacement: `0.0000045237`
- node/server sync gap: `0.0000000000`
- resumed commanded translation: `1.31299651`
- resumed commanded rotation: `0.22062322`
- second freeze toggle jump: `0.0000000000`
- second frozen-window drift: `0.0000000000`
- initial mass: `35.099998`
- post-edit mass: `33.750000`
- initial collision shapes: `26`
- post-edit collision shapes: `25`
- Matter changes from initial state: `3`
- lineage changes from initial state: `3`

Identity and authoritative state remained one logical set throughout the experiment.

## Host velocity semantics

Before first freeze:

- linear velocity: `(2.3, 0.4, -1.1)`
- angular velocity: `(0.31, -0.47, 0.22)`

Those same values remained visible through:

- immediately after `freeze = true`,
- the entire frozen window,
- immediately before `freeze = false`,
- immediately after `freeze = false`.

After the first actual solver step following unfreeze, both became:

- linear velocity: `(0, 0, 0)`
- angular velocity: `(0, 0, 0)`

Godot's `RigidBody3D` implementation changes body mode to STATIC for `FREEZE_MODE_STATIC` and back to RIGID when unfrozen. The experiment therefore rejects the interpretation of freeze as a general-purpose pause/resume of solver velocity state.

## What this establishes

Within the tested scope:

- one `RigidBody3D` can survive dynamic → static-freeze → dynamic → static-freeze without changing instance or RID identity;
- freeze/unfreeze itself does not synchronously move the body when measured at the correct transaction boundary;
- arbitrary world orientation survives static freeze;
- frozen pose remains stable;
- authoritative Matter and lineage remain coherent;
- mesh/collision/mass/COM-derived state can be rebuilt while frozen without moving the host pose;
- the same host can later resume active motion after an explicit velocity command;
- in-place freeze is a useful low-churn lifecycle control.

## Explicit non-claims

This does **not** establish:

- that in-place freeze is the preferred final representation lifecycle;
- that velocity automatically resumes after unfreeze;
- provider/body replacement continuity;
- persistent logical Space identity independent of provider identity;
- scalable collision representation;
- actor continuity through provider-class change;
- save/load or streaming semantics.

## Consequence for the next campaign

I0B/I1 should now test the stronger claim: one persistent logical local Space survives **real provider replacement** between the existing static `MatterRepresentation` and dynamic `ConstructBody`, with exactly one pose authority and a reusable pre-PhysicsServer transition path.
