#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter not found in PATH. Install Flutter and try again." >&2
  exit 1
fi
if ! command -v flatpak-builder >/dev/null 2>&1; then
  echo "flatpak-builder not found. Install org.flatpak.Builder and try again." >&2
  exit 1
fi
if ! command -v flatpak >/dev/null 2>&1; then
  echo "flatpak not found. Install Flatpak and try again." >&2
  exit 1
fi

flutter build linux --release

BUILD_DIR="$ROOT_DIR/build/flatpak"
REPO_DIR="$ROOT_DIR/build/flatpak-repo"
BUNDLE_OUT="$ROOT_DIR/build/evmrider.flatpak"

flatpak-builder --force-clean --repo="$REPO_DIR" "$BUILD_DIR" flatpak/com.peerchemist.evmrider.yml
flatpak build-bundle "$REPO_DIR" "$BUNDLE_OUT" com.peerchemist.evmrider

echo "Built Flatpak bundle: $BUNDLE_OUT"
