# Offene Punkte

Wünsche, Fehler und technische Arbeiten werden hier gesammelt und zu festen Zeitpunkten gebündelt umgesetzt,
statt jede Änderung sofort einzubauen. Erledigtes wandert mit Version ins CHANGELOG.

## Geplant

### Nächste Runde

- **Navigation, Anzeige unten:** Verbleibende Fahrtdauer groß und fett, die Ankunftsuhrzeit klein unten neben den
  Kilometern (heute umgekehrt).
- **„Zu Objekten navigieren“ nur mit aktiven Elementen:** Zum Beispiel erscheinen bei den Zielen zwei Fahrzeuge,
  obwohl eins vorübergehend deaktiviert ist. Deaktivierte Fahrzeuge (je Instanz) und ausgeblendete Ziele weglassen.
- **Mehr › Ebenen und Pakete aufräumen:**
  - „Paket vorbereiten“ und andere Reste entfernen, das läuft jetzt über das Instanzenmenü.
  - Neu: Knopf „Paket aus der Bibliothek importieren“.
  - Argus Predict bleibt vorerst so; es soll später komplett integriert werden.
- **GPS-Tracker:** Die SMS-Befehle für SinoTrack in der App wieder ausblenden; das Einrichten läuft künftig über den
  PC (siehe Sentinel Web).
- **ÖPNV-Fahrzeuge** (erst mit 0.17 nochmal prüfen):
  - Fahrzeuge verschwinden nicht zuverlässig fünf Minuten nach dem Ende der Fahrt.
  - In der Fahrzeugansicht wieder den Countdown zeigen, wie lange das Fahrzeug noch da ist (gab es zeitweise, war
    beliebt).
- **Zielfahrzeug und Zielperson, Ansicht:**
  - Der Abstand zwischen „Standortquelle“ und „Hinführen“ ist zu groß und wirkt unnatürlich.
  - In der Übersicht des Zielfahrzeugs steht nur noch das Kennzeichen. Das Kennzeichen bleibt namensgebend, auch auf
    der Karte, aber die Bezeichnung soll ebenfalls irgendwo stehen.
- **Fotos und Dateien beim Bearbeiten** (überall, wo es diese Auswahl gibt):
  - „Hinzufügen“ öffnet eine Sprechblase, die oft an der falschen Stelle sitzt und manchmal von selbst zugeht.
    Stattdessen ein Vollbild-Blatt; Sprechblasen-Menüs sind unerwünscht.
  - „Foto aus Mediathek“: Die Mediathek schließt sofort wieder, und die Bearbeiten-Ansicht gleich mit. Ursache finden.
  - „Ansehen“ geht beim ersten Mal sofort wieder zu, erst beim zweiten Mal bleibt es offen.
  - In der Fotoansicht die Bedienelemente immer eingeblendet lassen. Bisher blendet ein Tipp sie aus und macht den
    Hintergrund schwarz, zum Schließen muss man nochmal tippen; das verwirrt.
- **ÖPNV-Auswahl im Stil der Verlaufs-Pillen:** Die Auswahl „Fahrzeug, Strecke, Haltestellen“ (Übernehmen und
  Einsteigen in der ÖPNV-Karte, Ebenen der ÖPNV-Strecke) soll aussehen wie die Pillen im Verlauf: Glaskapseln, die
  man einzeln hinzufügen und entfernen kann. Sie ersetzen die bisherigen Umschaltknöpfe als zuständiges
  Bedienelement.
- **Verlauf, Zeitraum von–bis direkt wählbar:** Von und Bis immer sichtbar im Verlauf. Heute stecken sie hinter
  „Zeitraum › Eigener Zeitraum“; die Vorgaben werden zu Schnellwahlen. Die Zeitleiste läuft genau über den gewählten
  Zeitraum. Prüfen, ob sie dabei auch nur die Punkte darin zeigt.
- **„Im Dienst“-Schalter entfernen:** Ob man im Dienst ist, ergibt sich künftig aus Betreten und Verlassen der
  Instanzen. Entschieden:
  - Es gibt einen Zustand „keine Instanz“ (außer Dienst). Wer seine letzte Instanz verlässt, ist außer Dienst: kein
    Standort teilen, keine A, kein Verlauf.
  - Mit dem Betreten einer Instanz ist man wieder im Dienst.
  - Dafür muss auch die Hauptlage verlassen werden können.
- **ÖPNV-Navigation ausbauen:** Die einzelnen Schritte auf der Karte sichtbar machen: Fußwege, Ein- und
  Ausstieg, Linie, Umstieg. Dazu eine ausklappbare Liste aller Schritte.
- **Kfz-Navigation ohne Sonderrechte ist weiterhin seltsam:** Sie führt z. B. unterwegs in eine Sackgasse hinein und
  wieder heraus. Routenwahl und Plausibilitätsprüfung (direkte vs. geführte Route, Apple-Vergleich) überprüfen.
- **Kreuzungsvorschläge laden immer noch sehr lange:** Die Vorschläge plausibler Straßenecken brauchen weiterhin
  spürbar Zeit. Messen, wo die Zeit verloren geht (Server-Abfrage, Overpass, Abgleich), und beschleunigen, z. B.
  vorab laden oder zwischenspeichern.
- **Verlauf an zwei zentrale Stellen verlegen:** „Verlauf auf der Karte“ steht heute bei jedem Fahnder, Ziel,
  Fahrzeug und Tracker einzeln. Das soll weg. Stattdessen:
  1. Im Plus-Menü der Karte als hinzufügbares Kartenobjekt „Verlauf“. Dort wählt man aus, wessen Verlauf gezeigt wird.
  2. Gesammelt unter „Mehr“ als eigener Bereich „Verläufe“: alle Spuren, Aufbewahrung, eigene Aufzeichnung.
  Die Schalter „Verlauf aufzeichnen“ bei den einzelnen Objekten neu bewerten: dort lassen oder auch dorthin verlegen.
- **Lagename = Instanzname:** In der Infoleiste unten auf der Karte (Lageübersicht) soll als Name der Lage einfach der
  Name der Instanz stehen; kein eigener Lagetitel mehr.
- **Standardinstanz umbenennen:** Die Hauptlage soll „KSOD“ heißen, auch auf dem bestehenden Server (Umbenennung
  per Migration).
- **Punkte auf der Karte clustern:** Beim Herauszoomen nah beieinander liegende Punkte zu einem Cluster
  zusammenfassen. Auseinanderrücken nur, wenn man nah herangezoomt ist.
- **Offene Rückfrage:** Soll der Schalter „Auf der Karte“ in der Zielliste für alle in der Instanz gelten statt nur
  auf dem eigenen Gerät?

### Sentinel Web (bisher „Kommandozentrale“)

- **Umbenennen** in „Sentinel Web“.
- **Anmeldung** mit demselben Zugangscode wie alle anderen statt eigenem Verwaltungspasswort.
- **Nur noch Dark Mode**, den Light Mode entfernen.
- **SinoTrack über USB einrichten:** Sentinel Web fragt im Browser (Chrome, WebSerial/WebUSB) nach USB-Zugriff. Der
  angesteckte Tracker wird dann auf Sentinel programmiert: Server, Port, Intervall, APN. Die APN wird abgefragt,
  Beispieltext ist die APN der Beach SIM (Kanada). Grundlage ist ein Chat mit Claude am Desktop, in dem der Anschluss
  an den PC schon umgesetzt wurde; diesen Stand übernehmen.

- **Kreuzungssuche nach dem Update prüfen:** Kommen plausible Straßenecken jetzt zuverlässig, auch nach dem ersten Buchstaben der zweiten Straße? Falls nicht: Beispiel nachstellen.

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
  - 0.17: Verlauf auf der Karte, Tracker-Ansicht mit Akku und Befehlen (welche Werte der SinoTrack tatsächlich
    meldet, zeigen die letzten Nachrichten), Navigation „Halte voraus“, Kompass ohne Sprung
