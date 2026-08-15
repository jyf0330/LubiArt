#!/usr/bin/env python3
import argparse
import json
from pathlib import Path

from PIL import Image


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--base", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("layers", nargs="+")
    args = parser.parse_args()

    manifest = json.loads(Path(args.manifest).read_text(encoding="utf-8"))
    by_index = {item["index"]: item for item in manifest["layers"] if "index" in item}
    canvas = Image.open(args.base).convert("RGBA")

    for spec in args.layers:
        index_text, image_path = spec.split("=", 1)
        item = by_index[int(index_text)]
        layer = Image.open(image_path).convert("RGBA")
        canvas.alpha_composite(layer, (item["left"], item["top"]))

    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(args.out, quality=94)


if __name__ == "__main__":
    main()
