# Offene Punkte

Wünsche, Fehler und technische Arbeiten werden hier gesammelt und zu festen Zeitpunkten gebündelt umgesetzt,
statt jede Änderung sofort einzubauen. Erledigtes wandert mit Version ins CHANGELOG.

## Geplant

### Nächste Runde

- **Straßenverzeichnis beobachten:** Läuft mit 2 GB Container-Speicher, Node.js darf bis 1,5 GB nutzen. Stand
  22.11.: 286 MB im Betrieb, kein Neustart seit dem Update. Das nächste wöchentliche Neuladen über Overpass ist um
  den 27.11.; danach den Speicher prüfen. Wird es knapp, die Straßen in SQLite statt im Arbeitsspeicher halten.
- **Fahrspuren beim Abbiegehinweis beobachten:** Die Anzeige gibt es; bei Gelegenheit prüfen, ob sie zuverlässig
  erscheint.
- **SinoTrack per USB:** Mit dem echten Tracker prüfen, ob er die Befehle über USB annimmt (Baudrate, Befehlsform).
  Den Stand aus dem Desktop-Chat abgleichen und die APN der Beach SIM als Beispiel eintragen.
- **Kreuzungssuche nach dem Update prüfen:** Kommen plausible Straßenecken jetzt zuverlässig, auch nach dem ersten Buchstaben der zweiten Straße? Falls nicht: Beispiel nachstellen.

### Karte, Kompass und Navigation

- **Straßenschild am eigenen Punkt**: Text mit aktueller Straße und Fahrtrichtung kleiner (etwa wie die eigene
  Beschriftung/Funkrufname) und zweizeilig: darunter „Ecke <Querstraße>“, die nächstgelegene Querstraße (vor oder hinter
  einem), z. B. „Nordschleswiger Straße Richtung Nord“ / „Ecke Straßburger Straße“. Ersetzt die Querstraßen-Schilder
  entlang der Route, die auf dem Gerät nicht erscheinen (prüfen, warum `CrossStreetLayer` nichts zeigt).
- (Fix liegt auf dem Arbeitszweig, kommt mit der nächsten Version) Sehr schneller Wisch löste angeheftet nicht, wenn
  zwischen Beginn und Ende keine Bewegung gemeldet wurde (Kamera-Test 0.33).
- **Navigation zu einem Zielfahrzeug mit drei Modi** (wie der Schalter beim ÖPNV): normal, parallel, Vorlauf. Nur
  sinnvoll mit Live-Standort samt Richtung (Tracker oder A-Position), nicht bei von Hand gesetztem Standort.
  - *Vorlauf* (zuerst umsetzen, gut machbar): Straße des Ziels über den Straßenindex/Valhalla bestimmen, in
    Fahrtrichtung die nächste (bzw. übernächste) Kreuzung suchen und dorthin navigieren; ist das Ziel daran vorbei,
    zur nächsten Kreuzung neu berechnen. Annahme: Das Ziel fährt geradeaus weiter.
  - *Parallel* (machbar, heuristisch): Route zu einem Punkt seitlich voraus berechnen und die Straße des Ziels für
    Valhalla sperren (Ausschlussfläche entlang seiner Straße), regelmäßig neu. Gibt es keine Parallelstraße (Umweg zu
    groß, z. B. Landstraße), automatisch normal navigieren.
- Überschlagende Navigation und Navigation zu Haltestellen (1, 2, 3 voraus): Keine zusätzlichen Haltestellenmarker mit
  Nummer daneben (`StopsLayer`), die doppelt neben schon angelegten Haltestellen stehen und nach dem Ende liegen
  bleiben. Stattdessen: Ist die Haltestellenebene eingeschaltet, die Ziel-Haltestelle bzw. die eigene Position im
  Überschlagen dort hervorheben. Ohne Haltestellenebene darf ein Marker erscheinen, der aber wieder verschwindet bzw.
  die Hervorhebung endet, sobald die Navigation endet oder zur nächsten Haltestelle weitergeht.
- **App-Absturz während aktiver Navigation (0.9: mögliche Ursache abgesichert):** Dafür ist ein Absturzbericht nötig, zu finden unter Einstellungen › Datenschutz & Sicherheit › Analyse & Verbesserungen › Analysedaten › „Sentinel-…“.

### Marker und Oberfläche

- **Ebene leeren**: Unter „Ebenen und Pakete“ fehlt bei den Ebenen (mindestens der Lage-Ebene) die Möglichkeit, alle
  Objekte der Ebene zu löschen. Im Menüpunkt bzw. in der Ansicht der Ebene selbst unterbringen, mit Rückfrage.
- **Kurzübersichten als Variante 2** (Skizzen vom 23.11.): Statt der Fenster mit großen „Schließen“/„Bearbeiten“-
  Knöpfen überall schwebende Glaskarten mit kleinen runden Knöpfen (Hinführen blau, Bearbeiten, Schließen) für
  Marker, Objekte, Zielpersonen, Zielfahrzeuge, ÖPNV-Linien und den GPS-Verlauf. Umsetzung als iOS-26-Fenster mit
  Stufen: niedrig schwebend als Karte, hochgezogen halbe Höhe bzw. fast Vollbild mit allen Angaben; Karte dahinter
  in der niedrigen Stufe bedienbar.
- Beschriftung auf Flächen (`AreaLabelLayer`) schwer lesbar wegen Glow: Text in der Farbe der Fläche (deckend, nicht
  transparent) mit festem Rand von wenigen Pixeln statt Glow.
- **Zielperson: Karte friert ein (0.13: ÖPNV-Positionsberechnung als wahrscheinliche Ursache stark beschleunigt):** Offene Rückfrage, welches Symbol genau gemeint ist: im Plus-Menü, im Editor („Unterwegs“) oder auf der Karte. Mit 0.13 erneut prüfen.

### Codebase-Qualität

- **Build-Pipeline beschleunigen** (heute ~45 min bis SideStore): main übernimmt das getestete App-Paket des
  Arbeitszweigs statt neu zu bauen; Cache für Swift-Pakete/Build; Archiv parallel zum Rundgang; schnelle Spur
  (Bauen + Unit-Tests) für kleine Fixes, Kamera-Test nur bei Änderungen an der Kartensteuerung.

- **Laufende Bereinigung:** `MapScreen` ist inzwischen auf fünf Dateien verteilt (Hauptdatei gut 400 Zeilen). Offen
  bleiben App-Tests über den UI-Rundgang hinaus, z. B. für die ÖPNV-Bewegung (`TransitSimulation`) und das
  Überschlagen.

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
  - 0.17: Verlauf auf der Karte, Tracker-Ansicht mit Akku und Befehlen (welche Werte der SinoTrack tatsächlich
    meldet, zeigen die letzten Nachrichten), Navigation „Halte voraus“, Kompass ohne Sprung
  - 0.18: Cluster, flacher Navi-Pfeil, Fotoauswahl, ÖPNV-Schritte, Dienst über Instanzen, Kreuzungsvorschläge,
    Sentinel Web mit Zugangscode
  - 0.20: Geofence-Alarm (Verlassen und Betreten), Standortverlauf auf der Karte, reduzierte Verlaufskarte
  - 0.21: Anheften mit Zoomen/Neigen/Verschieben (mit dem Kamerawerte-Overlay), Route von einem Platz aus, ÖPNV-Gleiten,
    Kopfzeilen mit Verlauf
  - 0.22: Antippen und Marker setzen, Verlauf ohne Vorauswahl
  - 0.23: Anheften mit MapKit-Verfolgung (Zoomen, Kippen, Lösen durch Verschieben/Drehen, Navi), ÖPNV-Halten und
    Kurven, Hauptmenü mit zwei Tabs, Argus als Paket
  - 0.24: Überschlagend zu einem ÖPNV-Fahrzeug mit mehreren Fahndern (über Ziel, A und Fahrzeug)
  - 0.25: Querstraßen-Sprechblasen, Antippen von ÖPNV-Fahrzeugen und Datumsfeldern beim ersten Mal
  - 0.26: ÖPNV ohne Wackeln, Haltestellen nah auf der ÖPNV-Karte
  - 0.27: Anheften mit Gesten aus MapKits Erkennern (Zoomen/Kippen behalten, Verschieben/Drehen lösen, kein Pumpen)
