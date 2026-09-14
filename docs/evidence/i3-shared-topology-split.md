# I3 — shared topology split lifecycle

Status: **FULL PASS / integrated shared-runtime evidence**

Commit under final verdict: `240e4b127cb269cc809c99853620c84da05d8a27`

CI authority: `Validate research harness` run `34881294855` — fast and full research jobs both PASS; full research path completed all 47 validation steps.

## Question

Can a moving logical `LocalMatterSpace` split through shared runtime execution rather than recreating connected-component, compact-rebase, lineage, provider and physical-state succession logic inside an adversarial test?

## Bounded setup

- One dynamic `LocalMatterSpace` owns authoritative `CellVolume` + `MatterLineageMap`.
- Geometry consists of two solid regions connected by a narrow bridge.
- An ordinary shared Matter mutation destroys one bridge cell and retires its lineage.
- `LocalMatterSpace.request_connected_component_split()` queues a one-to-many lifecycle transaction for the defended pre-step boundary.
- The source Space is retired rather than arbitrarily assigning its logical Space identity to one component.
- The runtime computes connected components, compact local origins, successor Matter + lineage storage, world transforms and rigid velocity-field inheritance, then creates fresh dynamic successor Spaces/providers.
- An actor standing on retained Matter consumes the explicit source→successor mapping through the already existing topology support-frame handoff. The test does not create successor bodies, compact Matter, copy lineage, or derive velocity inheritance itself.

## Final measurements

`LIFECYCLE_SHARED_TOPOLOGY_SPLIT_METRIC`

- successors: `2`
- retained cells: `65`
- successor lineage union: `65`
- compact rebased cells exercised: `37`
- pre-split actor local drift: `0.0000248688`
- legal source phase advance before transaction: `0.0676866099`
- actor handoff world jump at transaction boundary: `0.0000019073`
- retained Matter world-position error: `0.0000019073`
- inherited rigid velocity-field error: `0.0000014502`
- minimum first-server-step successor displacement: `0.0708184689`
- successor Node/PhysicsServer sync gap on next boundary: `0.0000000000`
- post-split actor local drift: `0.0000117963`
- actor grounded loss: `0`
- wrong successor support frames: `0`

The destroyed bridge lineage token did not reappear in any successor.

## What this establishes

Within the tested scope:

1. **One-to-many topology execution now exists in shared runtime.** The adversarial probe is primarily a client of `LocalMatterSpace`, `MatterTopology` and the explicit split result instead of the implementation site for the split.
2. **Source authority is singular and terminates explicitly.** After commit the source Space is retired, has no live provider, and no longer owns live Matter/lineage truth.
3. **Successor Space identity is fresh by default.** Without an explicit owner/root/anchor policy there is no arbitrary rule declaring one fragment to be “the old Space”. Matter identity continuity is instead carried by lineage.
4. **Compact rebasing is compatible with continuity.** Successors can own compact local Matter coordinates while retained cell world placement remains continuous through explicit source-origin mappings.
5. **Rigid physical state can be inherited without treating solver COM as synchronous transaction authority.** Successor linear/angular state reproduces the source instantaneous rigid velocity field at retained Matter points within numerical tolerance.
6. **Fresh successor RIDs can participate in the first upcoming solver step.** Scene-node visibility still catches that result on the next PhysicsServer sync, preserving the lifecycle timing model established by I0B/I2.
7. **Actor succession composes with the shared split.** Existing explicit topology support mapping transfers the actor onto the compact successor with negligible world jump and no grounded/support loss in the tested ride window.

## Important first-run finding

The first gated I3 run failed only the post-split actor drift assertion, reporting approximately `0.0677329` while Matter/lineage partition, world placement, velocity inheritance, fresh-RID timing, grounded state and support identity all passed.

This was an observer-phase error, not runtime topology drift. After the split, the successor node had already synchronized to the latest PhysicsServer transform while the actor had not yet executed its corresponding `_physics_process` transport for that tick. Sampling `support_body.to_local(actor.global_position)` at that moment therefore mixed two observation phases.

The corrected invariant uses the explicit `mapped_actor_local` produced by the topology transaction as the post-split local reference. With that correction, measured drift became `0.0000117963` without changing runtime behavior.

This independently reinforces the project-wide timing distinction:

- transaction truth,
- current PhysicsServer/solver truth,
- synchronized scene-node/consumer visibility

are related but not universally simultaneous observation layers.

## Non-claims / scope limits

This PASS does **not** establish:

- scalable topology cost,
- dirty/local connectivity updates,
- scalable collision generation,
- automatic succession of arbitrary actors/mechanisms without explicit mapping policy,
- persistence identity across save/load,
- canonical-world reintegration,
- network replication,
- nested simulation domains,
- production Space API or manager architecture.

The current split is deliberately a clear reference implementation. It may perform full connectivity/compaction and full derived-representation construction synchronously. Those costs are now appropriate subjects for measurement rather than assumptions.

## Re-audit consequence

I0B → LAB → I2 → I3 has established enough integrated lifecycle coherence to enter the scalable-representation frontier empirically. The next high-value question is no longer “can one more lifecycle semantic be demonstrated?” but **where does the current truth/reference representation actually stop being cheap enough?**

Therefore the next campaign should begin with an R0 scale baseline before choosing greedy collision, dirty regions, chunking, convex decomposition or another optimization mechanism.