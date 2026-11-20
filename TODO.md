# Offene Punkte

Wünsche, Fehler und technische Arbeiten werden hier gesammelt und zu festen Zeitpunkten gebündelt umgesetzt,
statt jede Änderung sofort einzubauen. Erledigtes wandert mit Version ins CHANGELOG.

## Geplant

### Nächste Runde

- **Tab-Kopfzeilen (Ziele, Kräfte, Chat, Mehr):** Den Plus-Knopf oben auf die Höhe des großen Titels setzen. Die
  feste Leiste oben beim Scrollen mit einem Verlauf ins Transparente auslaufen lassen statt mit harter Kante.
- **ÖPNV-Ansicht, „Hierhin navigieren“:** Der Knopf ist in den Einstellungen (Bearbeiten) gelandet, gehört aber in die
  Übersicht (Ansicht des Objekts).
- **ÖPNV-Fahrzeuge ruckeln wieder:** Sie gleiten nicht, sondern springen in kleinen Schritten. Ursache gründlich
  suchen (Takt 0,5 s, Kamera-Nachführung, Neuberechnung der Position) und dauerhaft beheben.
- **Navigation findet keine Route:** Das Routing (Valhalla) deckt Hamburg, Schleswig-Holstein und Niedersachsen ab.
  Der Valhalla-Log zeigt „No suitable edges near location“, also keine Straße nah genug am Start- oder Zielpunkt
  (z. B. mitten auf einem Platz). Lösung: Suchradius für das Einrasten auf die Straße vergrößern (`radius`/
  `search_cutoff` je Punkt) und, falls nötig, auf Fußwege ausweichen, statt die Route zu verwerfen. Liegt der Ort
  außerhalb dieser drei Länder, die Abdeckung erweitern.
- **Kamera angeheftet (3D): Winkel und Zoom von Hand gründlich lösen.** Neigen und Zoomen mit zwei Fingern
  funktionieren beim Anheften wieder nicht richtig. Diesmal in Ruhe und vollständig umsetzen. Anforderungen:
  - Angeheftet folgt die Kamera dem eigenen Standort (und in 3D der Fahrtrichtung) ohne Zittern und ohne ständige
    Kamerafahrten im Stand.
  - Zoomen (Zwei-Finger-Zusammenziehen) und Neigen (zwei Finger senkrecht wischen) ändern Abstand bzw. Winkel, ohne
    dass die Kopplung gelöst wird. Die gewählten Werte bleiben beim weiteren Folgen erhalten und springen nicht
    zurück.
  - Erst bewusstes Verschieben mit einem Finger löst die Kopplung.
  - Standard beim Anheften: 3D mit Kompass 400 m, Norden oben 1500 m; Navigation wie bisher.
  - Vor der Umsetzung das Zusammenspiel von Nachführen (`followTick`), Gestenerkennung (`isUserCameraChange`) und
    MapKit-Kamerapositionen sauber neu entwerfen, statt weitere Schwellen nachzuschieben; mit dem
    Kamerawerte-Overlay (Mehr › Entwickler) auf dem Gerät prüfen.
- **Straßenverzeichnis beobachten:** Läuft seit 0.18 mit 2 GB Container-Speicher, Node.js darf bis 1,5 GB nutzen;
  nach dem Start belegt der Server etwa 380 MB. Den Speicher beim wöchentlichen Neuladen über Overpass im Blick
  behalten. Wird es knapp, die Straßen in SQLite statt im Arbeitsspeicher halten und in Kacheln laden.
- **Fahrspuren beim Abbiegehinweis beobachten:** Die Anzeige gibt es; bei Gelegenheit prüfen, ob sie zuverlässig
  erscheint.
- **SinoTrack per USB:** Mit dem echten Tracker prüfen, ob er die Befehle über USB annimmt (Baudrate, Befehlsform).
  Den Stand aus dem Desktop-Chat abgleichen und die APN der Beach SIM als Beispiel eintragen.
- **Kreuzungssuche nach dem Update prüfen:** Kommen plausible Straßenecken jetzt zuverlässig, auch nach dem ersten Buchstaben der zweiten Straße? Falls nicht: Beispiel nachstellen.

### Karte, Kompass und Navigation

- **Zoom beim Folgen auf dem Gerät prüfen (0.11: Zoom-Knöpfe, nähere Standard-Zoomstufe):** Die Toleranz für Zwei-Finger-Gesten legt MapKit selbst fest. Auf dem Gerät prüfen, ob die Zoom-Knöpfe reichen.
- **App-Absturz während aktiver Navigation (0.9: mögliche Ursache abgesichert):** Dafür ist ein Absturzbericht nötig, zu finden unter Einstellungen › Datenschutz & Sicherheit › Analyse & Verbesserungen › Analysedaten › „Sentinel-…“.

### Marker und Oberfläche

- **Zielperson: Karte friert ein (0.13: ÖPNV-Positionsberechnung als wahrscheinliche Ursache stark beschleunigt):** Offene Rückfrage, welches Symbol genau gemeint ist: im Plus-Menü, im Editor („Unterwegs“) oder auf der Karte. Mit 0.13 erneut prüfen.

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
  - 0.17: Verlauf auf der Karte, Tracker-Ansicht mit Akku und Befehlen (welche Werte der SinoTrack tatsächlich
    meldet, zeigen die letzten Nachrichten), Navigation „Halte voraus“, Kompass ohne Sprung
  - 0.18: Cluster, flacher Navi-Pfeil, Fotoauswahl, ÖPNV-Schritte, Dienst über Instanzen, Kreuzungsvorschläge,
    Sentinel Web mit Zugangscode
  - 0.20: Geofence-Alarm (Verlassen und Betreten), Standortverlauf auf der Karte, reduzierte Verlaufskarte
