#!/bin/zsh

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
  "art/scenes/three_choice/three_choice_scene.tscn"
  "art/scenes/battle/battle_art_scene.tscn"
  "art/prefabs/pet/pet.tscn"
  "art/prefabs/pet/pet_detail.tscn"
  "art/prefabs/terrain/terrain.tscn"
  "art/prefabs/terrain/terrain_detail.tscn"
  "session/mock_game_session.gd"
  "data/mock_battle_snapshot.json"
)

for relative_path in "${mirror_directories[@]}"; do
  if [[ ! -d "$MOCK_ROOT/$relative_path" ]]; then
    print -u2 "Required standalone UI directory is missing: $relative_path"
    exit 1
  fi
done

for relative_path in "${required_files[@]}"; do
  if [[ ! -f "$MOCK_ROOT/$relative_path" ]]; then
    print -u2 "Required standalone project file is missing: $relative_path"
    exit 1
  fi
done

expected_scenes=(
  "art/scenes/battle/battle_art_scene.tscn"
  "art/scenes/three_choice/three_choice_scene.tscn"
)

actual_scenes=("${(@f)$(cd "$MOCK_ROOT" && find art/scenes -type f -name "*.tscn" | sort)}")
if [[ "${(j:\n:)actual_scenes}" != "${(j:\n:)expected_scenes}" ]]; then
  print -u2 "Standalone project must contain exactly the two formal UI scenes."
  exit 1
fi

expected_prefabs=(
  "art/prefabs/pet/pet.tscn"
  "art/prefabs/pet/pet_detail.tscn"
  "art/prefabs/terrain/terrain.tscn"
  "art/prefabs/terrain/terrain_detail.tscn"
)

actual_prefabs=("${(@f)$(cd "$MOCK_ROOT" && find art/prefabs -type f -name "*.tscn" | sort)}")
if [[ "${(j:\n:)actual_prefabs}" != "${(j:\n:)expected_prefabs}" ]]; then
  print -u2 "Standalone project must contain exactly the four formal reusable prefabs."
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
    print -u2 "Legacy UI directory must not be restored: $relative_path"
    exit 1
  fi
done

if find "$MOCK_ROOT/art/scenes" "$MOCK_ROOT/art/prefabs" \
  -type f \( -name "*.gd" -o -name "*.gd.uid" -o -name "*.json" -o -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.webp" -o -name "*.svg" \) \
  -print -quit | grep -q .; then
  print -u2 "Scene and prefab directories may only contain scene files and documentation."
  exit 1
fi

if find "$MOCK_ROOT/art/images" \
  -type f \( -name "*.gd" -o -name "*.gd.uid" -o -name "*.tscn" -o -name "*.json" \) \
  -print -quit | grep -q .; then
  print -u2 "art/images may not contain scripts, scenes, or JSON manifests."
  exit 1
fi

if find "$MOCK_ROOT/art/manifests" \
  -type f \( -name "*.gd" -o -name "*.gd.uid" -o -name "*.tscn" -o -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.webp" -o -name "*.svg" \) \
  -print -quit | grep -q .; then
  print -u2 "art/manifests may only contain JSON manifests and documentation."
  exit 1
fi

if find "$MOCK_ROOT/core_ui" -type f ! -path "$MOCK_ROOT/core_ui/scripts/*" ! -name "README.md" -print -quit | grep -q .; then
  print -u2 "UI implementation files must be placed under core_ui/scripts."
  exit 1
fi

print "MOCK_UI_STANDALONE_STRUCTURE_PASS"

SOURCE_ROOT="${GODOT_LATEST_UI_SOURCE:-}"
if [[ -z "$SOURCE_ROOT" ]]; then
  print "MOCK_UI_SOURCE_COMPARISON_SKIPPED"
  exit 0
fi

if [[ ! -f "$SOURCE_ROOT/project.godot" ]]; then
  print -u2 "Optional UI comparison source is unavailable: $SOURCE_ROOT"
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

print "MOCK_UI_SOURCE_COMPARISON_PASS"
