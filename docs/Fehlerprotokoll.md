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

Rückmeldung zu 0.27 vom Gerät (22.11.): Zoomen und Kippen gehen in der 3D-Ansicht nicht, obwohl der Simulator-Test
grün war. Vermutungen (0.28): (a) MapKits Erkenner werden auf dem Gerät nicht gefunden; (b) eine laufende Kamerafahrt
der Nachführung (im Stand bis 2,5 s, Kompass-Meldungen dazwischen) läuft während der Geste weiter und überschreibt sie.
0.28: Test um „Zoomen im Stand mit seltenen GPS-Meldungen“ erweitert; Messdaten vom
Gerät über den Entwickler-Schalter „Kamera-Messdaten senden“ (Server: `/data/diagnose/kamera-<Gerät>.jsonl`), Overlay
zeigt Erkenner und Gesten. Lücke des Tests: Der Simulator hat keinen Kompass, Kippen ist nicht simulierbar.

Kamera-Test 0.28 (Lauf 45021559599): Kamera beim Gestenbeginn setzen (um eine laufende Fahrt anzuhalten) bricht
MapKits Geste ab: Zoomen und Wischen wirkungslos (began → allEnded ohne Zoom-/Verschiebe-Ereignisse). Zurückgenommen.
MapKits Erkenner laut Messung: MKVariableDelayTapRecognizer, UITapGestureRecognizer, UILongPressGestureRecognizer,
UIPinchGestureRecognizer, MKPanGestureRecognizer, _MKUserInteractionGestureRecognizer, UIRotationGestureRecognizer,
MKTiltGestureRecognizer, _MKConditionalPanRotation/Zoom/TiltGestureRecognizer, _MKOneHandedZoomGestureRecognizer,
_MKZoomingPanGestureRecognizer u. a.

Kamera-Test 0.28 korrigiert (Lauf 45023426484): komplett grün, auch „Zoomen im Stand mit seltenen GPS-Meldungen“.
Vermutung (b) im Simulator nicht bestätigt. Nächster Schritt: Messdaten vom Gerät auswerten (Vermutung a: Erkenner
auf dem Gerät nicht gefunden; Kompass-Einfluss; Kippen).

Gerätedaten 0.28 (22.11., `diagnose/kamera-YlXBwZC5x51F.jsonl`): Erkenner gefunden (18). Erste Zwei-Finger-Geste
im Kompassmodus greift (550 → 343 m). Jede weitere: Abstand ändert sich kurz (343 → 329/358) und springt NOCH WÄHREND
der Geste (g=1, Nachführung angehalten) exakt auf 343 zurück; Winkel bleibt immer 40° (Kippen kommt nicht durch).
Vermutung: SwiftUIs `Map(position:)` setzt die zuletzt gesetzte Position bei jedem Neuaufbau des Bildschirms erneut
(Kompass, GPS, andere Kräfte → ständige Neuaufbauten); erklärt auch das stückweise Folgen (Sprung ans Ziel mitten in
der Fahrt). Im Simulator kein Kompass → Test grün. Nachstellung: Test „Unruhe“ (`-unruhe`, 10 Neuaufbauten/s).

Kamera-Test „Unruhe“ (Lauf 45050621159, eigener Testlauf): 4 Neuaufbauten/s, zweimal Zoomen: beide greifen und bleiben
(550 → 334 → 203 m). Vermutung „Neuaufbau setzt Position zurück“ damit widerlegt.
Neue Spur aus den Gerätedaten: Erste Geste (79,0 s) zoomt auf 544 m, danach Rückzug auf 550 m = Ziel der noch laufenden
Anheft-Fahrt. Vermutung: Eine vor der Geste gestartete Kamerafahrt (Nachführung bis 2,5 s, im Stand durch Kompass und
GPS fast immer aktiv) läuft während der Geste weiter. 0.29 protokolliert jede Kamerafahrt (Auslöser, Ziel, Dauer) zur
Bestätigung auf dem Gerät.

Gerätedaten 0.28 beim Fahren (Norden, 22.70–27.98 s): Während der Geste (g=1) bleibt der Abstand 1745 m und die
Kartenmitte wandert weiter mit der Fahrt; nach der Geste kurz 1033 m, dann zurück auf 1745 m. BESTÄTIGT: Eine vor
der Geste gestartete Kamerafahrt der Nachführung (bei GPS je Sekunde ~1 s lang, also fast immer aktiv) steuert die
Kamera während der Geste weiter und schluckt sie. Abbrechen geht nicht (bricht die Geste ab, 0.28).
0.30: Nachführung in Schritten von 0,1 s zehnmal je Sekunde mit Vorausrechnung nach Tempo und Kurs und weicher
Annäherung; Kameraposition in eigenem Objekt (nur die Karte wird aufgefrischt). Test: Zoomen beim Fahren mit GPS je
Sekunde.

### Nicht wiederholen

- Kamera (SwiftUI-Position) während oder zu Beginn einer Geste setzen: bricht die Geste ab.

- MapKits `userTrackingMode` oder `.userLocation` zusammen mit SwiftUIs `Map(position:)`: zwei Steuerungen.
- Gesten aus Kamerawerten erraten (Schwellen auf Abstand, Winkel, Mitte).
- SwiftUI-Gesten (`simultaneousGesture`, `SpatialEventGesture`) an der Karte zur Gestenerkennung.
- Nachführung während einer laufenden Geste.
- Lange Kamerafahrten (über ~0,2 s) in der Nachführung: laufen in eine Geste hinein und schlucken sie.

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
