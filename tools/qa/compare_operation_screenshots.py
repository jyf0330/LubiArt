#!/usr/bin/env python3

import argparse
import json
from pathlib import Path

from compare_screenshots import compare


MINIMUM_OPERATION_COUNT = 5


def _resolve_path(manifest_dir: Path, raw_path: str) -> Path:
    path = Path(raw_path)
    return path if path.is_absolute() else manifest_dir / path


def validate_manifest(manifest_path: Path) -> dict:
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    operations = manifest.get("operations", [])
    if not isinstance(operations, list):
        raise ValueError("manifest.operations must be an array")

    manifest_dir = manifest_path.resolve().parent
    names = []
    comparisons = []
    errors = []
    for index, operation in enumerate(operations, start=1):
        if not isinstance(operation, dict):
            errors.append(f"operation {index} must be an object")
            continue
        name = str(operation.get("name", "")).strip()
        if not name:
            errors.append(f"operation {index} is missing a name")
            continue
        names.append(name)
        before_path = _resolve_path(manifest_dir, str(operation.get("before", "")))
        after_path = _resolve_path(manifest_dir, str(operation.get("after", "")))
        missing = [str(path) for path in (before_path, after_path) if not path.is_file()]
        if missing:
            errors.append(f"{name}: missing screenshot(s): {', '.join(missing)}")
            continue
        result = compare(before_path, after_path)
        result["name"] = name
        comparisons.append(result)

    unique_operation_count = len(set(names))
    if unique_operation_count < MINIMUM_OPERATION_COUNT:
        errors.append(
            f"requires at least {MINIMUM_OPERATION_COUNT} unique operations; "
            f"found {unique_operation_count}"
        )
    if len(names) != unique_operation_count:
        errors.append("operation names must be unique")

    all_identical = (
        not errors
        and len(comparisons) == len(operations)
        and all(item["identical"] for item in comparisons)
    )
    return {
        "result": "PASS" if all_identical else "BLOCKED",
        "minimum_operation_count": MINIMUM_OPERATION_COUNT,
        "operation_count": len(operations),
        "unique_operation_count": unique_operation_count,
        "all_identical": all_identical,
        "errors": errors,
        "operations": comparisons,
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Require at least five unique operation screenshot pairs to be pixel-identical."
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
    return 0 if result["all_identical"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
