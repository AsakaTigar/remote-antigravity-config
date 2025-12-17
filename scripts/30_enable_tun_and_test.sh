#!/usr/bin/env bash
set -euo pipefail

echo "========================================="
echo "Enable TUN and Test"
echo "========================================="

echo
echo "[1] Enabling TUN mode..."
clashctl tun on

echo
echo "[2] Clearing proxy environment variables..."
unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY no_proxy || true

echo
echo "[3] Testing DNS resolution..."
echo -n "  getent hosts www.google.com: "
getent hosts www.google.com || echo "FAILED"

echo
echo "[4] Testing Node HTTPS..."
echo -n "  Node HTTPS status: "
node -e 'require("https").get("https://www.google.com",r=>{console.log(r.statusCode);r.resume()}).on("error",e=>{console.error("ERROR:",e.message)})'

echo
echo "========================================="
echo "Test complete"
echo "========================================="
echo
echo "If tests passed, proceed to:"
echo "  bash scripts/40_cleanup_1080_shell_exports.sh"
