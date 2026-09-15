#!/usr/bin/env python3
"""Validate or enforce an Owner-candidate readiness manifest.

The campaign contract defines what must be true. The readiness manifest records
current evidence against that contract. Governance/evidence commits may be newer
than the frozen runtime candidate being reviewed. Delivery is authorized only
when every required quality plane and representative scenario is bound to one
exact approved runtime commit.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import re
import subprocess
import sys
from typing import Any

VALID_STATUSES = {"PASS", "FAIL", "PENDING", "SUPERSEDED"}
FULL_SHA_RE = re.compile(r"^[0-9a-fA-F]{40}$")


def fail(errors: list[str]) -> None:
    for error in errors:
        print(f"OWNER_READINESS_ERROR: {error}", file=sys.stderr)
    raise SystemExit(1)


def load_json(path: pathlib.Path, label: str) -> tuple[dict[str, Any] | None, list[str]]:
    if not path.is_file():
        return None, [f"{label} missing: {path}"]
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return None, [f"cannot parse {label}: {exc}"]
    if not isinstance(value, dict):
        return None, [f"{label} root must be an object"]
    return value, []


def is_nonempty_string(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def is_full_sha(value: Any) -> bool:
    return isinstance(value, str) and bool(FULL_SHA_RE.fullmatch(value.strip()))


def validate_repo_relative_file(repo_root: pathlib.Path, path_value: Any, label: str) -> list[str]:
    if not is_nonempty_string(path_value):
        return [f"{label} must be a non-empty repository-relative path"]
    value = str(path_value)
    if value.startswith(("http://", "https://", "/")):
        return [f"{label} must be repository-relative: {value}"]
    if not (repo_root / value).is_file():
        return [f"{label} references missing file: {value}"]
    return []


def git_blob_sha1(path: pathlib.Path) -> str:
    payload = path.read_bytes()
    header = f"blob {len(payload)}\0".encode("ascii")
    return hashlib.sha1(header + payload).hexdigest()


def active_contract_blob_history(repo_root: pathlib.Path, contract_path: pathlib.Path) -> tuple[set[str], list[str]]:
    if not (repo_root / ".git").exists():
        return set(), []
    try:
        rel = contract_path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError:
        return set(), ["active campaign contract is outside repository root"]
    try:
        history = subprocess.run(
            ["git", "log", "--all", "--format=%H", "--", rel],
            cwd=repo_root,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.splitlines()
    except (OSError, subprocess.CalledProcessError) as exc:
        return set(), [f"cannot inspect active contract Git history: {exc}"]

    blobs: set[str] = set()
    for commit in history:
        if not commit.strip():
            continue
        try:
            row = subprocess.run(
                ["git", "ls-tree", commit.strip(), "--", rel],
                cwd=repo_root,
                check=True,
                capture_output=True,
                text=True,
            ).stdout.strip()
        except (OSError, subprocess.CalledProcessError) as exc:
            return set(), [f"cannot inspect active contract blob at {commit}: {exc}"]
        if not row:
            continue
        parts = row.split()
        if len(parts) >= 3 and parts[1] == "blob":
            blobs.add(parts[2])
    return blobs, []


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


def string_set(value: Any) -> set[str]:
    if not isinstance(value, list):
        return set()
    return {str(item) for item in value if is_nonempty_string(item)}


def validate_monotonic_contract(current: dict[str, Any], previous: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    if current.get("owner_goal") != previous.get("owner_goal"):
        errors.append("owner_goal changed across contract versions; explicit Owner-authorized change handling is required")
    if current.get("owner_visible_surface") != previous.get("owner_visible_surface"):
        errors.append("owner_visible_surface changed across contract versions; explicit Owner-authorized change handling is required")

    current_gates, current_gate_errors = parse_contract_gates(current)
    previous_gates, previous_gate_errors = parse_contract_gates(previous)
    errors.extend(current_gate_errors)
    errors.extend(previous_gate_errors)
    for gate_id, evidence_type in previous_gates.items():
        if gate_id not in current_gates:
            errors.append(f"acceptance regression: required gate removed across contract versions: {gate_id}")
        elif current_gates[gate_id] != evidence_type:
            errors.append(f"acceptance regression: evidence type changed for inherited gate {gate_id}")

    for field in ("protected_invariants", "representative_scenarios", "negative_baseline"):
        removed = sorted(string_set(previous.get(field)) - string_set(current.get(field)))
        if removed:
            errors.append(f"acceptance regression: {field} removed inherited entries: {', '.join(removed)}")

    added_non_goals = sorted(string_set(current.get("explicit_non_goals")) - string_set(previous.get("explicit_non_goals")))
    if added_non_goals:
        errors.append(
            "scope relaxation: new explicit non-goals require separate Owner-authorized contract handling: "
            + ", ".join(added_non_goals)
        )
    return errors


def validate_contract(
    contract: dict[str, Any], repo_root: pathlib.Path, contract_path: pathlib.Path | None = None
) -> list[str]:
    errors: list[str] = []
    if contract.get("schema_version") != 2:
        errors.append("active campaign contract schema_version must be 2")
    if not isinstance(contract.get("contract_version"), int) or contract.get("contract_version", 0) < 2:
        errors.append("active campaign contract contract_version must be an integer >= 2")

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

    previous_path_value = contract.get("previous_contract")
    previous_hash = contract.get("previous_contract_git_blob_sha1")
    change_record = contract.get("change_record")
    errors.extend(validate_repo_relative_file(repo_root, previous_path_value, "previous_contract"))
    errors.extend(validate_repo_relative_file(repo_root, change_record, "change_record"))
    if not is_full_sha(previous_hash):
        errors.append("previous_contract_git_blob_sha1 must be a full 40-character Git blob SHA-1")
    elif is_nonempty_string(previous_path_value) and not str(previous_path_value).startswith(("http://", "https://", "/")):
        previous_path = repo_root / str(previous_path_value)
        if previous_path.is_file():
            actual_hash = git_blob_sha1(previous_path)
            if actual_hash.lower() != str(previous_hash).lower():
                errors.append(f"previous contract integrity mismatch: expected {previous_hash}, actual {actual_hash}")
            previous_contract, previous_errors = load_json(previous_path, "previous campaign contract")
            errors.extend(previous_errors)
            if previous_contract is not None:
                expected_previous_version = int(contract.get("contract_version", 0)) - 1
                if previous_contract.get("contract_version") != expected_previous_version:
                    errors.append("previous campaign contract version does not immediately precede active contract")
                if previous_contract.get("campaign_id") != contract.get("campaign_id"):
                    errors.append("previous campaign contract belongs to a different campaign")
                errors.extend(validate_monotonic_contract(contract, previous_contract))

    if contract_path is not None:
        version = contract.get("contract_version")
        expected_suffix = f".v{version}.json"
        if not contract_path.name.endswith(expected_suffix):
            errors.append(f"active contract filename must end with {expected_suffix}, got {contract_path.name}")
        blobs, history_errors = active_contract_blob_history(repo_root, contract_path)
        errors.extend(history_errors)
        if len(blobs) > 1:
            errors.append("active versioned campaign contract was modified in place; create a new contract version instead")
        elif (repo_root / ".git").exists() and not blobs:
            errors.append("active campaign contract is not represented in available Git history")

    change_policy = contract.get("change_policy")
    required_change_flags = (
        "acceptance_relaxation_requires_explicit_decision_record",
        "test_difficulty_is_not_valid_relaxation_reason",
        "owner_goal_change_requires_owner_feedback",
        "contract_changes_must_be_versioned",
        "versioned_contract_snapshots_are_append_only",
        "active_contract_snapshot_must_be_immutable",
    )
    if not isinstance(change_policy, dict):
        errors.append("campaign contract change_policy must be an object")
    else:
        for flag in required_change_flags:
            if change_policy.get(flag) is not True:
                errors.append(f"campaign contract change_policy.{flag} must be true")

    assurance_policy = contract.get("assurance_policy")
    required_assurance_flags = (
        "independent_read_only_review_required",
        "reviewer_must_not_author_candidate_changes_during_review",
        "review_must_attempt_falsification",
        "review_must_evaluate_owner_goal_and_claim_evidence_fit",
        "review_must_cover_nominal_and_off_nominal_scenarios",
        "review_must_reference_frozen_runtime_commit",
        "candidate_runtime_change_invalidates_review",
        "material_findings_block_promotion",
    )
    if not isinstance(assurance_policy, dict):
        errors.append("campaign contract assurance_policy must be an object")
    else:
        for flag in required_assurance_flags:
            if assurance_policy.get(flag) is not True:
                errors.append(f"campaign contract assurance_policy.{flag} must be true")

    promotion_policy = contract.get("promotion_policy")
    required_promotion_flags = (
        "all_required_gates_must_pass",
        "all_required_gates_must_be_verified_on_approved_runtime_commit",
        "open_blockers_must_be_empty",
        "owner_attention_event_must_be_authorized",
        "artifact_delivery_requires_approved_runtime_commit",
        "governance_commit_may_differ_from_runtime_commit",
        "delivery_materializes_approved_runtime_not_governance",
        "independent_assurance_required",
    )
    if not isinstance(promotion_policy, dict):
        errors.append("campaign contract promotion_policy must be an object")
    else:
        for flag in required_promotion_flags:
            if promotion_policy.get(flag) is not True:
                errors.append(f"campaign contract promotion_policy.{flag} must be true")
    return errors


def validate_bound_row(row: Any, label: str) -> list[str]:
    errors: list[str] = []
    if not isinstance(row, dict):
        return [f"{label} must be an object"]
    if row.get("status") not in VALID_STATUSES:
        errors.append(f"{label} has invalid status {row.get('status')!r}")
    runtime = row.get("verified_runtime_commit")
    if not isinstance(runtime, str):
        errors.append(f"{label} verified_runtime_commit must be a string")
    elif runtime and not is_full_sha(runtime):
        errors.append(f"{label} verified_runtime_commit must be empty or a full 40-character commit SHA")
    evidence = row.get("evidence")
    if not isinstance(evidence, list) or not all(is_nonempty_string(item) for item in evidence):
        errors.append(f"{label} evidence must be a list of non-empty paths")
    elif row.get("status") == "PASS" and not evidence:
        errors.append(f"{label} is PASS but has no evidence")
    return errors


def validate_manifest(
    data: dict[str, Any], contract: dict[str, Any], repo_root: pathlib.Path
) -> tuple[list[str], dict[str, str]]:
    errors: list[str] = []
    if data.get("schema_version") != 5:
        errors.append("readiness schema_version must be 5")
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
    candidate_state = data.get("candidate_state")
    if candidate_state not in {"OPEN", "FROZEN"}:
        errors.append("candidate_state must be OPEN or FROZEN")
    candidate_runtime = data.get("candidate_runtime_commit")
    if not isinstance(candidate_runtime, str):
        errors.append("candidate_runtime_commit must be a string")
        candidate_runtime = ""
    elif candidate_runtime and not is_full_sha(candidate_runtime):
        errors.append("candidate_runtime_commit must be empty or a full 40-character commit SHA")
    if candidate_state == "OPEN" and candidate_runtime:
        errors.append("OPEN candidate_state must not name a frozen candidate_runtime_commit")
    if candidate_state == "FROZEN" and not is_full_sha(candidate_runtime):
        errors.append("FROZEN candidate_state requires a full candidate_runtime_commit")

    if not isinstance(data.get("promotion_authorized"), bool):
        errors.append("promotion_authorized must be boolean")
    approved_runtime = data.get("approved_runtime_commit")
    if not isinstance(approved_runtime, str):
        errors.append("approved_runtime_commit must be a string")
        approved_runtime = ""
    elif approved_runtime and not is_full_sha(approved_runtime):
        errors.append("approved_runtime_commit must be empty or a full 40-character commit SHA")

    attention = data.get("owner_attention_event")
    if not isinstance(attention, dict):
        errors.append("owner_attention_event must be an object")
        attention = {}
    else:
        if not isinstance(attention.get("allowed"), bool):
            errors.append("owner_attention_event.allowed must be boolean")
        if not is_nonempty_string(attention.get("reason")):
            errors.append("owner_attention_event.reason must be non-empty")

    blockers = data.get("open_blockers")
    if not isinstance(blockers, list) or not all(is_nonempty_string(item) for item in blockers):
        errors.append("open_blockers must be a list of non-empty strings")
        blockers = []

    if data.get("status") != "READY_FOR_OWNER":
        if data.get("promotion_authorized") is True:
            errors.append("promotion_authorized cannot be true while campaign is not READY_FOR_OWNER")
        if attention.get("allowed") is True:
            errors.append("Owner attention cannot be allowed while campaign is not READY_FOR_OWNER")
        if approved_runtime:
            errors.append("approved_runtime_commit must remain empty until campaign is READY_FOR_OWNER")
    else:
        if candidate_state != "FROZEN" or not is_full_sha(candidate_runtime):
            errors.append("READY_FOR_OWNER requires one frozen candidate runtime")
        if not is_full_sha(approved_runtime) or approved_runtime.lower() != str(candidate_runtime).lower():
            errors.append("READY_FOR_OWNER requires approved_runtime_commit == candidate_runtime_commit")
        if data.get("promotion_authorized") is not True:
            errors.append("READY_FOR_OWNER requires promotion_authorized=true")
        if attention.get("allowed") is not True:
            errors.append("READY_FOR_OWNER requires Owner attention authorization")
        if blockers:
            errors.append("READY_FOR_OWNER requires zero open blockers")

    contract_gates, contract_gate_errors = parse_contract_gates(contract)
    errors.extend(contract_gate_errors)
    readiness_gates = data.get("required_gates")
    if not isinstance(readiness_gates, dict):
        errors.append("required_gates must be an object")
        readiness_gates = {}
    missing = sorted(set(contract_gates) - set(readiness_gates))
    unknown = sorted(set(readiness_gates) - set(contract_gates))
    if missing:
        errors.append("readiness missing contract gates: " + ", ".join(missing))
    if unknown:
        errors.append("readiness contains gates not in contract: " + ", ".join(unknown))

    for gate_name, contract_evidence_type in contract_gates.items():
        gate = readiness_gates.get(gate_name)
        errors.extend(validate_bound_row(gate, f"gate {gate_name}"))
        if not isinstance(gate, dict):
            continue
        if gate.get("evidence_type") != contract_evidence_type:
            errors.append(
                f"gate {gate_name} evidence_type {gate.get('evidence_type')!r} does not match contract {contract_evidence_type!r}"
            )
        evidence = gate.get("evidence")
        if isinstance(evidence, list):
            for index, evidence_path in enumerate(evidence):
                errors.extend(validate_repo_relative_file(repo_root, evidence_path, f"gate {gate_name} evidence[{index}]"))
        bound = str(gate.get("verified_runtime_commit", "")).lower()
        if candidate_state == "FROZEN" and gate.get("status") == "PASS" and bound and bound != str(candidate_runtime).lower():
            errors.append(f"gate {gate_name} PASS is bound to runtime {bound}, not frozen candidate {candidate_runtime}")

    scenarios = string_set(contract.get("representative_scenarios"))
    coverage = data.get("scenario_coverage")
    if not isinstance(coverage, dict):
        errors.append("scenario_coverage must be an object")
        coverage = {}
    missing_scenarios = sorted(scenarios - set(coverage))
    unknown_scenarios = sorted(set(coverage) - scenarios)
    if missing_scenarios:
        errors.append("scenario_coverage missing contract scenarios: " + ", ".join(missing_scenarios))
    if unknown_scenarios:
        errors.append("scenario_coverage contains scenarios not in contract: " + ", ".join(unknown_scenarios))
    for scenario in sorted(scenarios):
        row = coverage.get(scenario)
        errors.extend(validate_bound_row(row, f"scenario {scenario}"))
        if not isinstance(row, dict):
            continue
        evidence = row.get("evidence")
        if isinstance(evidence, list):
            for index, evidence_path in enumerate(evidence):
                errors.extend(validate_repo_relative_file(repo_root, evidence_path, f"scenario {scenario} evidence[{index}]"))
        bound = str(row.get("verified_runtime_commit", "")).lower()
        if candidate_state == "FROZEN" and row.get("status") == "PASS" and bound and bound != str(candidate_runtime).lower():
            errors.append(f"scenario {scenario} PASS is bound to runtime {bound}, not frozen candidate {candidate_runtime}")

    return errors, contract_gates


def enforce_delivery(data: dict[str, Any], contract: dict[str, Any], contract_gates: dict[str, str]) -> list[str]:
    errors: list[str] = []
    if data.get("status") != "READY_FOR_OWNER":
        errors.append("campaign status is not READY_FOR_OWNER")
    if data.get("candidate_state") != "FROZEN":
        errors.append("candidate runtime is not FROZEN")
    if data.get("promotion_authorized") is not True:
        errors.append("promotion_authorized is not true")
    attention = data.get("owner_attention_event", {})
    if attention.get("allowed") is not True:
        errors.append("Owner attention event is not authorized")
    blockers = data.get("open_blockers", [])
    if blockers:
        errors.append(f"{len(blockers)} open blocker(s) remain")

    candidate_runtime = str(data.get("candidate_runtime_commit", "")).strip().lower()
    approved_runtime = str(data.get("approved_runtime_commit", "")).strip().lower()
    if not is_full_sha(candidate_runtime):
        errors.append("candidate_runtime_commit is not a full frozen runtime SHA")
    if not is_full_sha(approved_runtime):
        errors.append("approved_runtime_commit is not a full 40-character commit SHA")
    elif candidate_runtime and approved_runtime != candidate_runtime:
        errors.append("approved_runtime_commit does not equal frozen candidate_runtime_commit")

    readiness_gates = data.get("required_gates", {})
    for gate_name in contract_gates:
        gate = readiness_gates.get(gate_name, {})
        if gate.get("status") != "PASS":
            errors.append(f"required gate {gate_name} is {gate.get('status', 'MISSING')}, not PASS")
        if not gate.get("evidence"):
            errors.append(f"required gate {gate_name} has no evidence")
        bound = str(gate.get("verified_runtime_commit", "")).strip().lower()
        if not is_full_sha(bound):
            errors.append(f"required gate {gate_name} has no full verified_runtime_commit")
        elif approved_runtime and bound != approved_runtime:
            errors.append(f"required gate {gate_name} was verified on runtime {bound}, not approved runtime {approved_runtime}")

    scenarios = string_set(contract.get("representative_scenarios"))
    coverage = data.get("scenario_coverage", {})
    for scenario in sorted(scenarios):
        row = coverage.get(scenario, {})
        if row.get("status") != "PASS":
            errors.append(f"required scenario {scenario} is {row.get('status', 'MISSING')}, not PASS")
        if not row.get("evidence"):
            errors.append(f"required scenario {scenario} has no evidence")
        bound = str(row.get("verified_runtime_commit", "")).strip().lower()
        if not is_full_sha(bound):
            errors.append(f"required scenario {scenario} has no full verified_runtime_commit")
        elif approved_runtime and bound != approved_runtime:
            errors.append(f"required scenario {scenario} was verified on runtime {bound}, not approved runtime {approved_runtime}")

    if "independent_assurance_review" not in contract_gates:
        errors.append("campaign contract does not require independent_assurance_review")
    return errors


def load_state(repo_root: pathlib.Path, manifest_name: str) -> tuple[
    dict[str, Any] | None, dict[str, Any] | None, dict[str, str], list[str]
]:
    manifest_path = (repo_root / manifest_name).resolve()
    data, errors = load_json(manifest_path, "readiness manifest")
    if errors or data is None:
        return data, None, {}, errors
    contract_path_value = data.get("campaign_contract")
    errors.extend(validate_repo_relative_file(repo_root, contract_path_value, "campaign_contract"))
    if errors:
        return data, None, {}, errors
    contract_path = (repo_root / str(contract_path_value)).resolve()
    contract, contract_load_errors = load_json(contract_path, "campaign contract")
    errors.extend(contract_load_errors)
    if contract is None:
        return data, None, {}, errors
    errors.extend(validate_contract(contract, repo_root, contract_path))
    manifest_errors, contract_gates = validate_manifest(data, contract, repo_root)
    errors.extend(manifest_errors)
    return data, contract, contract_gates, errors


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", default="quality/p1-owner-readiness.json")
    parser.add_argument("--mode", choices=("validate", "delivery", "approved-runtime"), default="validate")
    args = parser.parse_args()

    repo_root = pathlib.Path.cwd().resolve()
    data, contract, contract_gates, errors = load_state(repo_root, args.manifest)
    if errors or data is None or contract is None:
        fail(errors)

    if args.mode == "delivery":
        errors = enforce_delivery(data, contract, contract_gates)
        if errors:
            fail(errors)
        runtime_commit = str(data["approved_runtime_commit"]).lower()
        print(
            "OWNER_READINESS_DELIVERY_PASS: contract, quality planes and representative scenarios are PASS; "
            "all evidence is bound to one frozen approved runtime, independent assurance is required, no blockers remain, "
            "and Owner attention is authorized."
        )
        print(f"APPROVED_RUNTIME_COMMIT={runtime_commit}")
        return

    if args.mode == "approved-runtime":
        runtime_commit = str(data.get("approved_runtime_commit", "")).strip().lower()
        if not runtime_commit or not is_full_sha(runtime_commit):
            fail(["approved_runtime_commit is not available as a full 40-character SHA"])
        print(runtime_commit)
        return

    pending_gates = [name for name in contract_gates if data["required_gates"].get(name, {}).get("status") != "PASS"]
    pending_scenarios = [
        scenario for scenario in string_set(contract.get("representative_scenarios"))
        if data.get("scenario_coverage", {}).get(scenario, {}).get("status") != "PASS"
    ]
    print(
        "OWNER_READINESS_MANIFEST_VALID: contract_version=%s status=%s candidate_state=%s "
        "promotion_authorized=%s pending_gates=%d pending_scenarios=%d"
        % (
            contract["contract_version"],
            data["status"],
            data["candidate_state"],
            data["promotion_authorized"],
            len(pending_gates),
            len(pending_scenarios),
        )
    )


if __name__ == "__main__":
    main()
