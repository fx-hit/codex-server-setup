#!/usr/bin/env bash
set -euo pipefail

CLAUDE_RELEASE_URL="${CLAUDE_RELEASE_URL:-https://github.com/anthropics/claude-code/releases/latest/download/claude-linux-x64.tar.gz}"
CLAUDE_DOWNLOAD_PROXY="${CLAUDE_DOWNLOAD_PROXY:-http://127.0.0.1:18080}"
ARCHIVE_PATH="${CLAUDE_ARCHIVE_PATH:-/tmp/claude.tar.gz}"
EXTRACT_DIR="${CLAUDE_EXTRACT_DIR:-/tmp/claude-bin}"
INSTALL_DIR="${CLAUDE_INSTALL_DIR:-${HOME:-/root}/.local/bin}"
INSTALL_PATH="${CLAUDE_INSTALL_PATH:-$INSTALL_DIR/claude-real}"

# Download the tarball.
curl_args=(-L -o "$ARCHIVE_PATH")
if [ -n "$CLAUDE_DOWNLOAD_PROXY" ]; then
  curl_args+=(--proxy "$CLAUDE_DOWNLOAD_PROXY")
fi
curl_args+=("$CLAUDE_RELEASE_URL")

echo "Downloading Claude Code release..."
curl "${curl_args[@]}"

# Extract and locate the claude binary.
rm -rf "$EXTRACT_DIR"
mkdir -p "$EXTRACT_DIR"
tar -xzf "$ARCHIVE_PATH" -C "$EXTRACT_DIR"

CLAUDE_EXE="$(find "$EXTRACT_DIR" -maxdepth 5 -type f -name "claude" | head -n 1)"

if [ -z "$CLAUDE_EXE" ]; then
  echo "ERROR: did not find claude binary in tarball" >&2
  find "$EXTRACT_DIR" -maxdepth 5 -type f -print
  exit 1
fi

# Install as claude-real (wrapper will be created later).
mkdir -p "$(dirname "$INSTALL_PATH")"
install -m 755 "$CLAUDE_EXE" "$INSTALL_PATH"

rm -rf "$EXTRACT_DIR"

echo "Installed Claude Code binary as claude-real:"
echo "  $INSTALL_PATH"
"$INSTALL_PATH" --version

install_dir="$(dirname "$INSTALL_PATH")"
case ":$PATH:" in
  *":$install_dir:"*) ;;
  *)
    echo "Add Claude to PATH before running it by name:"
    echo "  export PATH=\"$install_dir:\$PATH\""
    ;;
esac
