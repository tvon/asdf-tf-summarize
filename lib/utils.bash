#!/usr/bin/env bash

set -euo pipefail

# TODO: Ensure this is the correct GitHub homepage where releases can be downloaded for tf-summarize.
GH_REPO="https://github.com/dineshba/tf-summarize"
TOOL_NAME="tf-summarize"
TOOL_TEST="tf-summarize -v"

fail() {
  echo -e "asdf-$TOOL_NAME: $*"
  exit 1
}

curl_opts=(-fsSL)

# NOTE: You might want to remove this if tf-summarize is not hosted on GitHub releases.
if [ -n "${GITHUB_API_TOKEN:-}" ]; then
  curl_opts=("${curl_opts[@]}" -H "Authorization: token $GITHUB_API_TOKEN")
fi

sort_versions() {
  sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
    LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

list_github_tags() {
  git ls-remote --tags --refs "$GH_REPO" |
    grep -o 'refs/tags/.*' | cut -d/ -f3- |
    sed 's/^v//' # NOTE: You might want to adapt this sed to remove non-version strings from tags
}

list_all_versions() {
  # TODO: Adapt this. By default we simply list the tag names from GitHub releases.
  # Change this function if tf-summarize has other means of determining installable versions.
  list_github_tags
}

download_release() {
  local version filename found url_prefix platform arch
  version="$1"
  filename="$2" # we will treat this like a prefix

  platform=$(getPlatform)
  arch=$(getArch)

  url_prefix="$GH_REPO/releases/download/v${version}/${TOOL_NAME}_${platform}_${arch}"

  found=false
  for extension in zip tar.gz; do

    echo "* Downloading $TOOL_NAME release $version (trying $extension)..."
    if curl "${curl_opts[@]}" -o "${filename}.${extension}" -C - "${url_prefix}.${extension}"; then
      found=true
      break
    fi
  done
  $found || fail "Could not download $url_prefix(.tar.gz|.zip)"
}

install_version() {
  local install_type="$1"
  local version="$2"
  local install_path="${3%/bin}/bin"

  if [ "$install_type" != "version" ]; then
    fail "asdf-$TOOL_NAME supports release installs only"
  fi

  (
    mkdir -p "$install_path"
    cp -r "$ASDF_DOWNLOAD_PATH"/* "$install_path"

    # TODO: Assert tf-summarize executable exists.
    local tool_cmd
    tool_cmd="$(echo "$TOOL_TEST" | cut -d' ' -f1)"
    test -x "$install_path/$tool_cmd" || fail "Expected $install_path/$tool_cmd to be executable."

    echo "$TOOL_NAME $version installation was successful!"
  ) || (
    rm -rf "$install_path"
    fail "An error occurred while installing $TOOL_NAME $version."
  )
}

getArch() {
  local ARCH
  ARCH=$(uname -m)

  case $ARCH in
  armv*) ARCH="arm" ;;
  aarch64) ARCH="arm64" ;;
  x86) ARCH="386" ;;
  x86_64) ARCH="amd64" ;;
  i686) ARCH="386" ;;
  i386) ARCH="386" ;;
  esac
  echo "${ARCH}"
}

getPlatform() {
  local platform
  [ "Linux" = "$(uname)" ] && platform="linux" || platform="darwin"
  echo "${platform}"
}
