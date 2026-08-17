#!/usr/bin/env python3
"""Run layered Godot QA suites with isolated user data and evidence."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from qa_contract import (
    DEFAULT_MANIFEST,
    REPO_ROOT,
    TestSpec,
    expand_suite,
    read_json,
    resolve_godot,
    slugify,
    timestamp_id,
    user_data_dir,
)
from qa_reports import write_junit, write_summary
from qa_runtime import capped_log_text, create_overlay, ensure_project_import, run_test, runtime_user_args


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--suite", default="fast")
    parser.add_argument("--test", action="append", default=[],
                        help="Run a specific res://-relative GDScript; may be repeated.")
    parser.add_argument("--manifest", default=str(DEFAULT_MANIFEST))
    parser.add_argument("--godot", default="")
    parser.add_argument("--output", default="")
    parser.add_argument("--run-id", default="")
    parser.add_argument("--seed-count", type=int, default=0)
    parser.add_argument("--timeout", type=int, default=0)
    parser.add_argument("--screen", type=int, default=-1,
                        help="Display index for display tests; omitted in CI by default.")
    parser.add_argument("--list", action="store_true")
    parser.add_argument("--skip-import", action="store_true")
    parser.add_argument("--keep-user-data", action="store_true")
    parser.add_argument("--update-baselines", action="store_true")
    parser.add_argument("--fail-fast", action="store_true")
    return parser.parse_args(argv)


def _selected_specs(options: argparse.Namespace, manifest: dict) -> tuple[str, list[TestSpec]]:
    if not options.test:
        return options.suite, expand_suite(manifest, options.suite, root=REPO_ROOT)
    defaults = dict(manifest.get("defaults", {}))
    return "adhoc", [
        TestSpec(
            path=value.removeprefix("res://"),
            timeout_seconds=int(defaults.get("timeout_seconds", 180)),
            strict_output=bool(defaults.get("strict_output", True)),
        )
        for value in options.test
    ]


def main(argv: list[str] | None = None) -> int:
    options = parse_args(argv or sys.argv[1:])
    manifest = read_json(Path(options.manifest).expanduser().resolve())
    suite_name, specs = _selected_specs(options, manifest)
    if options.list:
        for spec in specs:
            mode = "display" if spec.display else "headless"
            print(f"{spec.identity}\t{mode}\t{spec.path}\t{' '.join(spec.args)}")
        return 0
    if not specs:
        print(f"QA suite {options.suite} has no tests", file=sys.stderr)
        return 2

    godot = resolve_godot(options.godot)
    run_id = options.run_id or f"{timestamp_id()}-{slugify(suite_name)}"
    output_root = (Path(options.output).expanduser().resolve() if options.output
                   else REPO_ROOT / "output" / "validation" / "qa" / run_id)
    output_root.mkdir(parents=True, exist_ok=True)
    if not options.skip_import:
        ensure_project_import(godot, REPO_ROOT, output_root)

    print(f"QA_RUN_START suite={suite_name} tests={len(specs)} output={output_root}", flush=True)
    results = []
    for index, spec in enumerate(specs, start=1):
        print(f"QA_TEST_START {index}/{len(specs)} id={spec.identity} path={spec.path}", flush=True)
        result = run_test(
            spec, godot, REPO_ROOT, run_id, output_root,
            options.keep_user_data, options.update_baselines,
            max(0, options.seed_count), max(0, options.timeout), options.screen,
        )
        results.append(result)
        print(f"QA_TEST_{result.status.upper()} id={spec.identity} seconds={result.duration_seconds:.2f}",
              flush=True)
        if result.status != "passed" and options.fail_fast:
            break

    write_summary(results, output_root / "summary.json", suite_name, run_id)
    write_junit(results, output_root / "junit.xml", suite_name)
    failed = sum(result.status != "passed" for result in results)
    print(f"QA_RUN_{'FAIL' if failed else 'OK'} suite={suite_name} "
          f"passed={len(results) - failed} failed={failed} output={output_root}", flush=True)
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
