#!/usr/bin/env python3
import argparse
import json
import xml.etree.ElementTree as ET
from collections import Counter
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("--results-dir", default="/logs/verifier")
parser.add_argument("--config", default="/tests/config.json")
args = parser.parse_args()

RESULTS_DIR = Path(args.results_dir)
CONFIG_PATH = Path(args.config)
TRX_PATH = RESULTS_DIR / "sentinel-results.trx"
RAW_EXIT_PATH = RESULTS_DIR / "raw_test_exit_code.txt"
REWARD_PATH = RESULTS_DIR / "reward.txt"
DETAILS_PATH = RESULTS_DIR / "test_results.json"


def fail(reason: str, observed: list[dict] | None = None) -> None:
    payload = {"reward": 0, "reason": reason, "tests": observed or []}
    REWARD_PATH.write_text("0\n", encoding="utf-8")
    DETAILS_PATH.write_text(json.dumps(payload, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(payload, sort_keys=True))
    raise SystemExit(1)


try:
    config = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    expected = config["grading"]["fail_to_pass"] + config["grading"]["pass_to_pass"]
except (OSError, json.JSONDecodeError, KeyError, TypeError) as exc:
    fail(f"invalid verifier configuration: {exc}")

if not expected or len(expected) != len(set(expected)):
    fail("expected test IDs are empty or duplicated")

try:
    raw_exit = int(RAW_EXIT_PATH.read_text(encoding="utf-8").strip())
except (OSError, ValueError) as exc:
    fail(f"missing or malformed raw test exit code: {exc}")

if raw_exit != 0:
    fail(f"dotnet test exited with status {raw_exit}")

try:
    root = ET.parse(TRX_PATH).getroot()
except (OSError, ET.ParseError) as exc:
    fail(f"missing or malformed TRX results: {exc}")

observed = []
for element in root.iter():
    if element.tag.rsplit("}", 1)[-1] != "UnitTestResult":
        continue
    observed.append({
        "name": element.attrib.get("testName", ""),
        "status": element.attrib.get("outcome", ""),
    })

counts = Counter(item["name"] for item in observed)
duplicates = sorted(name for name, count in counts.items() if count != 1)
if duplicates:
    fail(f"duplicate test result IDs: {duplicates}", observed)

expected_set = set(expected)
observed_set = set(counts)
if observed_set != expected_set:
    missing = sorted(expected_set - observed_set)
    unexpected = sorted(observed_set - expected_set)
    fail(f"graded test set mismatch; missing={missing}, unexpected={unexpected}", observed)

nonpassing = sorted(item["name"] for item in observed if item["status"] != "Passed")
if nonpassing:
    fail(f"non-passing graded tests: {nonpassing}", observed)

payload = {"reward": 1, "tests": sorted(observed, key=lambda item: item["name"])}
REWARD_PATH.write_text("1\n", encoding="utf-8")
DETAILS_PATH.write_text(json.dumps(payload, sort_keys=True) + "\n", encoding="utf-8")
print(json.dumps(payload, sort_keys=True))
