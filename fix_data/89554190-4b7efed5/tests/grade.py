#!/usr/bin/env python3
"""Grade declared fail-to-pass and pass-to-pass Vitest assertions."""

import json
import os
import sys


def load_expected():
    config_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "config.json")
    with open(config_path, "r", encoding="utf-8") as config_file:
        grading = json.load(config_file).get("grading", {})
    return grading.get("fail_to_pass", []) + grading.get("pass_to_pass", [])


def normalize_path(path):
    return str(path or "").replace("\\", "/")


def collect_assertions(results):
    """Return {(spec suffix, title): status} from a Vitest JSON report."""
    assertions = {}
    for file_result in results.get("testResults", []):
        spec_path = normalize_path(file_result.get("name"))
        for assertion in file_result.get("assertionResults", []):
            title = assertion.get("title")
            if title:
                assertions[(spec_path, title)] = assertion.get("status")
    return assertions


def assertion_passed(assertions, expected_id):
    if "::" not in expected_id:
        return False
    expected_path, expected_title = expected_id.split("::", 1)
    expected_path = normalize_path(expected_path)
    return any(
        spec_path.endswith(expected_path)
        and title == expected_title
        and status == "passed"
        for (spec_path, title), status in assertions.items()
    )


def main():
    if len(sys.argv) != 2:
        print("0")
        return 1

    try:
        with open(sys.argv[1], "r", encoding="utf-8") as results_file:
            results = json.load(results_file)
        expected = load_expected()
    except (OSError, ValueError, TypeError, json.JSONDecodeError):
        print("0")
        return 1

    assertions = collect_assertions(results)
    all_passed = bool(expected) and all(assertion_passed(assertions, test_id) for test_id in expected)
    print("1" if all_passed else "0")
    return 0 if all_passed else 1


if __name__ == "__main__":
    sys.exit(main())
