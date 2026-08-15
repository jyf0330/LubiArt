#!/usr/bin/env python3
import argparse
from pathlib import Path

from PIL import Image


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("input")
    parser.add_argument("output")
    parser.add_argument("--width", type=int, required=True)
    parser.add_argument("--height", type=int, required=True)
    parser.add_argument("--fill", type=float, default=0.92)
    args = parser.parse_args()

    image = Image.open(args.input).convert("RGBA")
    bbox = image.getbbox()
    if bbox:
        image = image.crop(bbox)

    max_w = max(1, int(args.width * args.fill))
    max_h = max(1, int(args.height * args.fill))
    image.thumbnail((max_w, max_h), Image.Resampling.NEAREST)

    canvas = Image.new("RGBA", (args.width, args.height), (0, 0, 0, 0))
    canvas.alpha_composite(image, ((args.width - image.width) // 2, (args.height - image.height) // 2))
    Path(args.output).parent.mkdir(parents=True, exist_ok=True)
    canvas.save(args.output)


if __name__ == "__main__":
    main()
