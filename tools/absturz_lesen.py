#!/usr/bin/env python3
"""Liest einen iOS-Absturzbericht (.ips) und gibt Ausnahme und abgestürzten Faden mit Symbolen aus."""
import json
import sys

text = open(sys.argv[1], encoding="utf-8", errors="replace").read()
header, _, body = text.partition("\n")
data = json.loads(body)
print("Prozess:", data.get("procName"), "Ausnahme:", json.dumps(data.get("exception")), "Grund:", json.dumps(data.get("termination", {}))[:400])
if "asi" in data:
    print("Hinweis:", json.dumps(data["asi"])[:1500])
images = data.get("usedImages", [])
for thread in data.get("threads", []):
    if not thread.get("triggered"):
        continue
    for i, frame in enumerate(thread.get("frames", [])[:40]):
        image = images[frame.get("imageIndex", 0)].get("name", "?") if frame.get("imageIndex", -1) < len(images) else "?"
        print(f"{i:3d} {image:28.28s} {frame.get('symbol', '?')} +{frame.get('symbolLocation', '')}  {frame.get('sourceFile', '')}:{frame.get('sourceLine', '')}")
