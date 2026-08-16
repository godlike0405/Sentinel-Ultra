#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys
from typing import Any


def write_text(path: str, value: str) -> None:
    destination = Path(path)
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(value, encoding="utf-8")


def finish(
    *,
    reward: float,
    exit_code: int,
    output_path: str,
    report_path: str,
    reward_path: str,
    records: list[dict[str, Any]],
    report: dict[str, Any],
) -> int:
    report["reward"] = reward
    write_text(output_path, json.dumps({"tests": records}, indent=2) + "\n")
    write_text(report_path, json.dumps(report, indent=2) + "\n")
    write_text(reward_path, "1\n" if reward == 1.0 else "0\n")
    return exit_code


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True)
    parser.add_argument("--results", required=True)
    parser.add_argument("--raw-exit-code", required=True, type=int)
    parser.add_argument("--output", required=True)
    parser.add_argument("--report", required=True)
    parser.add_argument("--reward", required=True)
    args = parser.parse_args()

    try:
        config = json.loads(Path(args.config).read_text(encoding="utf-8"))
        result_document = json.loads(Path(args.results).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return finish(
            reward=0.0,
            exit_code=2,
            output_path=args.output,
            report_path=args.report,
            reward_path=args.reward,
            records=[],
            report={
                "success": False,
                "raw_exit_code": args.raw_exit_code,
                "infrastructure_error": f"could not load verifier-owned JSON: {exc}",
            },
        )

    grading = config.get("grading")
    if not isinstance(grading, dict):
        grading = {}
    fail_to_pass = grading.get("fail_to_pass")
    pass_to_pass = grading.get("pass_to_pass")
    if not isinstance(fail_to_pass, list) or not isinstance(pass_to_pass, list):
        fail_to_pass, pass_to_pass = [], []
    expected = [str(name) for name in [*fail_to_pass, *pass_to_pass]]
    expected_duplicates = sorted({name for name in expected if expected.count(name) > 1})

    raw_records = result_document.get("tests") if isinstance(result_document, dict) else None
    records = raw_records if isinstance(raw_records, list) else []
    malformed_records: list[int] = []
    normalized: list[dict[str, Any]] = []
    for index, record in enumerate(records):
        if not isinstance(record, dict):
            malformed_records.append(index)
            continue
        name = record.get("name")
        status = record.get("status")
        if not isinstance(name, str) or status not in {"PASSED", "FAILED"}:
            malformed_records.append(index)
            continue
        normalized.append(record)

    observed_names = [str(record["name"]) for record in normalized]
    observed_duplicates = sorted(
        {name for name in observed_names if observed_names.count(name) > 1}
    )
    expected_set = set(expected)
    observed_set = set(observed_names)
    missing = sorted(expected_set - observed_set)
    unexpected = sorted(observed_set - expected_set)
    failed = sorted(
        str(record["name"])
        for record in normalized
        if record.get("status") != "PASSED" and record.get("name") in expected_set
    )

    configuration_ok = (
        10 <= len(fail_to_pass) <= 20
        and len(pass_to_pass) > 0
        and not bool(grading.get("allow_extra_failures", True))
        and not expected_duplicates
    )
    inventory_ok = (
        len(normalized) == len(records)
        and not malformed_records
        and not observed_duplicates
        and not missing
        and not unexpected
        and len(observed_names) == len(expected)
    )
    success = configuration_ok and inventory_ok and not failed and args.raw_exit_code == 0

    report = {
        "success": success,
        "raw_exit_code": args.raw_exit_code,
        "infrastructure_error": None,
        "configuration_ok": configuration_ok,
        "inventory_ok": inventory_ok,
        "expected_test_count": len(expected),
        "observed_test_count": len(observed_names),
        "missing_tests": missing,
        "unexpected_tests": unexpected,
        "failed_tests": failed,
        "expected_duplicates": expected_duplicates,
        "observed_duplicates": observed_duplicates,
        "malformed_record_indexes": malformed_records,
    }
    return finish(
        reward=1.0 if success else 0.0,
        exit_code=0 if success else 1,
        output_path=args.output,
        report_path=args.report,
        reward_path=args.reward,
        records=normalized,
        report=report,
    )


if __name__ == "__main__":
    sys.exit(main())
