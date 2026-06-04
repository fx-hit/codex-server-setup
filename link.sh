#!/usr/bin/env bash
set -euo pipefail

# Keep persistent Codex data on the shared volume, but keep
# /root/.codex/app-server-control as a real local directory. Codex Desktop SSH
# creates a Unix domain socket there, and the shared FUSE filesystem does not
# support socket files.

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

LOCAL_CODEX_HOME="${CODEX_HOME:-/root/.codex}"
CONTROL_DIR="$LOCAL_CODEX_HOME/app-server-control"

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
# into the persistent directory. app-server-control is runtime-only and stays
# local.
shopt -s dotglob nullglob
for local_entry in "$LOCAL_CODEX_HOME"/*; do
  name="$(basename "$local_entry")"
  case "$name" in
    .|..|app-server-control)
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
  tmp
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
  state_5.sqlite
  state_5.sqlite-shm
  state_5.sqlite-wal
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

# Link persistent data back into the local CODEX_HOME. Skip app-server-control:
# it must remain a real local directory, not a symlink.
for persistent_entry in "$PERSISTENT_CODEX_HOME"/*; do
  name="$(basename "$persistent_entry")"
  case "$name" in
    .|..|.codex|app-server-control|app-server-control.bak.*)
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
echo "  persistent data: $PERSISTENT_CODEX_HOME"
