#!/usr/bin/env python3
"""Holt Messdatei und Einzelbilder des Kamera-Tests aus dem Ablaufprotokoll (falls Artefakte nicht erreichbar sind).

Aufruf: tools/kamera_aus_protokoll.py <Zielordner> [Lauf-ID]
Die Blöcke stehen zwischen Zeilen, die genau „=====MESSDATEI-ANFANG=====“ usw. lauten (nur die Ausgabe, nicht das
im Protokoll mit abgedruckte Skript).
"""
import base64, gzip, io, json, os, re, subprocess, sys, tarfile


def gh(path: str) -> str:
    return subprocess.run(["gh", "api", path], check=True, capture_output=True, text=True).stdout


def main() -> None:
    out = sys.argv[1] if len(sys.argv) > 1 else "kamera"
    run = sys.argv[2] if len(sys.argv) > 2 else json.loads(gh("repos/NikGro/Sentinel/actions/workflows/kamera.yml/runs?per_page=1"))["workflow_runs"][0]["id"]
    job = json.loads(gh(f"repos/NikGro/Sentinel/actions/runs/{run}/jobs"))["jobs"][0]["id"]
    log = gh(f"repos/NikGro/Sentinel/actions/jobs/{job}/logs")
    os.makedirs(os.path.join(out, "bilder"), exist_ok=True)
    lines = [re.sub(r"^\d{4}-\d\d-\d\dT[\d:.]+Z ", "", l) for l in log.splitlines()]
    with open(os.path.join(out, "protokoll.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines))

    def block(name: str) -> bytes | None:
        start = end = None
        for i, line in enumerate(lines):
            if line.strip() == f"====={name}-ANFANG=====":
                start = i
            elif line.strip() == f"====={name}-ENDE=====" and start is not None and i > start:
                end = i
        if start is None or end is None:
            return None
        return base64.b64decode("".join(l.strip() for l in lines[start + 1:end]))

    data = block("MESSDATEI")
    if data:
        with open(os.path.join(out, "kamera.jsonl"), "wb") as f:
            f.write(gzip.decompress(data))
        print("Messdatei:", os.path.join(out, "kamera.jsonl"))
    images = block("BILDER")
    if images:
        with tarfile.open(fileobj=io.BytesIO(images), mode="r:gz") as tar:
            tar.extractall(os.path.join(out, "bilder"), filter="data")
        print("Bilder:", len(os.listdir(os.path.join(out, "bilder"))))
    for line in lines:
        if re.search(r"error:|Test Case .* (passed|failed)|Pumpen|Lösen ohne", line):
            print(line[:300])


if __name__ == "__main__":
    main()
