#!/usr/bin/env bash
set -euo pipefail

echo "========================================="
echo "Cleanup 1080 Shell Exports"
echo "========================================="

echo
echo "[1] Checking for 1080 references in shell configs..."
grep -nE '127\.0\.0\.1:1080' ~/.bashrc ~/.profile 2>/dev/null || echo "  No references found"

echo
echo "[2] Removing 1080 references (creating backups)..."
sed -i.bak '/127\.0\.0\.1:1080/d' ~/.bashrc ~/.profile

echo
echo "[3] Verification:"
grep -nE '127\.0\.0\.1:1080' ~/.bashrc ~/.profile 2>/dev/null || echo "  ✓ All 1080 references removed"

echo
echo "========================================="
echo "Cleanup complete"
echo "========================================="
echo
echo "Backups created:"
echo "  ~/.bashrc.bak"
echo "  ~/.profile.bak"
echo
echo "Next step:"
echo "  python3 scripts/50_cleanup_vscode_proxy_settings.py"
