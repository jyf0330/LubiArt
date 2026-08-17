#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
godot_bin="${GODOT_BIN:-/Users/ywh/Downloads/Godot.app/Contents/MacOS/Godot}"
remote_host="${GODOT_TEST_HOST:-ubuntu@124.222.83.113}"
remote_key="${GODOT_TEST_SSH_KEY:-$HOME/.ssh/web.pem}"
remote_dir="${GODOT_TEST_REMOTE_DIR:-/var/www/ysbzs/godot-test}"
local_dir="$project_dir/build/web"

if [[ ! -x "$godot_bin" ]]; then
  echo "Godot executable not found: $godot_bin" >&2
  exit 1
fi

rm -rf "$local_dir"
mkdir -p "$local_dir"
"$godot_bin" --headless --path "$project_dir" --export-release Web "$local_dir/index.html"

test -f "$local_dir/index.html"
test -f "$local_dir/index.wasm"
test -f "$local_dir/index.pck"

ssh_opts=(-i "$remote_key" -o BatchMode=yes -o ConnectTimeout=15)
staging_dir="$(ssh "${ssh_opts[@]}" "$remote_host" "mktemp -d '${remote_dir}.staging.XXXXXX'")"
cleanup() {
  ssh "${ssh_opts[@]}" "$remote_host" "rm -rf '$staging_dir'" >/dev/null 2>&1 || true
}
trap cleanup EXIT

rsync -az --delete -e "ssh -i $remote_key -o BatchMode=yes -o ConnectTimeout=15" \
  "$local_dir/" "$remote_host:$staging_dir/"
ssh "${ssh_opts[@]}" "$remote_host" \
  "rm -rf '${remote_dir}.previous'; if [[ -e '$remote_dir' ]]; then mv '$remote_dir' '${remote_dir}.previous'; fi; mv '$staging_dir' '$remote_dir'; rm -rf '${remote_dir}.previous'"

trap - EXIT
url="http://124.222.83.113/ysbzs/godot-test/"
curl --fail --silent --show-error --head "$url" >/dev/null
echo "Published: $url"
