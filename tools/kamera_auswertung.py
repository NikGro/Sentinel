#!/usr/bin/env python3
"""Auswertung des Kamera-Tests (Artefakt „Kamera-…“ aus .github/workflows/kamera.yml).

Aufruf: tools/kamera_auswertung.py <Ordner mit kamera.jsonl und kamera.mp4> [Bilder je Sekunde]

- Liest die Messdatei der App (eine Zeile je Kamerabewegung, dazu Gesten- und Anheft-Ereignisse) und gibt eine
  Zeitachse aus: Abstand, Winkel, Richtung, Anheft-Modus, laufende Geste.
- Markiert Pumpen: Der Abstand wechselt mehrfach die Richtung (rein/raus), während keine Geste läuft.
- Markiert ungewolltes Lösen: Wechsel auf „none“ ohne vorheriges Verschieben oder Drehen.
- Zerlegt das Video mit ffmpeg in Einzelbilder (Standard 2 je Sekunde) nach <Ordner>/bilder/.
"""
import json
import os
import subprocess
import sys


def main() -> None:
    folder = sys.argv[1] if len(sys.argv) > 1 else "."
    fps = sys.argv[2] if len(sys.argv) > 2 else "2"
    path = os.path.join(folder, "kamera.jsonl")
    rows, events = [], []
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            try:
                item = json.loads(line)
            except json.JSONDecodeError:
                continue
            (events if "ereignis" in item else rows).append(item)
    print(f"{len(rows)} Kamerawerte, {len(events)} Ereignisse")

    # Zeitachse, auf 0,25 s verdichtet.
    timeline = sorted([(r["t"], "kamera", r) for r in rows] + [(e["t"], "ereignis", e) for e in events], key=lambda x: x[0])
    last_print = -1.0
    for t, kind, item in timeline:
        if kind == "ereignis":
            print(f"{t:8.2f}  >> {item['ereignis']}")
        elif t - last_print >= 0.25:
            last_print = t
            print(f"{t:8.2f}  pin={item['pin']:<7} d={item['d']:7.0f} p={item['p']:4.0f} h={item['h']:5.0f} geste={item['geste']}" + (f" symbol={(item['sx']**2 + item['sy']**2) ** 0.5:4.0f}" if 'sx' in item else ""))

    # Pumpen: Vorzeichenwechsel der Abstandsänderung ohne Geste, innerhalb von 3 s.
    pumps, previous, direction, flips = [], None, 0, []
    for r in rows:
        if previous is not None and r["geste"] == 0 and r["pin"] != "none":
            delta = r["d"] - previous["d"]
            if abs(delta) > 2:
                new = 1 if delta > 0 else -1
                if direction and new != direction:
                    flips.append(r["t"])
                    flips = [f for f in flips if r["t"] - f < 3]
                    if len(flips) >= 3:
                        pumps.append(r["t"])
                        flips = []
                direction = new
        previous = r
    print("\nPumpen (Zoom rein/raus ohne Geste):", ", ".join(f"{t:.1f}s" for t in pumps) or "keins")

    # Lösen ohne Verschieben oder Drehen davor.
    unexpected, recent, pinned_once = [], [], False
    for t, kind, item in timeline:
        if kind != "ereignis":
            continue
        name = item["ereignis"]
        if name.startswith("pin ") and name != "pin none":
            pinned_once = True
        if name.startswith("panned") or name.startswith("rotated") or name == "released":
            recent.append(t)
        # Der Anfangszustand („pin none“ beim Start) zählt nicht.
        if name == "pin none" and pinned_once and not any(t - r < 1.5 for r in recent):
            unexpected.append(t)
    print("Lösen ohne Verschieben/Drehen:", ", ".join(f"{t:.1f}s" for t in unexpected) or "keins")

    video = os.path.join(folder, "kamera.mp4")
    if os.path.exists(video):
        out = os.path.join(folder, "bilder")
        os.makedirs(out, exist_ok=True)
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", video, "-vf", f"fps={fps},scale=390:-1", os.path.join(out, "bild-%04d.png")], check=False)
        print(f"\nEinzelbilder: {out} ({len(os.listdir(out))} Bilder, {fps} je Sekunde)")


if __name__ == "__main__":
    main()
