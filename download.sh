#!/usr/bin/env bash
set -euo pipefail

CODEX_RELEASE_URL="${CODEX_RELEASE_URL:-https://github.com/openai/codex/releases/latest/download/codex-x86_64-unknown-linux-musl.tar.gz}"
CODEX_DOWNLOAD_PROXY="${CODEX_DOWNLOAD_PROXY:-http://127.0.0.1:18080}"
ARCHIVE_PATH="${CODEX_ARCHIVE_PATH:-/tmp/codex.tar.gz}"
EXTRACT_DIR="${CODEX_EXTRACT_DIR:-/tmp/codex-bin}"
INSTALL_PATH="${CODEX_INSTALL_PATH:-/usr/local/bin/codex}"

curl_args=(-L -o "$ARCHIVE_PATH")
if [ -n "$CODEX_DOWNLOAD_PROXY" ]; then
  curl_args+=(--proxy "$CODEX_DOWNLOAD_PROXY")
fi
curl_args+=("$CODEX_RELEASE_URL")

echo "Downloading Codex release..."
curl "${curl_args[@]}"

rm -rf "$EXTRACT_DIR"
mkdir -p "$EXTRACT_DIR"
tar -xzf "$ARCHIVE_PATH" -C "$EXTRACT_DIR"

binary_path="$EXTRACT_DIR/codex-x86_64-unknown-linux-musl"
if [ ! -f "$binary_path" ]; then
  echo "Codex binary not found after extraction: $binary_path" >&2
  exit 1
fi

install -m 755 "$binary_path" "$INSTALL_PATH"

echo "Installed raw Codex binary:"
command -v codex || true
codex --version
