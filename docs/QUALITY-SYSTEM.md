# FrameMatter Owner-Centered Quality System

Status: **ACTIVE PROCESS CONTRACT / Q0 HARDENING**

This system exists because the first P1 Owner candidate demonstrated a dangerous failure mode: a large campaign can accumulate sophisticated implementation, extensive automated tests and a green delivery pipeline while still fail badly at the surface through which the Owner actually experiences and judges the project.

The correction is broader than screenshot tests or more polish. FrameMatter needs a quality system capable of carrying long, ambitious campaigns without allowing implementation momentum, test count or internal sophistication to substitute for the actual Owner goal.

## Fundamental model

A large campaign has six independent truth planes:

1. **Owner-intent truth** — are we still building the thing the Owner asked for, at the intended quality/usefulness level?
2. **Substrate truth** — are hidden data/physics/lifecycle invariants correct?
3. **Composition truth** — do defended systems still work together through the real runtime?
4. **Observable truth** — do pixels and other outputs faithfully expose rather than hide/misrepresent the system?
5. **Interaction truth** — can a human use the composed system naturally enough to test the intended ideas and understand consequences?
6. **Promotion truth** — is one exact frozen runtime candidate actually worthy of scarce Owner attention?

A PASS on one plane never implies a PASS on another.

P1 failed because substrate/composition truth became strong while observable/interaction truth remained weak, and promotion nevertheless proceeded.

## Rule 1 — the Owner surface is part of the system

For Owner-facing research, presentation is not a cosmetic shell. Rendering, camera, visual language, feedback and UI are measurement instrumentation whenever they mediate Owner understanding.

> **Hidden truth that cannot be reliably observed is insufficient Owner-facing evidence.**

The same rule applies to audio, controls, timing, editor affordances and other relevant surfaces.

## Rule 2 — Campaign Contract before large promotion claims

Every major campaign has a versioned **Campaign Contract** containing at minimum:

- Owner goal,
- Owner-visible surface,
- protected invariants,
- required quality gates and evidence types,
- representative scenarios,
- negative baseline,
- explicit non-goals,
- change/assurance/promotion policy.

Acceptance properties cannot silently move to `later`, `polish` or `nonclaim` because they are difficult to test.

Versioned contract snapshots are append-only. The active snapshot is sealed after creation; material change requires the next contract version plus an explicit change record and predecessor hash binding.

The quality guard also ratchets inherited acceptance by default: a later contract may not silently remove an inherited required gate, protected invariant, representative scenario or negative baseline, change an inherited gate's evidence type, or add a new non-goal that shrinks scope.

If Owner intent genuinely changes, handle that as an explicit Owner-authorized contract transition rather than editing history.

## Rule 3 — claim/evidence type must match

No proxy evidence certifies a different quality dimension.

Examples:

- compile PASS cannot certify runtime behavior,
- headless physics PASS cannot certify rendering,
- screenshots cannot certify interaction feel,
- SpringArm existence cannot certify camera composition,
- export success cannot certify package usefulness,
- low numerical error cannot certify causal legibility,
- many tests cannot certify the Owner goal if those tests do not measure it.

Every promoted claim names its evidence type and scope.

## Rule 4 — readiness is a matrix, not one green pipeline

Readiness is tracked in **two dimensions**.

### Quality-plane axis

Each contracted gate is `PASS`, `FAIL`, `PENDING` or `SUPERSEDED`.

Examples: mechanical integration, form/depth readability, Matter granularity, state semantics, camera composition, interaction hierarchy, UI hierarchy, independent assurance.

### Representative-scenario axis

Every scenario in the Campaign Contract has its own status/evidence/runtime binding.

For current P1 this includes:

- default static Matter,
- remove/place/expand targeting,
- zero-launch release,
- dynamic translation/yaw,
- moving edit + storage rebase,
- topology split + successor relations,
- freeze at current pose,
- close-camera obstacle stress,
- actor near Space edge,
- fall/recovery.

A campaign cannot promote because all component/system rows are green while an ordinary composed scenario remains unproven.

One material FAIL or required PENDING blocks Owner delivery.

## Rule 5 — representative evidence uses the real Owner surface

The same scenario set is reused across challengers so A/B comparisons remain causal rather than anecdotal.

Rendered evidence must include a parity path close enough to the actual Owner environment to reproduce relevant backend-specific failures. Convenient alternate renderers may remain regression lanes but cannot silently substitute for the Owner path.

Every important Owner-facing dimension receives at least one composed scenario using real Matter, camera, interaction and runtime state rather than synthetic neutral fixtures only.

## Rule 6 — bounded challengers before promotion

When a quality dimension is weak:

1. preserve the failed baseline,
2. state one hypothesis,
3. change one coherent mechanism family,
4. capture the same representative states,
5. compare directly,
6. record improvement and regression,
7. promote only the winning mechanism.

Do not combine lighting/material/camera/UI changes merely to produce a nicer screenshot. A/B challenger infrastructure is preferred where practical.

## Rule 7 — candidate lifecycle prevents moving-target evidence

Development and promotion are distinct states.

### OPEN

Implementation may change freely. Evidence is exploratory/bounded and may refer to different commits. No final Owner-readiness claim exists.

### FROZEN

One full `candidate_runtime_commit` is selected as the object being judged. Candidate code stops changing.

All final G8 gate evidence and every representative scenario must be re-earned/bound to this same frozen runtime SHA.

If implementation changes are required, the old frozen candidate is abandoned. A new runtime SHA becomes the next candidate and final evidence must be repeated where relevant.

### READY_FOR_OWNER

Only after all required gates and scenarios PASS on the frozen runtime, independent assurance passes, blockers are empty and Owner attention is explicitly authorized can that same runtime become `approved_runtime_commit`.

Therefore:

> **development HEAD ≠ frozen runtime candidate ≠ governance/evidence HEAD.**

They may coincide, but the process never assumes they do.

## Rule 8 — governance/evidence may be newer than runtime

A self-referential "manifest must contain its own commit SHA" model is rejected.

The runtime object is frozen first. Later commits may add screenshots, reports, readiness updates and authorization while continuing to point at the same runtime SHA.

This permits honest provenance:

- runtime commit = what is being certified and eventually packaged,
- governance/evidence commit = the later state that explains why that runtime is allowed to reach the Owner.

Changing governance does not silently change the runtime artifact.

## Rule 9 — independent assurance before promotion

The final implementation context cannot be the only judge of its own readiness.

After candidate freeze and final evidence collection, a separate **read-only falsification review** is required. Prefer a fresh/separate AI context rather than the implementation conversation.

The reviewer:

- does not patch the candidate,
- evaluates the original Owner goal,
- checks claim↔evidence fit,
- reviews nominal and adverse scenarios,
- searches for scope drift and first-minute embarrassment,
- records material findings.

Any material finding blocks promotion. Fixing a finding creates a new runtime candidate; the reviewer does not mutate the reviewed candidate into PASS.

Protocol: `docs/INDEPENDENT-ASSURANCE.md`.

Machine report: `quality/assurance/p1-independent-review.json`.

## Rule 10 — Owner attention is a scarce resource

Before asking the Owner to run a build, internal work exhausts cheaper evidence:

- mechanical tests,
- deterministic rendered captures,
- baseline A/B review,
- scripted adverse scenarios,
- autonomous real-time rehearsal,
- frame-by-frame review,
- package/runtime sanity,
- independent assurance.

The Owner should answer questions only the Owner can answer: feel, desire, priorities, emergent use, whether the experience matches intent.

The Owner should not be first to discover that half the screen is black, camera loses the experiment, controls are misleading or UI is obviously broken.

## Rule 11 — promotion is an explicit transaction

A campaign does not become an Owner candidate because the work feels complete.

Promotion requires the machine-readable readiness state to prove:

- `candidate_state = FROZEN`,
- all contracted quality gates PASS,
- all representative scenarios PASS,
- every PASS has direct evidence,
- every gate/scenario is bound to the frozen runtime SHA,
- independent assurance PASS on that runtime,
- no open blockers,
- `promotion_authorized = true`,
- `approved_runtime_commit == candidate_runtime_commit`,
- Owner attention event explicitly allowed.

`quality/p1-owner-readiness.json` is the current executable P1 state.

## Rule 12 — delivery materializes the approved runtime, not governance HEAD

Delivery starts from the later governance/evidence checkout and validates readiness + assurance.

It then separately checks out **exactly `approved_runtime_commit`** and exports that runtime. Packaging sanity uses the governance wrappers against the frozen runtime checkout.

Build provenance records both:

- approved runtime SHA,
- governance/evidence SHA.

A manual workflow click is never authorization by itself.

## Rule 13 — artifact still needs artifact-level sanity

Readiness authorizes packaging; packaging is still fallible.

Delivery verifies where practical:

- approved runtime checkout identity,
- strict import/compile,
- canonical startup,
- critical integrated runtime path,
- exports,
- file/provenance/metadata,
- artifact-level startup or smoke where host support permits,
- hashes/provenance.

Artifact failure does not retroactively falsify source evidence, but it blocks delivery.

## Rule 14 — escaped failures become permanent negative baselines

A failed Owner candidate is not overwritten after repair.

Preserve:

- runtime/artifact identity,
- recording/screenshots,
- failure symptoms,
- confirmed vs inferred root causes,
- gates that failed to catch it,
- process correction.

The next candidate must be demonstrably superior in the dimensions that triggered the recovery campaign.

A material defect discovered by the Owner should create a durable regression/evidence ratchet whenever practical.

## Rule 15 — host/tool judgments require competent usage first

Framework viability cannot be judged through a configuration mistake or intentionally primitive presentation path.

Before blaming the host:

- reproduce the failure,
- identify project-side vs backend-specific vs host-inherent causes,
- use normal host facilities competently,
- compare a bounded equivalent implementation only if host friction remains disproportionate.

This prevents both sunk-cost loyalty and premature host rejection.

# Large-campaign operating loop

## A — recover + contract

Recover Owner intent/history. Establish/update Campaign Contract before major claims.

## B — bounded research

Attack uncertain foundations with falsifiable challengers. Preserve negative results.

## C — integrate

Compose the smallest real runtime exercising neighboring systems together.

## D — observe

Instrument the actual Owner surface: rendered frames, recordings, interaction traces or relevant editor workflows.

## E — improve through bounded A/B work

Fix one coherent failure family at a time and compare against identical scenarios.

## F — freeze candidate

When implementation appears worthy of final evaluation, select one exact runtime SHA and stop candidate mutation.

## G — final evidence matrix

Re-run required quality gates and every representative scenario on that frozen runtime.

## H — adversarial rehearsal

Deliberately seek ugly/edge/confused states and review the result as a user would.

## I — independent assurance

Fresh read-only falsification review of contract, candidate and evidence. Material finding returns work to implementation and therefore creates a new runtime candidate.

## J — readiness audit + authorization

Re-read original Campaign Contract. Promote only if all gates/scenarios/assurance are PASS on the same frozen runtime.

## K — exact-runtime delivery

Materialize approved runtime, prove artifact/provenance, then spend Owner attention.

## L — Owner evidence + retrospective

Use Owner test for high-information judgment, then record learning before expanding scope.

# Required red-team questions before every Owner promotion

- What could make this build embarrassing within 30 seconds?
- What can be catastrophically wrong while automated tests remain green?
- Which acceptance property has the weakest direct evidence?
- Which representative scenario is least well observed?
- Which subsystem pair has not been observed together at the Owner surface?
- Are we promoting because the goal is met, or because much work accumulated?
- Did an original requirement quietly move into later/polish/nonclaim?
- Is the Owner about to discover something we could find ourselves by simply looking/listening/using the build?
- Is any PASS based on evidence from another runtime SHA?
- Would we accept this evidence if another team produced it?

Any uncomfortable material answer blocks promotion until resolved or explicitly changed by the Owner through a new contract version.

# Attention-cost rule

Optimize not only implementation cost but **Owner attention cost**.

A long internal run is valuable when it converts many low-information interruptions into one high-information Owner test. A long run ending in an obvious first-frame failure is a quality failure even when hidden implementation is sophisticated.

# Current application to P1

P1 is the first campaign governed by this system.

- substrate truth: strongly defended in current bounded/integrated scope,
- composition truth: mechanically strong,
- observable truth: recovery active; first P1 candidate failed,
- interaction truth: not yet re-earned,
- candidate state: `OPEN`,
- promotion truth: **BLOCKED**.

Active sealed contract: `quality/contracts/p1-owner-facing-recovery.v3.json`.

Executable readiness state: `quality/p1-owner-readiness.json`.

Readiness guard: `ci/verify_owner_readiness.py`.

Independent assurance guard: `ci/verify_independent_assurance.py`.

# Non-goal of the quality system

This system must not become ceremony that prevents experimentation.

OPEN research remains permissive, destructive and fast. Heavy gates apply at **freeze/promotion boundaries**, where claims strengthen and Owner attention is about to be spent.

The purpose is not to slow exploration. It is to stop unearned promotion.