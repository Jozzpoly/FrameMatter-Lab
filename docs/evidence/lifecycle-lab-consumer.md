# Interactive LAB lifecycle consumer — evidence

Status: **FULL PASS / reusable-substrate evidence in a narrow lifecycle scope**

Commit under test: `d0dee2e9e811568a458acc3ff35f7de4c204931c`

CI authority: `Validate research harness` run `34879294428`; both fast and full research jobs passed.

## Question

Can the actual Owner-facing `lab/main.tscn` consume the same `LocalMatterSpace` lifecycle path already exercised by I0B, instead of owning its own Matter/provider replacement orchestration?

## Setup

The legacy G0 LAB front door was retained and rewired to use one `LocalMatterSpace` containing one authoritative `CellVolume + MatterLineageMap` pair.

Interactive actions:

- `A` — request static → dynamic provider replacement,
- `F` — request dynamic → static provider replacement,
- `M` — destroy/recreate one probe cell through shared Matter+lineage mutation authority,
- `C` — mutate retained Matter material while retaining lineage,
- `R` — reset the bounded LAB.

The automated smoke test instantiates the real `lab/main.tscn` scene and invokes those same LAB actions. It does not implement provider replacement itself.

## Result

**PASS.**

Measured fast-path run:

- persistent logical Space ID: `29477570019`,
- initial static provider ID: `29494347236`,
- dynamic provider ID: `32279365092`,
- final static provider ID: `42966451684`,
- first dynamic PhysicsServer displacement: `0.0310848188`,
- next-sync PhysicsServer → Node position gap: `0.0000000000`,
- observed dynamic translation: `0.15992963`,
- post-freeze maximum static drift: `0.0000000000`,
- probe lineage: `500041` initially → `500077` after dynamic destroy/recreate → `500078` after post-freeze destroy/recreate,
- final occupied cells: `76`.

The full research job also passed all existing ratchets after the LAB consumer was inserted.

## What this establishes

Within this bounded lifecycle:

- the real interactive scene and the adversarial I0B probe share the same runtime lifecycle substrate,
- one logical Space identity survives real provider identity changes,
- the LAB does not own static/dynamic replacement logic,
- dynamic motion is already visible in the first solver step even though Node visibility follows on the next PhysicsServer sync,
- the same mutation authority works while dynamic and again after returning to static,
- destroy/recreate semantics produce fresh Matter lineage,
- retained-material mutation preserves lineage,
- the HUD can expose provider authority and solver/node visibility without becoming a second authority.

This is the first evidence that `LocalMatterSpace` is reusable by more than one consumer shape: an adversarial automated lifecycle client and the actual interactive LAB front door.

## Explicit non-claims

This does **not** establish:

- production-ready Space architecture or final APIs,
- actor continuity across provider changes,
- scalable collision/meshing,
- persistence/save-load identity,
- canonical-world reintegration,
- topology split through the shared runtime,
- world streaming or multiple simulation domains,
- playability/product value.

The result should therefore be treated as narrow **reusable-substrate evidence**, not as architectural finalization.
