#!/usr/bin/env bash
set -euo pipefail

U="${1:-$USER}"
HOME_DIR="$(eval echo "~${U}")"

for f in "${HOME_DIR}/.bashrc" "${HOME_DIR}/.profile"; do
  if [[ -f "$f" ]]; then
    cp -a "$f" "${f}.bak.$(date +%s)" || true
    sed -i '/127\.0\.0\.1:1080/d' "$f"
  fi
done

echo "Cleaned 1080 lines from .bashrc/.profile for user: ${U}"
echo "Open a new shell or run: source ~/.bashrc"
