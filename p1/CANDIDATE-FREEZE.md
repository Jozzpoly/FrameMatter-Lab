# P1 post-R-V5 candidate freeze marker

The commit that introduces this revision is the proposed frozen P1 runtime candidate after the Owner-failed visual package and the R-V0 through R-V5 rebuild campaign.

The previous G8 freeze represented the superseded `b5050b669ec4101226095183929f5790f0a034fc` candidate and has no current promotion authority.

This marker is intentionally runtime-neutral: Godot does not load it and it changes no scene, script, resource, physics or presentation behavior. Its location under `p1/` is deliberate so the active exact-source P1 mechanical and rendered workflows re-run against one common candidate commit.

R-V5 has already produced a qualified pre-freeze runtime (`5b16759d0c5dbfda36f7f48a80e3498c5db8719e`) and durable finding/repair evidence in `docs/evidence/p1-rv5-chaotic-owner-surface-rehearsal.md`. This marker does not inherit PASS merely from that earlier runtime: the commit containing this marker must re-earn the active candidate evidence on its own exact SHA.

Governance must not set `candidate_state` to `FROZEN`, authorize Owner attention or approve delivery merely because this marker exists. The candidate is frozen only after the same commit has re-earned the required runtime/rendered evidence and the readiness manifest is updated in a later governance-only commit.

Any subsequent change to P1 runtime, scene, presentation, interaction, physics or evidence-driving behavior invalidates this proposed candidate and requires a new freeze-marker commit / candidate SHA.
