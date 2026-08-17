"""JUnit and JSON report writers for the QA runner."""

from __future__ import annotations

import json
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Iterable

from qa_contract import TestResult


def write_junit(results: Iterable[TestResult], destination: Path, suite_name: str) -> None:
    result_list = list(results)
    testsuite = ET.Element("testsuite", {
        "name": f"ysbzs-{suite_name}",
        "tests": str(len(result_list)),
        "failures": str(sum(result.status != "passed" for result in result_list)),
        "time": f"{sum(result.duration_seconds for result in result_list):.3f}",
    })
    for result in result_list:
        testcase = ET.SubElement(testsuite, "testcase", {
            "classname": result.spec.path.replace("/", "."),
            "name": result.spec.identity,
            "time": f"{result.duration_seconds:.3f}",
        })
        if result.status != "passed":
            failure = ET.SubElement(testcase, "failure", {
                "message": result.failure_reason or "Godot QA failure",
            })
            failure.text = result.output[-12000:]
        ET.SubElement(testcase, "system-out").text = result.output[-12000:]
    destination.parent.mkdir(parents=True, exist_ok=True)
    ET.ElementTree(testsuite).write(destination, encoding="utf-8", xml_declaration=True)


def write_summary(results: list[TestResult], destination: Path, suite_name: str, run_id: str) -> None:
    summary = {
        "schema": "ysbzs.qa.run.v1",
        "runId": run_id,
        "suite": suite_name,
        "status": "passed" if all(result.status == "passed" for result in results) else "failed",
        "total": len(results),
        "passed": sum(result.status == "passed" for result in results),
        "failed": sum(result.status != "passed" for result in results),
        "durationSeconds": round(sum(result.duration_seconds for result in results), 3),
        "tests": [{
            "id": result.spec.identity,
            "path": result.spec.path,
            "args": list(result.spec.args),
            "status": result.status,
            "exitCode": result.exit_code,
            "durationSeconds": round(result.duration_seconds, 3),
            "failureReason": result.failure_reason,
            "evidenceDir": result.evidence_dir,
            "userDataDir": result.user_data_dir,
        } for result in results],
    }
    destination.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
