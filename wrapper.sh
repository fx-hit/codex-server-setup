#!/usr/bin/env bash
set -euo pipefail

DEFAULT_CODEX_BIN_DIR="${CODEX_INSTALL_DIR:-${HOME:-/root}/.local/bin}"
CODEX_BIN="${CODEX_BIN:-${CODEX_INSTALL_PATH:-$DEFAULT_CODEX_BIN_DIR/codex}}"
CODEX_REAL="${CODEX_REAL:-$(dirname "$CODEX_BIN")/codex-real}"
CODEX_REAL_ESCAPED="$(printf '%q' "$CODEX_REAL")"

if [ ! -x "$CODEX_BIN" ] && [ ! -x "$CODEX_REAL" ]; then
  echo "Codex is not installed. Run download.sh first." >&2
  exit 1
fi

if [ -x "$CODEX_BIN" ] && ! grep -Fq "exec $CODEX_REAL_ESCAPED \"\$@\"" "$CODEX_BIN" 2>/dev/null; then
  mkdir -p "$(dirname "$CODEX_REAL")"
  install -m 755 "$CODEX_BIN" "$CODEX_REAL"
fi

if [ ! -x "$CODEX_REAL" ]; then
  echo "Raw Codex binary is missing: $CODEX_REAL" >&2
  exit 1
fi

mkdir -p "$(dirname "$CODEX_BIN")"

cat > "$CODEX_BIN" <<EOF
#!/usr/bin/env bash

# Remote server accesses the internet through the Mac reverse proxy.
export HTTP_PROXY="\${HTTP_PROXY:-http://127.0.0.1:18080}"
export HTTPS_PROXY="\${HTTPS_PROXY:-http://127.0.0.1:18080}"
export http_proxy="\${http_proxy:-http://127.0.0.1:18080}"
export https_proxy="\${https_proxy:-http://127.0.0.1:18080}"

# Keep local app-server websocket and localhost traffic out of the proxy.
export NO_PROXY="\${NO_PROXY:-127.0.0.1,localhost,::1}"
export no_proxy="\${no_proxy:-127.0.0.1,localhost,::1}"

unset ALL_PROXY
unset all_proxy

exec $CODEX_REAL_ESCAPED "\$@"
EOF

chmod +x "$CODEX_BIN"

echo "Installed Codex proxy wrapper:"
"$CODEX_BIN" --version

codex_bin_dir="$(dirname "$CODEX_BIN")"
case ":$PATH:" in
  *":$codex_bin_dir:"*) ;;
  *)
    echo "Add Codex to PATH before running it by name:"
    echo "  export PATH=\"$codex_bin_dir:\$PATH\""
    ;;
esac
