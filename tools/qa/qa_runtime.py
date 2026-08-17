"""Isolated Godot process execution and evidence collection."""

from __future__ import annotations

import os
import shutil
import signal
import subprocess
import tempfile
import time
from pathlib import Path

from qa_contract import TestResult, TestSpec, USER_DATA_NAMESPACE, slugify, user_data_dir


EVIDENCE_SUFFIXES = {".json", ".jsonl", ".log", ".png", ".txt", ".xml"}
MAX_EVIDENCE_FILE_BYTES = 25 * 1024 * 1024
MAX_PROCESS_LOG_BYTES = 4 * 1024 * 1024


def _quote_godot_string(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def create_overlay(root: Path, run_id: str, spec: TestSpec) -> tuple[Path, str, Path]:
    overlay = Path(tempfile.mkdtemp(prefix=f"ysbzs-qa-{spec.identity}-"))
    shutil.copy2(root / "project.godot", overlay / "project.godot")
    skipped = {".git", ".godot", "project.godot", "override.cfg", "output", "outputs", "build"}
    for child in root.iterdir():
        if child.name in skipped:
            continue
        destination = overlay / child.name
        try:
            destination.symlink_to(child.resolve(), target_is_directory=child.is_dir())
        except OSError:
            if child.is_dir():
                shutil.copytree(child, destination, dirs_exist_ok=True)
            else:
                shutil.copy2(child, destination)
    if (root / ".godot").exists():
        (overlay / ".godot").symlink_to((root / ".godot").resolve(), target_is_directory=True)
    custom_name = f"{USER_DATA_NAMESPACE}/{slugify(run_id)}/{spec.identity}"
    override = "\n".join((
        "[application]",
        f"config/name={_quote_godot_string('YSBZS QA ' + spec.identity)}",
        "config/use_custom_user_dir=true",
        f"config/custom_user_dir_name={_quote_godot_string(custom_name)}",
        "",
    ))
    (overlay / "override.cfg").write_text(override, encoding="utf-8")
    return overlay, custom_name, user_data_dir(custom_name)


def safe_remove_user_data(path: Path) -> None:
    resolved = path.resolve(strict=False)
    if USER_DATA_NAMESPACE not in resolved.parts:
        raise ValueError(f"Refusing to remove non-QA user data path: {resolved}")
    if resolved.exists():
        shutil.rmtree(resolved)


def ensure_project_import(godot: Path, root: Path, output_dir: Path) -> None:
    imported = root / ".godot" / "imported"
    if imported.is_dir() and any(imported.iterdir()):
        return
    log_path = output_dir / "project-import.log"
    process = subprocess.run(
        [str(godot), "--headless", "--editor", "--path", str(root), "--import", "--quit"],
        cwd=root, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        timeout=600, check=False,
    )
    log_path.write_text(process.stdout or "", encoding="utf-8")
    if process.returncode != 0:
        raise RuntimeError(f"Godot import failed; see {log_path}")


def collect_user_evidence(source: Path, destination: Path) -> list[str]:
    copied: list[str] = []
    if not source.is_dir():
        return copied
    for candidate in sorted(source.rglob("*")):
        if not candidate.is_file() or candidate.suffix.lower() not in EVIDENCE_SUFFIXES:
            continue
        if candidate.stat().st_size > MAX_EVIDENCE_FILE_BYTES:
            continue
        target = destination / candidate.relative_to(source)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(candidate, target)
        copied.append(target.as_posix())
    return copied


def strict_output_failure(output: str) -> str:
    for pattern in ("SCRIPT ERROR:", "Parse Error:", "Failed to load script", "Cannot get class"):
        if pattern in output:
            return f"strict output matched {pattern}"
    return ""


def capped_log_text(value: str, max_bytes: int = MAX_PROCESS_LOG_BYTES) -> tuple[str, bool]:
    encoded = value.encode("utf-8", errors="replace")
    if len(encoded) <= max_bytes:
        return value, False
    tail = encoded[-max_bytes:].decode("utf-8", errors="replace")
    return "[QA runner truncated earlier process output]\n" + tail, True


def runtime_user_args(spec: TestSpec, seed_count: int, update_baselines: bool) -> list[str]:
    arguments = list(spec.args)
    if seed_count > 0 and spec.path.endswith("seed_bot.gd"):
        arguments = [value for value in arguments if not value.startswith("--qa-seed-count=")]
        arguments.append(f"--qa-seed-count={seed_count}")
    if update_baselines and spec.path.endswith("ui_regression.gd"):
        arguments.append("--qa-update-baselines")
    return arguments


def terminate_process(process: subprocess.Popen[str]) -> None:
    if process.poll() is not None:
        return
    try:
        os.killpg(process.pid, signal.SIGTERM) if os.name == "posix" else process.terminate()
        process.wait(timeout=5)
    except (ProcessLookupError, subprocess.TimeoutExpired):
        try:
            os.killpg(process.pid, signal.SIGKILL) if os.name == "posix" else process.kill()
        except ProcessLookupError:
            pass


def run_test(spec: TestSpec, godot: Path, root: Path, run_id: str, output_root: Path,
             keep_user_data: bool, update_baselines: bool, seed_count: int,
             timeout_override: int, screen_index: int) -> TestResult:
    test_dir = output_root / "tests" / spec.identity
    test_dir.mkdir(parents=True, exist_ok=True)
    overlay, custom_name, isolated_user_dir = create_overlay(root, run_id, spec)
    safe_remove_user_data(isolated_user_dir)
    isolated_user_dir.mkdir(parents=True, exist_ok=True)
    command = [str(godot)]
    if not spec.display:
        command.append("--headless")
    elif screen_index >= 0:
        command.extend(["--screen", str(screen_index)])
    command.extend(["--path", str(overlay), *spec.engine_args, "--script", f"res://{spec.path}", "--",
                    f"--qa-output={test_dir}", f"--qa-user-token={spec.identity}",
                    *runtime_user_args(spec, seed_count, update_baselines)])
    environment = os.environ.copy()
    environment.update({"QA_RUN_ID": run_id, "QA_TEST_ID": spec.identity,
                        "QA_EVIDENCE_DIR": str(test_dir), "YSBZS_LOG": "1", "YSBZS_OPERATION_LOG": "1"})
    timeout_seconds = timeout_override or spec.timeout_seconds
    started = time.monotonic()
    process: subprocess.Popen[str] | None = None
    timed_out, output, exit_code = False, "", -1
    try:
        process = subprocess.Popen(command, cwd=root, env=environment, text=True,
                                   stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                   start_new_session=(os.name == "posix"))
        try:
            output, _ = process.communicate(timeout=timeout_seconds)
        except subprocess.TimeoutExpired:
            timed_out = True
            terminate_process(process)
            remaining, _ = process.communicate()
            output += remaining or ""
        exit_code = process.returncode if process.returncode is not None else -1
    finally:
        duration = time.monotonic() - started
        stored_output, output_truncated = capped_log_text(output or "")
        (test_dir / "stdout.log").write_text(stored_output, encoding="utf-8")
    failure_reason = (f"timed out after {timeout_seconds}s" if timed_out else
                      f"Godot exited with {exit_code}" if exit_code != 0 else
                      strict_output_failure(output) if spec.strict_output else "")
    status = "passed" if not failure_reason else "failed"
    if status == "failed":
        collect_user_evidence(isolated_user_dir, test_dir / "user_data")
    metadata = {
        "schema": "ysbzs.qa.test-result.v1", "path": spec.path, "args": list(spec.args),
        "engineArgs": list(spec.engine_args), "status": status, "exitCode": exit_code,
        "timedOut": timed_out, "durationSeconds": round(duration, 3),
        "failureReason": failure_reason, "outputTruncated": output_truncated,
        "command": command, "userDataDir": str(isolated_user_dir), "customUserDirName": custom_name,
    }
    import json
    (test_dir / "result.json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + "\n",
                                          encoding="utf-8")
    shutil.rmtree(overlay, ignore_errors=True)
    if not keep_user_data:
        safe_remove_user_data(isolated_user_dir)
    return TestResult(spec, status, exit_code, duration, timed_out, output or "", str(test_dir),
                      str(isolated_user_dir), command, failure_reason)
