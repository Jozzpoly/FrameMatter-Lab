#!/usr/bin/env python3
"""Adversarial self-test for the Owner-readiness guard.

The goal is to prove that the quality gate detects contract/readiness drift,
stale evidence binding and blocked promotion, while still accepting a fully
consistent synthetic READY state. This is intentionally independent of Godot.
"""

from __future__ import annotations

import copy
import json
import pathlib
import sys

import verify_owner_readiness as guard


ROOT = pathlib.Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / "quality/p1-owner-readiness.json"
CONTRACT_PATH = ROOT / "quality/p1-campaign-contract.json"


failures: list[str] = []


def check(condition: bool, description: str) -> None:
    if not condition:
        failures.append(description)


def load(path: pathlib.Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def structural_errors(manifest: dict, contract: dict) -> list[str]:
    errors = guard.validate_contract(contract, ROOT)
    manifest_errors, _ = guard.validate_manifest(manifest, contract, ROOT)
    errors.extend(manifest_errors)
    return errors


def main() -> None:
    manifest = load(MANIFEST_PATH)
    contract = load(CONTRACT_PATH)

    # Control: the real in-progress state must be structurally valid.
    errors = structural_errors(manifest, contract)
    check(not errors, "current contract/readiness pair is structurally valid: %s" % errors)

    # Drift 1: readiness silently omits a contracted quality plane.
    missing_gate = copy.deepcopy(manifest)
    missing_gate["required_gates"].pop("camera_composition")
    errors = structural_errors(missing_gate, contract)
    check(any("missing contract gates" in error and "camera_composition" in error for error in errors),
          "missing contracted gate is rejected")

    # Drift 2: readiness changes what kind of evidence a contracted gate requires.
    wrong_type = copy.deepcopy(manifest)
    wrong_type["required_gates"]["camera_composition"]["evidence_type"] = "mechanical_runtime"
    errors = structural_errors(wrong_type, contract)
    check(any("camera_composition" in error and "evidence_type" in error for error in errors),
          "evidence-type drift is rejected")

    # Drift 3: practical Owner goal changes without changing the contract.
    wrong_goal = copy.deepcopy(manifest)
    wrong_goal["owner_goal"] = "Ship something mechanically green."
    errors = structural_errors(wrong_goal, contract)
    check(any("owner_goal" in error for error in errors), "Owner-goal drift is rejected")

    # Drift 4: contract adds a new required plane and readiness fails to acknowledge it.
    expanded_contract = copy.deepcopy(contract)
    expanded_contract["required_gates"].append(
        {"id": "new_required_plane", "evidence_type": "new_evidence_type"}
    )
    errors = structural_errors(manifest, expanded_contract)
    check(any("new_required_plane" in error for error in errors),
          "new contract requirement cannot be silently ignored by readiness")

    # Parse the real contract once for promotion controls. A parse failure here is
    # itself a self-test failure; never silently turn it into an empty gate set.
    contract_gates, contract_gate_errors = guard.parse_contract_gates(contract)
    check(not contract_gate_errors, "campaign contract gate parsing succeeds: %s" % contract_gate_errors)
    check(bool(contract_gates), "campaign contract exposes a non-empty promotion gate set")

    # Control: the real BLOCKED state must not be deliverable.
    errors = guard.enforce_delivery(manifest, contract_gates, "deadbeef")
    check(bool(errors), "real BLOCKED state is rejected by delivery enforcement")
    check(any("not READY_FOR_OWNER" in error for error in errors),
          "BLOCKED state fails for explicit readiness reason")

    # Stale binding: even a synthetically complete candidate must fail if gate evidence
    # was verified on an older commit.
    candidate_commit = "0123456789abcdef0123456789abcdef01234567"
    stale_commit = "89abcdef0123456789abcdef0123456789abcdef"
    stale = copy.deepcopy(manifest)
    stale["status"] = "READY_FOR_OWNER"
    stale["promotion_authorized"] = True
    stale["approved_commit"] = candidate_commit
    stale["owner_attention_event"] = {"allowed": True, "reason": "synthetic guard test"}
    stale["open_blockers"] = []
    for gate in stale["required_gates"].values():
        gate["status"] = "PASS"
        gate["verified_commit"] = stale_commit
        if not gate["evidence"]:
            gate["evidence"] = ["docs/QUALITY-SYSTEM.md"]
    errors = structural_errors(stale, contract)
    check(not errors, "synthetic stale candidate remains structurally valid before promotion check: %s" % errors)
    errors = guard.enforce_delivery(stale, contract_gates, candidate_commit)
    check(any("verified on" in error and "not exact delivery commit" in error for error in errors),
          "stale per-gate evidence binding is rejected")

    # Positive control: the guard must be capable of accepting a fully consistent
    # exact-commit candidate, otherwise a permanently red gate would be useless.
    ready = copy.deepcopy(stale)
    for gate in ready["required_gates"].values():
        gate["verified_commit"] = candidate_commit
    errors = structural_errors(ready, contract)
    check(not errors, "synthetic exact-commit candidate is structurally valid: %s" % errors)
    errors = guard.enforce_delivery(ready, contract_gates, candidate_commit)
    check(not errors, "fully consistent synthetic READY candidate is accepted: %s" % errors)

    if failures:
        for failure in failures:
            print("OWNER_READINESS_GUARD_SELFTEST_FAIL: " + failure, file=sys.stderr)
        raise SystemExit(1)

    print(
        "OWNER_READINESS_GUARD_SELFTEST_PASS: guard rejects missing gates, evidence-type drift, "
        "Owner-goal drift, unacknowledged contract expansion, BLOCKED delivery and stale commit evidence, "
        "while accepting a fully consistent exact-commit READY state."
    )


if __name__ == "__main__":
    main()
