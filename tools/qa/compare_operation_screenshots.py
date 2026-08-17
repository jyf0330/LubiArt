#!/usr/bin/env python3

import argparse
import json
from pathlib import Path

from compare_screenshots import compare


PRESERVE = "preserve"
INTENTIONAL_CHANGE = "intentional_change"
VALID_EXPECTATIONS = {PRESERVE, INTENTIONAL_CHANGE}


def _resolve_path(manifest_dir: Path, raw_path: str) -> Path:
    path = Path(raw_path)
    return path if path.is_absolute() else manifest_dir / path


def validate_manifest(manifest_path: Path) -> dict:
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    default_expectation = str(
        manifest.get("expectation", manifest.get("mode", PRESERVE))
    ).strip()
    if default_expectation not in VALID_EXPECTATIONS:
        raise ValueError(
            "manifest.expectation must be one of: "
            + ", ".join(sorted(VALID_EXPECTATIONS))
        )
    approval = str(manifest.get("approval", "")).strip()
    operations = manifest.get("operations", [])
    if not isinstance(operations, list):
        raise ValueError("manifest.operations must be an array")

    manifest_dir = manifest_path.resolve().parent
    names = []
    comparisons = []
    errors = []
    if not operations:
        errors.append("manifest.operations must contain the task's risk-based coverage")
    for index, operation in enumerate(operations, start=1):
        if not isinstance(operation, dict):
            errors.append(f"operation {index} must be an object")
            continue
        name = str(operation.get("name", "")).strip()
        if not name:
            errors.append(f"operation {index} is missing a name")
            continue
        expectation = str(operation.get("expectation", default_expectation)).strip()
        if expectation not in VALID_EXPECTATIONS:
            errors.append(
                f"{name}: expectation must be one of: "
                + ", ".join(sorted(VALID_EXPECTATIONS))
            )
            continue
        expected_change = str(operation.get("expected_change", "")).strip()
        if expectation == INTENTIONAL_CHANGE and not expected_change:
            errors.append(f"{name}: intentional_change requires expected_change")
        if expectation == INTENTIONAL_CHANGE and not approval:
            errors.append(f"{name}: intentional_change requires manifest.approval")
        names.append(name)
        before_path = _resolve_path(manifest_dir, str(operation.get("before", "")))
        after_path = _resolve_path(manifest_dir, str(operation.get("after", "")))
        missing = [str(path) for path in (before_path, after_path) if not path.is_file()]
        if missing:
            errors.append(f"{name}: missing screenshot(s): {', '.join(missing)}")
            continue
        result = compare(before_path, after_path)
        result["name"] = name
        result["expectation"] = expectation
        if expected_change:
            result["expected_change"] = expected_change
        expectation_passed = (
            result["identical"]
            if expectation == PRESERVE
            else result["same_size"] and result["differing_pixels"] > 0
        )
        result["pixel_comparison_result"] = result["result"]
        result["expectation_passed"] = expectation_passed
        result["result"] = "PASS" if expectation_passed else "BLOCKED"
        comparisons.append(result)

    unique_operation_count = len(set(names))
    if len(names) != unique_operation_count:
        errors.append("operation names must be unique")

    passed = (
        not errors
        and len(comparisons) == len(operations)
        and all(item["expectation_passed"] for item in comparisons)
    )
    return {
        "result": "PASS" if passed else "BLOCKED",
        "passed": passed,
        "default_expectation": default_expectation,
        "approval": approval,
        "operation_count": len(operations),
        "unique_operation_count": unique_operation_count,
        "errors": errors,
        "operations": comparisons,
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Validate a task-defined screenshot matrix with per-operation preserve or "
            "intentional-change expectations."
        )
    )
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()

    if not args.manifest.is_file():
        parser.error(f"manifest does not exist: {args.manifest}")

    try:
        result = validate_manifest(args.manifest)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        parser.error(str(error))
    output = json.dumps(result, ensure_ascii=False, indent=2)
    print(output)
    if args.report is not None:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(output + "\n", encoding="utf-8")
    return 0 if result["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
