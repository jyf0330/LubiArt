"""Write deterministic content packages by business domain."""

from __future__ import annotations

import json
import re
import shutil
from pathlib import Path
from typing import Any

SCHEMA = "ysbzs.content-package.v1"


class PackWriter:
    def __init__(self, output: Path) -> None:
        self.output = output
        self.package_count = 0
        self.operation_count = 0
        self.output.mkdir(parents=True, exist_ok=True)

    def emit_domain(self, name: str, value: Any, order: int) -> None:
        self.package_count += 1
        self.operation_count += 1
        slug = _slug(name)
        package = {
            "schema": SCHEMA,
            "package_id": f"generated.{slug}",
            "priority": 0,
            "order": order,
            "operations": [{"op": "set", "path": [name], "value": value}],
        }
        # Generated packages are machine-owned. Compact JSON keeps a large,
        # cohesive domain reviewable as one file without reintroducing
        # line-count shards.
        text = json.dumps(package, ensure_ascii=False, separators=(",", ":")) + "\n"
        (self.output / f"{order:03d}_{slug}.json").write_text(text, encoding="utf-8")


def export_content_pack(data: dict[str, Any], output: Path, extensions: Path) -> tuple[int, int]:
    clean_data = json.loads(json.dumps(data, ensure_ascii=False))
    _strip_extensions(clean_data, extensions)
    temporary = output.with_name(output.name + ".tmp")
    if temporary.exists():
        shutil.rmtree(temporary)
    writer = PackWriter(temporary)
    for order, (key, value) in enumerate(clean_data.items(), start=1):
        writer.emit_domain(str(key), value, order)
    if output.exists():
        shutil.rmtree(output)
    temporary.rename(output)
    return writer.package_count, writer.operation_count


def _slug(value: str) -> str:
    normalized = re.sub(r"[^a-zA-Z0-9_]+", "_", value).strip("_").lower()
    if not normalized:
        raise ValueError(f"content domain has no stable ASCII slug: {value!r}")
    return normalized[:64]


def _value_at(data: dict[str, Any], path: list[str]) -> Any:
    current: Any = data
    for segment in path:
        current = current[segment]
    return current


def _strip_extensions(data: dict[str, Any], extensions: Path) -> None:
    if not extensions.exists():
        return
    for path in sorted(extensions.rglob("*.json")):
        package = json.loads(path.read_text(encoding="utf-8"))
        for operation in package.get("operations", []):
            target_path = [str(value) for value in operation.get("path", [])]
            if operation.get("op") == "set":
                parent = _value_at(data, target_path[:-1])
                if parent.get(target_path[-1]) == operation.get("value"):
                    del parent[target_path[-1]]
            elif operation.get("op") == "attach_unique":
                for entity in _value_at(data, target_path):
                    if entity.get(operation["match_key"]) == operation["match_value"]:
                        values = entity.get(operation["field"], [])
                        if operation.get("value") in values:
                            values.remove(operation["value"])
