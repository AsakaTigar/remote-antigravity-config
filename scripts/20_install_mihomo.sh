#!/usr/bin/env bash
set -euo pipefail

echo "========================================="
echo "Install mihomo (clash-for-linux-install)"
echo "========================================="

WORKDIR="${WORKDIR:-/mnt/t2-6tb/_src}"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

echo
echo "[1] Cloning clash-for-linux-install..."
if [ ! -d clash-for-linux-install ]; then
  git clone --depth 1 https://github.com/nelvko/clash-for-linux-install.git
  echo "  Cloned successfully"
else
  echo "  Already exists, skipping clone"
fi

cd clash-for-linux-install

echo
echo "[2] Running installer..."
echo "  You will be prompted for a subscription URL."
echo "  ⚠️  DO NOT paste it into any file tracked by git!"
echo

sudo bash install.sh

echo
echo "========================================="
echo "Installation complete"
echo "========================================="
echo
echo "Next steps:"
echo "  1. Run: bash scripts/30_enable_tun_and_test.sh"
echo "  2. Verify DNS and Node HTTPS work"
