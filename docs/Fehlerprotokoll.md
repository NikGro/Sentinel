# Fehlerprotokoll

Hartnäckige Fehler mit allen Lösungsversuchen und ihrem Ergebnis. Vor jedem neuen Versuch hier nachsehen, damit
gescheiterte Ansätze nicht wiederholt werden. Neue Versuche und Rückmeldungen vom Gerät sofort eintragen.

## Testumgebung für Kamera und Gesten

- `ios/SentinelUITests/KameraTests.swift`: fährt im Simulator eine Strecke ab, heftet an, zoomt (Zwei-Finger),
  dreht und wischt und prüft jede Anforderung unten automatisch (angeheftet, Abstand, Pumpen, Lösen).
- Messfühler in der App (`CameraProbe`, nur Testbuild mit `-kameraprobe`): eine Zeile je Kamerabewegung und je
  Gesten-Ereignis in `kamera.jsonl`, dazu ein lesbares Element `kamera-probe` für den Test.
- Ablauf `.github/workflows/kamera.yml` (bei jedem Push auf `ios/**` oder von Hand): Test mit Videoaufnahme;
  Artefakt `Kamera-<Nr>` mit `kamera.mp4`, `kamera.jsonl`, Bildschirmfotos und `ergebnis.txt`.
- Auswertung: Artefakt laden, dann `tools/kamera_auswertung.py <Ordner>` (Zeitachse, Pumpen, ungewolltes Lösen,
  Einzelbilder per ffmpeg). Ist der Artefakt-Speicher nicht erreichbar (Netzsperre in der Claude-Umgebung):
  `tools/kamera_aus_protokoll.py <Ordner> [Lauf-ID]` holt Messdatei und Einzelbilder aus dem Ablaufprotokoll.
- Grenze: Kippen mit zwei Fingern kann XCUITest nicht ausführen; das bleibt eine Prüfung auf dem Gerät.
- Falle: Simuliertes Zusammenziehen (`pinch` mit Faktor < 1) setzt die Finger weit auseinander an; einer traf die
  Tab-Leiste („Chat“), die Karte sah nur Verschieben. Herauszoomen deshalb per Tippen mit zwei Fingern prüfen.

## Kamera beim Anheften (Karte am eigenen Standort)

### Anforderungen (verbindlich, vom Nutzer)

- Norden oben: 1500 m von oben. Kompass: 550 m schräg von hinten (Winkel wie bisher). Navigation: eigene Werte.
- Angeheftet zoomen und kippen, ohne dass sich die Kopplung löst; die gewählten Werte bleiben.
- Im Navi und außerhalb weich und gleichmäßig folgen.
- Lösen durch seitliches Verschieben oder Herausdrehen aus der Kompass-Ausrichtung; Toleranz so, dass Zoomen und
  Kippen nie versehentlich lösen.
- Kein Zittern beim Lösen; das erste Wischen über der Schwelle löst und wird nicht unterbrochen.
- Vorbild: Google Maps auf iOS.

### Versuche

| Version | Ansatz | Ergebnis auf dem Gerät | Ursache |
|---|---|---|---|
| bis 0.18 | SwiftUI `MapCameraPosition.userLocation` (Apples Verfolgung) | Zoom springt beim Übergeben | Apple setzt eigene Zoomstufe |
| 0.18–0.20 | Eigene Nachführung, Gesten über Zeitfenster nach eigener Kamerafahrt | Folgen hörte beim Fahren auf | Zeitfenster passte nicht zu laufenden Fahrten |
| 0.20 | Eigene Nachführung, Gesten aus Kamerawerten (Abstand > 3 %, Winkel > 3°, Mitte) | Zoomen unmöglich, Zoom kroch | Geländehöhe verfälscht gemeldete Werte; Nachführung kämpft gegen Finger |
| 0.21 | Finger zählen per SwiftUI `SpatialEventGesture` an der Karte | Antippen ging verloren (Marker), Zittern im 3D | SwiftUI-Geste konkurriert mit MapKits Gesten, Ende kommt nicht an |
| 0.22 | Finger zählen per eigenem `UIGestureRecognizer` am Fenster | „geht immer noch nicht richtig“ | Fingerzahl sagt nicht, was MapKit daraus macht; Rückfall über Kamerawerte |
| 0.23 | MapKits `userTrackingMode` direkt an der `MKMapView` (Kamera setzen, dann Verfolgung) | Zoomt nach Erreichen wieder heraus, dreht im Kreis | Zwei Stellen steuern dieselbe Kamera (SwiftUI `position` und MapKit) |
| 0.26 | Wie 0.23, Reihenfolge getauscht und einmal nachgesetzt | Zoomt wild rein und raus | Derselbe Grundfehler wie 0.23, Nachsetzen verstärkt das Pumpen |
| 0.27 | Eigene Nachführung als einzige Steuerung; Gesten lesend an MapKits eigenen Erkennern (`MapGestureWatcher`) | Simulator, Kamera-Test komplett grün (Lauf 45014906691): Anheften 550 m/40°, beim Fahren konstant; Hineinzoomen behält Kopplung (550 → 270 m, danach konstant); Herauszoomen per Zwei-Finger-Tipp behält Kopplung (270 → 448 m, konstant); Drehen löst; Wischen löst nach 52 pt; Norden 1500 m/0°; kein Pumpen. Gerät: offen | — |

### Nicht wiederholen

- MapKits `userTrackingMode` oder `.userLocation` zusammen mit SwiftUIs `Map(position:)`: zwei Steuerungen.
- Gesten aus Kamerawerten erraten (Schwellen auf Abstand, Winkel, Mitte).
- SwiftUI-Gesten (`simultaneousGesture`, `SpatialEventGesture`) an der Karte zur Gestenerkennung.
- Nachführung während einer laufenden Geste.

### Falls 0.27 scheitert

- Prüfen, ob `MapGestureWatcher.isAttached` auf dem Gerät `true` wird (Kamerawerte-Overlay erweitern).
- Nächster grundsätzlicher Schritt wäre die Hauptkarte als `MKMapView` (UIViewRepresentable) mit voller Kontrolle
  über Kamera und Delegate. Großer Umbau (alle Kartenebenen).

## ÖPNV-Fahrzeuge bewegen sich nicht ruhig

| Version | Ansatz | Ergebnis |
|---|---|---|
| bis 0.20 | Neue Position alle 2 s bzw. 0,5 s, gleitende Animation | „kleine Sprünge“: andere Kamerabewegungen unterbrachen das Gleiten |
| 0.21 | 10 Schritte/s mit 0,1-s-Animation | „spacken vor und zurück“ |
| 0.23 | Halt an Haltestellen, Kurven langsamer, Echtzeitkorrektur ohne Zurückspringen (`TransitSmoother`) | „zittern immer noch“ |
| 0.25 | Takt nur für die ÖPNV-Ebene (eigene Uhr), 5 Schritte/s mit Animation | „zittern immer noch“ |
| 0.26 | 10 Schritte/s ohne Animation | offen |

Offene Vermutung: Fahrzeuge auf der ÖPNV-Karte springen zusätzlich beim Nachladen alle 20 s (kein Glätten dort).

## Antippen muss wiederholt werden

| Version | Ansatz | Ergebnis |
|---|---|---|
| 0.21 | (Ursache eingeführt) 10-Hz-Takt als Zustand des ganzen Kartenbildschirms | Antipper gehen verloren |
| 0.25 | Takt nur in der ÖPNV-Ebene; Datumsfelder mit minutengenauem Wert | offen |

## Haltestellen verschwinden nah herangezoomt (ÖPNV-Karte)

| Version | Ansatz | Ergebnis |
|---|---|---|
| 0.26 | Abgebrochene Abfrage leert die Haltestellen nicht mehr; nah größerer Ausschnitt | offen |
