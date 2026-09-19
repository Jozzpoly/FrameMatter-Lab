# Reciprocal contact Owner gate — 2026-09-19

Status: **TECHNICAL PASS / OWNER FEEL GATE**

Qualified source:

`2300cbcab5bc0adbae0e1254957276465999024b`

Workflow run:

`35471659480`

Job:

`105973582388`

## Protected question

Can the existing responsive query-controller and dynamic Matter exchange finite, mass-sensitive contact in both directions without restoring CharacterBody-style mass-independent push authority?

## Bounded challenger result

Metric:

`light_dx=1.984030 heavy_dx=0.000011 light_contacts=48 heavy_contacts=5 light_max_impulse=1.728000 heavy_max_impulse=8.000000 incoming_control_actor_dx=0.007999 incoming_actor_dx=1.325294 incoming_contacts=30 incoming_max_impulse=8.000000 incoming_control_body_x=8.823343 incoming_body_x=7.706112`

Result:

- same actor intent visibly displaced light Matter by ~1.98 m;
- the 64x-mass control moved only ~0.000011 m;
- impulse remained finite and capped;
- incoming dynamic Matter produced ~1.33 m actor displacement versus ~0.008 m in the no-reciprocity control;
- incoming Matter itself lost momentum, so response is not actor-only presentation.

The original reciprocity-OFF volumetric actor contract remained green.

## Red iterations retained as evidence

The first RED established that actor -> Matter already worked while incoming Matter could pass through the query actor without reciprocal detection.

The second RED showed that overlap detection alone did not prove the claim because the incoming fixture stopped on floor friction before reaching the actor. The fixture was corrected rather than relaxing the behavioral gate.

The third RED reached actual incoming contact but exposed a real query-controller artifact: the same overlapping body that imparted momentum also blocked the actor from moving away from contact. The runtime was corrected with a bounded recoil motion query that excludes only the impacting body while preserving collision with the rest of the world. The >5 cm actor-response gate was not weakened.

## Owner scene composition

Metric:

`reciprocal=true props=2 registry_spaces=1 headless_scale=1.0`

The Owner sandbox now:

- enables reciprocal contact;
- exposes one small/light and one larger/heavy bounded Matter-derived contact specimen;
- keeps the logical Space registry startup unchanged;
- freezes structural-seam authoring for this gate;
- starts graphical Owner play at the previously preferred 2x C1 proxy, while headless qualification retains the 1x control.

The loose props are deliberately bounded contact instrumentation. They are not promoted to a new Matter/Space ontology.

## Protected causal baseline

W0D remains PASS:

`bridge=(14,5,16) witness=(18,5,17) token=1202204 active_before=1 active_after=2 handoff_error=0 target_fall=0.464622 actor_fall=0.464622 transfers=1 acquisitions=0`

The exact exported executable separately re-passed C0:

`C0_EXPORTED_SPARK_BASELINE_PASS`

## Exact artifact

Executable SHA-256:

`2fda163d1dc5310d6c34a280c41391bd268687e677e7771d104ed91899fe31e8`

Artifact:

- name: `FrameMatter-Reciprocal-Contact-Windows`
- id: `10592769292`
- workflow artifact digest: `sha256:52943494e427ee4bed2048fd8ae4f579c7adcdaacf0e661046628994d56a452a`

## Earned claim

Within this bounded challenger, the current query actor can participate in visibly reciprocal, finite, mass-sensitive dynamic contact without giving up the existing responsive/query locomotion substrate.

This does **not** establish a final player controller, final physical mass model, contact torque/friction model, true Matter resolution, large-world representation, or general embodied-material architecture.

## Stop rule

**Stop development here.**

The next authority is Owner feel. Do not start true-scale Matter, large-world work, solver-actor rewrite, new relation work, reconnect, or adaptive representation until the Owner has played this exact specimen and the resulting pressure is interpreted.
