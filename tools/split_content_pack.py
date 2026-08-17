#!/usr/bin/env python3
"""Migrate a legacy runtime snapshot into modular content packages."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from content_pack_exporter import export_content_pack


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, default=Path("data/ysbzs_singleplayer_data.json"))
    parser.add_argument("--output", type=Path, default=Path("data/content/generated"))
    parser.add_argument("--extensions", type=Path, default=Path("data/content/extensions"))
    parser.add_argument("--remove-source", action="store_true")
    args = parser.parse_args()
    data = json.loads(args.input.read_text(encoding="utf-8"))
    package_count, operation_count = export_content_pack(data, args.output, args.extensions)
    if args.remove_source:
        args.input.unlink()
    print(
        f"CONTENT_PACK_SPLIT_OK packages={package_count} "
        f"operations={operation_count} output={args.output}"
    )


if __name__ == "__main__":
    main()
