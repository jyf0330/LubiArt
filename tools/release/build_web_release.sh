#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
godot_bin="${GODOT_BIN:-$(command -v godot || true)}"
output_dir="${1:-${project_dir}/build/web}"

if [[ -z "${godot_bin}" || ! -x "${godot_bin}" ]]; then
  echo "Godot executable not found; set GODOT_BIN." >&2
  exit 2
fi

case "${output_dir}" in
  "${project_dir}/build/web"|"${project_dir}/build/web/"|/tmp/ysbzs-web-release.*)
    ;;
  *)
    echo "Refusing to replace unexpected release directory: ${output_dir}" >&2
    exit 2
    ;;
esac

staging_dir="$(mktemp -d /tmp/ysbzs-web-release.XXXXXX)"
cleanup() {
  rm -rf "${staging_dir}"
}
trap cleanup EXIT

"${godot_bin}" --headless --path "${project_dir}" \
  --export-release Web "${staging_dir}/index.html"

for required in index.html index.js index.wasm index.pck; do
  if [[ ! -s "${staging_dir}/${required}" ]]; then
    echo "Web release is missing ${required}." >&2
    exit 1
  fi
done

(
  cd "${staging_dir}"
  shasum -a 256 index.html index.js index.wasm index.pck > SHA256SUMS
)

mkdir -p "$(dirname "${output_dir}")"
previous_dir="${output_dir}.previous"
rm -rf "${previous_dir}"
if [[ -e "${output_dir}" ]]; then
  mv "${output_dir}" "${previous_dir}"
fi
if ! mv "${staging_dir}" "${output_dir}"; then
  if [[ -e "${previous_dir}" ]]; then
    mv "${previous_dir}" "${output_dir}"
  fi
  exit 1
fi
rm -rf "${previous_dir}"
trap - EXIT

echo "WEB_RELEASE_BUILD_OK output=${output_dir}"
