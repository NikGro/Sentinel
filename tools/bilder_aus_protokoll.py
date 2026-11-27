#!/usr/bin/env python3
"""Holt Bildschirmfotos aus einem Ablaufprotokoll (zwischen =====BILD name===== und =====BILD-ENDE=====)."""
import base64, os, re, sys

protokoll, ziel = sys.argv[1], sys.argv[2]
os.makedirs(ziel, exist_ok=True)
text = open(protokoll, errors="replace").read()
for name, daten in re.findall(r"=====BILD (\S+)=====\s*\n(?:\S+ )?([A-Za-z0-9+/=]+)", text):
    pfad = os.path.join(ziel, os.path.basename(name))
    open(pfad, "wb").write(base64.b64decode(daten))
    print(pfad)
