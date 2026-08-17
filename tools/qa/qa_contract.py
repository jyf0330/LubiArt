"""QA suite contracts, manifest expansion, and executable discovery."""

from __future__ import annotations

import dataclasses
import datetime as dt
import fnmatch
import hashlib
import json
import os
import re
import shutil
import sys
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_MANIFEST = REPO_ROOT / "qa" / "suites.json"
DEFAULT_GODOT_CANDIDATES = (
    Path("/Users/ywh/Downloads/Godot.app/Contents/MacOS/Godot"),
    Path("/Applications/Godot.app/Contents/MacOS/Godot"),
)
USER_DATA_NAMESPACE = "YSBZS_QA"


@dataclasses.dataclass(frozen=True)
class TestSpec:
    path: str
    args: tuple[str, ...] = ()
    engine_args: tuple[str, ...] = ()
    timeout_seconds: int = 180
    display: bool = False
    strict_output: bool = False
    label: str = ""

    @property
    def identity(self) -> str:
        payload = "\0".join((self.path, *self.args, *self.engine_args))
        digest = hashlib.sha1(payload.encode("utf-8")).hexdigest()[:8]
        return f"{slugify(self.label or Path(self.path).stem)}-{digest}"


@dataclasses.dataclass
class TestResult:
    spec: TestSpec
    status: str
    exit_code: int
    duration_seconds: float
    timed_out: bool
    output: str
    evidence_dir: str
    user_data_dir: str
    command: list[str]
    failure_reason: str = ""


def slugify(value: str) -> str:
    value = re.sub(r"[^A-Za-z0-9_.-]+", "-", value.strip())
    return value.strip("-._") or "qa"


def timestamp_id() -> str:
    return dt.datetime.now().astimezone().strftime("%Y%m%d-%H%M%S")


def read_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        value = json.load(handle)
    if not isinstance(value, dict):
        raise ValueError(f"{path} must contain a JSON object")
    return value


def _entry_to_specs(entry: dict[str, Any], root: Path, defaults: dict[str, Any]) -> list[TestSpec]:
    paths: list[str] = []
    if "path" in entry:
        paths = [str(entry["path"])]
    elif "glob" in entry:
        excludes = tuple(str(value) for value in entry.get("exclude", []))
        for candidate in sorted(root.glob(str(entry["glob"]))):
            relative = candidate.relative_to(root).as_posix()
            if candidate.is_file() and not any(fnmatch.fnmatch(relative, item) for item in excludes):
                paths.append(relative)
    else:
        raise ValueError(f"Suite entry needs path, glob, or suite: {entry}")
    return [
        TestSpec(
            path=path,
            args=tuple(str(value) for value in entry.get("args", [])),
            engine_args=tuple(str(value) for value in entry.get("engine_args", [])),
            timeout_seconds=int(entry.get("timeout_seconds", defaults.get("timeout_seconds", 180))),
            display=bool(entry.get("display", defaults.get("display", False))),
            strict_output=bool(entry.get("strict_output", defaults.get("strict_output", False))),
            label=str(entry.get("label", "")),
        )
        for path in paths
    ]


def expand_suite(manifest: dict[str, Any], suite_name: str, root: Path = REPO_ROOT,
                 stack: tuple[str, ...] = ()) -> list[TestSpec]:
    suites = manifest.get("suites", {})
    if suite_name not in suites:
        raise KeyError(f"Unknown QA suite: {suite_name}")
    if suite_name in stack:
        raise ValueError(f"Recursive QA suite: {' -> '.join((*stack, suite_name))}")
    defaults = dict(manifest.get("defaults", {}))
    specs: list[TestSpec] = []
    for raw_entry in suites[suite_name]:
        if not isinstance(raw_entry, dict):
            raise ValueError(f"Invalid entry in {suite_name}: {raw_entry!r}")
        if "suite" in raw_entry:
            specs.extend(expand_suite(manifest, str(raw_entry["suite"]), root, (*stack, suite_name)))
        else:
            specs.extend(_entry_to_specs(raw_entry, root, defaults))
    deduplicated: list[TestSpec] = []
    seen: set[tuple[str, tuple[str, ...], tuple[str, ...], bool]] = set()
    for spec in specs:
        key = (spec.path, spec.args, spec.engine_args, spec.display)
        if key not in seen:
            seen.add(key)
            deduplicated.append(spec)
    return deduplicated


def resolve_godot(explicit: str = "") -> Path:
    candidates = [Path(explicit).expanduser()] if explicit else []
    if os.environ.get("GODOT_BIN", "").strip():
        candidates.append(Path(os.environ["GODOT_BIN"]).expanduser())
    candidates.extend(DEFAULT_GODOT_CANDIDATES)
    executable = shutil.which("godot") or shutil.which("godot4")
    if executable:
        candidates.append(Path(executable))
    for candidate in candidates:
        if candidate.is_file() and os.access(candidate, os.X_OK):
            return candidate.resolve()
    raise FileNotFoundError("Godot executable not found. Pass --godot or set GODOT_BIN.")


def user_data_dir(custom_name: str, platform: str | None = None) -> Path:
    if not custom_name.startswith(f"{USER_DATA_NAMESPACE}/"):
        raise ValueError(f"Unsafe QA user data name: {custom_name}")
    platform = platform or sys.platform
    if platform == "darwin":
        base = Path.home() / "Library" / "Application Support"
    elif platform.startswith("win"):
        base = Path(os.environ.get("APPDATA", ""))
        if not str(base):
            raise RuntimeError("APPDATA is required on Windows")
    else:
        base = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local" / "share"))
    return base.joinpath(*custom_name.split("/"))
