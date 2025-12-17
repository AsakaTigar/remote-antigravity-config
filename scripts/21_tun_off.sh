#!/usr/bin/env bash
set -euo pipefail
command -v clashctl >/dev/null 2>&1 || { echo "clashctl not found"; exit 1; }
clashctl tun off
clashctl status || true
