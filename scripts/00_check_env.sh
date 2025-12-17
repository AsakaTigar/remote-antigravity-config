#!/usr/bin/env bash
set -euo pipefail

echo "========================================="
echo "Environment Check"
echo "========================================="

echo
echo "[1] Disk usage:"
df -h /

echo
echo "[2] Listening ports (1080/7890):"
ss -lntp 2>/dev/null | egrep ':(1080|7890)\b' || echo "  No 1080 or 7890 ports listening"

echo
echo "[3] Proxy environment variables:"
env | egrep -i '(^|_)http_proxy=|(^|_)https_proxy=|(^|_)all_proxy=|LD_PRELOAD' || echo "  No proxy env vars set"

echo
echo "[4] Check for 1080 leftovers in shell configs:"
grep -nE '127\.0\.0\.1:1080' ~/.bashrc ~/.profile 2>/dev/null || echo "  No 1080 references found"

echo
echo "[5] Check mihomo/clash status:"
if command -v clashctl &> /dev/null; then
    echo "  clashctl found"
    clashctl tun status 2>/dev/null || echo "  TUN status: unknown"
else
    echo "  clashctl not found (mihomo not installed)"
fi

echo
echo "========================================="
echo "Check complete"
echo "========================================="
