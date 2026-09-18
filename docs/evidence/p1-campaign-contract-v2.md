# P1 Campaign Contract v2 — promotion-model hardening

Status: **CONTRACT CHANGE RECORD**

This record explains why P1 Owner-facing recovery moves from Campaign Contract v1 to v2.

The change is intentionally made before visual recovery resumes. It is not a relaxation of Owner requirements; it makes promotion stricter and removes two weaknesses found while red-teaming Q0-v1.

## Trigger 1 — exact-commit self-reference was not implementable cleanly

Q0-v1 required the Readiness Manifest itself, every gate verification and the packaged candidate to share one exact Git commit SHA.

That sounds precise but is self-referential: a commit SHA is known only after the manifest is committed. Writing that SHA into the manifest creates a new commit with a different SHA.

A quality system that requires an impossible final state encourages either manual exceptions or fake precision.

### v2 correction

Separate:

- **approved runtime commit** — the frozen source revision whose executable behavior was actually verified and will be packaged;
- **governance/evidence commit** — later repository state containing reviews, evidence records and authorization referring to that frozen runtime.

Every required runtime-relevant gate is bound to the exact approved runtime commit.

The delivery workflow first validates governance/readiness, then explicitly checks out and packages `approved_runtime_commit` rather than implicitly building governance HEAD.

Any executable/runtime change requires a new runtime candidate and re-verification. Documentation/evidence recording after a frozen runtime candidate does not create an impossible SHA loop.

## Trigger 2 — author and final assurer were still effectively the same role

Q0-v1 made evidence much harder to fake accidentally, but the same working agent could still:

1. implement the candidate,
2. select the evidence,
3. interpret the evidence,
4. authorize promotion.

That leaves confirmation bias and claim/evidence mismatch insufficiently challenged.

NASA software assurance guidance describes IV&V as rigorous analysis/testing that identifies objective evidence and provides a **second independent assessment** throughout the lifecycle; validation separately asks whether the product meets mission/customer needs rather than merely whether it was implemented correctly.

FrameMatter is not a safety-critical NASA program, but the structural lesson applies directly to the P1 failure mode.

### v2 correction

Add required gate:

`independent_assurance_review`

The review is read-only with respect to the candidate under review and must attempt falsification rather than polishing the implementation.

Its minimum questions are:

- Is the current Owner goal still the one being promoted?
- Did any acceptance property weaken or disappear?
- Does each material claim have evidence of the correct type?
- Is the evidence actually from the approved runtime candidate and relevant Owner surface?
- Are nominal and deliberately adverse representative scenarios covered?
- Is any required gate relying on proxy evidence?
- Is there any obvious first-minute defect the Owner would discover before providing high-value judgment?
- Are unresolved material findings being hidden by aggregate green status?

A material assurance finding blocks promotion and routes work back to the relevant quality plane.

## Trigger 3 — one mutable contract file was too easy to reinterpret

Logical `contract_version` alone is not enough historical clarity if the same file path can be overwritten repeatedly.

### v2 correction

Campaign contracts become versioned snapshots under:

`quality/contracts/`

v1 is preserved as:

`quality/contracts/p1-owner-facing-recovery.v1.json`

v2 is a new file rather than an in-place rewrite. It points to its predecessor and this change record.

Future material contract changes should create v3, v4, etc., with their own change records. Old snapshots are historical evidence, not mutable live policy.

## Owner intent impact

None of these changes reduce scope or visual/interaction expectations.

They strengthen the route to claiming those expectations are met.

The core Owner-facing goal remains unchanged:

> provide a professional, physically legible sandbox research surface where the Owner can directly see and judge editable Matter, moving/static local Spaces, actor relations, editing, topology consequences and motion without reconstructing hidden mechanics from debug output.

## Promotion consequence

P1 remains **BLOCKED**.

Contract v2 adds another required evidence plane and replaces impossible same-commit governance binding with explicit frozen-runtime provenance.

No Owner package may be produced until the v2 readiness guard, adversarial self-tests and delivery path demonstrate these rules are actually enforceable.