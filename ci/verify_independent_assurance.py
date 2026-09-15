#!/usr/bin/env python3
"""Validate P1 independent-assurance evidence.

Ordinary validation accepts a structurally valid PENDING report. Delivery mode
requires a falsification-oriented PASS report bound to the exact approved frozen
runtime and zero material findings.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys
from typing import Any

FULL_SHA_RE = re.compile(r"^[0-9a-fA-F]{40}$")
REPORT_PATH = pathlib.Path("quality/assurance/p1-independent-review.json")
READINESS_PATH = pathlib.Path("quality/p1-owner-readiness.json")


def load(path: pathlib.Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise SystemExit(f"ASSURANCE_ERROR: cannot load {path}: {exc}")
    if not isinstance(value, dict):
        raise SystemExit(f"ASSURANCE_ERROR: {path} root must be an object")
    return value


def nonempty_list(value: Any) -> bool:
    return isinstance(value, list) and bool(value) and all(isinstance(item, str) and item.strip() for item in value)


def full_sha(value: Any) -> bool:
    return isinstance(value, str) and bool(FULL_SHA_RE.fullmatch(value.strip()))


def validate_report(report: dict[str, Any], readiness: dict[str, Any], require_pass: bool) -> list[str]:
    errors: list[str] = []
    if report.get("schema_version") != 1:
        errors.append("schema_version must be 1")
    if report.get("campaign_id") != readiness.get("campaign_id"):
        errors.append("campaign_id does not match readiness")
    if report.get("campaign_contract_version") != readiness.get("campaign_contract_version"):
        errors.append("campaign_contract_version does not match readiness")
    if report.get("status") not in {"PENDING", "PASS", "FAIL"}:
        errors.append("status must be PENDING, PASS or FAIL")
    if report.get("disposition") not in {"PENDING", "PASS", "FAIL"}:
        errors.append("disposition must be PENDING, PASS or FAIL")
    if report.get("review_mode") != "read_only_falsification":
        errors.append("review_mode must be read_only_falsification")
    if report.get("reviewer_role") != "independent_assurance":
        errors.append("reviewer_role must be independent_assurance")
    if report.get("candidate_changes_authored_during_review") is not False:
        errors.append("candidate_changes_authored_during_review must be false")
    findings = report.get("material_findings")
    if not isinstance(findings, list):
        errors.append("material_findings must be a list")
        findings = []

    if report.get("status") == "PASS" or report.get("disposition") == "PASS":
        require_pass = True

    if require_pass:
        approved = readiness.get("approved_runtime_commit")
        candidate = readiness.get("candidate_runtime_commit")
        reviewed = report.get("reviewed_runtime_commit")
        if readiness.get("candidate_state") != "FROZEN":
            errors.append("assurance PASS requires candidate_state FROZEN")
        if not full_sha(candidate):
            errors.append("assurance PASS requires full candidate_runtime_commit")
        if not full_sha(approved) or str(approved).lower() != str(candidate).lower():
            errors.append("assurance PASS requires approved_runtime_commit == frozen candidate_runtime_commit")
        if not full_sha(reviewed) or str(reviewed).lower() != str(candidate).lower():
            errors.append("reviewed_runtime_commit does not match the frozen candidate runtime")
        if report.get("status") != "PASS" or report.get("disposition") != "PASS":
            errors.append("delivery requires assurance status=PASS and disposition=PASS")
        if not isinstance(report.get("review_context_id"), str) or not report.get("review_context_id", "").strip():
            errors.append("PASS report requires a non-empty review_context_id")
        if report.get("reviewer_context_separated_from_implementation") is not True:
            errors.append("PASS report requires reviewer context separated from implementation")
        if report.get("runtime_was_frozen") is not True:
            errors.append("PASS report requires runtime_was_frozen=true")
        if report.get("owner_goal_evaluated") is not True:
            errors.append("PASS report requires owner_goal_evaluated=true")
        if report.get("claim_evidence_fit_evaluated") is not True:
            errors.append("PASS report requires claim_evidence_fit_evaluated=true")
        if not nonempty_list(report.get("nominal_scenarios_reviewed")):
            errors.append("PASS report requires nominal_scenarios_reviewed")
        if not nonempty_list(report.get("off_nominal_scenarios_reviewed")):
            errors.append("PASS report requires off_nominal_scenarios_reviewed")
        if not nonempty_list(report.get("evidence_examined")):
            errors.append("PASS report requires evidence_examined")
        if findings:
            errors.append(f"PASS report has {len(findings)} material finding(s)")

        gate = readiness.get("required_gates", {}).get("independent_assurance_review", {})
        if gate.get("status") != "PASS":
            errors.append("readiness independent_assurance_review gate is not PASS")
        if str(gate.get("verified_runtime_commit", "")).lower() != str(candidate).lower():
            errors.append("readiness assurance gate is not bound to the frozen candidate runtime")
        evidence = gate.get("evidence", [])
        if REPORT_PATH.as_posix() not in evidence:
            errors.append("readiness assurance gate does not cite the machine-readable assurance report")

    return errors


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=("validate", "delivery"), default="validate")
    args = parser.parse_args()

    readiness = load(READINESS_PATH)
    report = load(REPORT_PATH)
    errors = validate_report(report, readiness, require_pass=args.mode == "delivery")
    if errors:
        for error in errors:
            print(f"ASSURANCE_ERROR: {error}", file=sys.stderr)
        raise SystemExit(1)
    if args.mode == "delivery":
        print("INDEPENDENT_ASSURANCE_DELIVERY_PASS: frozen runtime received a separate read-only falsification review with zero material findings.")
    else:
        print(f"INDEPENDENT_ASSURANCE_REPORT_VALID: status={report['status']} disposition={report['disposition']}")


if __name__ == "__main__":
    main()
