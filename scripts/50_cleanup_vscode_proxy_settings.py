#!/usr/bin/env python3
"""
Clean up VS Code Remote proxy settings from settings.json
Removes: http.proxy, http.proxyStrictSSL, http.proxySupport
"""

import json
from pathlib import Path

def main():
    settings_path = Path.home() / ".antigravity-server" / "data" / "Machine" / "settings.json"
    
    if not settings_path.exists():
        print(f"settings.json not found: {settings_path}")
        print("Skipping cleanup (VS Code Remote may not be configured yet)")
        return 0
    
    print(f"Reading: {settings_path}")
    settings = json.loads(settings_path.read_text(encoding="utf-8"))
    
    # Remove proxy-related keys
    removed_keys = []
    for key in ["http.proxy", "http.proxyStrictSSL", "http.proxySupport"]:
        if key in settings:
            settings.pop(key)
            removed_keys.append(key)
    
    if removed_keys:
        print(f"Removed keys: {', '.join(removed_keys)}")
        settings_path.write_text(json.dumps(settings, indent=2, ensure_ascii=False), encoding="utf-8")
        print(f"✓ Patched: {settings_path}")
    else:
        print("✓ No proxy settings found (already clean)")
    
    return 0

if __name__ == "__main__":
    exit(main())
