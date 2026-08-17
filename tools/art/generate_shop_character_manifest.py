#!/usr/bin/env python3
"""Build and verify the formal shop-character image generation manifest."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

from PIL import Image


REPO_ROOT = Path(__file__).resolve().parents[2]
ROUTE_PATH = REPO_ROOT / "data/content/generated/013_route.json"
NODE_MAP_PATH = REPO_ROOT / "art/manifests/route/shop/characters/shop_character_node_map_manifest.json"
MANIFEST_PATH = REPO_ROOT / "art/manifests/route/shop/characters/shop_character_generation_manifest.json"
CHARACTER_MAP_PATH = REPO_ROOT / "art/manifests/route/shop/characters/shop_character_map.json"
GENERATED_DIR = REPO_ROOT / "art/images/route/shop/characters/generated"
RESOURCE_PREFIX = "res://art/images/route/shop/characters/generated"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    return parser.parse_args()


def load_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def json_text(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, indent=2) + "\n"


def sha256_json(value: Any) -> str:
    return hashlib.sha256(json_text(value).encode("utf-8")).hexdigest()


def formal_shop_rows() -> list[dict[str, str]]:
    route_package = load_json(ROUTE_PATH)
    for operation in route_package.get("operations", []):
        if operation.get("path") != ["route"]:
            continue
        route = operation.get("value", {})
        return [
            {
                "nodeId": str(node["nodeId"]),
                "name": str(node["name"]),
                "shopPoolId": str(node["shopPoolId"]),
            }
            for node in route.get("node_pool", [])
            if node.get("nodeType") == "shop" and node.get("status") == "正式"
        ]
    raise ValueError("route package does not contain the canonical ['route'] operation")


def build_node_map() -> dict[str, Any]:
    mapped: list[dict[str, Any]] = []
    for index, row in enumerate(formal_shop_rows(), start=1):
        character_id = f"shop_character_{index:03d}"
        mapped.append(
            {
                "index": index,
                **row,
                "path": f"{RESOURCE_PREFIX}/{character_id}.png",
            }
        )
    return {
        "source": "data/content/generated/013_route.json operations[path=['route']].value.node_pool",
        "rule": "all formal shop nodes map by canonical node_pool order to shop_character_001..N",
        "mapped": mapped,
        "unmapped_formal_shop_nodes": [],
    }


def build_character_map(node_map: dict[str, Any]) -> dict[str, str]:
    result: dict[str, str] = {}
    pool_counts: dict[str, int] = {}
    for item in node_map.get("mapped", []):
        pool_id = str(item["shopPoolId"])
        pool_counts[pool_id] = pool_counts.get(pool_id, 0) + 1
    for item in node_map.get("mapped", []):
        index = int(item["index"])
        character_id = f"shop_character_{index:03d}"
        path = str(item["path"])
        result[character_id] = path
        result[str(index)] = path
    for item in node_map.get("mapped", []):
        path = str(item["path"])
        result[str(item["nodeId"])] = path
        result[str(item["name"])] = path
        pool_id = str(item["shopPoolId"])
        if pool_counts[pool_id] == 1:
            result[pool_id] = path
    return result


def existing_reviews() -> dict[str, tuple[str, str]]:
    if not MANIFEST_PATH.is_file():
        return {}
    manifest = load_json(MANIFEST_PATH)
    return {
        str(target.get("character_id", "")): (
            str(target.get("review_status", "pending")),
            str(target.get("review_note", "")),
        )
        for target in manifest.get("targets", [])
    }


def target_rows(node_map: dict[str, Any]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for item in node_map.get("mapped", []):
        rows.append(
            {
                "index": int(item["index"]),
                "node_id": str(item["nodeId"]),
                "name": str(item["name"]),
                "shop_pool_id": str(item["shopPoolId"]),
            }
        )
    next_index = len(rows) + 1
    for item in node_map.get("unmapped_formal_shop_nodes", []):
        rows.append(
            {
                "index": next_index,
                "node_id": str(item["nodeId"]),
                "name": str(item["name"]),
                "shop_pool_id": str(item["shopPoolId"]),
            }
        )
        next_index += 1
    return rows


def image_record(path: Path) -> dict[str, Any]:
    if not path.is_file():
        return {"state": "missing"}
    with Image.open(path) as image:
        rgba = image.convert("RGBA")
        alpha = rgba.getchannel("A")
        bbox = alpha.getbbox()
        return {
            "state": "generated",
            "sha256": sha256_file(path),
            "width": rgba.width,
            "height": rgba.height,
            "mode": "RGBA",
            "has_alpha": True,
            "alpha_bbox": list(bbox) if bbox is not None else None,
            "alpha_values": sorted(set(alpha.getdata())),
        }


def build_manifest(node_map: dict[str, Any]) -> dict[str, Any]:
    reviews = existing_reviews()
    targets: list[dict[str, Any]] = []
    for row in target_rows(node_map):
        index = int(row["index"])
        character_id = f"shop_character_{index:03d}"
        review_status, review_note = reviews.get(character_id, ("pending", ""))
        targets.append(
            {
                "character_id": character_id,
                **row,
                "output_path": f"{RESOURCE_PREFIX}/{character_id}.png",
                "file": image_record(GENERATED_DIR / f"{character_id}.png"),
                "review_status": review_status,
                "review_note": review_note,
            }
        )
    generated = sum(target["file"]["state"] == "generated" for target in targets)
    approved = sum(
        target["file"]["state"] == "generated" and target["review_status"] == "approved"
        for target in targets
    )
    return {
        "schema": "ysbzs.shop-character-generation-manifest.v1",
        "source": "res://data/content/generated/013_route.json",
        "source_node_map": "res://art/manifests/route/shop/characters/shop_character_node_map_manifest.json",
        "source_node_map_sha256": sha256_json(node_map),
        "style_reference": "res://art/images/route/three_choice_psd/route_portrait_shop.png",
        "style_contract": {
            "id": "ysbzs-route-chibi-pixel-v1",
            "required": [
                "compact Q-version merchant with one readable trade identity",
                "visible hard pixel clusters and stair-step contours",
                "dark warm outline and limited flat stepped shading",
                "one complete reusable character on transparency without UI",
            ],
            "forbidden": [
                "smooth painterly, vector, 3D-rendered, or photorealistic surfaces",
                "scenery, stall, card frame, text, logo, watermark, glow, or gradient",
            ],
        },
        "target_count": len(targets),
        "generated_count": generated,
        "approved_count": approved,
        "pending_count": len(targets) - approved,
        "targets": targets,
    }


def validate(manifest: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    targets = manifest.get("targets", [])
    formal_count = len(formal_shop_rows())
    if manifest.get("target_count") != formal_count or len(targets) != formal_count:
        errors.append(f"expected {formal_count} formal shop characters, got {len(targets)}")
    ids = [str(target.get("character_id", "")) for target in targets]
    node_ids = [str(target.get("node_id", "")) for target in targets]
    if len(set(ids)) != len(ids):
        errors.append("duplicate character_id")
    if len(set(node_ids)) != len(node_ids):
        errors.append("duplicate node_id")
    hashes: dict[str, str] = {}
    for target in targets:
        file_record = target.get("file", {})
        if file_record.get("state") != "generated":
            if target.get("review_status") == "approved":
                errors.append(f"approved target is missing: {target.get('character_id')}")
            continue
        if file_record.get("alpha_values") != [0, 255]:
            errors.append(f"non-hard alpha: {target.get('character_id')}")
        digest = str(file_record.get("sha256", ""))
        if digest in hashes:
            errors.append(
                f"duplicate image hash: {hashes[digest]} and {target.get('character_id')}"
            )
        hashes[digest] = str(target.get("character_id", ""))
    return errors


def main() -> int:
    args = parse_args()
    expected_node_map = build_node_map()
    expected_character_map = build_character_map(expected_node_map)
    expected = build_manifest(expected_node_map)
    errors = validate(expected)
    if args.check:
        for path, value, label in [
            (NODE_MAP_PATH, expected_node_map, "node map"),
            (CHARACTER_MAP_PATH, expected_character_map, "character map"),
            (MANIFEST_PATH, expected, "manifest"),
        ]:
            if not path.is_file():
                errors.append(f"{label} missing: {path}")
            elif load_json(path) != value:
                errors.append(f"{label} is stale; run generator without --check")
        if errors:
            for error in errors:
                print(f"SHOP_CHARACTER_MANIFEST_ERROR {error}")
            return 1
        print(
            "SHOP_CHARACTER_MANIFEST_OK "
            f"targets={expected['target_count']} generated={expected['generated_count']} "
            f"approved={expected['approved_count']} pending={expected['pending_count']}"
        )
        return 0
    if errors:
        for error in errors:
            print(f"SHOP_CHARACTER_MANIFEST_ERROR {error}")
        return 1
    for path, value in [
        (NODE_MAP_PATH, expected_node_map),
        (CHARACTER_MAP_PATH, expected_character_map),
        (MANIFEST_PATH, expected),
    ]:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json_text(value), encoding="utf-8")
    print(
        "SHOP_CHARACTER_MANIFEST_WRITTEN "
        f"targets={expected['target_count']} generated={expected['generated_count']} "
        f"approved={expected['approved_count']} pending={expected['pending_count']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
