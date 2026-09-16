# Independent Owner assurance protocol

Status: **REQUIRED AT FINAL PROMOTION / READ-ONLY**

This protocol exists to prevent the same implementation context from being the sole author, evidence selector and final judge of its own Owner-readiness claim.

It is deliberately narrow. It is not a second development team and it must not become continuous ceremony during exploration.

## When it runs

Independent assurance runs only after:

1. one runtime commit has been explicitly frozen as the final candidate,
2. implementation work on that candidate has stopped,
3. mechanical, rendered, interaction and scenario evidence has been collected for that exact runtime,
4. the candidate is otherwise approaching G8 promotion.

The review is invalidated by any change to candidate runtime. A changed runtime becomes a new candidate and must receive a new review.

## Separation requirement

The review should run in a **separate read-only AI context** from the implementation run wherever the product environment permits it (for example a fresh Browser ChatGPT conversation or another explicitly read-only reviewer context).

The reviewer receives:

- Campaign Contract,
- Owner-visible goal and negative baseline,
- frozen runtime SHA,
- readiness matrix,
- rendered/rehearsal evidence,
- important mechanical evidence,
- known limitations and open questions.

It does **not** receive a mandate to fix the candidate while reviewing it.

If a material finding requires implementation change, assurance stops with FAIL/BLOCKED. The implementation context creates a new runtime candidate. Review does not patch the old candidate into PASS.

This separation is procedural rather than cryptographic. The machine-readable report records whether the required separation was actually used. The frozen runtime SHA prevents the review from blessing a moving implementation target.

## Reviewer mandate

The reviewer is asked to falsify readiness, not confirm it.

At minimum it must ask:

- Does the evidence directly support the original Owner goal rather than a narrower proxy?
- Did any acceptance property move into polish/later/nonclaim without Owner authorization?
- Is any required quality plane supported only by a different evidence type?
- Are all representative scenarios covered on the frozen runtime?
- Is there a subsystem composition that can still create an embarrassing first-minute failure while individual gates remain green?
- Does the rendered/interactive evidence actually show the hidden systems the Owner is meant to judge?
- Are nominal and adverse conditions both represented?
- Is there a material known defect that the readiness manifest understates?
- Would this evidence be convincing if it came from another team?

## Material finding

A material finding is any issue that could reasonably make the Owner-facing claim false, misleading or substantially weaker than the Campaign Contract.

Examples:

- dominant visual failure in an ordinary view,
- camera state that loses the experiment,
- misleading operation feedback,
- important scenario lacking direct evidence,
- evidence produced from a different runtime SHA,
- mechanical state that is hidden or visually misrepresented,
- scope drift that weakens the Owner goal,
- a package/runtime mismatch,
- a known first-minute defect being classified as minor to allow delivery.

Any material finding blocks promotion. Findings are resolved by producing a new candidate/evidence state, not by downgrading the finding inside the assurance review.

## Machine-readable assurance report

Current P1 report:

`quality/assurance/p1-independent-review.json`

A PASS report must state, at minimum:

- exact frozen runtime SHA reviewed,
- separate read-only review context identifier,
- reviewer role and falsification mode,
- no candidate changes authored during review,
- Owner goal evaluated,
- claim/evidence fit evaluated,
- non-empty nominal scenario review,
- non-empty adverse/off-nominal scenario review,
- non-empty evidence set examined,
- zero material findings,
- final disposition PASS.

The readiness checker validates these conditions when `independent_assurance_review` is promoted to PASS.

## What this does not claim

This is not organizational independence equivalent to an external certification authority. FrameMatter is a small Owner+AI R&D project.

The purpose is practical epistemic separation: freeze the object being judged, make the final reviewer read-only and falsification-oriented, and prevent implementation momentum from automatically becoming promotion confidence.
