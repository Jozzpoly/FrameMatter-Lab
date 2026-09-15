#!/usr/bin/env python3
"""Validate or enforce an Owner-candidate readiness manifest.

The campaign contract defines what must be true. The readiness manifest records
current evidence against that contract. Ordinary CI validates consistency while
allowing a deliberately BLOCKED campaign. Delivery requires every contract gate
to PASS and to have been re-verified on the exact commit being packaged.
"""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import sys
from typing import Any


VALID_STATUSES = {"PASS", "FAIL", "PENDING", "SUPERSEDED"}


def fail(errors: list[str]) -> None:
    for error in errors:
        print(f"OWNER_READINESS_ERROR: {error}", file=sys.stderr)
    sys.exit(1)


def load_json(path: pathlib.Path, label: str) -> tuple[dict[str, Any] | None, list[str]]:
    errors: list[str] = []
    if not path.is_file():
        return None, [f"{label} missing: {path}"]
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return None, [f"cannot parse {label}: {exc}"]
    if not isinstance(value, dict):
        errors.append(f"{label} root must be an object")
        return None, errors
    return value, errors


def is_nonempty_string(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def validate_repo_relative_file(repo_root: pathlib.Path, path_value: Any, label: str) -> list[str]:
    errors: list[str] = []
    if not is_nonempty_string(path_value):
        return [f"{label} must be a non-empty repository-relative path"]
    value = str(path_value)
    if value.startswith(("http://", "https://", "/")):
        return [f"{label} must be repository-relative: {value}"]
    if not (repo_root / value).is_file():
        errors.append(f"{label} references missing file: {value}")
    return errors


def parse_contract_gates(contract: dict[str, Any]) -> tuple[dict[str, str], list[str]]:
    errors: list[str] = []
    gate_rows = contract.get("required_gates")
    if not isinstance(gate_rows, list) or not gate_rows:
        return {}, ["campaign contract required_gates must be a non-empty list"]

    gates: dict[str, str] = {}
    for index, row in enumerate(gate_rows):
        if not isinstance(row, dict):
            errors.append(f"campaign contract gate #{index} must be an object")
            continue
        gate_id = row.get("id")
        evidence_type = row.get("evidence_type")
        if not is_nonempty_string(gate_id):
            errors.append(f"campaign contract gate #{index} id must be non-empty")
            continue
        gate_id = str(gate_id)
        if gate_id in gates:
            errors.append(f"campaign contract gate id duplicated: {gate_id}")
            continue
        if not is_nonempty_string(evidence_type):
            errors.append(f"campaign contract gate {gate_id} evidence_type must be non-empty")
            continue
        gates[gate_id] = str(evidence_type)
    return gates, errors


def validate_contract(contract: dict[str, Any], repo_root: pathlib.Path) -> list[str]:
    errors: list[str] = []
    if contract.get("schema_version") != 1:
        errors.append("campaign contract schema_version must be 1")
    if not isinstance(contract.get("contract_version"), int) or contract.get("contract_version", 0) < 1:
        errors.append("campaign contract contract_version must be an integer >= 1")

    for key in ("campaign_id", "owner_goal", "owner_visible_surface"):
        if not is_nonempty_string(contract.get(key)):
            errors.append(f"campaign contract {key} must be a non-empty string")

    for key in ("protected_invariants", "representative_scenarios"):
        value = contract.get(key)
        if not isinstance(value, list) or not value or not all(is_nonempty_string(item) for item in value):
            errors.append(f"campaign contract {key} must be a non-empty list of strings")

    non_goals = contract.get("explicit_non_goals")
    if not isinstance(non_goals, list) or not all(is_nonempty_string(item) for item in non_goals):
        errors.append("campaign contract explicit_non_goals must be a list of non-empty strings")

    negative_baseline = contract.get("negative_baseline")
    if not isinstance(negative_baseline, list) or not negative_baseline:
        errors.append("campaign contract negative_baseline must be a non-empty list")
    else:
        for index, path_value in enumerate(negative_baseline):
            errors.extend(validate_repo_relative_file(repo_root, path_value, f"negative_baseline[{index}]"))

    _, gate_errors = parse_contract_gates(contract)
    errors.extend(gate_errors)

    change_policy = contract.get("change_policy")
    required_change_flags = (
        "acceptance_relaxation_requires_explicit_decision_record",
        "test_difficulty_is_not_valid_relaxation_reason",
        "owner_goal_change_requires_owner_feedback",
        "contract_changes_must_be_versioned",
    )
    if not isinstance(change_policy, dict):
        errors.append("campaign contract change_policy must be an object")
    else:
        for flag in required_change_flags:
            if change_policy.get(flag) is not True:
                errors.append(f"campaign contract change_policy.{flag} must be true")

    promotion_policy = contract.get("promotion_policy")
    required_promotion_flags = (
        "all_required_gates_must_pass",
        "all_required_gates_must_be_verified_on_exact_candidate_commit",
        "open_blockers_must_be_empty",
        "owner_attention_event_must_be_authorized",
        "artifact_delivery_requires_exact_approved_commit",
    )
    if not isinstance(promotion_policy, dict):
        errors.append("campaign contract promotion_policy must be an object")
    else:
        for flag in required_promotion_flags:
            if promotion_policy.get(flag) is not True:
                errors.append(f"campaign contract promotion_policy.{flag} must be true")

    return errors


def validate_manifest(
    data: dict[str, Any], contract: dict[str, Any], repo_root: pathlib.Path
) -> tuple[list[str], dict[str, str]]:
    errors: list[str] = []

    if data.get("schema_version") != 3:
        errors.append("readiness schema_version must be 3")

    for key in ("campaign_id", "candidate_label", "source_branch", "owner_goal", "owner_visible_surface"):
        if not is_nonempty_string(data.get(key)):
            errors.append(f"readiness {key} must be a non-empty string")

    if data.get("campaign_id") != contract.get("campaign_id"):
        errors.append("readiness campaign_id does not match campaign contract")
    if data.get("campaign_contract_version") != contract.get("contract_version"):
        errors.append("readiness campaign_contract_version does not match campaign contract")
    if data.get("owner_goal") != contract.get("owner_goal"):
        errors.append("readiness owner_goal does not exactly match campaign contract")
    if data.get("owner_visible_surface") != contract.get("owner_visible_surface"):
        errors.append("readiness owner_visible_surface does not exactly match campaign contract")

    if data.get("status") not in {"BLOCKED", "READY_FOR_OWNER"}:
        errors.append("readiness status must be BLOCKED or READY_FOR_OWNER")
    if not isinstance(data.get("promotion_authorized"), bool):
        errors.append("promotion_authorized must be boolean")
    if not isinstance(data.get("approved_commit"), str):
        errors.append("approved_commit must be a string")

    attention = data.get("owner_attention_event")
    if not isinstance(attention, dict):
        errors.append("owner_attention_event must be an object")
    else:
        if not isinstance(attention.get("allowed"), bool):
            errors.append("owner_attention_event.allowed must be boolean")
        if not is_nonempty_string(attention.get("reason")):
            errors.append("owner_attention_event.reason must be non-empty")

    blockers = data.get("open_blockers")
    if not isinstance(blockers, list) or not all(is_nonempty_string(item) for item in blockers):
        errors.append("open_blockers must be a list of non-empty strings")

    contract_gates, contract_gate_errors = parse_contract_gates(contract)
    errors.extend(contract_gate_errors)

    readiness_gates = data.get("required_gates")
    if not isinstance(readiness_gates, dict):
        errors.append("required_gates must be an object")
        return errors, contract_gates

    missing = sorted(set(contract_gates) - set(readiness_gates))
    unknown = sorted(set(readiness_gates) - set(contract_gates))
    if missing:
        errors.append("readiness missing contract gates: " + ", ".join(missing))
    if unknown:
        errors.append("readiness contains gates not in contract: " + ", ".join(unknown))

    for gate_name, contract_evidence_type in contract_gates.items():
        gate = readiness_gates.get(gate_name)
        if not isinstance(gate, dict):
            continue

        status = gate.get("status")
        if status not in VALID_STATUSES:
            errors.append(f"gate {gate_name} has invalid status {status!r}")

        evidence_type = gate.get("evidence_type")
        if evidence_type != contract_evidence_type:
            errors.append(
                f"gate {gate_name} evidence_type {evidence_type!r} does not match contract {contract_evidence_type!r}"
            )

        verified_commit = gate.get("verified_commit")
        if not isinstance(verified_commit, str):
            errors.append(f"gate {gate_name} verified_commit must be a string")

        evidence = gate.get("evidence")
        if not isinstance(evidence, list) or not all(is_nonempty_string(item) for item in evidence):
            errors.append(f"gate {gate_name} evidence must be a list of non-empty paths")
            continue
        if status == "PASS" and not evidence:
            errors.append(f"gate {gate_name} is PASS but has no evidence")
        for index, evidence_path in enumerate(evidence):
            errors.extend(validate_repo_relative_file(repo_root, evidence_path, f"gate {gate_name} evidence[{index}]"))

    return errors, contract_gates


def enforce_delivery(data: dict[str, Any], contract_gates: dict[str, str], commit: str) -> list[str]:
    errors: list[str] = []
    commit = commit.strip().lower()

    if data.get("status") != "READY_FOR_OWNER":
        errors.append("campaign status is not READY_FOR_OWNER")
    if data.get("promotion_authorized") is not True:
        errors.append("promotion_authorized is not true")

    attention = data.get("owner_attention_event", {})
    if attention.get("allowed") is not True:
        errors.append("Owner attention event is not authorized")

    blockers = data.get("open_blockers", [])
    if blockers:
        errors.append(f"{len(blockers)} open blocker(s) remain")

    approved_commit = str(data.get("approved_commit", "")).strip().lower()
    if not approved_commit:
        errors.append("approved_commit is empty")
    elif not commit:
        errors.append("current commit could not be resolved")
    elif approved_commit != commit:
        errors.append(f"approved_commit {approved_commit} does not match exact delivery commit {commit}")

    readiness_gates = data.get("required_gates", {})
    for gate_name in contract_gates:
        gate = readiness_gates.get(gate_name, {})
        if gate.get("status") != "PASS":
            errors.append(f"required gate {gate_name} is {gate.get('status', 'MISSING')}, not PASS")
        if not gate.get("evidence"):
            errors.append(f"required gate {gate_name} has no evidence")

        verified_commit = str(gate.get("verified_commit", "")).strip().lower()
        if not verified_commit:
            errors.append(f"required gate {gate_name} has no verified_commit")
        elif not commit:
            errors.append(f"required gate {gate_name} cannot be matched because current commit is empty")
        elif verified_commit != commit:
            errors.append(
                f"required gate {gate_name} was verified on {verified_commit}, not exact delivery commit {commit}"
            )

    return errors


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", default="quality/p1-owner-readiness.json")
    parser.add_argument("--mode", choices=("validate", "delivery"), default="validate")
    parser.add_argument("--commit", default=os.environ.get("GITHUB_SHA", ""))
    args = parser.parse_args()

    repo_root = pathlib.Path.cwd().resolve()
    manifest_path = (repo_root / args.manifest).resolve()
    data, errors = load_json(manifest_path, "readiness manifest")
    if errors or data is None:
        fail(errors)

    contract_path_value = data.get("campaign_contract")
    contract_path_errors = validate_repo_relative_file(repo_root, contract_path_value, "campaign_contract")
    if contract_path_errors:
        fail(contract_path_errors)
    contract_path = (repo_root / str(contract_path_value)).resolve()
    contract, contract_load_errors = load_json(contract_path, "campaign contract")
    if contract_load_errors or contract is None:
        fail(contract_load_errors)

    errors = validate_contract(contract, repo_root)
    manifest_errors, contract_gates = validate_manifest(data, contract, repo_root)
    errors.extend(manifest_errors)

    if args.mode == "delivery" and not errors:
        errors.extend(enforce_delivery(data, contract_gates, args.commit))

    if errors:
        fail(errors)

    if args.mode == "delivery":
        print(
            "OWNER_READINESS_DELIVERY_PASS: campaign contract is satisfied; every required gate is PASS, "
            "evidence exists, no blockers remain, Owner attention is authorized, and every gate was "
            "verified on the exact delivery commit."
        )
    else:
        pending = [
            name
            for name in contract_gates
            if data["required_gates"].get(name, {}).get("status") != "PASS"
        ]
        unbound = [
            name
            for name in contract_gates
            if not str(data["required_gates"].get(name, {}).get("verified_commit", "")).strip()
        ]
        print(
            "OWNER_READINESS_MANIFEST_VALID: contract_version=%s status=%s promotion_authorized=%s "
            "pending_or_failed=%d unbound_gates=%d"
            % (
                contract["contract_version"],
                data["status"],
                data["promotion_authorized"],
                len(pending),
                len(unbound),
            )
        )


if __name__ == "__main__":
    main()
