# P1 quality-system postmortem

Status: **MATERIAL PROCESS FAILURE / CORRECTIVE SYSTEM ACTIVE**

This record is not a renderer postmortem. It explains how a long, technically serious campaign produced a mechanically sophisticated but visibly unacceptable Owner candidate, and why the failure was not caught before consuming Owner attention.

## Executive finding

The first P1 Owner candidate failed because the project had an **asymmetric quality system**.

Hidden correctness had many strong gates. Owner-visible correctness had almost none.

As work accumulated, the campaign optimized toward the surfaces that were easiest to prove automatically: physics invariants, lifecycle continuity, topology, storage, canonical startup and packaging. The original acceptance target also required a coherent, physically legible Owner-facing sandbox, but that part of the contract gradually lost enforcement.

The final failure was therefore not one bad lighting value. The lighting value was only the defect that exposed the process problem.

## Failure chain

### 1. The original campaign trigger was correct

P1 started because P0/P0.5 Owner interaction showed that prototype-level actor/camera/presentation contamination was preventing trustworthy evaluation.

The P1 rebuild audit explicitly asked whether Godot + FrameMatter could provide a coherent, physically legible sandbox loop whose remaining failures reflected real substrate questions rather than prototype neglect.

That was the right problem statement.

### 2. Hidden-system work became much better defended than visible-system work

P1 created strong automated pressure for:

- volumetric actor collision,
- logical Space/provider replacement,
- storage-frame maintenance,
- topology succession,
- finite solver-owned motion,
- actor/camera relation maintenance,
- integrated causal-loop continuity,
- cross-platform startup,
- strict zero-engine-error execution.

These were real improvements.

No equivalent evidence architecture existed for:

- lighting validity,
- Matter form readability,
- cell granularity,
- state visual semantics,
- camera composition,
- interaction hierarchy,
- default UI hierarchy,
- visible causal readability of split/freeze/motion.

The project therefore became increasingly good at proving what the Owner could not directly see and remained weak at proving what the Owner actually experienced.

### 3. Proxy success was allowed to substitute for the missing surface

Examples:

- SpringArm existence/context relation stood in for camera quality.
- mechanical topology succession stood in for visually understandable topology consequence.
- integrated physics continuity stood in for a coherent visible causal loop.
- canonical startup/export success stood in for Owner-candidate readiness.

Each proxy was valid for its narrow claim. The process failure was allowing several narrow claims to aggregate into a stronger Owner-facing claim they did not support.

### 4. Definition-of-done drift occurred during execution

The original P1 acceptance target included physical legibility.

The later promotion evidence explicitly listed production UI/visuals as a nonclaim and nevertheless permitted Owner packaging.

This was an unearned relaxation of the campaign contract. It happened without new evidence showing visual quality was irrelevant and without Owner intent changing.

Testing difficulty and implementation focus silently changed the practical definition of done.

### 5. Promotion language became stronger than the evidence

Terms such as "Owner candidate", "canonical", "promotion" and "ready to test" created a semantic pressure toward closure.

Once the mechanical campaign became very green, the process framed the remaining work as something the Owner should now reveal rather than asking whether the build had internally earned an Owner test.

The amount of completed work became psychologically correlated with readiness.

This is a form of sunk-cost/promotion bias even though individual technical claims remained careful.

### 6. The Owner became the first serious reviewer of the actual output

This was the most expensive operational error.

The first direct Owner run immediately revealed failures that did not require Owner judgment:

- black Matter surfaces,
- flat white planes,
- weak cell readability,
- debug target language,
- destructive camera framing,
- telemetry-dominated UI.

These are defects the project could and should have found autonomously by rendering and looking at the same pixels.

Owner attention was spent on elementary QA instead of high-information judgment about feel, ambition and direction.

### 7. The renderer defect proved the magnitude of the blind spot

P1 configured the Environment ambient source as SKY while providing no Sky resource.

A Windows D3D12 rendered parity harness later reproduced the Owner's black-surface failure.

Changing only the ambient source to COLOR and zeroing sky contribution changed the deterministic initial scene approximately from:

- near-black coverage `52.96% -> 0.00%`,
- luminance below `0.08`: `54.70% -> 1.74%`,
- mean luminance `0.142 -> 0.366`.

The fact that a one-configuration-line class of defect could survive the entire former promotion pipeline proves that the evidence architecture was incomplete.

## Root causes

### RC1 — evidence-plane imbalance

Mechanical correctness had dense automated evidence. Owner-visible correctness had narrative confidence.

### RC2 — no explicit separation of truth planes

Substrate, composition, observable, interaction and promotion truth were not tracked independently.

### RC3 — no anti-drift mechanism

An original acceptance property could be moved into a nonclaim without a versioned contract change.

### RC4 — no parity rendering lane

The project had no machine that rendered the actual Owner-facing scene through a desktop-class path and returned images for review.

### RC5 — no representative visual scenario set

There was no stable rendered sequence for comparing static, dynamic, editing, rebase, split, freeze and camera stress states.

### RC6 — no adversarial Owner-surface rehearsal

The project did not internally perform and review the kind of ugly, chaotic interaction sequence expected from the Owner.

### RC7 — delivery was an engineering pipeline, not a quality transaction

The old pipeline proved that source could compile, run tests and export. It did not prove that the artifact deserved Owner attention.

### RC8 — progress accumulation biased promotion

Large technical investment created pressure to call the stage complete rather than re-read the original campaign trigger and ask what was still unproven.

## Corrective system

The corrective architecture is defined in `docs/QUALITY-SYSTEM.md` and has two machine-readable parts:

- `quality/p1-campaign-contract.json` — versioned statement of the Owner goal, protected invariants, representative scenarios, required gates and promotion policy.
- `quality/p1-owner-readiness.json` — current evidence state against that contract.

`ci/verify_owner_readiness.py` enforces consistency between them.

Owner delivery now hard-fails unless:

- campaign status is `READY_FOR_OWNER`,
- every contract-required gate is `PASS`,
- every gate has repository evidence,
- every gate was re-verified on the exact delivery commit,
- no blockers remain,
- Owner attention is explicitly authorized,
- `approved_commit` exactly equals the commit being packaged.

Manual workflow dispatch alone is no longer sufficient.

## Process corrections that are machine-enforced

- required readiness gates come from a versioned campaign contract,
- readiness cannot silently omit or invent gates,
- evidence types must match the contract,
- PASS gates require durable repository evidence,
- delivery requires exact-commit re-verification for every gate,
- delivery requires explicit authorization and zero blockers,
- evidence file references are validated by CI.

## Process corrections that still require disciplined judgment

Not every quality property can or should be reduced to a script.

Human/agent judgment is still required to:

- judge semantic readability of rendered output,
- decide whether evidence type is actually persuasive rather than formally present,
- red-team composition failures,
- identify when the campaign contract itself is wrong,
- distinguish acceptable research roughness from misleading/broken presentation,
- protect the Owner from low-information tests.

The Quality System therefore intentionally combines machine enforcement with durable review records rather than pretending all quality is numerically automatable.

## New promotion principle

The project will no longer ask:

> "Did we build a lot and make CI green?"

It will ask:

> "For every property we originally said mattered, what current evidence directly proves it on the exact candidate the Owner is about to see?"

If that question cannot be answered, promotion is blocked.

## Q0 stop condition

The P1 visual recovery campaign must not advance materially beyond already-running bounded G2 experiments until the new quality infrastructure itself is green and the live project documents reflect the corrected promotion model.

Q0 requires:

1. versioned Campaign Contract present,
2. machine-readable Readiness Manifest present,
3. consistency validator green in CI,
4. delivery hard-blocked by readiness + exact commit,
5. live truth documents updated to the six-plane quality model,
6. a recorded retrospective explaining the previous failure,
7. no automatic Owner artifact production while status is BLOCKED.

Only after Q0 PASS may visual recovery continue as ordinary G2/G3/G4 work.
