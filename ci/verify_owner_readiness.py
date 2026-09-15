#!/usr/bin/env python3
"""Validate or enforce the Owner-candidate readiness manifest.

Ordinary CI uses --mode validate so a deliberately BLOCKED campaign remains
valid while work is in progress. Owner delivery uses --mode delivery, which
requires every promotion condition to be satisfied and every required gate to
have been re-verified on the exact commit being packaged.
"""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import sys
from typing import Any


REQUIRED_GATES = (
    "owner_intent_contract",
    "mechanical_integrated_runtime",
    "rendered_parity_harness",
    "form_depth_readability",
    "matter_granularity",
    "system_state_semantics",
    "camera_composition",
    "interaction_hierarchy",
    "world_motion_causality",
    "ui_hierarchy",
    "cross_layer_visible_composition",
    "adversarial_rehearsal",
    "final_readiness_audit",
)

VALID_STATUSES = {"PASS", "FAIL", "PENDING", "SUPERSEDED"}


def fail(errors: list[str]) -> None:
    for error in errors:
        print(f"OWNER_READINESS_ERROR: {error}", file=sys.stderr)
    sys.exit(1)


def validate_structure(data: dict[str, Any], repo_root: pathlib.Path) -> list[str]:
    errors: list[str] = []

    if data.get("schema_version") != 2:
        errors.append("schema_version must be 2")

    for key in ("campaign_id", "candidate_label", "source_branch", "owner_goal", "owner_visible_surface"):
        value = data.get(key)
        if not isinstance(value, str) or not value.strip():
            errors.append(f"{key} must be a non-empty string")

    if data.get("status") not in {"BLOCKED", "READY_FOR_OWNER"}:
        errors.append("status must be BLOCKED or READY_FOR_OWNER")

    if not isinstance(data.get("promotion_authorized"), bool):
        errors.append("promotion_authorized must be boolean")

    approved_commit = data.get("approved_commit")
    if not isinstance(approved_commit, str):
        errors.append("approved_commit must be a string")

    attention = data.get("owner_attention_event")
    if not isinstance(attention, dict):
        errors.append("owner_attention_event must be an object")
    else:
        if not isinstance(attention.get("allowed"), bool):
            errors.append("owner_attention_event.allowed must be boolean")
        if not isinstance(attention.get("reason"), str) or not attention.get("reason", "").strip():
            errors.append("owner_attention_event.reason must be non-empty")

    blockers = data.get("open_blockers")
    if not isinstance(blockers, list) or not all(isinstance(item, str) and item.strip() for item in blockers):
        errors.append("open_blockers must be a list of non-empty strings")

    gates = data.get("required_gates")
    if not isinstance(gates, dict):
        errors.append("required_gates must be an object")
        return errors

    missing = [gate for gate in REQUIRED_GATES if gate not in gates]
    if missing:
        errors.append("missing required gates: " + ", ".join(missing))

    unknown = sorted(set(gates) - set(REQUIRED_GATES))
    if unknown:
        errors.append("unknown required gates: " + ", ".join(unknown))

    for gate_name in REQUIRED_GATES:
        gate = gates.get(gate_name)
        if not isinstance(gate, dict):
            continue

        status = gate.get("status")
        if status not in VALID_STATUSES:
            errors.append(f"gate {gate_name} has invalid status {status!r}")

        evidence_type = gate.get("evidence_type")
        if not isinstance(evidence_type, str) or not evidence_type.strip():
            errors.append(f"gate {gate_name} evidence_type must be non-empty")

        verified_commit = gate.get("verified_commit")
        if not isinstance(verified_commit, str):
            errors.append(f"gate {gate_name} verified_commit must be a string")

        evidence = gate.get("evidence")
        if not isinstance(evidence, list) or not all(isinstance(item, str) and item.strip() for item in evidence):
            errors.append(f"gate {gate_name} evidence must be a list of non-empty paths")
            continue
        if status == "PASS" and not evidence:
            errors.append(f"gate {gate_name} is PASS but has no evidence")

        for evidence_path in evidence:
            # Only repository-relative evidence paths are accepted. External run IDs
            # may be recorded inside those durable evidence records.
            if evidence_path.startswith(("http://", "https://", "/")):
                errors.append(f"gate {gate_name} evidence must be repository-relative: {evidence_path}")
                continue
            if not (repo_root / evidence_path).is_file():
                errors.append(f"gate {gate_name} references missing evidence file: {evidence_path}")

    return errors


def enforce_delivery(data: dict[str, Any], commit: str) -> list[str]:
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

    gates = data.get("required_gates", {})
    for gate_name in REQUIRED_GATES:
        gate = gates.get(gate_name, {})
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

    if not manifest_path.is_file():
        fail([f"readiness manifest missing: {args.manifest}"])

    try:
        data = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        fail([f"cannot parse readiness manifest: {exc}"])

    if not isinstance(data, dict):
        fail(["readiness manifest root must be an object"])

    errors = validate_structure(data, repo_root)
    if args.mode == "delivery" and not errors:
        errors.extend(enforce_delivery(data, args.commit))

    if errors:
        fail(errors)

    if args.mode == "delivery":
        print(
            "OWNER_READINESS_DELIVERY_PASS: every required quality plane is PASS, "
            "evidence exists, no blockers remain, Owner attention is authorized, "
            "and every gate is verified on the exact delivery commit."
        )
    else:
        pending = [
            name
            for name, gate in data["required_gates"].items()
            if gate.get("status") != "PASS"
        ]
        unbound = [
            name
            for name, gate in data["required_gates"].items()
            if not str(gate.get("verified_commit", "")).strip()
        ]
        print(
            "OWNER_READINESS_MANIFEST_VALID: status=%s promotion_authorized=%s pending_or_failed=%d unbound_gates=%d"
            % (data["status"], data["promotion_authorized"], len(pending), len(unbound))
        )


if __name__ == "__main__":
    main()
