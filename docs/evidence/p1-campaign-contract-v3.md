# P1 campaign contract v3 — sealed quality contract

Status: **Q0 HARDENING / NO ACCEPTANCE RELAXATION**

Contract v3 does not weaken the Owner-facing target established by v2. It seals the quality model after the runtime/governance split was made executable in the readiness checker and delivery workflow.

## Why v3 exists

During Q0 hardening, v2 itself was edited while the quality tooling was still being designed. That is acceptable as construction history but means v2 cannot honestly serve as the first immutable active contract snapshot.

V3 therefore becomes the first contract intended to be **append-only after creation**.

The active quality checker must reject an active versioned contract whose repository history contains more than one distinct Git blob. Future changes to acceptance, evidence type, assurance policy or promotion policy must create v4 (or later) with an explicit predecessor binding and change record.

## Strengthening relative to v2

V3 keeps the same Owner goal, visible surface, representative scenarios and required quality gates.

It strengthens process semantics by making explicit that:

- the approved runtime commit is the object being certified,
- later governance/evidence commits may authorize that frozen runtime but may not silently become the runtime artifact,
- delivery must materialize the approved runtime commit rather than governance HEAD,
- independent assurance must review one frozen runtime commit,
- changing candidate runtime after assurance invalidates that assurance,
- the active versioned contract snapshot itself is immutable; changes require a new contract version.

No existing visual, interaction or mechanical acceptance requirement is removed.

## Relationship to older contracts

- v1: first machine-readable campaign contract.
- v2: introduced independent assurance and runtime/governance separation while the tooling was still being hardened.
- v3: seals those semantics into the first immutable active snapshot.

V3 pins the exact Git blob of v2 so later mutation of the predecessor breaks contract-chain validation.
