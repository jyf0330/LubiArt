#!/bin/zsh

set -euo pipefail

MOCK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

mirror_directories=(
  "game"
  "features"
  "shared/prefabs"
  "assets/artist_ui"
  "assets/battle_ui"
)

required_files=(
  "project.godot"
  "game/scenes/game.tscn"
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
    "$MOCK_ROOT/$relative_path" \
    "$SOURCE_ROOT/$relative_path"
done

print "MOCK_UI_SOURCE_COMPARISON_PASS"
