# Offene Punkte

Wünsche, Fehler und technische Arbeiten werden hier gesammelt und zu festen Zeitpunkten gebündelt umgesetzt,
statt jede Änderung sofort einzubauen. Erledigtes wandert mit Version ins CHANGELOG.

## Geplant

### Karte, Kompass und Navigation

- **Zoom beim Folgen auf dem Gerät prüfen (0.11: Zoom-Knöpfe, nähere Standard-Zoomstufe):** Die Toleranz für Zwei-Finger-Gesten legt MapKit selbst fest. Auf dem Gerät prüfen, ob die Zoom-Knöpfe reichen.
- **App-Absturz während aktiver Navigation (0.9: mögliche Ursache abgesichert):** Dafür ist ein Absturzbericht nötig, zu finden unter Einstellungen › Datenschutz & Sicherheit › Analyse & Verbesserungen › Analysedaten › „Sentinel-…“.

### Marker und Oberfläche

- **Zielperson: Karte friert ein (0.13: ÖPNV-Positionsberechnung als wahrscheinliche Ursache stark beschleunigt):** Offene Rückfrage, welches Symbol genau gemeint ist: im Plus-Menü, im Editor („Unterwegs“) oder auf der Karte. Mit 0.13 erneut prüfen.

### Tracker

- **SinoTrack „Test“ (7026222172) sendet nicht:** Am Router die Portweiterleitung TCP 5013 zur Synology prüfen. Am Gerät die SMS-Einrichtung prüfen: öffentliche Adresse, Port 5013, Protokoll H02.

### Codebase-Qualität

- **Laufende Bereinigung:** `MapScreen.swift` ist mit über 1000 Zeilen der größte Brocken. Dort weiter in kleinere Bausteine aufteilen, z. B. Karteninhalt, Leisten und Tippen/Zeichnen. Die Server-Tests decken Instanzen, Pakete, PAJ-Konten und Querstraßen ab. Die App-Seite hat bisher nur den UI-Rundgang.

### Noch praktisch zu überprüfen

- **Auf dem Gerät prüfen:**
  - Ferrostar-Navigation mit Querstraßen
  - Fahrzeugsymbol nach dem Aussteigen
  - Instanzwechsel mit Hinweisen aus anderen Instanzen (Banner und Mitteilung)
  - Paket übernehmen
  - PAJ-Tracker mit eigenem Konto
