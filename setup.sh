#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ $# -gt 1 ]; then
  echo "Usage: $0 <persistent-codex-home>" >&2
  exit 2
fi

"$SCRIPT_DIR/download.sh"
"$SCRIPT_DIR/wrapper.sh"
"$SCRIPT_DIR/link.sh" "${1:-${PERSISTENT_CODEX_HOME:-}}"

echo "Codex server setup completed."
