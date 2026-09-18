# Convergence C0–C1 qualification record — 2026-09-18

Status: **C0 EXACT-ARTIFACT PASS / C1 TECHNICAL PASS / C1 OWNER JUDGEMENT OPEN**

This record exists to preserve why the Convergence campaign trusts the current baseline and where machine evidence deliberately stops.

## C0 — exact-artifact Spark qualification

Frozen source:

`028c12764692b8d79ba9b2c634ed9fbd6a2d7f70`

Successful C0 workflow:

`35347808664`

Protected causal flow:

> ordinary WORLD Matter cut → authority transfer → derived dynamic autonomy → actor/support handoff → gravity/ride → live edit of moving Matter.

### Material C0 finding

The first exact exported executable failed while the corresponding source-level probe passed.

Root cause:

authoritative W0 staging mutations such as target `set_cell`, target lineage transfer and source clearing were executed inside `assert(...)` expressions. Release exports do not evaluate assertions, so the side effects disappeared.

The fix moved authoritative mutations out of assertions and added runtime fail-closed handling.

This is why source/debug PASS is not sufficient authority for protected Convergence behavior.

## C1 — relative scale probe

Branch:

`research/convergence-c1-scale-probe`

Technically qualified source:

`f52dce049a6be5aebc4c864e5005dfaa13b7390f`

Workflow run:

`35350213339`

Artifact:

`FrameMatter-Convergence-C1-Windows`

Artifact ID:

`10549852238`

GitHub artifact digest:

`sha256:0422126c8e978edca5137674c05b9e703cb36580c2628a732c9087c17bcba68a`

Exported EXE SHA-256 recorded by workflow:

`4ec7067465ab039ddda8e96ad1d2827875a2da95373f0da470ce44ae8000c080`

### C1 first failure

Initial scale switching reached the intended scale values but exposed stale typed references to freed `LocalMatterSpace` instances during world reset.

Classification:

`PRODUCT DEFECT / lifecycle reset boundary`

It was not evidence against the scale hypothesis.

### C1 lifecycle correction

World replacement now explicitly clears/rebinds consumer state across the reset boundary:

- actor support is detached before old-world retirement;
- focus and camera context are cleared;
- state presentation focus is cleared;
- registry publication no longer exposes consumers to retained old-world references;
- recovery observer reacquires canonical WORLD identity.

### Final C1 technical evidence

The final qualification drove:

`1x → 2x → 4x → 8x → 1x`

and checked coherent actor dimensions, movement-related physical scale, edit reach, camera scale, reset and reacquisition of ordinary WORLD support at every stage.

The same run also produced:

`W0D_RECOVERY_CAUSAL_LOOP_PASS`

with representative source metric:

- witness lineage token `1202204`;
- actor handoff error `0.0000000000`;
- target fall and actor fall equal in the source rehearsal.

The exact exported C1 executable then produced:

`C0_EXPORTED_SPARK_BASELINE_PASS`

with:

- target fall `0.369606`;
- actor fall `0.369606`;
- actor handoff error `0.00000000`;
- two active Spaces after causal detachment.

## Claim boundary

C1 currently proves only that one runtime can safely expose the four relative-scale proxies while preserving the protected Spark.

It does **not** prove:

- that 25 cm, 12.5 cm or any other value is the correct final Matter resolution;
- that the proxy is equivalent to a true finer-resolution representation;
- that any mode feels better to the Owner;
- that representation work should outrank WORLD LANGUAGE after the test.

The remaining C1 evidence is genuinely human/experiential.
