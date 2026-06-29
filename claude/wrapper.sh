#!/usr/bin/env bash
set -euo pipefail

DEFAULT_CLAUDE_BIN_DIR="${CLAUDE_INSTALL_DIR:-${HOME:-/root}/.local/bin}"
CLAUDE_BIN="${CLAUDE_BIN:-$DEFAULT_CLAUDE_BIN_DIR/claude}"
CLAUDE_REAL="${CLAUDE_REAL:-$DEFAULT_CLAUDE_BIN_DIR/claude-real}"
CLAUDE_REAL_ESCAPED="$(printf '%q' "$CLAUDE_REAL")"

if [ ! -x "$CLAUDE_REAL" ]; then
  echo "Claude Code real binary is not installed: $CLAUDE_REAL" >&2
  echo "Run download.sh first." >&2
  exit 1
fi

mkdir -p "$(dirname "$CLAUDE_BIN")"

cat > "$CLAUDE_BIN" <<'WRAPPER_EOF'
#!/usr/bin/env bash
set -euo pipefail

# Remote server accesses internet through local reverse proxy.
export HTTP_PROXY="${HTTP_PROXY:-http://127.0.0.1:18080}"
export HTTPS_PROXY="${HTTPS_PROXY:-http://127.0.0.1:18080}"
export http_proxy="${http_proxy:-http://127.0.0.1:18080}"
export https_proxy="${https_proxy:-http://127.0.0.1:18080}"

# Keep localhost traffic out of proxy.
export NO_PROXY="${NO_PROXY:-127.0.0.1,localhost,::1}"
export no_proxy="${no_proxy:-127.0.0.1,localhost,::1}"

# Avoid ALL_PROXY breaking localhost / internal tools.
unset ALL_PROXY
unset all_proxy

# Load current provider API key.
if [ -f "$HOME/.claude/provider.env" ]; then
  # shellcheck disable=SC1091
  source "$HOME/.claude/provider.env"
fi

if [ -z "${ANTHROPIC_AUTH_TOKEN:-}" ]; then
  echo "ERROR: ANTHROPIC_AUTH_TOKEN is not set." >&2
  echo "Please create $HOME/.claude/provider.env with:" >&2
  echo '  export ANTHROPIC_AUTH_TOKEN="sk-..."' >&2
  exit 1
fi

exec CLAUDE_REAL_PLACEHOLDER "$@"
WRAPPER_EOF

# Replace placeholder with the real binary path.
sed -i "s|CLAUDE_REAL_PLACEHOLDER|$CLAUDE_REAL_ESCAPED|" "$CLAUDE_BIN"

chmod +x "$CLAUDE_BIN"

# Ensure ~/.local/bin is in PATH via shell rc files.
claude_bin_dir="$(dirname "$CLAUDE_BIN")"
path_line="export PATH=\"$claude_bin_dir:\$PATH\""
for rc_file in "${HOME:-/root}/.bashrc" "${HOME:-/root}/.zshrc"; do
  if [ -e "$rc_file" ] && ! grep -Fqx "$path_line" "$rc_file"; then
    printf '\n%s\n' "$path_line" >> "$rc_file"
  fi
done

# For root, also symlink to /usr/local/bin if not already taken.
if [ "$(id -u)" -eq 0 ] && [ "$CLAUDE_BIN" != "/usr/local/bin/claude" ]; then
  if [ ! -e /usr/local/bin/claude ] || [ "$(readlink /usr/local/bin/claude 2>/dev/null || true)" = "$CLAUDE_BIN" ]; then
    ln -sfn "$CLAUDE_BIN" /usr/local/bin/claude
  fi
fi

echo "Installed Claude Code proxy wrapper:"
"$CLAUDE_BIN" --version

case ":$PATH:" in
  *":$claude_bin_dir:"*) ;;
  *)
    if ! command -v claude >/dev/null 2>&1; then
      echo "Add Claude to PATH before running it by name:"
      echo "  export PATH=\"$claude_bin_dir:\$PATH\""
    fi
    ;;
esac
