#!/usr/bin/env python3
import argparse
import json
import re
import struct
from pathlib import Path

from PIL import Image


def read(fmt, data, off):
    size = struct.calcsize(fmt)
    return struct.unpack(fmt, data[off:off + size]), off + size


def pad4(n):
    return (n + 3) & ~3


def read_pascal(data, off):
    if off >= len(data):
        return "", off
    length = data[off]
    start = off + 1
    raw = data[start:start + length]
    end = off + pad4(1 + length)
    return raw.decode("macroman", errors="replace"), end


def decode_packbits_row(row):
    out = bytearray()
    i = 0
    while i < len(row):
        n = row[i]
        i += 1
        if n <= 127:
            count = n + 1
            out.extend(row[i:i + count])
            i += count
        elif n >= 129:
            count = 257 - n
            if i < len(row):
                out.extend([row[i]] * count)
            i += 1
        # 128 is noop.
    return bytes(out)


def decode_channel(payload, width, height):
    if width <= 0 or height <= 0:
        return b""
    if len(payload) < 2:
        return bytes([0] * width * height)
    compression = struct.unpack(">H", payload[:2])[0]
    if compression == 0:
        raw = payload[2:2 + width * height]
        return raw.ljust(width * height, b"\x00")
    if compression != 1:
        return bytes([0] * width * height)

    counts_off = 2
    counts_len = height * 2
    counts = [
        struct.unpack(">H", payload[counts_off + i * 2:counts_off + i * 2 + 2])[0]
        for i in range(height)
    ]
    pos = counts_off + counts_len
    rows = []
    for count in counts:
        encoded = payload[pos:pos + count]
        pos += count
        row = decode_packbits_row(encoded)[:width]
        rows.append(row.ljust(width, b"\x00"))
    return b"".join(rows)


def safe_name(index, name):
    cleaned = re.sub(r"[^\w\-. \u4e00-\u9fff]+", "_", name).strip(" ._")
    return f"{index:03d}_{cleaned or 'layer'}"


def parse_additional_blocks(data, off, end):
    blocks = {}
    section_type = None
    while off + 12 <= end:
        sig = data[off:off + 4]
        key = data[off + 4:off + 8]
        off += 8
        length = struct.unpack(">I", data[off:off + 4])[0]
        off += 4
        body = data[off:off + length]
        off += pad4(length)
        if sig not in (b"8BIM", b"8B64"):
            continue
        key_s = key.decode("latin1", errors="replace")
        if key_s == "luni" and len(body) >= 4:
            chars = struct.unpack(">I", body[:4])[0]
            raw = body[4:4 + chars * 2]
            blocks["unicode_name"] = raw.decode("utf-16-be", errors="replace")
        elif key_s in ("lsct", "lsdk") and len(body) >= 4:
            section_type = struct.unpack(">I", body[:4])[0]
            blocks["section_type"] = section_type
    return blocks


def parse_psd(path):
    data = Path(path).read_bytes()
    off = 0
    if data[:4] != b"8BPS":
        raise ValueError("Not a PSD/PSB file")
    off = 4
    (version,), off = read(">H", data, off)
    off += 6
    (channels, height, width, depth, color_mode), off = read(">HIIHH", data, off)
    if version != 1:
        raise ValueError("Only PSD is supported by this lightweight parser")
    if depth != 8 or color_mode != 3:
        raise ValueError(f"Only 8-bit RGB PSD is supported, got depth={depth}, mode={color_mode}")

    (color_len,), off = read(">I", data, off)
    off += color_len
    (resources_len,), off = read(">I", data, off)
    off += resources_len
    (layer_mask_len,), off = read(">I", data, off)
    layer_mask_start = off
    layer_mask_end = off + layer_mask_len
    if layer_mask_len == 0:
        return {"width": width, "height": height, "channels": channels, "layers": [], "data": data}

    (layer_info_len,), off = read(">I", data, off)
    layer_info_end = off + layer_info_len
    if layer_info_len == 0:
        return {"width": width, "height": height, "channels": channels, "layers": [], "data": data}

    (layer_count_raw,), off = read(">h", data, off)
    layer_count = abs(layer_count_raw)
    layers = []
    for i in range(layer_count):
        (top, left, bottom, right, ch_count), off = read(">iiiiH", data, off)
        channel_info = []
        for _ in range(ch_count):
            (ch_id, ch_len), off = read(">hI", data, off)
            channel_info.append({"id": ch_id, "length": ch_len})
        blend_sig = data[off:off + 4]
        blend_key = data[off + 4:off + 8]
        off += 8
        (opacity, clipping, flags, filler), off = read(">BBBB", data, off)
        (extra_len,), off = read(">I", data, off)
        extra_start = off
        extra_end = off + extra_len

        (mask_len,), off = read(">I", data, off)
        off += mask_len
        (blend_ranges_len,), off = read(">I", data, off)
        off += blend_ranges_len
        name, off = read_pascal(data, off)
        blocks = parse_additional_blocks(data, off, extra_end)
        off = extra_end

        section_type = blocks.get("section_type")
        kind = {
            1: "folder_open",
            2: "folder_closed",
            3: "bounding_section_divider",
        }.get(section_type, "layer")
        layers.append({
            "index": i,
            "name": blocks.get("unicode_name") or name,
            "top": top,
            "left": left,
            "bottom": bottom,
            "right": right,
            "width": max(0, right - left),
            "height": max(0, bottom - top),
            "visible": not bool(flags & 0x02),
            "opacity": opacity,
            "blend_mode": blend_key.decode("latin1", errors="replace"),
            "kind": kind,
            "channels": channel_info,
        })

    pixel_off = off
    for layer in layers:
        for ch in layer["channels"]:
            ch["offset"] = pixel_off
            pixel_off += ch["length"]

    return {
        "width": width,
        "height": height,
        "channels": channels,
        "layers": layers,
        "layer_info_end": layer_info_end,
        "layer_mask_start": layer_mask_start,
        "layer_mask_end": layer_mask_end,
        "data": data,
    }


def export_layers(psd, out_dir):
    out_dir.mkdir(parents=True, exist_ok=True)
    data = psd["data"]
    manifest = []
    for layer in psd["layers"]:
        if layer["kind"] != "layer" or layer["width"] <= 0 or layer["height"] <= 0:
            manifest.append({k: v for k, v in layer.items() if k != "channels"})
            continue
        w, h = layer["width"], layer["height"]
        channels = {}
        for ch in layer["channels"]:
            payload = data[ch["offset"]:ch["offset"] + ch["length"]]
            channels[ch["id"]] = decode_channel(payload, w, h)
        r = channels.get(0, bytes([0] * w * h))
        g = channels.get(1, r)
        b = channels.get(2, r)
        a = channels.get(-1, bytes([255] * w * h))
        rgba = bytearray(w * h * 4)
        rgba[0::4] = r
        rgba[1::4] = g
        rgba[2::4] = b
        rgba[3::4] = a
        image = Image.frombytes("RGBA", (w, h), bytes(rgba))
        filename = safe_name(layer["index"], layer["name"]) + ".png"
        image.save(out_dir / filename)
        item = {k: v for k, v in layer.items() if k != "channels"}
        item["file"] = filename
        manifest.append(item)
    (out_dir / "manifest.json").write_text(json.dumps({
        "canvas": {"width": psd["width"], "height": psd["height"]},
        "layers": manifest,
    }, ensure_ascii=False, indent=2), encoding="utf-8")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("psd")
    parser.add_argument("--out")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    psd = parse_psd(args.psd)
    report = {
        "width": psd["width"],
        "height": psd["height"],
        "channels": psd["channels"],
        "layer_count": len(psd["layers"]),
        "layers": [{k: v for k, v in layer.items() if k != "channels"} for layer in psd["layers"]],
    }
    if args.out:
        export_layers(psd, Path(args.out))
    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print(f"{psd['width']}x{psd['height']}, layers={len(psd['layers'])}")
        for layer in psd["layers"]:
            hidden = "" if layer["visible"] else " hidden"
            print(f"{layer['index']:03d} {layer['kind']:<24} {layer['width']:4d}x{layer['height']:<4d} {layer['name']}{hidden}")


if __name__ == "__main__":
    main()
