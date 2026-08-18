#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from datasets import load_dataset


def load_instance(dataset_name: str, split: str, instance_id: str) -> dict:
    dataset = load_dataset(dataset_name, split=split)
    for row in dataset:
        if row["instance_id"] == instance_id:
            return dict(row)
    raise SystemExit(f"instance not found: {instance_id} in {dataset_name}:{split}")


def build_prompt(row: dict) -> str:
    parts = [
        "You are fixing a SWE-bench task in the current git repository checkout.",
        "",
        "Task:",
        row["problem_statement"].rstrip(),
    ]
    hints = (row.get("hints_text") or "").strip()
    if hints:
        parts.extend(["", "Hints:", hints])
    parts.extend(
        [
            "",
            "Requirements:",
            "- Make the minimal correct code changes in this repository.",
            "- Inspect the relevant code before editing.",
            "- Run targeted checks when useful.",
            "- Do not ask for user input.",
            "- Do not stop at a plan; actually make the edits.",
            "- When finished, give a short summary of what changed.",
        ]
    )
    return "\n".join(parts) + "\n"


def cmd_prepare(args: argparse.Namespace) -> int:
    row = load_instance(args.dataset_name, args.split, args.instance_id)
    metadata = {
        "instance_id": row["instance_id"],
        "repo": row["repo"],
        "repo_url": f"https://github.com/{row['repo']}.git",
        "base_commit": row["base_commit"],
        "problem_statement": row["problem_statement"],
        "hints_text": row.get("hints_text") or "",
    }
    prompt_out = Path(args.prompt_out)
    metadata_out = Path(args.metadata_out)
    prompt_out.parent.mkdir(parents=True, exist_ok=True)
    metadata_out.parent.mkdir(parents=True, exist_ok=True)
    prompt_out.write_text(build_prompt(row), encoding="utf-8")
    metadata_out.write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    return 0


def cmd_prediction(args: argparse.Namespace) -> int:
    patch_text = Path(args.patch_file).read_text(encoding="utf-8")
    if not patch_text.strip():
        raise SystemExit(f"patch file is empty: {args.patch_file}")
    payload = [
        {
            "instance_id": args.instance_id,
            "model_name_or_path": args.model_name,
            "model_patch": patch_text,
        }
    ]
    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Helpers for whale SWE-bench runs")
    sub = parser.add_subparsers(dest="command", required=True)

    prepare = sub.add_parser("prepare", help="Render prompt and metadata for one instance")
    prepare.add_argument("--dataset-name", default="SWE-bench/SWE-bench_Lite")
    prepare.add_argument("--split", default="test")
    prepare.add_argument("--instance-id", required=True)
    prepare.add_argument("--prompt-out", required=True)
    prepare.add_argument("--metadata-out", required=True)
    prepare.set_defaults(func=cmd_prepare)

    prediction = sub.add_parser("prediction", help="Write a SWE-bench predictions file")
    prediction.add_argument("--instance-id", required=True)
    prediction.add_argument("--model-name", required=True)
    prediction.add_argument("--patch-file", required=True)
    prediction.add_argument("--out", required=True)
    prediction.set_defaults(func=cmd_prediction)
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
