#!/usr/bin/env bash
set -euo pipefail

echo "========================================="
echo "Restart VS Code Remote Processes"
echo "========================================="

echo
echo "[1] Killing Extension Host processes..."
pkill -u "$USER" -f 'bootstrap-fork --type=extensionHost' || echo "  No Extension Host processes found"

echo
echo "[2] Killing other VS Code Remote processes..."
pkill -u "$USER" -f 'remoteExtensionHost|extensionHost|antigravity|language_server' || echo "  No other processes found"

echo
echo "========================================="
echo "Processes killed"
echo "========================================="
echo
echo "Next steps:"
echo "  1. Reconnect VS Code Remote from your local machine"
echo "  2. Check Output panel for Language Server startup logs"
echo "  3. Verify plugins work correctly (code completion, etc.)"
