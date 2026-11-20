# Offene Punkte

Wünsche, Fehler und technische Arbeiten werden hier gesammelt und zu festen Zeitpunkten gebündelt umgesetzt,
statt jede Änderung sofort einzubauen. Erledigtes wandert mit Version ins CHANGELOG.

## Geplant

### Runde 0.14 (Rückmeldung vom 20.11.)

- **SOS-Knopf:** füllt sich beim Halten nicht weiß, Text „SOS“ fehlt – nur ein roter Kreis.
- **Standort-/Kompassknopf neu (wie im Tesla):** Pfeil immer mittig und nach oben, darum eine Kompassrose mit Himmelsrichtungen, die sich mit der Karte dreht. Angeheftet: Pfeil gefüllt; gelöst: Pfeil hohl. Erster Druck heftet immer an (Fahrtrichtung/Kompass, nah, flacher Navi-Winkel), weiterer Druck wechselt zu Norden oben (von oben, senkrecht) und zurück. Keine Plus/Minus-Knöpfe. Zwei-Finger-Zoom mit kleinen seitlichen Bewegungen löst die Kopplung nicht, erst bewusstes Verschieben über eine Schwelle; dann bleibt die Karte so ausgerichtet, wie sie gerade ist.
- **Eigener Standort:** flach auf der Karte liegender Kreis (kippt mit der Karte), gleich groß, mit Symbol zu Fuß / Auto / Bahn wie im Dreier-Umschalter; Straßenname darunter, solange angeheftet.
- **Andere Kräfte:** flache, zum Bildschirm ausgerichtete Symbole wie bisher, mit Symbol der Fortbewegung. Fahrzeuge/Kräfte als Rechteck in Blau-Lila mit Auto/Fußgänger/Bahn; Zielpersonen und -objekte als rotes Rechteck mit Auto/Fußgänger/Bahn/Haus.
- **Ziele-Tab wie Kräfte-Tab:** drei getrennte Abschnitte (Zielfahrzeuge, Zielpersonen, Zielobjekte) mit Schaltern zum Ein-/Ausblenden auf der Karte; Suche (Kennzeichen, Funkrufname, Spitzname) in Kräfte und Ziele, Treffer weiter nach Abschnitten getrennt.
- **Zielperson steigt ein:** wie bei den Kräften – „Fahrzeug“ fragt mit demselben Dialog nach dem Zielfahrzeug (oder sonstiges/neues), „ÖPNV“ nach dem ÖPNV-Fahrzeug; auf der Karte nur noch ein Symbol.
- **Kräfte-Tab:** Fahrzeugsymbol mit gleichem Seitenverhältnis (quadratisch, abgerundet); Plus zum Hinzufügen ergänzen.
- **Überschriften:** Ziele-Titel und Plus auf dieselbe Höhe wie bei Kräfte und Chat; im Chat das Plus auf Höhe der Überschrift.
- **Untere Leiste der Karte:** A-Knopf, Dreier-Umschalter und Lageleiste so hoch wie die runden Knöpfe und die Suchleiste.
- **Plus-Menü ÖPNV:** nur noch ein Eintrag „ÖPNV“ (die ÖPNV-Karte), darüber Haltestellen, Linien und Fahrzeuge übernehmen; keine mehrzeiligen Knöpfe, Auswahl ohne Häkchen-Liste.
- **Einheitliche Oberfläche:** gleiche Aufgaben (Ort setzen, Auswahl, Formulare) überall mit derselben Ansicht und demselben Design; App-weit mit UI-Design-Skills prüfen.

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
