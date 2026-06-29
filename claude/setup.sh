#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Step 1/2: Download and install Claude Code ==="
"$SCRIPT_DIR/download.sh"

echo ""
echo "=== Step 2/2: Create proxy wrapper ==="
"$SCRIPT_DIR/wrapper.sh"

echo ""
echo "Claude Code server setup completed."
echo ""
echo "Next steps:"
echo "  1. Create ~/.claude/provider.env with your API key:"
echo '     export ANTHROPIC_AUTH_TOKEN="sk-..."'
echo "  2. Create ~/.claude/settings.json with your API endpoint and model:"
echo '     { "env": { "ANTHROPIC_BASE_URL": "https://...", "ANTHROPIC_MODEL": "..." } }'
echo "  3. Run: claude"
