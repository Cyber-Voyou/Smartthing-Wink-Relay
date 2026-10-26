#!/usr/bin/env python3
from pathlib import Path
import re, sys

root=Path(__file__).resolve().parents[1]
files=[p for p in root.rglob('*') if p.is_file() and '.git' not in p.parts and p.name!='audit.py']
forbidden=[r'10\.50\.0\.',r'b4:79:a7:',r'(?i)ha-mqtt',r'(?i)mqtt_password\s*=\s*(?!REPLACE_)\S+']
for path in files:
    if path.suffix in {'.zip','.png','.jpg'}:continue
    text=path.read_text(errors='ignore')
    for pattern in forbidden:
        if re.search(pattern,text):
            raise SystemExit(f"forbidden private value pattern in {path.relative_to(root)}")
print(f"PASS: {len(files)} files audited; no known private values")
