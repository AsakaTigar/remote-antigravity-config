#!/usr/bin/env python3
import json
import pathlib
import sys
import time

import os

user = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("USER", os.getlogin())
p = pathlib.Path(f"/home/{user}/.antigravity-server/data/Machine/settings.json")

if not p.exists():
    print(f"settings.json not found: {p}")
    sys.exit(0)

bak = p.with_suffix(f".json.bak.{int(time.time())}")
bak.write_bytes(p.read_bytes())

d = json.loads(p.read_text(encoding="utf-8"))
for k in ["http.proxy", "http.proxyStrictSSL", "http.proxySupport"]:
    d.pop(k, None)

p.write_text(json.dumps(d, indent=2, ensure_ascii=False), encoding="utf-8")
print("patched:", p)
print("backup :", bak)
