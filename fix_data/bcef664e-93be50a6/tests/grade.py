#!/usr/bin/env python3
"""Grade verifier-owned per-test exit statuses against config.json."""

import argparse
import json
from pathlib import Path


def write_text(path, value):
    Path(path).write_text(value, encoding="utf-8")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True)
    parser.add_argument("--results", required=True)
    parser.add_argument("--raw-exit-code", required=True, type=int)
    parser.add_argument("--output", required=True)
    parser.add_argument("--report", required=True)
    parser.add_argument("--reward", required=True)
    args = parser.parse_args()

    reward = 0.0
    exit_code = 2
    report = {
        "success": False,
        "raw_exit_code": args.raw_exit_code,
        "infrastructure_error": None,
    }
    output = {"tests": []}

    try:
        config = json.loads(Path(args.config).read_text(encoding="utf-8"))
        results_doc = json.loads(Path(args.results).read_text(encoding="utf-8"))
        grading = config["grading"]
        expected = [*grading["fail_to_pass"], *grading["pass_to_pass"]]
        results = results_doc["tests"]

        if not expected:
            raise ValueError("no graded tests are configured")
        if len(expected) != len(set(expected)):
            raise ValueError("graded test IDs are duplicated")
        if not isinstance(results, list):
            raise ValueError("results.tests is not a list")

        observed = [entry.get("name") for entry in results]
        if observed != expected:
            raise ValueError("observed test IDs do not exactly match the declared order")
        if any(entry.get("status") not in {"PASSED", "FAILED"} for entry in results):
            raise ValueError("a test has an invalid status")
        if any(not isinstance(entry.get("exit_code"), int) for entry in results):
            raise ValueError("a test is missing its verifier-owned exit code")

        output = {"tests": results}
        missing = [entry["name"] for entry in results if entry["status"] != "PASSED"]
        success = args.raw_exit_code == 0 and not missing
        reward = 1.0 if success else 0.0
        exit_code = 0 if success else 1
        report.update(
            {
                "success": success,
                "required_tests_count": len(expected),
                "passed_tests_count": len(expected) - len(missing),
                "required_tests": expected,
                "missing_required_tests": missing,
            }
        )
    except (OSError, KeyError, TypeError, ValueError, json.JSONDecodeError) as exc:
        report["infrastructure_error"] = str(exc)

    report["reward"] = reward
    write_text(args.output, json.dumps(output, indent=2) + "\n")
    write_text(args.report, json.dumps(report, indent=2) + "\n")
    write_text(args.reward, f"{reward:.1f}\n")
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
