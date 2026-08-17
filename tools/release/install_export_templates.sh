#!/usr/bin/env bash
set -euo pipefail

download_dir="${1:?usage: install_export_templates.sh DOWNLOAD_DIR}"
godot_release="${GODOT_RELEASE:-4.7.1-stable}"
godot_version="${godot_release%-stable}"
template_version="${godot_release/-stable/.stable}"
archive_path="${download_dir}/templates.tpz"
case "$(uname -s)" in
  Darwin)
    template_dir="${HOME}/Library/Application Support/Godot/export_templates/${template_version}"
    ;;
  Linux)
    template_dir="${HOME}/.local/share/godot/export_templates/${template_version}"
    ;;
  *)
    echo "Unsupported export-template platform: $(uname -s)" >&2
    exit 2
    ;;
esac

mkdir -p "${download_dir}" "${template_dir}"
if [[ ! -f "${template_dir}/web_release.zip" ]]; then
  download_url="https://downloads.godotengine.org/?flavor=stable&platform=templates&slug=export_templates.tpz&version=${godot_version}"
  if [[ ! -s "${archive_path}" ]]; then
    curl --fail --location --retry 3 --output "${archive_path}" "${download_url}"
  fi
  if [[ ! -d "${download_dir}/unpacked/templates" ]]; then
    unzip -q -o "${archive_path}" -d "${download_dir}/unpacked"
  fi
  cp -R "${download_dir}/unpacked/templates/." "${template_dir}/"
fi

test -f "${template_dir}/web_release.zip"
echo "GODOT_EXPORT_TEMPLATES_OK dir=${template_dir}"
