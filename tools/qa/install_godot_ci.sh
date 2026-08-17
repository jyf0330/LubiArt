#!/usr/bin/env bash
set -euo pipefail

install_dir="${1:?usage: install_godot_ci.sh INSTALL_DIR}"
godot_release="${GODOT_RELEASE:-4.7.1-stable}"
godot_version="${godot_release%-stable}"
archive_path="${install_dir}/godot.zip"

mkdir -p "${install_dir}"

case "$(uname -s)" in
  Linux)
    platform="linux.64"
    slug="linux.x86_64.zip"
    binary_path="${install_dir}/Godot_v${godot_release}_linux.x86_64"
    ;;
  Darwin)
    platform="macos.universal"
    slug="macos.universal.zip"
    binary_path="${install_dir}/Godot.app/Contents/MacOS/Godot"
    ;;
  *)
    echo "Unsupported CI platform: $(uname -s)" >&2
    exit 2
    ;;
esac

if [[ ! -x "${binary_path}" ]]; then
  download_url="https://downloads.godotengine.org/?flavor=stable&platform=${platform}&slug=${slug}&version=${godot_version}"
  curl --fail --location --retry 3 --output "${archive_path}" "${download_url}"
  unzip -q -o "${archive_path}" -d "${install_dir}"
  chmod +x "${binary_path}"
fi

"${binary_path}" --headless --version >&2
printf '%s\n' "${binary_path}"
