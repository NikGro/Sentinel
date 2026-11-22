#!/bin/sh
# Holt Auswertung, Messdatei und Einzelbilder des letzten Kamera-Tests aus dem Ablaufprotokoll (falls die Artefakte
# nicht erreichbar sind). Aufruf: tools/kamera_aus_protokoll.sh <Zielordner> [Lauf-ID]
set -e
OUT=${1:-kamera}
RUN=${2:-$(gh api "repos/NikGro/Sentinel/actions/workflows/kamera.yml/runs?per_page=1" --jq '.workflow_runs[0].id')}
JOB=$(gh api "repos/NikGro/Sentinel/actions/runs/$RUN/jobs" --jq '.jobs[0].id')
mkdir -p "$OUT/bilder"
gh api "repos/NikGro/Sentinel/actions/jobs/$JOB/logs" > "$OUT/protokoll.log"
# Zeitstempel am Zeilenanfang entfernen.
sed -E 's/^[0-9T:.-]+Z //' "$OUT/protokoll.log" > "$OUT/protokoll.txt"
awk '/=====MESSDATEI-ANFANG=====/{f=1;next}/=====MESSDATEI-ENDE=====/{f=0}f' "$OUT/protokoll.txt" | base64 -d | gunzip > "$OUT/kamera.jsonl" || true
awk '/=====BILDER-ANFANG=====/{f=1;next}/=====BILDER-ENDE=====/{f=0}f' "$OUT/protokoll.txt" | base64 -d | tar -xzf - -C "$OUT/bilder" || true
grep -E "error:|Test Case .* (passed|failed)|Pumpen|Lösen ohne" "$OUT/protokoll.txt" | sort -u || true
ls "$OUT/bilder" | wc -l
