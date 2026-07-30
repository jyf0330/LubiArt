#!/usr/bin/env python3

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageChops


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def compare(before_path: Path, after_path: Path) -> dict:
    with Image.open(before_path) as before_source, Image.open(after_path) as after_source:
        before = before_source.convert("RGBA")
        after = after_source.convert("RGBA")
        same_size = before.size == after.size
        differing_pixels = None
        max_channel_difference = None
        if same_size:
            difference = ImageChops.difference(before, after)
            differing_pixels = sum(1 for pixel in difference.getdata() if pixel != (0, 0, 0, 0))
            extrema = difference.getextrema()
            max_channel_difference = max(channel[1] for channel in extrema)
        identical = same_size and differing_pixels == 0
        return {
            "result": "PASS" if identical else "BLOCKED",
            "identical": identical,
            "before": {
                "path": str(before_path.resolve()),
                "sha256": sha256(before_path),
                "size": list(before.size),
            },
            "after": {
                "path": str(after_path.resolve()),
                "sha256": sha256(after_path),
                "size": list(after.size),
            },
            "same_size": same_size,
            "differing_pixels": differing_pixels,
            "max_channel_difference": max_channel_difference,
        }


def main() -> int:
    parser = argparse.ArgumentParser(description="Require two screenshots to be pixel-identical.")
    parser.add_argument("before", type=Path)
    parser.add_argument("after", type=Path)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()

    for path in (args.before, args.after):
        if not path.is_file():
            parser.error(f"screenshot does not exist: {path}")

    result = compare(args.before, args.after)
    output = json.dumps(result, ensure_ascii=False, indent=2)
    print(output)
    if args.report is not None:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(output + "\n", encoding="utf-8")
    return 0 if result["identical"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
