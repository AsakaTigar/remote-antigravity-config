#!/usr/bin/env bash
set -euo pipefail

echo "[1/4] Ports:"
ss -lntp | egrep ':(7890|1080|1053)\b' || true
echo

echo "[2/4] DNS:"
getent hosts www.google.com || echo "DNS_FAIL"
echo

echo "[3/4] Node HTTPS:"
node -e 'require("https").get("https://www.google.com",r=>{console.log("status",r.statusCode);r.resume()}).on("error",e=>{console.error("err",e.message)})'
echo

echo "[4/4] Proxy env:"
env | egrep -i '^(http|https|all|no)_proxy=' || true
