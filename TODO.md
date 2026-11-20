# Offene Punkte

Wünsche, Fehler und technische Arbeiten werden hier gesammelt und zu festen Zeitpunkten gebündelt umgesetzt,
statt jede Änderung sofort einzubauen. Erledigtes wandert mit Version ins CHANGELOG.

## Geplant

### Nächste Runde

- **Doppeltes Profil nach Ab- und Wiederanmelden:**
  - Beim erneuten Anmelden entsteht ein neues Konto, das alte bleibt als Karteileiche stehen und lässt sich in der App nirgends löschen.
  - Gewünscht: altes Profil übernehmen statt neu anlegen, oder zumindest alte Profile und Geräte löschen können.
- **Anheften der Kamera:** Die Karte teleportiert beim Anheften wild durch die Gegend. Neu seit 0.15, vermutlich durch das kurze Festhalten der Zoomstufe.
- **SOS-Knopf:**
  - Den dauerhaften, transparenten weißen Ring außen entfernen.
  - Der Ring, der sich beim Halten füllt, soll innerhalb des roten Liquid-Glass-Knopfs laufen, nicht außen herum.

- **Navigation:**
  - Der eigene Pfeil sitzt jetzt fast zu weit über der unteren Leiste (Beenden-Knopf). Ein Mittelding zwischen vorher und jetzt wäre gut.
  - Beim Start der Navigation ist die Karte viel zu weit herausgezoomt. Vermutlich derselbe Zoom-Sprung wie beim Anheften.

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
  - 0.14: Standortknopf (Anheften, Toleranz beim Zoomen, Kompassrose), SOS-Füllung, flacher eigener Standort,
    Einsteigen der Zielperson, Kreuzungssuche mit Tippfehlern
  - 0.15: Zoom ohne Sprung beim Anheften, Kopplungsschwelle, Tempolimit ohne Navigation, Standortquelle der Ziele,
    ÖPNV-Strecke mit Ebenen
