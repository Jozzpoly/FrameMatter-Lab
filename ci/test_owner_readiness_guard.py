#!/usr/bin/env python3
"""Adversarial self-test for the Owner-readiness guard.

The test attacks contract/readiness drift, predecessor tampering, in-place
contract edits, missing independent assurance and stale runtime evidence. It
also proves that later governance can authorize one frozen runtime candidate
without confusing the governance commit with the delivered artifact.
"""

from __future__ import annotations

import copy
import json
import pathlib
import subprocess
import sys
import tempfile

import verify_owner_readiness as guard

ROOT = pathlib.Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / "quality/p1-owner-readiness.json"
CONTRACT_PATH = ROOT / "quality/contracts/p1-owner-facing-recovery.v3.json"

failures: list[str] = []


def check(condition: bool, description: str) -> None:
    if not condition:
        failures.append(description)


def load(path: pathlib.Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def structural_errors(manifest: dict, contract: dict) -> list[str]:
    errors = guard.validate_contract(contract, ROOT, CONTRACT_PATH)
    manifest_errors, _ = guard.validate_manifest(manifest, contract, ROOT)
    errors.extend(manifest_errors)
    return errors


def make_two_blob_repo() -> tuple[set[str], list[str]]:
    with tempfile.TemporaryDirectory() as tmp:
        root = pathlib.Path(tmp)
        subprocess.run(["git", "init", "-q"], cwd=root, check=True)
        subprocess.run(["git", "config", "user.email", "quality@example.invalid"], cwd=root, check=True)
        subprocess.run(["git", "config", "user.name", "Quality Selftest"], cwd=root, check=True)
        path = root / "quality/contracts/test.v3.json"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text('{"contract_version":3,"state":"first"}\n', encoding="utf-8")
        subprocess.run(["git", "add", path.relative_to(root).as_posix()], cwd=root, check=True)
        subprocess.run(["git", "commit", "-q", "-m", "create sealed contract"], cwd=root, check=True)
        path.write_text('{"contract_version":3,"state":"mutated"}\n', encoding="utf-8")
        subprocess.run(["git", "add", path.relative_to(root).as_posix()], cwd=root, check=True)
        subprocess.run(["git", "commit", "-q", "-m", "mutate sealed contract"], cwd=root, check=True)
        return guard.active_contract_blob_history(root, path)


def main() -> None:
    manifest = load(MANIFEST_PATH)
    contract = load(CONTRACT_PATH)

    errors = structural_errors(manifest, contract)
    check(not errors, "current sealed v3 contract/readiness pair is structurally valid: %s" % errors)

    blobs, history_errors = guard.active_contract_blob_history(ROOT, CONTRACT_PATH)
    check(not history_errors, "active v3 contract history can be inspected: %s" % history_errors)
    check(len(blobs) == 1, "active v3 contract has exactly one distinct historical blob: %s" % sorted(blobs))

    synthetic_blobs, synthetic_errors = make_two_blob_repo()
    check(not synthetic_errors, "synthetic contract history can be inspected: %s" % synthetic_errors)
    check(len(synthetic_blobs) == 2, "in-place versioned contract edit produces two distinct blobs")

    missing_gate = copy.deepcopy(manifest)
    missing_gate["required_gates"].pop("camera_composition")
    errors = structural_errors(missing_gate, contract)
    check(any("missing contract gates" in error and "camera_composition" in error for error in errors),
          "missing contracted gate is rejected")

    wrong_type = copy.deepcopy(manifest)
    wrong_type["required_gates"]["camera_composition"]["evidence_type"] = "mechanical_runtime"
    errors = structural_errors(wrong_type, contract)
    check(any("camera_composition" in error and "evidence_type" in error for error in errors),
          "evidence-type drift is rejected")

    wrong_goal = copy.deepcopy(manifest)
    wrong_goal["owner_goal"] = "Ship something mechanically green."
    errors = structural_errors(wrong_goal, contract)
    check(any("owner_goal" in error for error in errors), "Owner-goal drift is rejected")

    expanded_contract = copy.deepcopy(contract)
    expanded_contract["required_gates"].append({"id": "new_required_plane", "evidence_type": "new_evidence_type"})
    errors = structural_errors(manifest, expanded_contract)
    check(any("new_required_plane" in error for error in errors),
          "new contract requirement cannot be silently ignored by readiness")

    bad_chain = copy.deepcopy(contract)
    bad_chain["previous_contract_git_blob_sha1"] = "0" * 40
    errors = structural_errors(manifest, bad_chain)
    check(any("previous contract integrity mismatch" in error for error in errors),
          "tampered predecessor binding is rejected")

    contract_gates, contract_gate_errors = guard.parse_contract_gates(contract)
    check(not contract_gate_errors, "campaign contract gate parsing succeeds: %s" % contract_gate_errors)
    check(bool(contract_gates), "campaign contract exposes a non-empty promotion gate set")
    check("independent_assurance_review" in contract_gates,
          "sealed contract explicitly requires independent assurance")

    errors = guard.enforce_delivery(manifest, contract_gates)
    check(bool(errors), "real BLOCKED state is rejected by delivery enforcement")
    check(any("not READY_FOR_OWNER" in error for error in errors),
          "BLOCKED state fails for explicit readiness reason")

    candidate_runtime = "0123456789abcdef0123456789abcdef01234567"
    stale_runtime = "89abcdef0123456789abcdef0123456789abcdef"

    ready = copy.deepcopy(manifest)
    ready["status"] = "READY_FOR_OWNER"
    ready["promotion_authorized"] = True
    ready["approved_runtime_commit"] = candidate_runtime
    ready["owner_attention_event"] = {"allowed": True, "reason": "synthetic guard test"}
    ready["open_blockers"] = []
    for gate in ready["required_gates"].values():
        gate["status"] = "PASS"
        gate["verified_runtime_commit"] = candidate_runtime
        if not gate["evidence"]:
            gate["evidence"] = ["docs/QUALITY-SYSTEM.md"]

    stale = copy.deepcopy(ready)
    stale["required_gates"]["camera_composition"]["verified_runtime_commit"] = stale_runtime
    errors = structural_errors(stale, contract)
    check(not errors, "stale candidate remains structurally valid before promotion check: %s" % errors)
    errors = guard.enforce_delivery(stale, contract_gates)
    check(any("camera_composition" in error and "not approved runtime" in error for error in errors),
          "stale per-gate runtime evidence is rejected")

    no_assurance = copy.deepcopy(ready)
    no_assurance["required_gates"]["independent_assurance_review"]["status"] = "PENDING"
    no_assurance["required_gates"]["independent_assurance_review"]["evidence"] = []
    no_assurance["required_gates"]["independent_assurance_review"]["verified_runtime_commit"] = ""
    errors = guard.enforce_delivery(no_assurance, contract_gates)
    check(any("independent_assurance_review" in error for error in errors),
          "missing independent assurance blocks promotion")

    errors = structural_errors(ready, contract)
    check(not errors, "synthetic runtime-bound candidate is structurally valid: %s" % errors)
    errors = guard.enforce_delivery(ready, contract_gates)
    check(not errors,
          "fully consistent frozen-runtime candidate is accepted by later governance state: %s" % errors)

    if failures:
        for failure in failures:
            print("OWNER_READINESS_GUARD_SELFTEST_FAIL: " + failure, file=sys.stderr)
        raise SystemExit(1)

    print(
        "OWNER_READINESS_GUARD_SELFTEST_PASS: guard rejects in-place sealed-contract mutation, predecessor "
        "tampering, missing gates, evidence-type drift, Owner-goal drift, contract expansion drift, BLOCKED "
        "delivery, stale runtime evidence and missing independent assurance, while accepting a fully "
        "consistent frozen-runtime candidate authorized by later governance evidence."
    )


if __name__ == "__main__":
    main()
