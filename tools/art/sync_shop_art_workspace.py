#!/usr/bin/env python3
"""Audited two-way sync for the independent shop art workspace.

The outbound half exports public presentation data and only the PNG closure
needed by that data. The inbound half accepts only the explicitly allowlisted
art-owned shop PNGs. No Scene, script, Session, save, or authority file can
cross from the art workspace into the formal project.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import struct
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath
from typing import Any


SCHEMA = "ysbzs.shop-art-workspace-sync.v1"
CAPTURE_SCHEMA = "ysbzs.public-shop-art-capture.v1"
MAX_ART_REFERENCE_PETS = 16
ART_MANIFEST_PATH = Path("art/manifests/shop/formal_sync_manifest.json")
ART_RESOURCE_INVENTORY_PATH = Path("art/manifests/shop/formal_resource_inventory.json")
ART_PREVIEW_PATH = Path("data/formal_shop_art_preview.json")
ART_RUNTIME_PATH = Path("data/formal_shop_art_runtime.json")
PET_MAP_PATH = Path("art/manifests/shared/pets/sheets/pet_id_map.json")
MERCHANT_MAP_PATH = Path("art/manifests/shop/merchant_map.json")
FORMAL_PET_MAP_PATH = Path("art/manifests/shared/pets/sheets/pet_id_map.json")
FORMAL_MERCHANT_MAP_PATH = Path("art/manifests/route/shop/characters/shop_character_map.json")
FORMAL_PET_FALLBACK_PATH = Path("art/images/shared/pets/sheets/slices/pal_042.png")
SHOP_ART_ROOT = Path("art/images/shop/screen_shop_godot_v1")
RETURN_ART_MAPPINGS = tuple(
    (SHOP_ART_ROOT / name, SHOP_ART_ROOT / name)
    for name in (
        "background.png",
        "shop_facade.png",
        "merchant_default.png",
        "refresh_curtain.png",
        "refresh_bell_normal.png",
        "refresh_bell_hover.png",
        "shared_party_shadow.png",
    )
) + (
    (
        Path("art/images/route/three_choice_psd/bag_closed.png"),
        SHOP_ART_ROOT / "shared_bag_closed.png",
    ),
    (
        Path("art/images/route/three_choice_psd/bag_open_full.png"),
        SHOP_ART_ROOT / "shared_bag_open.png",
    ),
    (
        Path("art/images/route/three_choice_psd/bag_inventory_base.png"),
        SHOP_ART_ROOT / "shared_bag_inventory.png",
    ),
    (
        Path("art/images/route/three_choice_psd/bag_item_highlight.png"),
        SHOP_ART_ROOT / "shared_bag_item_highlight.png",
    ),
    (
        Path("art/images/route/three_choice_psd/party_shelf.png"),
        SHOP_ART_ROOT / "shared_party_shelf.png",
    ),
    (
        Path("art/images/route/three_choice_psd/coin_panel_static.png"),
        SHOP_ART_ROOT / "shared_coin_panel.png",
    ),
    (
        Path("art/images/route/three_choice_psd/exit_normal.png"),
        SHOP_ART_ROOT / "shared_exit_normal.png",
    ),
    (
        Path("art/images/route/three_choice_psd/exit_hover.png"),
        SHOP_ART_ROOT / "shared_exit_hover.png",
    ),
)

# The art workspace keeps the complete public capture as an audited reference,
# while its runnable Mock receives only fields consumed by the route/shop
# presentation. This prevents unrelated battle, catalog, run-plan, and trace
# payloads from silently becoming a second runtime authority.
ART_RUNTIME_SNAPSHOT_KEYS = (
    "phase",
    "day",
    "node_index",
    "nodeIndex",
    "coins",
    "hero_hp",
    "heroHp",
    "hero_max_hp",
    "heroMaxHp",
    "ap",
    "difficulty",
    "economy_multiplier",
    "economyMultiplier",
    "max_route_day",
    "active_stall",
    "active_shop_pool",
    "active_shop_seed_context",
    "route_options",
    "route_events",
    "route_effects",
    "shop_offers",
    "shop_refresh",
    "shop_free_rolls",
    "shop_next_discount",
    "shop_paid_refreshes",
    "shop_roll_count",
    "shop_context_roll_count",
    "shop_seed_audit",
    "shop_events",
    "shop_event_effects",
    "shop_seen_pet_ids",
    "shop_seen_pet_ids_by_day",
    "inventory",
    "roster",
    "last_command_result",
    "lastCommandResult",
    "state_version",
    "stateVersion",
    "state_hash",
    "stateHash",
    "source",
)


class SyncError(RuntimeError):
    pass


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def json_load(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise SyncError(f"cannot read JSON {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise SyncError(f"JSON root must be an object: {path}")
    return value


def json_write(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def json_write_compact(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(value, ensure_ascii=False, separators=(",", ":")) + "\n",
        encoding="utf-8",
    )


def art_runtime_snapshot(snapshot: dict[str, Any]) -> dict[str, Any]:
    """Project a public formal Snapshot onto the art runtime's read boundary."""
    return {
        key: snapshot[key]
        for key in ART_RUNTIME_SNAPSHOT_KEYS
        if key in snapshot
    }


def art_runtime_capture(capture: dict[str, Any]) -> dict[str, Any]:
    projected: dict[str, Any] = {
        "schema": capture.get("schema", ""),
        "source": capture.get("source", {}),
        "operations": capture.get("operations", []),
        "runtime_projection_keys": list(ART_RUNTIME_SNAPSHOT_KEYS),
    }
    for key in (
        "route_snapshot",
        "shop_snapshot",
        "refreshed_snapshot",
        "purchased_snapshot",
        "second_purchased_snapshot",
        "party_full_snapshot",
        "paid_refreshed_snapshot",
        "bag_purchased_snapshot",
        "exit_snapshot",
        "reentered_snapshot",
    ):
        value = capture.get(key, {})
        if not isinstance(value, dict):
            raise SyncError(f"capture {key} must be an object")
        projected[key] = art_runtime_snapshot(value)
    replay_snapshots = capture.get("replay_snapshots", {})
    if not isinstance(replay_snapshots, dict):
        raise SyncError("capture replay_snapshots must be an object")
    projected["replay_snapshots"] = {
        str(key): art_runtime_snapshot(value)
        for key, value in replay_snapshots.items()
        if isinstance(value, dict)
    }
    for raw_operation in projected["operations"]:
        if not isinstance(raw_operation, dict):
            raise SyncError("capture operations must contain objects")
        snapshot_key = str(raw_operation.get("snapshot_key", ""))
        if snapshot_key and snapshot_key not in projected["replay_snapshots"]:
            raise SyncError(f"capture operation references missing replay snapshot: {snapshot_key}")
    return projected


def git_head(root: Path) -> str:
    result = subprocess.run(
        ["git", "-C", str(root), "rev-parse", "HEAD"],
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def normalized_relative(value: str) -> Path:
    posix = PurePosixPath(value)
    if posix.is_absolute() or ".." in posix.parts or not posix.parts:
        raise SyncError(f"unsafe relative path: {value!r}")
    return Path(*posix.parts)


def resource_relative(value: str) -> Path:
    if not value.startswith("res://"):
        raise SyncError(f"resource path must start with res://: {value}")
    return normalized_relative(value.removeprefix("res://"))


def mapped_png_hashes(root: Path, mapping: dict[str, Any]) -> set[str]:
    hashes: set[str] = set()
    for raw_resource in mapping.values():
        resource = str(raw_resource)
        if not resource.startswith("res://") or not resource.lower().endswith(".png"):
            continue
        path = root / resource_relative(resource)
        if path.is_file():
            hashes.add(sha256(path))
    return hashes


def png_info(path: Path) -> dict[str, Any]:
    data = path.read_bytes()[:29]
    if len(data) < 29 or data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        raise SyncError(f"not a valid PNG: {path}")
    width, height = struct.unpack(">II", data[16:24])
    color_type = data[25]
    return {
        "width": width,
        "height": height,
        "has_alpha": color_type in (4, 6),
    }


def file_record(source_path: Path, source: Path, target: Path, owner: str) -> dict[str, Any]:
    record = {
        "source": source.as_posix(),
        "target": target.as_posix(),
        "owner": owner,
    }
    if source.suffix.lower() == ".png":
        record.update(png_info(source_path))
    return record


def shop_route_option(snapshot: dict[str, Any], preferred: str) -> dict[str, Any]:
    first: dict[str, Any] = {}
    for raw in snapshot.get("route_options", []):
        if not isinstance(raw, dict):
            continue
        if str(raw.get("kind", raw.get("nodeType", ""))) != "shop":
            continue
        if not first:
            first = raw
        identity = str(raw.get("id", raw.get("option_id", "")))
        if identity == preferred:
            return raw
    return first


def identity_candidates(value: dict[str, Any]) -> list[str]:
    result: list[str] = []
    for source in (value, value.get("sourceNode", {}), value.get("source_node", {})):
        if not isinstance(source, dict):
            continue
        for key in ("nodeId", "node_id", "id", "shopPoolId", "shop_pool_id", "name", "label"):
            item = str(source.get(key, "")).strip()
            if item and item not in result:
                result.append(item)
    return result


def prepare(args: argparse.Namespace) -> None:
    formal_root = args.formal_root.resolve()
    art_root = args.art_root.resolve()
    bundle = args.bundle_dir.resolve()
    capture_path = args.capture.resolve()
    capture = json_load(capture_path)
    if capture.get("schema") != CAPTURE_SCHEMA:
        raise SyncError(f"unexpected capture schema: {capture.get('schema')!r}")
    route_snapshot = capture.get("route_snapshot")
    if not isinstance(route_snapshot, dict):
        raise SyncError("capture route_snapshot is missing")

    formal_pet_map = json_load(formal_root / FORMAL_PET_MAP_PATH).get("by_pet_id", {})
    if not isinstance(formal_pet_map, dict):
        raise SyncError("formal pet_id_map.by_pet_id is missing")
    formal_merchant_map = json_load(formal_root / FORMAL_MERCHANT_MAP_PATH)
    art_pet_map_document = json_load(art_root / PET_MAP_PATH)
    art_pet_map = art_pet_map_document.get("by_pet_id", {})
    if not isinstance(art_pet_map, dict):
        raise SyncError("art pet_id_map.by_pet_id is missing")
    selected_option_id = str(capture.get("source", {}).get("selected_option_id", ""))
    selected_option = shop_route_option(route_snapshot, selected_option_id)
    if not selected_option:
        raise SyncError("capture has no selected shop route option")

    referenced_pet_ids: list[str] = []
    # Close over images used by the recorded operations first. Route snapshots
    # may expose a much larger candidate pool and must not starve visible shop
    # and refresh records when the bounded art bundle is assembled.
    replay_snapshots = capture.get("replay_snapshots", {})
    if not isinstance(replay_snapshots, dict):
        raise SyncError("capture replay_snapshots must be an object")
    visible_snapshots = list(replay_snapshots.values()) + [route_snapshot]
    for snapshot in visible_snapshots:
        if not isinstance(snapshot, dict):
            continue
        # Roster pets are visible on the shared lower rail in every captured
        # shop operation, so their images are part of the visual closure too.
        for raw in snapshot.get("roster", []):
            if not isinstance(raw, dict):
                continue
            pet_id = str(raw.get("pet_id", raw.get("petId", raw.get("id", "")))).strip()
            if pet_id and pet_id not in referenced_pet_ids:
                referenced_pet_ids.append(pet_id)
        for raw in snapshot.get("shop_offers", []):
            if not isinstance(raw, dict):
                continue
            pet_id = str(raw.get("pet_id", raw.get("petId", ""))).strip()
            if pet_id and pet_id not in referenced_pet_ids:
                referenced_pet_ids.append(pet_id)
    referenced_pet_ids = referenced_pet_ids[:MAX_ART_REFERENCE_PETS]
    if len(referenced_pet_ids) < 3:
        raise SyncError("capture references fewer than three pet images")

    outbound_files: list[dict[str, Any]] = []
    pet_updates: dict[str, str] = {}
    for pet_id in referenced_pet_ids:
        resource_path = str(formal_pet_map.get(pet_id, ""))
        used_missing_mapping_fallback = not resource_path
        if used_missing_mapping_fallback:
            resource_path = "res://" + FORMAL_PET_FALLBACK_PATH.as_posix()
        source_rel = resource_relative(resource_path)
        source = formal_root / source_rel
        if not source.is_file():
            raise SyncError(f"missing formal pet image for {pet_id}: {source_rel}")
        target_rel = Path("art/images/formal_sync/shop/pets") / f"{pet_id}.png"
        record = file_record(source, source_rel, target_rel, "formal_reference")
        record["sha256"] = sha256(source)
        record["asset_id"] = pet_id
        record["missing_mapping_fallback"] = used_missing_mapping_fallback
        outbound_files.append(record)
        pet_updates[pet_id] = "res://" + target_rel.as_posix()

    merchant_resource = ""
    merchant_identity = ""
    for candidate in identity_candidates(selected_option):
        mapped = str(formal_merchant_map.get(candidate, ""))
        if mapped:
            merchant_identity = candidate
            merchant_resource = mapped
            break
    if not merchant_resource:
        raise SyncError(f"selected shop has no formal merchant image mapping: {identity_candidates(selected_option)}")
    merchant_source_rel = resource_relative(merchant_resource)
    merchant_source = formal_root / merchant_source_rel
    if not merchant_source.is_file():
        raise SyncError(f"missing formal merchant image: {merchant_source_rel}")
    merchant_target_rel = Path("art/images/formal_sync/shop/merchants") / merchant_source.name
    merchant_record = file_record(merchant_source, merchant_source_rel, merchant_target_rel, "formal_reference")
    merchant_record["sha256"] = sha256(merchant_source)
    merchant_record["asset_id"] = merchant_identity
    outbound_files.append(merchant_record)
    merchant_updates = {
        candidate: "res://" + merchant_target_rel.as_posix()
        for candidate in identity_candidates(selected_option)
    }

    current_pet_ids = set(referenced_pet_ids)
    protected_other_sync_pet_ids: set[str] = set()
    for other_manifest_path in (art_root / "art/manifests").glob("*/formal_sync_manifest.json"):
        if other_manifest_path.resolve() == (art_root / ART_MANIFEST_PATH).resolve():
            continue
        other_manifest = json_load(other_manifest_path)
        for raw in other_manifest.get("outbound_files", []):
            if not isinstance(raw, dict):
                continue
            target = str(raw.get("target", ""))
            asset_id = str(raw.get("asset_id", ""))
            if target.startswith("art/images/formal_sync/shop/pets/") and asset_id:
                protected_other_sync_pet_ids.add(asset_id)
    art_sync_pet_dir = art_root / "art/images/formal_sync/shop/pets"
    existing_synced_pet_ids = sorted(
        path.stem for path in art_sync_pet_dir.glob("*.png") if path.is_file()
    )
    stale_synced_pet_ids = sorted(
        set(existing_synced_pet_ids) - current_pet_ids - protected_other_sync_pet_ids
    )
    stale_pet_map_ids = sorted(
        pet_id
        for pet_id, resource in art_pet_map.items()
        if str(resource).startswith("res://art/images/formal_sync/shop/pets/")
        and pet_id not in current_pet_ids
        and pet_id not in protected_other_sync_pet_ids
    )
    fallback_pet_ids = sorted(
        str(record["asset_id"])
        for record in outbound_files
        if bool(record.get("missing_mapping_fallback", False))
    )
    formal_pet_resources = {
        str(resource)
        for resource in formal_pet_map.values()
        if str(resource).startswith("res://") and str(resource).lower().endswith(".png")
    }
    formal_merchant_resources = {
        str(resource)
        for resource in formal_merchant_map.values()
        if str(resource).startswith("res://") and str(resource).lower().endswith(".png")
    }
    formal_pet_hashes = mapped_png_hashes(formal_root, formal_pet_map)
    formal_merchant_hashes = mapped_png_hashes(formal_root, formal_merchant_map)
    art_png_hashes = {
        sha256(path)
        for path in (art_root / "art").rglob("*.png")
        if path.is_file()
    }
    matching_formal_pet_hashes = formal_pet_hashes & art_png_hashes
    matching_formal_merchant_hashes = formal_merchant_hashes & art_png_hashes
    contains_all_formal_program_images = (
        formal_pet_hashes <= art_png_hashes
        and formal_merchant_hashes <= art_png_hashes
    )
    return_files: list[dict[str, Any]] = []
    for source_relative, target_relative in RETURN_ART_MAPPINGS:
        formal_path = formal_root / target_relative
        art_path = art_root / source_relative
        if not art_path.is_file():
            raise SyncError(f"art return source is missing: {source_relative}")
        art_info = png_info(art_path)
        target_existed = formal_path.is_file()
        if target_existed and png_info(formal_path) != art_info:
            raise SyncError(
                f"return asset geometry differs before sync: {source_relative} -> {target_relative}"
            )
        return_files.append({
            "source": source_relative.as_posix(),
            "target": target_relative.as_posix(),
            "owner": "art_owned",
            "formal_target_existed": target_existed,
            "formal_baseline_sha256": sha256(formal_path) if target_existed else "",
            "art_baseline_sha256": sha256(art_path),
            **art_info,
        })

    inventory = {
        "schema": "ysbzs.shop-formal-resource-inventory.v1",
        "formal_commit": git_head(formal_root),
        "art_commit_before_sync": git_head(art_root),
        "fixed_seed": str(capture.get("source", {}).get("run_seed", "")),
        "formal_image_universe": {
            "pet_identity_mappings": len(formal_pet_map),
            "unique_pet_png_resources": len(formal_pet_resources),
            "merchant_identity_mappings": len(formal_merchant_map),
            "unique_merchant_png_resources": len(formal_merchant_resources),
        },
        "fixed_seed_visible_closure": {
            "pet_ids": referenced_pet_ids,
            "pet_count": len(referenced_pet_ids),
            "merchant_ids": [merchant_identity],
            "merchant_count": 1,
            "outbound_png_count": len(outbound_files),
            "file_closure_complete": True,
            "identity_art_complete": not fallback_pet_ids,
        },
        "missing_real_art": [
            {
                "asset_id": pet_id,
                "reason": "missing_formal_pet_mapping",
                "fallback_source": "res://" + FORMAL_PET_FALLBACK_PATH.as_posix(),
            }
            for pet_id in fallback_pet_ids
        ],
        "art_workspace_before_sync": {
            "all_pet_identity_mappings": len(art_pet_map),
            "matching_formal_pet_png_resources": len(matching_formal_pet_hashes),
            "missing_formal_pet_png_resources": len(formal_pet_hashes - art_png_hashes),
            "matching_formal_merchant_png_resources": len(matching_formal_merchant_hashes),
            "missing_formal_merchant_png_resources": len(formal_merchant_hashes - art_png_hashes),
            "formal_sync_pet_png_ids": existing_synced_pet_ids,
            "stale_formal_sync_pet_png_ids": stale_synced_pet_ids,
            "stale_formal_sync_pet_mapping_ids": stale_pet_map_ids,
            "protected_by_other_sync_pet_ids": sorted(protected_other_sync_pet_ids),
        },
        "art_to_formal_allowlist": {
            "png_count": len(return_files),
            "targets": [str(item["target"]) for item in return_files],
            "copied_code_files": 0,
        },
        "verdict": {
            "contains_all_formal_program_images": contains_all_formal_program_images,
            "contains_current_fixed_seed_file_closure": True,
            "contains_current_fixed_seed_identity_art": not fallback_pet_ids,
        },
    }

    bundle.mkdir(parents=True, exist_ok=True)
    preview_bundle_path = bundle / ART_PREVIEW_PATH
    preview_bundle_path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(capture_path, preview_bundle_path)
    for record in outbound_files:
        source = formal_root / normalized_relative(str(record["source"]))
        destination = bundle / normalized_relative(str(record["target"]))
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)
    json_write(bundle / ART_RESOURCE_INVENTORY_PATH, inventory)
    json_write(formal_root / ART_RESOURCE_INVENTORY_PATH, inventory)

    preconditions = {
        "art_pet_map_sha256": sha256(art_root / PET_MAP_PATH),
        "art_merchant_map_sha256": sha256(art_root / MERCHANT_MAP_PATH),
    }
    manifest = {
        "schema": SCHEMA,
        "direction": "formal_to_art_then_art_to_formal",
        "formal_commit": git_head(formal_root),
        "art_commit": git_head(art_root),
        "capture_sha256": sha256(capture_path),
        "display_only": True,
        "forbidden_inbound_types": ["gd", "tscn", "tres", "save", "session", "authority"],
        "outbound_files": outbound_files,
        "pet_map_updates": pet_updates,
        "merchant_map_updates": merchant_updates,
        "return_files": return_files,
        "resource_inventory": ART_RESOURCE_INVENTORY_PATH.as_posix(),
        "resource_inventory_sha256": sha256(bundle / ART_RESOURCE_INVENTORY_PATH),
        "pet_map_removals": stale_pet_map_ids,
        "preconditions": preconditions,
    }
    json_write(bundle / ART_MANIFEST_PATH, manifest)
    print(
        "SHOP_ART_SYNC_PREPARE_OK "
        f"pets={len(pet_updates)} merchants=1 return_assets={len(return_files)} "
        f"fallbacks={len(fallback_pet_ids)} stale={len(stale_synced_pet_ids)} bundle={bundle}"
    )


def checked_copy(source: Path, target: Path, expected_sha: str) -> str:
    actual = sha256(source)
    if actual != expected_sha:
        raise SyncError(f"bundle file hash mismatch: {source}")
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)
    copied = sha256(target)
    if copied != expected_sha:
        raise SyncError(f"copied file hash mismatch: {target}")
    return copied


def apply_outbound(args: argparse.Namespace) -> None:
    art_root = args.art_root.resolve()
    bundle = args.bundle_dir.resolve()
    manifest = json_load(bundle / ART_MANIFEST_PATH)
    if manifest.get("schema") != SCHEMA:
        raise SyncError("unexpected sync manifest schema")
    previous_path = art_root / ART_MANIFEST_PATH
    previous = json_load(previous_path) if previous_path.is_file() else {}
    previous_by_target = {
        str(item.get("target", "")): item
        for item in previous.get("outbound_files", [])
        if isinstance(item, dict)
    }
    receipt_files: list[dict[str, Any]] = []
    for raw in manifest.get("outbound_files", []):
        if not isinstance(raw, dict):
            raise SyncError("outbound manifest entry must be an object")
        source_rel = normalized_relative(str(raw.get("target", "")))
        target_rel = normalized_relative(str(raw.get("target", "")))
        source = bundle / source_rel
        target = art_root / target_rel
        expected = str(raw.get("sha256", ""))
        before = sha256(target) if target.is_file() else ""
        prior = previous_by_target.get(target_rel.as_posix(), {})
        prior_applied = str(prior.get("applied_sha256", prior.get("sha256", "")))
        if before and before != expected and (not prior_applied or before != prior_applied):
            raise SyncError(f"FILE_CONFLICT_STOP: art reference changed outside sync: {target_rel}")
        after = checked_copy(source, target, expected)
        raw["applied_sha256"] = after
        receipt_files.append({"path": target_rel.as_posix(), "before": before, "after": after})

    capture_source = bundle / ART_PREVIEW_PATH
    capture = json_load(capture_source)
    if sha256(capture_source) != str(manifest.get("capture_sha256", "")):
        raise SyncError("public shop capture hash mismatch")
    preview_target = art_root / ART_PREVIEW_PATH
    preview_before = sha256(preview_target) if preview_target.is_file() else ""
    checked_copy(capture_source, preview_target, str(manifest["capture_sha256"]))

    inventory_rel = normalized_relative(str(manifest.get("resource_inventory", "")))
    inventory_source = bundle / inventory_rel
    inventory_target = art_root / inventory_rel
    inventory_expected = str(manifest.get("resource_inventory_sha256", ""))
    if not inventory_expected:
        raise SyncError("resource inventory hash is missing")
    inventory_before = sha256(inventory_target) if inventory_target.is_file() else ""
    checked_copy(inventory_source, inventory_target, inventory_expected)

    preconditions = manifest.get("preconditions", {})
    runtime_capture = art_runtime_capture(capture)
    runtime_document = {
        "schema": "ysbzs.shop-art-runtime-projection.v1",
        "presentation_bootstrap_snapshot": runtime_capture["route_snapshot"],
        "shop_art_capture": runtime_capture,
        "presentation_source": {
            "schema": CAPTURE_SCHEMA,
            "formal_commit": manifest.get("formal_commit", ""),
            "capture_sha256": manifest.get("capture_sha256", ""),
            "selected_option_id": capture.get("source", {}).get("selected_option_id", ""),
            "display_only": True,
            "runtime_projection_keys": list(ART_RUNTIME_SNAPSHOT_KEYS),
        },
    }
    runtime_path = art_root / ART_RUNTIME_PATH
    runtime_before = sha256(runtime_path) if runtime_path.is_file() else ""
    json_write_compact(runtime_path, runtime_document)

    pet_map_path = art_root / PET_MAP_PATH
    if sha256(pet_map_path) != str(preconditions.get("art_pet_map_sha256", "")):
        raise SyncError("FILE_CONFLICT_STOP: Mock pet map changed after prepare")
    pet_map = json_load(pet_map_path)
    by_pet_id = pet_map.setdefault("by_pet_id", {})
    if not isinstance(by_pet_id, dict):
        raise SyncError("Mock pet map by_pet_id is invalid")
    for pet_id in manifest.get("pet_map_removals", []):
        resource = str(by_pet_id.get(str(pet_id), ""))
        if resource and not resource.startswith("res://art/images/formal_sync/shop/pets/"):
            raise SyncError(f"FILE_CONFLICT_STOP: refusing to remove art-owned pet mapping: {pet_id}")
        by_pet_id.pop(str(pet_id), None)
    by_pet_id.update(manifest.get("pet_map_updates", {}))
    json_write(pet_map_path, pet_map)

    merchant_map_path = art_root / MERCHANT_MAP_PATH
    if sha256(merchant_map_path) != str(preconditions.get("art_merchant_map_sha256", "")):
        raise SyncError("FILE_CONFLICT_STOP: Mock merchant map changed after prepare")
    merchant_map = json_load(merchant_map_path)
    variants = merchant_map.setdefault("variants", {})
    if not isinstance(variants, dict):
        raise SyncError("Mock merchant map variants is invalid")
    variants.update(manifest.get("merchant_map_updates", {}))
    merchant_map["status"] = "formal_reference_sync_active"
    json_write(merchant_map_path, merchant_map)

    manifest["applied_art_commit_before"] = git_head(art_root)
    manifest["applied_at_utc"] = datetime.now(timezone.utc).isoformat()
    manifest["shop_runtime_projection"] = ART_RUNTIME_PATH.as_posix()
    manifest["shop_runtime_projection_sha256"] = sha256(runtime_path)
    json_write(previous_path, manifest)
    receipt = {
        "schema": "ysbzs.shop-art-sync-receipt.v1",
        "direction": "formal_to_art",
        "status": "applied",
        "files": receipt_files,
        "preview": {"before": preview_before, "after": sha256(preview_target)},
        "resource_inventory": {
            "before": inventory_before,
            "after": sha256(inventory_target),
        },
        "shop_runtime_projection": {"before": runtime_before, "after": sha256(runtime_path)},
        "pet_map_updates": len(manifest.get("pet_map_updates", {})),
        "pet_map_removals": len(manifest.get("pet_map_removals", [])),
        "merchant_map_updates": len(manifest.get("merchant_map_updates", {})),
    }
    json_write(bundle / "formal_to_art_receipt.json", receipt)
    print(
        "SHOP_ART_SYNC_OUTBOUND_OK "
        f"files={len(receipt_files)} pets={receipt['pet_map_updates']} merchants={receipt['merchant_map_updates']}"
    )


def collect_inbound(args: argparse.Namespace) -> None:
    formal_root = args.formal_root.resolve()
    art_root = args.art_root.resolve()
    receipt_dir = args.receipt_dir.resolve()
    manifest = json_load(art_root / ART_MANIFEST_PATH)
    if manifest.get("schema") != SCHEMA:
        raise SyncError("art workspace has no compatible formal sync manifest")
    results: list[dict[str, Any]] = []
    conflicts: list[str] = []
    for raw in manifest.get("return_files", []):
        if not isinstance(raw, dict) or raw.get("owner") != "art_owned":
            raise SyncError("invalid inbound allowlist entry")
        source_rel = normalized_relative(str(raw.get("source", "")))
        target_rel = normalized_relative(str(raw.get("target", "")))
        if source_rel.suffix.lower() != ".png" or target_rel.suffix.lower() != ".png":
            raise SyncError(f"inbound accepts PNG only: {source_rel}")
        source = art_root / source_rel
        target = formal_root / target_rel
        if not source.is_file():
            raise SyncError(f"inbound source file missing: {source_rel}")
        art_hash = sha256(source)
        formal_hash = sha256(target) if target.is_file() else ""
        art_base = str(raw.get("art_baseline_sha256", ""))
        formal_base = str(raw.get("formal_baseline_sha256", ""))
        target_existed = bool(raw.get("formal_target_existed", True))
        if png_info(source) != {k: raw[k] for k in ("width", "height", "has_alpha")}:
            raise SyncError(f"art return geometry changed without a new contract: {source_rel}")
        if art_hash == formal_hash:
            status = "unchanged"
        elif not target_existed and formal_hash == "":
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
            if sha256(target) != art_hash:
                raise SyncError(f"inbound art-origin copy hash mismatch: {target_rel}")
            status = "applied_art_origin"
        elif art_hash != art_base and formal_hash == formal_base:
            shutil.copy2(source, target)
            if sha256(target) != art_hash:
                raise SyncError(f"inbound copy hash mismatch: {target_rel}")
            status = "applied_art_change"
        elif art_hash == art_base and formal_hash != formal_base:
            status = "formal_newer_skipped"
        else:
            status = "conflict"
            conflicts.append(target_rel.as_posix())
        results.append({
            "source": source_rel.as_posix(),
            "target": target_rel.as_posix(),
            "status": status,
            "art_sha256": art_hash,
            "formal_sha256_before": formal_hash,
            "formal_sha256_after": sha256(target),
        })
    receipt = {
        "schema": "ysbzs.shop-art-sync-receipt.v1",
        "direction": "art_to_formal",
        "status": "conflict" if conflicts else "completed",
        "files": results,
        "copied_code_files": 0,
        "conflicts": conflicts,
    }
    json_write(receipt_dir / "art_to_formal_receipt.json", receipt)
    if conflicts:
        raise SyncError("FILE_CONFLICT_STOP: " + ", ".join(conflicts))
    changed = sum(item["status"] in ("applied_art_change", "applied_art_origin") for item in results)
    print(f"SHOP_ART_SYNC_INBOUND_OK assets={len(results)} changed={changed} code=0")


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(description=__doc__)
    sub = root.add_subparsers(dest="command", required=True)
    prepare_cmd = sub.add_parser("prepare", help="build a formal-to-art bundle")
    prepare_cmd.add_argument("--formal-root", type=Path, required=True)
    prepare_cmd.add_argument("--art-root", type=Path, required=True)
    prepare_cmd.add_argument("--capture", type=Path, required=True)
    prepare_cmd.add_argument("--bundle-dir", type=Path, required=True)
    prepare_cmd.set_defaults(run=prepare)
    outbound = sub.add_parser("apply-outbound", help="apply the prepared reference bundle")
    outbound.add_argument("--art-root", type=Path, required=True)
    outbound.add_argument("--bundle-dir", type=Path, required=True)
    outbound.set_defaults(run=apply_outbound)
    inbound = sub.add_parser("collect-inbound", help="collect only allowlisted art-owned PNGs")
    inbound.add_argument("--formal-root", type=Path, required=True)
    inbound.add_argument("--art-root", type=Path, required=True)
    inbound.add_argument("--receipt-dir", type=Path, required=True)
    inbound.set_defaults(run=collect_inbound)
    return root


def main() -> int:
    args = parser().parse_args()
    try:
        args.run(args)
    except (SyncError, OSError, subprocess.CalledProcessError) as exc:
        print(f"SHOP_ART_SYNC_FAIL: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
