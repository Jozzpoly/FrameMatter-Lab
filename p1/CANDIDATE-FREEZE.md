# P1 G8 candidate freeze marker

The commit that introduces this file is the proposed frozen P1 runtime candidate for final adversarial preflight.

This marker is intentionally runtime-neutral: Godot does not load it and it changes no scene, script, resource, physics or presentation behavior. Its location under `p1/` is deliberate so the existing exact-source P1 mechanical and rendered workflows re-run against one common candidate commit.

Governance must not set `candidate_state` to `FROZEN`, authorize Owner attention or approve delivery merely because this marker exists. The candidate is frozen only after the same commit has re-earned the required runtime/rendered evidence and the readiness manifest is updated in a later governance-only commit.

Any subsequent change to P1 runtime, scene, presentation, interaction, physics or evidence-driving behavior invalidates this proposed candidate and requires a new freeze marker commit / candidate SHA.
