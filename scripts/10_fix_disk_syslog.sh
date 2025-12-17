#!/usr/bin/env bash
set -euo pipefail

echo "========================================="
echo "Fix Disk: Clean syslog"
echo "========================================="

echo
echo "[1] Top files under /var/log:"
sudo du -ah /var/log --one-file-system 2>/dev/null | sort -rh | head -n 30 || true

echo
echo "[2] Stopping rsyslog..."
sudo systemctl stop rsyslog || true

echo
echo "[3] Truncating syslog files..."
sudo truncate -s 0 /var/log/syslog || true
if [ -f /var/log/syslog.1 ]; then 
    sudo truncate -s 0 /var/log/syslog.1 || true
fi

echo
echo "[4] Removing old compressed logs..."
sudo rm -f /var/log/syslog.*.gz 2>/dev/null || true

echo
echo "[5] Starting rsyslog..."
sudo systemctl start rsyslog || true

echo
echo "[6] Disk usage after cleanup:"
df -h /

echo
echo "========================================="
echo "Cleanup complete"
echo "========================================="
echo
echo "If disk is still full, check for deleted files held by processes:"
echo "  sudo lsof +L1 | sort -k7 -h | tail -n 20"
