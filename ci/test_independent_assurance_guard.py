#!/usr/bin/env python3
"""Adversarial self-test for independent assurance enforcement."""

from __future__ import annotations

import copy
import json
import pathlib
import sys

import verify_independent_assurance as guard

ROOT = pathlib.Path(__file__).resolve().parents[1]
READINESS = json.loads((ROOT / "quality/p1-owner-readiness.json").read_text(encoding="utf-8"))
REPORT = json.loads((ROOT / "quality/assurance/p1-independent-review.json").read_text(encoding="utf-8"))
RUNTIME = "0123456789abcdef0123456789abcdef01234567"
failures: list[str] = []


def check(condition: bool, label: str) -> None:
    if not condition:
        failures.append(label)


def make_ready() -> dict:
    data = copy.deepcopy(READINESS)
    data["status"] = "READY_FOR_OWNER"
    data["candidate_state"] = "FROZEN"
    data["candidate_runtime_commit"] = RUNTIME
    data["approved_runtime_commit"] = RUNTIME
    data["promotion_authorized"] = True
    data["owner_attention_event"] = {"allowed": True, "reason": "synthetic assurance self-test"}
    data["open_blockers"] = []
    gate = data["required_gates"]["independent_assurance_review"]
    gate["status"] = "PASS"
    gate["verified_runtime_commit"] = RUNTIME
    gate["evidence"] = ["quality/assurance/p1-independent-review.json"]
    return data


def make_pass_report() -> dict:
    report = copy.deepcopy(REPORT)
    report.update(
        {
            "status": "PASS",
            "disposition": "PASS",
            "reviewed_runtime_commit": RUNTIME,
            "review_context_id": "synthetic-fresh-read-only-context",
            "reviewer_context_separated_from_implementation": True,
            "runtime_was_frozen": True,
            "candidate_changes_authored_during_review": False,
            "owner_goal_evaluated": True,
            "claim_evidence_fit_evaluated": True,
            "nominal_scenarios_reviewed": ["default_static_matter", "dynamic_translation_and_yaw"],
            "off_nominal_scenarios_reviewed": ["close_camera_obstacle_stress", "fall_and_recovery"],
            "evidence_examined": ["rendered baseline", "rehearsal video", "readiness matrix"],
            "material_findings": [],
        }
    )
    return report


def main() -> None:
    errors = guard.validate_report(REPORT, READINESS, require_pass=False)
    check(not errors, "real PENDING assurance report is structurally valid: %s" % errors)

    ready = make_ready()
    report = make_pass_report()
    errors = guard.validate_report(report, ready, require_pass=True)
    check(not errors, "complete separated PASS review is accepted: %s" % errors)

    wrong_runtime = copy.deepcopy(report)
    wrong_runtime["reviewed_runtime_commit"] = "89abcdef0123456789abcdef0123456789abcdef"
    errors = guard.validate_report(wrong_runtime, ready, require_pass=True)
    check(any("does not match" in error for error in errors), "review of a different runtime is rejected")

    self_review = copy.deepcopy(report)
    self_review["reviewer_context_separated_from_implementation"] = False
    errors = guard.validate_report(self_review, ready, require_pass=True)
    check(any("separated" in error for error in errors), "non-separated implementation self-review is rejected")

    mutating_review = copy.deepcopy(report)
    mutating_review["candidate_changes_authored_during_review"] = True
    errors = guard.validate_report(mutating_review, ready, require_pass=True)
    check(any("candidate_changes_authored" in error for error in errors), "review that edits candidate is rejected")

    finding = copy.deepcopy(report)
    finding["material_findings"] = ["ordinary close camera view loses the active Space"]
    errors = guard.validate_report(finding, ready, require_pass=True)
    check(any("material finding" in error for error in errors), "material finding blocks assurance PASS")

    happy_only = copy.deepcopy(report)
    happy_only["off_nominal_scenarios_reviewed"] = []
    errors = guard.validate_report(happy_only, ready, require_pass=True)
    check(any("off_nominal" in error for error in errors), "happy-path-only assurance is rejected")

    missing_goal = copy.deepcopy(report)
    missing_goal["owner_goal_evaluated"] = False
    errors = guard.validate_report(missing_goal, ready, require_pass=True)
    check(any("owner_goal_evaluated" in error for error in errors), "assurance that ignores Owner goal is rejected")

    if failures:
        for failure in failures:
            print("INDEPENDENT_ASSURANCE_SELFTEST_FAIL: " + failure, file=sys.stderr)
        raise SystemExit(1)
    print(
        "INDEPENDENT_ASSURANCE_SELFTEST_PASS: guard accepts a separated frozen-runtime falsification review "
        "and rejects wrong-runtime, self-review, candidate mutation, material findings, happy-path-only review "
        "and omission of the Owner goal."
    )


if __name__ == "__main__":
    main()
