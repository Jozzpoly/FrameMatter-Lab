# FrameMatter Owner-Centered Quality System

Status: **ACTIVE PROCESS CONTRACT**

This system exists because the first P1 Owner candidate demonstrated a dangerous failure mode: a large campaign can accumulate strong implementation, extensive automated tests and a green delivery pipeline while still failing badly at the surface through which the Owner actually experiences and judges the project.

The correction is broader than adding screenshot tests. FrameMatter needs a quality system capable of carrying long, ambitious campaigns without allowing hidden technical progress to substitute for the actual Owner goal.

## Fundamental model

A large campaign has six independent truth planes:

1. **Owner-intent truth** — are we still building the thing the Owner asked for, at the level of quality and usefulness actually intended?
2. **Substrate truth** — are the hidden data/physics/lifecycle invariants correct?
3. **Composition truth** — do individually defended systems still work when composed through the real runtime?
4. **Observable truth** — do the pixels and other outputs faithfully expose what the system is doing rather than hiding, flattening or misleading it?
5. **Interaction truth** — can a human actually use the composed system naturally enough to test the intended ideas and understand consequences?
6. **Promotion truth** — is the exact packaged candidate worthy of consuming scarce Owner attention?

A PASS on one plane never implies a PASS on another.

P1 failed because substrate and composition truth became strong while observable and interaction truth remained weak, and promotion nevertheless proceeded.

## Rule 1 — the Owner surface is part of the system

For Owner-facing research, presentation is not a cosmetic shell.

If a system is meant to be understood through rendered output, then rendering, camera, visual language, feedback and UI are measurement instrumentation. A broken instrument contaminates the experiment even when the hidden mechanics are correct.

Therefore:

> **hidden truth that cannot be reliably observed is insufficient Owner-facing evidence.**

This applies beyond graphics. Audio, control feedback, timing, editor affordances and other surfaces become first-class whenever they mediate the Owner's understanding of a system.

## Rule 2 — acceptance properties cannot silently become non-goals

Every major campaign starts with an explicit **Campaign Contract** containing:

- Owner goal / north star,
- Owner-visible surface being improved or tested,
- defended invariants that must survive,
- acceptance dimensions,
- representative scenarios,
- known negative baseline,
- explicit non-goals,
- stop conditions,
- promotion conditions.

During execution an acceptance property may be revised only when one of these is true:

- evidence demonstrates that the property is wrong or irrelevant,
- a stronger formulation supersedes it,
- the Owner explicitly changes the intent.

Difficulty of testing is **not** a valid reason to demote an acceptance property into a nonclaim.

Every material change to the campaign contract must be recorded as a decision, including what changed, why, and what evidence or Owner feedback justified it.

This is the anti-drift rule that P1 previously lacked.

## Rule 3 — claim/evidence type must match

No proxy evidence may certify a different quality dimension.

Examples:

- compile PASS cannot certify runtime behavior,
- headless physics PASS cannot certify rendering,
- screenshot PASS cannot certify interaction feel,
- scene-graph composition cannot certify camera composition,
- a SpringArm node existing cannot certify useful framing,
- package export success cannot certify package usefulness,
- low numerical error cannot certify causal legibility,
- many tests cannot certify the original Owner goal if the tests do not measure it.

Every promoted claim must name its evidence type and scope.

## Rule 4 — quality is a matrix, not one green pipeline

Campaign readiness is tracked per acceptance dimension.

A dimension may be:

- `PASS` — current evidence directly supports it,
- `FAIL` — current evidence contradicts it,
- `PENDING` — evidence is missing or insufficient,
- `SUPERSEDED` — a stronger explicit contract replaced it.

There is no aggregate "mostly green" promotion state. One material `FAIL` or required `PENDING` blocks Owner delivery.

The machine-readable readiness manifest is the executable form of this rule.

## Rule 5 — evidence must be representative of the real surface

Each Owner-facing campaign defines a **Representative Scenario Set** before polish or promotion.

For P1 the set includes at minimum:

- default static Matter,
- editing/targeting,
- release,
- dynamic translation/rotation,
- moving edit and storage rebase,
- topology split,
- successor freeze,
- close-camera/obstacle stress,
- fall/recovery.

The same scenarios are reused across challengers so comparisons are causal rather than anecdotal.

Rendered evidence must use a parity path close enough to the actual Owner environment to reproduce relevant backend-specific failures. A convenient alternate renderer may remain a regression lane but cannot silently stand in for the Owner path.

## Rule 6 — bounded challengers before promotion

When a quality dimension is weak:

1. preserve the failed baseline,
2. state one hypothesis,
3. change one coherent mechanism family,
4. capture the same representative scenarios,
5. compare directly,
6. record improvement and regression,
7. promote only the winning mechanism.

Do not combine lighting, material, camera and UI changes merely to produce a nicer screenshot. That destroys causal knowledge and makes regressions difficult to attribute.

A/B challenger infrastructure should be preferred when variants can be tested without mutating canonical runtime.

## Rule 7 — composition must be re-tested at the visible layer

Isolated components can be individually correct and jointly disastrous.

The failed P1 camera + lighting interaction is the canonical example: camera collision shortened framing near Matter while the lighting defect turned that Matter into a black screen. Neither isolated mechanical test captured the composed visual failure.

Therefore every important Owner-facing dimension needs at least one composed scenario using the **real Matter, real camera, real interaction and real runtime state**, not only synthetic neutral fixtures.

## Rule 8 — Owner attention is a scarce resource

An Owner test is not free QA.

Before asking the Owner to run a build, internal work must have already exhausted cheap evidence sources:

- automated mechanical tests,
- rendered deterministic captures,
- side-by-side baseline comparison,
- scripted adversarial sequences,
- autonomous real-time rehearsal,
- frame-by-frame review,
- package startup/runtime sanity.

The Owner should be asked questions that only the Owner can answer: feel, desire, priorities, emergent use, whether the experience matches intent.

The Owner should **not** be the first person to discover that half the screen is black, the camera loses the experiment, controls are misleading, or the UI is obviously broken.

## Rule 9 — promotion is an explicit transaction

A campaign does not become an Owner candidate because work "feels finished".

Promotion requires a machine-readable readiness manifest with:

- all required dimensions `PASS`,
- evidence references for every required PASS,
- no open blockers,
- explicit `promotion_authorized = true`,
- an exact `approved_commit`,
- permission for an Owner attention event.

The delivery workflow verifies this manifest and exact commit before export.

A later code change invalidates the authorization until the manifest is deliberately rebound to the new commit after relevant evidence is re-run.

This prevents a green old rehearsal from blessing a changed executable.

## Rule 10 — delivery must test the artifact, not only the source

After pre-promotion readiness succeeds, the delivery workflow must still:

- build the exact approved commit,
- verify canonical startup,
- re-run critical integrated gates where practical,
- export the artifact,
- verify file/provenance/metadata,
- perform an artifact-level startup or smoke check where the host allows it,
- record hashes and provenance.

Source readiness authorizes packaging; packaging still has to prove itself.

## Rule 11 — failure is preserved, not overwritten

A failed Owner candidate becomes a permanent negative baseline.

Do not rewrite its evidence into a softer description after a fix. Preserve:

- exact commit/artifact,
- screenshots/recording,
- failure symptoms,
- root causes separated into confirmed vs inferred,
- which gates failed to catch it,
- process correction.

The next candidate must be demonstrably superior to the failed baseline in the dimensions that triggered the recovery campaign.

## Rule 12 — host/tool judgments require competent usage first

Framework or engine viability cannot be judged through a configuration mistake or intentionally primitive presentation path.

Before blaming the host:

- reproduce the failure,
- identify whether it is project-side, backend-specific or host-inherent,
- use the host's normal intended facilities competently,
- compare a bounded equivalent implementation only if the host still appears disproportionately costly or limiting.

This protects against both sunk-cost loyalty and premature host rejection.

## Large-campaign operating loop

### Phase A — contract

Recover Owner intent and project history. Write/update Campaign Contract and readiness dimensions before major implementation.

### Phase B — bounded research

Attack uncertain foundations with falsifiable challengers. Preserve negative results.

### Phase C — integrate

Compose the smallest real runtime that exercises neighboring systems together.

### Phase D — observe

Build evidence for the actual Owner surface: rendered frames, recordings, interaction traces, editor workflows or other relevant instrumentation.

### Phase E — adversarial rehearsal

Deliberately seek ugly states, edge cases, confused framing, rapid repeated input, transitions and recovery paths. Review the result as a user would experience it.

### Phase F — readiness audit

Re-read the original Campaign Contract. For every acceptance property ask:

- is it still required?
- what current evidence directly supports it?
- did scope drift weaken it?
- did another subsystem make it worse?
- would the Owner see/feel the claimed property?

Only then update the readiness manifest.

### Phase G — promotion transaction

Bind readiness to an exact commit and authorize Owner delivery.

### Phase H — Owner evidence

Use Owner time for high-information judgment rather than obvious defect discovery.

### Phase I — retrospective

After Owner evidence, update failure/learning records before expanding scope.

## Required red-team questions before every Owner promotion

- What would make this build embarrassing within the first 30 seconds?
- What can be catastrophically wrong while all current automated tests remain green?
- Which acceptance property has the weakest direct evidence?
- Which subsystem pair has not been observed together at the Owner surface?
- Are we promoting because the goal is met, or because a lot of work has accumulated?
- Did any original requirement quietly move into "later", "polish" or "nonclaim"?
- Is the Owner about to discover a problem we could have found ourselves by simply looking, listening or using the build?
- If this were produced by another team, would we accept the evidence as sufficient?

Any uncomfortable answer blocks promotion until resolved or explicitly accepted by the Owner.

## Attention-cost rule

Work should optimize not only implementation cost but **Owner attention cost**.

A long internal run is justified when it converts many low-value Owner interruptions into one high-information test. Conversely, a long run that ends by exposing an obvious first-frame failure to the Owner is a quality failure even if the implementation underneath is sophisticated.

## Current application to P1

P1 is the first campaign governed by this system.

- Substrate truth: strongly defended in bounded/integrated scope.
- Composition truth: strongly defended mechanically in current scope.
- Observable truth: recovery in progress; first P1 candidate failed.
- Interaction truth: not yet re-earned after the visual failure.
- Promotion truth: **BLOCKED**.

`quality/p1-owner-readiness.json` is the executable readiness state.

`ci/verify_owner_readiness.py` validates the structure during ordinary CI and hard-blocks Owner delivery until every required gate is PASS and authorization is bound to the exact commit.

## Non-goal of the quality system

This system must not become ceremony that prevents experimentation.

Early research remains permissive, destructive and fast. Heavy gates apply at **promotion boundaries**, where claims become stronger and Owner attention is about to be spent.

The purpose is not to slow exploration. It is to stop unearned promotion.