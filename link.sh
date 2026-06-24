#!/usr/bin/env bash
set -euo pipefail

# Keep persistent Codex data on the shared volume, but keep runtime-only
# directories on local storage. Codex Desktop SSH creates a Unix domain socket
# under app-server-control, and Codex's arg0 launcher writes startup cache under
# tmp; both are a poor fit for shared FUSE filesystems.

if [ $# -gt 1 ]; then
  echo "Usage: $0 <persistent-codex-home>" >&2
  exit 2
fi

PERSISTENT_CODEX_HOME="${1:-${PERSISTENT_CODEX_HOME:-}}"
if [ -z "$PERSISTENT_CODEX_HOME" ]; then
  cat >&2 <<'EOF'
Usage: link.sh <persistent-codex-home>

Example:
  bash link.sh /path/to/persistent/.codex

You can also set PERSISTENT_CODEX_HOME instead of passing an argument.
EOF
  exit 2
fi

LOCAL_CODEX_HOME="${CODEX_HOME:-${HOME:-/root}/.codex}"
CONTROL_DIR="$LOCAL_CODEX_HOME/app-server-control"
LOCAL_TMP_DIR="$LOCAL_CODEX_HOME/tmp"
CODEX_BIN="${CODEX_INSTALL_PATH:-${CODEX_INSTALL_DIR:-${HOME:-/root}/.local/bin}/codex}"
STANDALONE_CODEX="$LOCAL_CODEX_HOME/packages/standalone/current/codex"

mkdir -p "$PERSISTENT_CODEX_HOME"
chmod 700 "$PERSISTENT_CODEX_HOME"

if [ -L "$LOCAL_CODEX_HOME" ]; then
  rm "$LOCAL_CODEX_HOME"
elif [ -e "$LOCAL_CODEX_HOME" ] && [ ! -d "$LOCAL_CODEX_HOME" ]; then
  mv "$LOCAL_CODEX_HOME" "$LOCAL_CODEX_HOME.bak.$(date +%Y%m%d%H%M%S)"
fi

mkdir -p "$LOCAL_CODEX_HOME"
chmod 700 "$LOCAL_CODEX_HOME"

# If Codex created real local files before this script ran, move those files
# into the persistent directory. Runtime-only directories stay local.
shopt -s dotglob nullglob
for local_entry in "$LOCAL_CODEX_HOME"/*; do
  name="$(basename "$local_entry")"
  case "$name" in
    .|..|app-server-control|app-server-daemon|db-backups|packages|tmp|tmp.bak.*|state_5.sqlite|state_5.sqlite-shm|state_5.sqlite-wal)
      continue
      ;;
  esac

  if [ -L "$local_entry" ]; then
    continue
  fi

  persistent_entry="$PERSISTENT_CODEX_HOME/$name"
  if [ ! -e "$persistent_entry" ] && [ ! -L "$persistent_entry" ]; then
    mv "$local_entry" "$persistent_entry"
  else
    mv "$local_entry" "$local_entry.bak.$(date +%Y%m%d%H%M%S)"
  fi
done

mkdir -p "$CONTROL_DIR"
chmod 700 "$CONTROL_DIR"
rm -f "$CONTROL_DIR/app-server-startup.lock"

if [ -L "$LOCAL_TMP_DIR" ]; then
  rm "$LOCAL_TMP_DIR"
elif [ -e "$LOCAL_TMP_DIR" ] && [ ! -d "$LOCAL_TMP_DIR" ]; then
  mv "$LOCAL_TMP_DIR" "$LOCAL_TMP_DIR.bak.$(date +%Y%m%d%H%M%S)"
fi
mkdir -p "$LOCAL_TMP_DIR"
chmod 700 "$LOCAL_TMP_DIR"
rm -rf "$LOCAL_TMP_DIR/arg0"

for stale_arg0_dir in "$LOCAL_CODEX_HOME"/tmp.bak.*/arg0; do
  [ -e "$stale_arg0_dir" ] || continue
  rm -rf "$stale_arg0_dir"
done

mkdir -p "$(dirname "$STANDALONE_CODEX")"
if [ -x "$CODEX_BIN" ]; then
  ln -sfn "$CODEX_BIN" "$STANDALONE_CODEX"
fi

for state_file in \
  "$LOCAL_CODEX_HOME/state_5.sqlite" \
  "$LOCAL_CODEX_HOME/state_5.sqlite-shm" \
  "$LOCAL_CODEX_HOME/state_5.sqlite-wal"; do
  if [ -L "$state_file" ]; then
    rm "$state_file"
  fi
done

persistent_dirs=(
  .tmp
  archived_sessions
  attachments
  cache
  plugins
  rules
  sessions
  shell_snapshots
  skills
  vendor_imports
)

persistent_files=(
  .personality_migration
  AGENTS.md
  auth.json
  config.toml
  history.jsonl
  installation_id
  models_cache.json
  session_index.jsonl
  goals_1.sqlite
  goals_1.sqlite-shm
  goals_1.sqlite-wal
  logs_2.sqlite
  logs_2.sqlite-shm
  logs_2.sqlite-wal
  memories_1.sqlite
  memories_1.sqlite-shm
  memories_1.sqlite-wal
)

for name in "${persistent_dirs[@]}"; do
  persistent_entry="$PERSISTENT_CODEX_HOME/$name"
  local_entry="$LOCAL_CODEX_HOME/$name"

  mkdir -p "$persistent_entry"
  if [ -e "$local_entry" ] || [ -L "$local_entry" ]; then
    if [ -L "$local_entry" ] && [ "$(readlink "$local_entry")" = "$persistent_entry" ]; then
      continue
    fi
    mv "$local_entry" "$local_entry.bak.$(date +%Y%m%d%H%M%S)"
  fi
  ln -s "$persistent_entry" "$local_entry"
done

for name in "${persistent_files[@]}"; do
  persistent_entry="$PERSISTENT_CODEX_HOME/$name"
  local_entry="$LOCAL_CODEX_HOME/$name"

  if [ -e "$local_entry" ] || [ -L "$local_entry" ]; then
    if [ -L "$local_entry" ] && [ "$(readlink "$local_entry")" = "$persistent_entry" ]; then
      continue
    fi
    mv "$local_entry" "$local_entry.bak.$(date +%Y%m%d%H%M%S)"
  fi
  ln -s "$persistent_entry" "$local_entry"
done

# Link persistent data back into the local CODEX_HOME. Skip runtime-only
# directories: they must remain real local directories, not symlinks.
for persistent_entry in "$PERSISTENT_CODEX_HOME"/*; do
  name="$(basename "$persistent_entry")"
  case "$name" in
    .|..|.codex|app-server-control|app-server-control.bak.*|app-server-daemon|db-backups|packages|tmp|tmp.bak.*|state_5.sqlite|state_5.sqlite-shm|state_5.sqlite-wal)
      continue
      ;;
  esac

  local_entry="$LOCAL_CODEX_HOME/$name"
  if [ -e "$local_entry" ] || [ -L "$local_entry" ]; then
    if [ -L "$local_entry" ] && [ "$(readlink "$local_entry")" = "$persistent_entry" ]; then
      continue
    fi
    mv "$local_entry" "$local_entry.bak.$(date +%Y%m%d%H%M%S)"
  fi

  ln -s "$persistent_entry" "$local_entry"
done

if command -v python3 >/dev/null 2>&1; then
  python3 - "$CONTROL_DIR/socket-test.sock" <<'PY'
import os
import socket
import sys

path = sys.argv[1]
try:
    try:
        os.unlink(path)
    except FileNotFoundError:
        pass
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.bind(path)
    sock.close()
finally:
    try:
        os.unlink(path)
    except FileNotFoundError:
        pass
PY
fi

echo "Codex link setup completed."
echo "  local CODEX_HOME: $LOCAL_CODEX_HOME"
echo "  local control dir: $CONTROL_DIR"
echo "  local tmp dir: $LOCAL_TMP_DIR"
echo "  local standalone codex: $STANDALONE_CODEX"
echo "  persistent data: $PERSISTENT_CODEX_HOME"
