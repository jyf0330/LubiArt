#!/usr/bin/env bash

set -euo pipefail

MOCK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

mirror_directories=(
  "art/scenes"
  "art/prefabs"
  "art/images"
  "art/manifests"
  "core_ui/scripts"
)

required_files=(
  "project.godot"
  "docs/SCENE_ROUTING_STANDARD.md"
  "art/scenes/app/game.tscn"
  "art/scenes/three_choice/three_choice_scene.tscn"
  "art/scenes/battle/battle_art_scene.tscn"
  "art/scenes/sprite_info_card_debug/sprite_info_card_debug_scene.tscn"
  "art/prefabs/pet/pet.tscn"
  "art/prefabs/pet/pet_detail.tscn"
  "art/prefabs/pet/sprite_info_card.tscn"
  "art/prefabs/shop/bazaar_info_panel.tscn"
  "art/prefabs/battle/hud/attack_direction_drawer.tscn"
  "art/prefabs/shared/cursor/game_cursor.tscn"
  "art/prefabs/terrain/terrain.tscn"
  "art/prefabs/terrain/terrain_detail.tscn"
  "session/mock_game_session.gd"
  "data/mock_battle_snapshot.json"
)

for relative_path in "${mirror_directories[@]}"; do
  if [[ ! -d "$MOCK_ROOT/$relative_path" ]]; then
    printf '%s\n' "Required standalone UI directory is missing: $relative_path" >&2
    exit 1
  fi
done

for relative_path in "${required_files[@]}"; do
  if [[ ! -f "$MOCK_ROOT/$relative_path" ]]; then
    printf '%s\n' "Required standalone project file is missing: $relative_path" >&2
    exit 1
  fi
done

expected_scenes=(
  "art/scenes/app/game.tscn"
  "art/scenes/battle/battle_art_scene.tscn"
  "art/scenes/sprite_info_card_debug/sprite_info_card_debug_scene.tscn"
  "art/scenes/three_choice/three_choice_scene.tscn"
)

actual_scenes="$(cd "$MOCK_ROOT" && find art/scenes -type f -name "*.tscn" | sort)"
expected_scenes_text="$(printf '%s\n' "${expected_scenes[@]}")"
if [[ "$actual_scenes" != "$expected_scenes_text" ]]; then
  printf '%s\n' "Standalone project must contain the Game shell, two formal UI scenes and the SpriteInfoCard debug scene." >&2
  exit 1
fi

expected_prefabs=(
  "art/prefabs/battle/hud/attack_direction_drawer.tscn"
  "art/prefabs/pet/pet.tscn"
  "art/prefabs/pet/pet_detail.tscn"
  "art/prefabs/pet/sprite_info_card.tscn"
  "art/prefabs/route/three_choice_card.tscn"
  "art/prefabs/shared/cursor/game_cursor.tscn"
  "art/prefabs/shop/bazaar_info_panel.tscn"
  "art/prefabs/terrain/terrain.tscn"
  "art/prefabs/terrain/terrain_detail.tscn"
)

actual_prefabs="$(cd "$MOCK_ROOT" && find art/prefabs -type f -name "*.tscn" | sort)"
expected_prefabs_text="$(printf '%s\n' "${expected_prefabs[@]}")"
if [[ "$actual_prefabs" != "$expected_prefabs_text" ]]; then
  printf '%s\n' "Standalone project must contain four public prefabs and the required internal UI components, including the bazaar panel and game cursor." >&2
  exit 1
fi

legacy_directories=(
  "game"
  "features"
  "shared/prefabs"
  "assets/artist_ui"
  "assets/battle_ui"
)

for relative_path in "${legacy_directories[@]}"; do
  if [[ -e "$MOCK_ROOT/$relative_path" ]]; then
    printf '%s\n' "Legacy UI directory must not be restored: $relative_path" >&2
    exit 1
  fi
done

if find "$MOCK_ROOT/art/scenes" "$MOCK_ROOT/art/prefabs" \
  -type f \( -name "*.gd" -o -name "*.gd.uid" -o -name "*.json" -o -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.webp" -o -name "*.svg" \) \
  -print -quit | grep -q .; then
  printf '%s\n' "Scene and prefab directories may only contain scene files and documentation." >&2
  exit 1
fi

if find "$MOCK_ROOT/art/images" \
  -type f \( -name "*.gd" -o -name "*.gd.uid" -o -name "*.tscn" -o -name "*.json" \) \
  -print -quit | grep -q .; then
  printf '%s\n' "art/images may not contain scripts, scenes, or JSON manifests." >&2
  exit 1
fi

if find "$MOCK_ROOT/art/manifests" \
  -type f \( -name "*.gd" -o -name "*.gd.uid" -o -name "*.tscn" -o -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.webp" -o -name "*.svg" \) \
  -print -quit | grep -q .; then
  printf '%s\n' "art/manifests may only contain JSON manifests and documentation." >&2
  exit 1
fi

if find "$MOCK_ROOT/core_ui" -type f ! -path "$MOCK_ROOT/core_ui/scripts/*" ! -name "README.md" -print -quit | grep -q .; then
  printf '%s\n' "UI implementation files must be placed under core_ui/scripts." >&2
  exit 1
fi

printf '%s\n' "MOCK_UI_STANDALONE_STRUCTURE_PASS"

SOURCE_ROOT="${GODOT_LATEST_UI_SOURCE:-}"
if [[ -z "$SOURCE_ROOT" ]]; then
  printf '%s\n' "MOCK_UI_SOURCE_COMPARISON_SKIPPED"
  exit 0
fi

if [[ ! -f "$SOURCE_ROOT/project.godot" ]]; then
  printf '%s\n' "Optional UI comparison source is unavailable: $SOURCE_ROOT" >&2
  exit 2
fi

for relative_path in "${mirror_directories[@]}"; do
  diff -qr \
    -x ".DS_Store" \
    -x "._*" \
    -x "debug" \
    "$MOCK_ROOT/$relative_path" \
    "$SOURCE_ROOT/$relative_path"
done

printf '%s\n' "MOCK_UI_SOURCE_COMPARISON_PASS"
