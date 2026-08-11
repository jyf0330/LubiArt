#!/usr/bin/env python3
"""Reject unapproved or incomplete files in the protected sprite animation tree."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
REGISTRY_PATH = (
    PROJECT_ROOT
    / "art/manifests/shared/pets/animations/approved_sprite_animation_manifest.json"
)
RUNTIME_MANIFEST_PATH = (
    PROJECT_ROOT
    / "art/manifests/shared/pets/animations/pet_frame_animation_manifest.json"
)
VALID_ACTIONS = {"idle", "move", "attack"}


def load_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def fail(messages: list[str]) -> int:
    print("Sprite animation approval gate: BLOCKED", file=sys.stderr)
    for message in messages:
        print(f"- {message}", file=sys.stderr)
    return 1


def main() -> int:
    registry = load_json(REGISTRY_PATH)
    protected_root = PROJECT_ROOT / registry["protected_root"]
    errors: list[str] = []
    allowed_files: set[str] = set()
    registered_frames: set[str] = set()
    seen_keys: set[tuple[str, str, str]] = set()

    for entry in registry.get("approved_animations", []):
        sprite_id = entry["sprite_id"]
        animation_id = entry["animation_id"]
        action = entry["action"]
        version = entry["version"]
        frame_directory = Path(entry["frame_directory"])
        frame_count = entry["frame_count"]
        key = (sprite_id, action, version)

        if key in seen_keys:
            errors.append(f"duplicate registry entry: {sprite_id}/{action}/{version}")
        seen_keys.add(key)
        if not re.fullmatch(r"SPR_\d{3}", sprite_id):
            errors.append(f"invalid sprite ID: {sprite_id}")
        if not re.fullmatch(r"ANIM_SPR_\d{3}_(IDLE|MOVE|ATTACK)_\d{3}", animation_id):
            errors.append(f"invalid animation ID: {animation_id}")
        if action not in VALID_ACTIONS:
            errors.append(f"unsupported action in registry: {action}")
        if frame_count <= 0:
            errors.append(f"invalid frame count for {sprite_id}/{action}/{version}")

        for field in ("sprite_name", "animation_name", "frame_directory", "gif", "overview"):
            try:
                str(entry[field]).encode("ascii")
            except UnicodeEncodeError:
                errors.append(f"non-ASCII {field} for {animation_id}")

        for index in range(1, frame_count + 1):
            relative_frame = (frame_directory / f"frame_{index:03d}.png").as_posix()
            allowed_files.add(relative_frame)
            allowed_files.add(f"{relative_frame}.import")
            registered_frames.add(
                f"res://{registry['protected_root']}/{relative_frame}"
            )

        for artifact_field in ("gif", "overview"):
            relative_artifact = Path(entry[artifact_field]).as_posix()
            allowed_files.add(relative_artifact)
            allowed_files.add(f"{relative_artifact}.import")

    actual_files = {
        path.relative_to(protected_root).as_posix()
        for path in protected_root.rglob("*")
        if path.is_file()
    }
    unexpected = sorted(actual_files - allowed_files)
    missing_assets = sorted(
        relative
        for relative in allowed_files - actual_files
        if not relative.endswith(".import")
    )
    if unexpected:
        errors.extend(f"unapproved file: {path}" for path in unexpected)
    if missing_assets:
        errors.extend(f"missing approved asset: {path}" for path in missing_assets)

    runtime_manifest = load_json(RUNTIME_MANIFEST_PATH)
    runtime_frames: set[str] = set()
    for pet_entry in runtime_manifest.get("by_texture_path", {}).values():
        for action, animation in pet_entry.items():
            if action not in VALID_ACTIONS:
                errors.append(f"unsupported runtime action: {action}")
                continue
            runtime_frames.update(animation.get("frames", []))

    unregistered_runtime_frames = sorted(runtime_frames - registered_frames)
    if unregistered_runtime_frames:
        errors.extend(
            f"runtime manifest references an unapproved frame: {path}"
            for path in unregistered_runtime_frames
        )

    if errors:
        return fail(errors)

    print(
        "Sprite animation approval gate: PASS "
        f"({len(seen_keys)} animations, {len(registered_frames)} frames)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
