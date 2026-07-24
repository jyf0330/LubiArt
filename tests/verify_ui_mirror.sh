#!/bin/zsh

set -euo pipefail

SOURCE_ROOT="${GODOT_LATEST_UI_SOURCE:-/Users/ywh/Documents/godot-latest}"
MOCK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ ! -f "$SOURCE_ROOT/project.godot" ]]; then
  print -u2 "UI mirror source is unavailable: $SOURCE_ROOT"
  exit 2
fi

mirror_directories=(
  "game"
  "features"
  "shared/prefabs"
  "assets/artist_ui"
  "assets/battle_ui"
)

for relative_path in "${mirror_directories[@]}"; do
  diff -qr "$MOCK_ROOT/$relative_path" "$SOURCE_ROOT/$relative_path"
done

print "MOCK_UI_LAYER_100_PERCENT_PASS"
