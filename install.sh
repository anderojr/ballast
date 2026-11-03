#!/bin/sh
set -eu

source_url=https://github.com/anderojr/ballast#build-from-source

die() {
  echo "error: $*" >&2
  exit 1
}

detect_platform() {
  os=$(uname -s)

  case "$os" in
  Linux) os=linux ;;
  *) die "unsupported OS: $os (supported: Linux); build from source: $source_url" ;;
  esac

  machine=$(uname -m)

  case "$machine" in
  x86_64 | amd64) arch=x86_64 ;;
  aarch64 | arm64) arch=arm64 ;;
  *) die "unsupported architecture: $machine (supported: x86_64, arm64); build from source: $source_url" ;;
  esac
}

resolve_version() {
  if [ -n "${BALLAST_VERSION:-}" ]; then
    version=$BALLAST_VERSION
    return
  fi

  latest_url=$(curl -fsSLI -o /dev/null -w '%{url_effective}' \
    https://github.com/anderojr/ballast/releases/latest) ||
    die "could not look up the latest release"

  version=${latest_url##*/}

  case "$version" in
  v*) ;;
  *) die "unexpected release URL: $latest_url" ;;
  esac
}

download_and_verify() {
  asset="ballast-${version}-${os}-${arch}.tar.gz"
  base="https://github.com/anderojr/ballast/releases/download/${version}"

  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT

  curl -fsSL -o "$tmp/$asset" "$base/$asset" ||
    die "could not download $base/$asset"
  curl -fsSL -o "$tmp/SHA256SUMS" "$base/SHA256SUMS" ||
    die "could not download $base/SHA256SUMS"

  (cd "$tmp" && grep " ${asset}\$" SHA256SUMS | sha256sum -c - >/dev/null) ||
    die "checksum mismatch for $asset"
}

install_binary() {
  dir=${BALLAST_INSTALL_DIR:-$HOME/.local/bin}
  name=${asset%.tar.gz}

  tar -xzf "$tmp/$asset" -C "$tmp" ||
    die "could not extract $asset"

  mkdir -p "$dir" ||
    die "could not create $dir"
  install -m 755 "$tmp/$name/ballast" "$dir/ballast" ||
    die "could not install to $dir"

  echo "ballast $version installed to $dir/ballast"

  case ":$PATH:" in
  *":$dir:"*) ;;
  *) echo "note: $dir is not in your PATH" >&2 ;;
  esac
}

main() {
  detect_platform
  resolve_version
  download_and_verify
  install_binary
}

main "$@"
