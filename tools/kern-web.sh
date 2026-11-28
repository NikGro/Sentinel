#!/usr/bin/env bash
# Baut den gemeinsamen Kern als JavaScript-Modul und legt ihn in Sentinel Web ab (server/web/src/kern).
# Nach Änderungen am Kern ausführen und das Ergebnis mit einchecken; die Server-CI prüft, dass es aktuell ist.
set -euo pipefail
cd "$(dirname "$0")/.."
./gradlew -p kern jsProductionLibraryCompileSync -q
quelle=kern/build/compileSync/js/main/productionLibrary/kotlin
ziel=server/web/src/kern
rm -rf "$ziel"
mkdir -p "$ziel"
cp "$quelle"/*.mjs "$quelle"/*.d.mts "$ziel"/
echo "Kern für das Web aktualisiert: $ziel"
