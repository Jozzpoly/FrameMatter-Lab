# Convergence C5B Relation Succession — qualification 2026-09-18

Status: **PASS / LIVING RELATION SUCCESSION BOUNDED**

Qualified source:

`6171413d165bf09cfe631663ea65bb658ec58a04`

Workflow:

`35380849919`

## Claim

C5B asked:

> if relation-owning Matter survives a topology split while its Space/body identity and compact local frame change, can the same logical relation follow retained lineage into the correct successor without a world-space seam discontinuity?

## First run — RED, then contract correction

Initial C5B source:

`cc4282b699cb791cf9d391b95a4f53caf9b7b65c`

The first run failed only this assertion:

> mapped successor relation frame is world-continuous before host rebind

The probe compared the successor seam against the **ideal authored anchor** with a tolerance of `2e-5`.

That was the wrong invariant.

The passive hinge already carries normal solver compliance of roughly `0.003` world units before succession. Topology succession must preserve the **actual live source seam frame at the transaction boundary**. It must not magically erase accumulated solver compliance and snap the world back to an authored ideal pose.

The corrected probe therefore compares:

`split_result.source_transform * old_anchor_local`

against:

`successor_body.global_transform * mapped_anchor_local`

while separately bounding ordinary passive-joint compliance against the authored anchor.

No runtime behavior was changed to obtain PASS.

## Qualified result

Metric:

`pre_gap=0.003385 split_gap=0.003062 succession_error=0.0000000000 post_gap=0.004296 post_rotation=1.519258 old_body=31289509377 new_body=33705428484 successor_origin=(2,0,0) endpoint=52003 cut_token=52002`

Meaning:

- relation is live before split;
- moving Matter edit destroys a non-endpoint bridge cell;
- production dynamic topology split retires the old Space/body;
- exact retained endpoint lineage resolves to one successor;
- successor compact mapping has non-zero source origin;
- successor relation-frame mapping has zero measured discontinuity relative to the live pre-split source frame;
- engine body identity changes;
- logical relation record remains unchanged;
- the passive solver host rebinds to the successor;
- seam remains bounded after succession;
- gravity-driven relative rotation continues.

## Protected chain

The same exact run re-passed:

- `C2_STRUCTURAL_LAW_PASS`;
- `C3_AUTHORITY_COMPOSITION_PASS`;
- `C4_PASSIVE_RELATION_PASS`;
- `C5A_RELATION_HISTORY_PASS`;
- `W0D_RECOVERY_CAUSAL_LOOP_PASS`;
- exact exported `C0_EXPORTED_SPARK_BASELINE_PASS`.

Exact C5B executable SHA-256:

`ec4fccac332ea2f0d7c29e7fe74b9e70605b7e44e18fb4f190dc99d03c8214d4`

## Earned conclusion

> **a living relation can follow retained Matter identity through real dynamic topology succession, compact-frame remap and fresh physics-body identity without reverting to snapshot-era object identity.**

## C5 closure judgement

C5 now has direct evidence for:

- moving live Matter edits while relation remains active;
- endpoint destruction killing relation truth;
- same-address recreation not resurrecting relation;
- topology succession/reframing preserving relation when endpoint Matter survives;
- solver-host identity being subordinate to live Matter identity/history.

The roadmap's rigid brace/bypass pressure is **not claimed**. It would require reconnect/authority-merge semantics across already separated authorities, which are not currently earned. That is retained as a future WORLD LANGUAGE pressure rather than silently expanding C5 into a reconnect framework.

C5 is therefore closed as a **bounded Living World PASS**, not as proof of complete mechanical relation semantics.
