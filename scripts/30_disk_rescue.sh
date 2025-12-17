#!/usr/bin/env bash
set -euo pipefail

echo "[1/3] df -h /"
df -h /
echo

echo "[2/3] top of /var/log (largest 15):"
sudo du -ah /var/log --one-file-system 2>/dev/null | sort -rh | head -n 15 || true
echo

read -r -p "Truncate /var/log/syslog and syslog.1 now? (yes/NO) " ans
if [[ "$ans" == "yes" ]]; then
  sudo systemctl stop rsyslog || true
  sudo truncate -s 0 /var/log/syslog || true
  [[ -f /var/log/syslog.1 ]] && sudo truncate -s 0 /var/log/syslog.1 || true
  sudo rm -f /var/log/syslog.*.gz 2>/dev/null || true
  sudo systemctl start rsyslog || true
  echo "Truncate done."
fi

echo "[3/3] df -h /"
df -h /
echo "Next: check logrotate.timer and rsyslog config if syslog regrows abnormally."
