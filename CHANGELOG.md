# Änderungen

## 0.37.0

**Navigation**
- Parallel-Modus: Bei fahrenden Zielen in der Navi-Leiste neben „Zum Ziel“ und „Vorlauf“. Geführt wird zur Kreuzung
  vor dem Ziel über eine Nebenstrecke, die Straße des Ziels bis dorthin meidet der Server. Gibt es keine Nebenstrecke,
  steht ein Hinweis in der Leiste und die Route führt direkt
- Sperrungen: Aktuelle Vollsperrungen der Autobahnen (Fahrbahnen und Anschlussstellen, offene Daten der Autobahn GmbH)
  werden alle 20 Minuten geladen und bei der Route gemieden
- Navi-Leiste kompakter: Verkehrsmittel und Navigationsart schmal nebeneinander, die gewählte Art steht in Worten darunter

**Ziele**
- Beziehungen statt fester Felder: Personen, Fahrzeuge und Objekte sind eigene Ziele und werden verbunden (z. B.
  Halter, Fahrer, Bewohner), mit Status (vermutet, bestätigt, beendet), Herkunft und Notiz; von beiden Seiten sichtbar
  und bearbeitbar, in der App und in Sentinel Web. Halter beim Fahrzeug, Wohnanschrift und genutztes Fahrzeug bei
  der Person entfallen als Eingabe; frühere Angaben bleiben sichtbar, bis sie übertragen und entfernt sind

**Oberfläche**
- Kurzübersichten (Variante 2): Kopfzeile mit Symbol, Titel und kleinen runden Knöpfen (Hinführen, Bearbeiten,
  Schließen) statt Navigationsleiste und großem Hinführen-Knopf; bei sehr großer Schrift Knöpfe unter dem Titel
- UI-Abnahme: Schalter der Navi-Leiste mit 44 Punkten Trefferfläche, Titel der Kurzübersicht als Überschrift für VoiceOver

## 0.36.0

**Karte**
- Eigener Punkt: Die Mitte des Kreises liegt genau auf dem Standort, Beschriftungen stehen darunter (vorher lag die
  Mitte der ganzen Gruppe auf dem Standort, der Kreis saß zu hoch)
- Straßenschild mit Richtung und „Ecke …“ im selben schlichten Stil wie die eigene Beschriftung
- Standortspur wächst fortlaufend mit den eigenen GPS-Punkten statt ruckweise, ohne Punkt am Anfang; Farbe in der
  Objektansicht umschaltbar nach Alter oder Häufigkeit (wie oft man dort schon entlanggefahren ist)
- Suche: Passendes aus der Lage (Ziele, Kräfte, Marker, Flächen, Linien, Haltestellen …) steht in der Adresssuche oben

**Navigation**
- Vorlauf: Bei fahrenden Zielen mit Live-Standort in der Navi-Leiste umschaltbar zwischen „Zum Ziel“ und „Vorlauf“;
  geführt wird zur nächsten Kreuzung vor dem Ziel in seiner Fahrtrichtung, ist es daran vorbei, zur nächsten

**Tests**
- Vorlauf (Kreuzung voraus, Fahrtrichtung) und ÖPNV-Glätter (kein Zurückspringen bei neuer Echtzeit)

## 0.35.0

**Karte und Navigation**
- Standortspur als Objekt (Plus-Menü › Auswertung): zeichnet den eigenen Weg ab dem Anlegen, deckend mit Farbverlauf
  nach Zeit (Blau alt, Rot neu), mehrfach gefahrene Wege werden nicht dunkler; Antippen an beliebiger Stelle öffnet
  das Objekt mit Bearbeiten und Löschen. Der Ebenen-Schalter „Bestreifte Wege“ entfällt
- Straßenschild am eigenen Punkt kleiner und zweizeilig: Straße und Richtung, darunter „Ecke …“ mit der nächsten
  Querstraße (ersetzt die Querstraßen-Schilder entlang der Route)
- Routenlinie beginnt an der Spitze des Navi-Pfeils statt unter seiner Mitte (kein Rest in der Kerbe)
- Überschlagen und „Halte voraus“: Die Ziel-Haltestelle wird hervorgehoben (grüner Ring auf einer vorhandenen
  Haltestelle, sonst eigenes Symbol ohne Nummer) und verschwindet mit dem Ende der Navigation bzw. beim Weiterrücken

**Ebenen und Oberfläche**
- Ebenen und Pakete: Ebene leeren (alle Objekte löschen, mit Rückfrage), nicht bei den dauerhaften Orten
- Beschriftung auf Flächen in der Farbe der Fläche mit festem weißem Rand statt Leuchten

**Bauen und Veröffentlichen**
- Testen und Archiv laufen parallel, Swift-Pakete und Build-Zwischenstände werden zwischengespeichert; main übernimmt
  die getestete App des Arbeitszweigs und veröffentlicht sie nur noch. Schnelle Spur mit „[schnell]“ (nur
  Unit-Tests); Kamera-Test nur bei Änderungen an der Kartensteuerung

## 0.34.1

**Navigation**
- Falsch abgebogen: Der eigene Punkt bleibt nicht mehr auf der alten Route kleben, sondern zeigt den echten Standort,
  sobald man über 25 m (bzw. die GPS-Ungenauigkeit) von der Route weg ist
- Abweichungen werden auch bei mäßigem GPS (bis 50 m Ungenauigkeit, im Auto üblich) erkannt und die Route neu
  berechnet; vorher erst ab 25 m Genauigkeit
- An der Ampel bleibt die Karte geradeaus: Die Fahrtrichtung wird im Fahrzeug erst ab etwa 11 km/h übernommen, darunter
  (Ausrollen, Stehen) gilt die letzte verlässliche Richtung

## 0.34.0

**Karte und Navigation**
- Eigener Punkt erscheint beim Anfliegen über den Kompassknopf nicht mehr doppelt
- Routenlinie beginnt genau unter dem eigenen Punkt und wird fünfmal je Sekunde gekürzt (kein Haken hinter einem)
- Navigation: Kamera 1500 m, 45°; im Fahrzeug hält die Karte an der Ampel die letzte Fahrtrichtung statt des Kompasses
- Finger auflegen stoppt eine ausrollende Karte und laufende Kamerafahrten
- Wischen löst angeheftet wieder zuverlässig (Fingerzahl kommt von iOS statt aus einem eigenen Zähler), auch sehr
  schnelles Wischen; schnelles Zoomen übernimmt auch die letzte Bewegung

## 0.33.0

**Karte und Kamera**
- Angeheftet zeichnet die App den eigenen Punkt selbst fest in der Bildmitte; die Kamera folgt dem (vorausberechneten)
  Standort statt Apples Standortanzeige. Behebt das Zittern des Punkts nach dem Anheften
- Drehen: feste Schwelle von 10° (beim Zoomen hing die Drehung bis 25°), kein Sprung bei kurz verlorenem Finger oder
  nach dem Lösen; Zwei-Finger-Gesten werden einmal je Bild ausgewertet
- Suchtreffer und gedrückter Ort: Die Kamera endet mit dem Ort mittig zwischen Suchleiste und Fenster unten
- Linie, ÖPNV-Strecke oder Standortverlauf antippen: niedriges Fenster, Punkt auf der Strecke, Kamera rückt ihn in die
  freie Mitte. Mehrfaches Tippen auf dieselbe Stelle schaltet durch übereinanderliegende Linien
- Standortverlauf: angetippt die Kurzübersicht mit Bearbeiten und den Werten an der Stelle; überall auf der Spur
  antippbar, zwischen zwei Punkten werden Ort, Zeit und Tempo angenommen. Anlegen als Fenster von unten mit Schließen
  und Hinzufügen, Gesamtansicht als Knopf am Rand. Datum und Uhrzeit getrennt (Kalender schließt nach dem Antippen)

**ÖPNV**
- Neues Fahrmodell: abgerundeter Fahrweg, langsamer in Kurven, weiches Bremsen und Anfahren, realistische Standzeiten
  (Bus/Tram ~20 s, U-Bahn ~25 s, Zug ~45 s), an den Fahrplan angepasst; Echtzeit-Korrekturen weich ohne Zurückspringen.
  Fahrzeuge mit 30 Schritten je Sekunde, Linien und Halte bleiben dabei ruhig

**Ziele**
- Zielperson auf ÖPNV setzen öffnet die ÖPNV-Karte zum Einsteigen
- Standortquelle als Vierer-Schalter (Ort beibehalten, von Hand, Tracker, A-Position), auch bei Zielfahrzeugen; bleibt
  sichtbar, wenn die Person in einem nicht angelegten Fahrzeug sitzt

**Hauptmenü**
- Instanzen antippen zum Öffnen bzw. Beitreten, wischen zum Verlassen bzw. Löschen, Pfeil statt Knöpfen; Pfeil auch am
  Eintrag Hauptmenü unter Mehr

## 0.32.0

**Eigene Kartensteuerung auf allen Karten (Lage, ÖPNV-Karte, Standortwahl)**
- Eine einzige Stelle steuert die Kamera, nach dem Prinzip von Google Maps: Apples Kartengesten sind aus, Verschieben,
  Zoomen, Drehen und Kippen erkennt die App selbst und setzt die Kamera Bild für Bild. Kein Gegeneinander mehr
  zwischen App und Apple, kein fremder Abstand beim Anheften (Apple setzte ~4,9 km)
- Gesten: Verschieben mit Schwung, Zoomen um den Punkt zwischen den Fingern, Drehen erst ab einigen Grad, Kippen mit
  zwei Fingern senkrecht, Doppeltippen zoomt hinein, Doppeltippen und Ziehen zoomt mit einem Finger, Tippen mit zwei
  Fingern zoomt heraus
- Angeheftet: Kompass 550 m schräg, Norden 1500 m von oben; die Karte folgt dem Standortsymbol bei jedem Bild (im
  Kamera-Test unter 1 Punkt Versatz). Zoomen und Kippen ändern nur Abstand und Winkel. Lösen durch Wischen mit einem
  Finger (über 30 Punkte) oder Drehen (20°, beim gleichzeitigen Zoomen mehr); die Geste läuft dabei ohne Ruck weiter
- Kamera-Test: misst zusätzlich den Versatz des Standortsymbols und schreibt Absturzberichte ins Protokoll

## 0.31.0

**Kamera beim Anheften: Apples eigene Standortverfolgung**
- Folgen, Zoomen, Kippen und Lösen übernimmt Apples Verfolgung (SwiftUI `.userLocation`), wie in Apple Karten. Die
  eigene Nachführung ist entfernt: Ihre Kamerafahrten schluckten Gesten (Gerätedaten 0.28/0.29), häufige kurze
  Schritte verhinderten sie ganz (0.30, nicht veröffentlicht)
- Abstand und Winkel werden vor dem Einschalten gesetzt; Apple behält sie (Kompass 550 m/40°, Norden 1500 m/0°)
- Eigenes Zoomen und Kippen wird zum neuen Sollwert. Springt Apple ohne Geste auf einen weiten Abstand, setzt die App
  den Sollwert wieder (höchstens dreimal je Anheften)
- Lösen: Verschieben mit einem Finger oder Herausdrehen aus der Kompass-Ausrichtung (über MapKits Gestenerkenner)
- Kamera-Test: Zoomen beim Fahren mit einer GPS-Meldung je Sekunde; alle Fälle grün

## 0.29.0

**Fehlersuche Kamera**
- Die Kamera-Messdaten enthalten jede Kamerafahrt der App (Anheften, Folgen, Zurückgleiten nach einer Geste) mit
  Ziel, Dauer und ob gerade eine Geste lief, sowie das Übernehmen von Abstand und Winkel nach einer Geste
- Kamera-Test „Unruhe“ (ständige Neuaufbauten wie auf dem Gerät) läuft in einem eigenen Testlauf

## 0.28.0

**Kamera**
- Nach Kippen wird der genaue Winkel übernommen (vorher in 2°-Schritten)

**Fehlersuche**
- Mehr › Entwickler: „Kamera-Messdaten senden“ schickt Kamerawerte und Gesten alle zehn Sekunden an den eigenen Server
- Kamerawerte-Overlay zeigt zusätzlich, ob MapKits Gestenerkenner gefunden wurden, ob eine Geste läuft und das letzte
  Ereignis
- Kamera-Test: neuer Fall „Zoomen im Stand mit seltenen GPS-Meldungen“

## 0.27.0

**Kamera beim Anheften: eine einzige Steuerung, Gesten aus MapKits eigenen Erkennern**
- Die MapKit-Standortverfolgung (0.23–0.26) ist entfernt: SwiftUIs Karte und MapKit steuerten dieselbe Kamera und
  zoomten gegeneinander hinein und heraus
- Die App führt die Kamera wieder allein nach. Welche Geste läuft, liest sie jetzt direkt an MapKits eigenen
  Gestenerkennern mit (Verschieben, Zoomen, Drehen, Kippen), statt sie aus Kamerawerten oder Fingern zu erraten
- Während einer Geste keine Nachführung; Verschieben mit einem Finger über 30 Punkte oder Drehen über 20° in der
  Kompass-Ausrichtung löst die Kopplung sofort, ohne die Kamera anzufassen
- Zoomen, Kippen und Doppeltippen behalten die Kopplung; nach dem Ausschwingen gelten Abstand und Winkel weiter

## 0.26.0

**Kamera**
- Anheften: erst die MapKit-Verfolgung einschalten, dann Abstand und Winkel setzen; ändert MapKit sie dennoch, wird
  einmal nachgesetzt (vorher zoomte die Karte nach dem Anheften wieder heraus)
- Herausdrehen aus der Kompass-Ausrichtung (mehr als 55° neben der Blickrichtung) löst die Kopplung, statt dass die
  Karte gegen den Finger zurückdreht

**ÖPNV**
- Fahrzeuge zehnmal je Sekunde ohne Animation weitergerückt (etwa ein Bildpunkt je Schritt): Die gleitende Animation
  wackelte, sobald sich die Kamera mitbewegte
- ÖPNV-Karte: Haltestellen bleiben auch nah herangezoomt; eine durch die nächste Kartenbewegung abgebrochene Abfrage
  leert sie nicht mehr, nah wird ein etwas größerer Ausschnitt geladen
- ÖPNV-Karte: SOS und Kompassknopf (zum eigenen Standort) oben rechts wie in den übrigen reduzierten Ansichten

**Oberfläche**
- Zielperson: Standortquelle direkt unter „Hinführen“, danach der Dreier-Schalter für das Verkehrsmittel
- Hauptmenü: Instanzen löschen in der Liste „Weitere Instanzen“ (nach dem Verlassen), nicht mehr bei den eigenen
- „Fertig“ in „Dauerhafte Orte bearbeiten“ und in einem Paket führt zurück ins Hauptmenü
- Navigieren / Hier anlegen: Postleitzahl und Ort sowie die Straßenansicht (Look Around)

## 0.25.0

**Navigation**
- Querstraßen als Sprechblasen direkt an der Kreuzung auf der Karte, solange man auf sie zufährt (bis 450 m voraus,
  höchstens drei); nicht mehr im Banner oben

**Antippen**
- Antipper gehen nicht mehr verloren (ÖPNV-Fahrzeuge, Datumsfelder im Verlauf): Der Takt der ÖPNV-Fahrzeuge frischt
  nur noch die Fahrzeuge auf der Karte auf statt den ganzen Bildschirm, fünfmal je Sekunde mit gleitendem Übergang;
  auf der ÖPNV-Karte ebenso
- Datumsfelder im Verlauf bekommen bei „bis jetzt“ einen auf die Minute festen Wert, statt bei jedem Neuaufbau einen
  um Millisekunden anderen, der das Feld zurücksetzte

## 0.24.0

**Überschlagendes Navigieren zu ÖPNV-Fahrzeugen**
- Neue Auswahl im Navi-Fenster neben „Fahrzeug“ und „1–3 Halte voraus“: überschlagend
- Geht zu jedem Ziel im ÖPNV: einem Ziel, das darin sitzt, einem Fahnder oder der A im ÖPNV oder dem
  ÖPNV-Fahrzeug selbst. Wege zum selben Fahrzeug zählen zusammen
- So viele Halte im Voraus, wie Fahnder mitmachen. Verlässt das Fahrzeug einen Halt, bekommt der dort Wartende den
  weitesten Halt; die anderen behalten ihre Halte und rücken nach, sobald ihr Halt passiert ist
- Mit echten Fahrplanzeiten (ÖPNV-Fahrzeug aus der ÖPNV-Karte) zählt die Abfahrt am Halt; der Server prüft das
  laufend

## 0.23.0

**Kamera beim Anheften: eingebaute Standortverfolgung von MapKit**
- Statt einer eigenen Nachführung übernimmt die Karte selbst (wie Apple Karten und Google Maps): Sie folgt flüssig,
  Zoomen und Kippen behalten die Kopplung, Verschieben löst sie sofort, ohne die Wischbewegung zu unterbrechen,
  Herausdrehen beendet die Kompass-Ausrichtung. Die App setzt nur noch Abstand und Winkel beim Anheften
- Kompass: 550 m schräg von hinten; Norden oben: 1500 m von oben
- 2D/3D-Knopf ändert angeheftet nur den Winkel und bleibt angeheftet

**Karte**
- Antippen auseinandergerückter Symbole trifft das Symbol, nicht die Form darunter
- Abgelegter Standortverlauf: Antippen einer Stelle zeigt Uhrzeit, Geschwindigkeit und Quelle
- Gelöschte Objekte: Die Ansicht schließt sofort, ohne leeres Fenster

**ÖPNV**
- Fahrzeuge halten an jeder Haltestelle (bis 20 s), fahren an, werden in Kurven langsamer und bremsen
- Neue Verspätungen lassen das Fahrzeug kurz warten statt zurückspringen; kleine Sprünge nach vorn gleiten
- Navigation zu einem Ziel im ÖPNV: Auswahl Fahrzeug / 1–3 Halte voraus ohne Text unten im Navi-Fenster
- Bearbeiten einer Strecke: Auswahl Fahrzeug, Strecke, Haltestellen frei über der Liste

**Hauptmenü**
- Zwei Tabs: Instanzen (mit Sonderbereichen) und Mehr
- Je Instanz „Verlassen“ und „Öffnen“ (blau) als Glasknöpfe, „Beitreten“ im selben Stil; „Zurück zu …“ entfällt
- In „Mehr“ des Hauptmenüs: Profil, Geräte und Zugangscode, GPS-Tracker, Argus Predict, App-Sperre, Verbindung,
  Entwickler, Abmelden. „Mehr“ in der Instanz behält Hauptmenü, Funkkanal sowie Ebenen und Pakete; „Verläufe“ entfällt
- Argus Predict legt die Prognose als Paket an statt direkt auf die Karte

**Oberfläche**
- Der erste Listeneintrag in allen Tabs sitzt unterhalb des Verlaufs der Kopfzeile

## 0.22.0

**Routing**
- Navigation und Weg-Zeit-Flächen jetzt in ganz Deutschland (vorher nur Hamburg, Schleswig-Holstein, Niedersachsen)

**Karte**
- Fingererkennung beim Anheften neu: ein Beobachter am Fenster liest Berührungen nur mit. Die Geste aus 0.21
  konkurrierte mit Apples Kartengesten; dadurch gingen Antipper auf die Karte verloren (Marker ließen sich nicht
  setzen), und im 3D zog die Kamera mitten in der Geste zurück (Zittern, kein Zoomen und Kippen)
- Solange ein Finger auf der Karte liegt, führt die App nicht nach; ein wischender Finger löst die Kopplung, Zoomen,
  Kippen, Drehen und Doppeltippen behalten sie. Wischen in Fenstern über der Karte zählt nicht
- 3D-Ansicht im Kartenstil-Menü wechselt wieder (die Kamerafahrt startet erst, wenn das Menü zu ist); angeheftet
  kippt sie um den eigenen Standort
- Beim Setzen eines Orts und bei Suchtreffern bleibt der Kompassknopf, um zum eigenen Standort zu springen

**Standortverlauf**
- Öffnet direkt im Verlauf, ohne Vorauswahl; Spuren kommen über das Plus dazu
- Oben rechts: „Ganze Spur“, Schließen und ganz außen ein blauer Haken zum dauerhaften Ablegen auf der Karte
- Vorgaben wie „Heute“ greifen beim ersten Tippen (das Datumsfeld überschrieb sie vorher als eigenen Zeitraum)
- Legende: „Keine Daten“ als gestrichelte Linie

## 0.21.0

**Kamera beim Anheften (neu aufgebaut)**
- Die App zählt die Finger auf der Karte direkt, statt Gesten aus den Kamerawerten zu erraten
- Zwei Finger (Zoomen, Neigen, Drehen): Die Kopplung bleibt, Zoomstufe und Neigung gelten danach weiter, die Kamera
  gleitet kurz zurück auf den eigenen Standort (MapKit zoomt um den Punkt zwischen den Fingern)
- Ein Finger, der spürbar wischt: Die Kopplung löst sich. Antippen ändert nichts
- Während ein Finger auf der Karte liegt, führt die App nicht nach
- Der 2D/3D-Knopf wirkt jetzt auch angeheftet; vorher setzte das Nachführen die Neigung sofort zurück
- Kein Zoom-Kriechen mehr durch die leicht schwankenden Werte mit Geländehöhe

**Navigation**
- Liegt Start oder Ziel abseits einer Straße (Platz, Hof, Park) oder passt die GPS-Richtung zu keiner Straße, rechnet
  der Server mit gelockertem Einrasten neu (bis 2 km zur nächsten passenden Straße), statt keine Route zu liefern

**ÖPNV**
- Fahrzeuge gleiten wieder: zehn kurze Schritte je Sekunde statt einer langen Animation, die von anderen
  Kartenaktualisierungen unterbrochen wurde; auf der ÖPNV-Karte fünf je Sekunde
- „Hierhin navigieren“ steht in der Übersicht des Objekts (auch bei Strecken mit Fahrzeug), nicht mehr beim Bearbeiten

**Oberfläche**
- Ziele, Kräfte, Chat, Mehr: Plus-Knopf auf Höhe des großen Titels; die Kopfzeile läuft unten weich ins Transparente aus

## 0.20.0

**Geofence-Alarm (neu im Plus-Menü unter Fahndung)**
- Bereich setzen, Ziele wählen und festlegen, ob beim Verlassen oder beim Betreten Alarm kommt
- Der Server prüft laufend die Standorte der Ziele; der Alarm geht an alle in der Instanz
- Beim Anlegen zählt nur der Wechsel: Ist ein Ziel schon draußen, gibt es keinen Alarm, bis es einmal drin war

**Standortverlauf (Plus-Menü, vorher „Verlauf“)**
- Neuer Knopf „Auf die Karte legen“: Die gezeigten Spuren bleiben als Objekt auf der Karte, für alle sichtbar.
  Vorgaben bis „jetzt“ laufen mit, ein fester Zeitraum bleibt fest. Aus dem Objekt heraus „Im Verlauf öffnen“
- Reduzierte Karte im Verlauf: keine Suche, rechts nur der Kompassknopf (und SOS)
- Das „+“ für weitere Spuren sitzt direkt neben den Pillen; die Zeitleiste ist entfernt, Punkte über Antippen der Spur

**Ziele und ÖPNV**
- Standortquelle „Aktuellen Ort beibehalten“: Das Ziel bleibt dort stehen, wo es gerade ist
- ÖPNV-Karte mit Knopf zum eigenen Standort

## 0.19.0

**Ziele instanzübergreifend**
- Ziele gibt es nur noch einmal für alle Instanzen, wie die Fahrzeuge der Kräfte; ihr Standort ist überall derselbe
- Der Schalter „Auf der Karte“ in der Zielliste gilt jetzt für alle Teilnehmer der Instanz (vorher nur auf dem
  eigenen Gerät). Neue Ziele sind in der Instanz sichtbar, in der sie angelegt werden
- Pakete schalten ihre Ziele beim Übernehmen sichtbar, statt sie zu kopieren; „Lage zurücksetzen mit Zielen“ blendet
  sie in der Instanz aus, statt sie zu löschen
- Bestehende Ziele wurden einmalig übernommen und sind in ihrer bisherigen Instanz sichtbar

**Server**
- 2 GB Speicher; das Straßenverzeichnis für die schnelle Kreuzungssuche ist wieder an

## 0.18.0

**Navigation**
- Unten groß die Restdauer, darunter Strecke und Ankunftszeit
- Eigener Standort in der Navigation als großer, flach auf der Karte liegender Pfeil; Kamera wie in üblichen Navis,
  etwas höher für mehr Überblick
- Kfz ohne Sonderrechte: Routen mit zusätzlichen Wenden (z. B. in eine Sackgasse hinein und wieder heraus) werden
  verworfen, die Durchfahrtspunkte rasten nur noch auf der Straße direkt am Punkt ein
- ÖPNV-Navigation: Schritte auf der Karte (Fußwege, Ein- und Ausstieg mit Linie und Zeit) und als ausklappbare Liste
- „Zu Objekten navigieren“ zeigt nur, was auch auf der Karte zu sehen ist

**Karte**
- Kompass und Anheften: feste Zoomstufe und Neigung, kein Zittern beim Wegwischen, im Stand keine ständigen
  Kamerafahrten mehr
- Punkte bündeln sich beim Herauszoomen zu einem Cluster mit Anzahl; Antippen zoomt hinein. Auseinandergerückt wird
  nur nah herangezoomt
- Lagename in der Leiste unten ist der Name der Instanz; die Standardinstanz heißt „KSOD“

**ÖPNV**
- Fahrzeuge verschwinden fünf Minuten nach der tatsächlichen Ankunft (mit Verspätung), mit Countdown in der Ansicht
- Echtzeit wird den Halten über die Halte-ID zugeordnet; Anfahren und Bremsen zwischen den Halten
- In der Fahrzeugansicht steht, wie verlässlich die Position ist: Echtzeit, Fahrplan oder geschätzt
- Auswahl von Fahrzeug, Strecke und Haltestellen als Pillen wie im Verlauf

**Verläufe**
- Verlauf jetzt im Plus-Menü der Karte und unter Mehr › Verläufe (mit Aufzeichnung je Objekt und Aufbewahrung);
  die einzelnen Knöpfe bei Fahndern, Zielen, Fahrzeugen und Trackern sind weg
- Von und Bis immer sichtbar, die Vorgaben sind Schnellwahlen

**Fotos und Dateien**
- Auswahlblatt statt Sprechblase; Mediathek, Kamera und Ansehen öffnen erst, wenn das Blatt geschlossen ist, und
  schließen nicht mehr von selbst samt Bearbeiten
- Eigene Fotoansicht mit immer sichtbaren Knöpfen, Zoomen und Teilen

**Instanzen und Dienst**
- Kein „Im Dienst“-Schalter mehr: Wer eine Instanz betritt, ist im Dienst; wer seine letzte verlässt, ist außer
  Dienst. Auch die Standardinstanz lässt sich verlassen

**Ziele, Tracker, Pakete**
- Zielansicht kompakter (Hinführen und Standortquelle enger), beim Zielfahrzeug steht die Bezeichnung wieder unter
  dem Kennzeichen
- Mehr › Ebenen und Pakete: „Paket aus der Bibliothek importieren“ statt „Paket vorbereiten“
- SMS-Befehle aus der Tracker-Ansicht entfernt

**Suche**
- Kreuzungsvorschläge aus einem lokalen Straßenverzeichnis auf dem Server (einmal je Woche geladen): Millisekunden
  statt Sekunden

**Sentinel Web** (bisher Kommandozentrale)
- Neuer Name, Anmeldung mit dem Zugangscode statt Verwaltungspasswort, nur noch dunkel
- SinoTrack per USB einrichten (Chrome/Edge): Server, Port, Datenverbindung, Intervall und APN direkt an den Tracker

## 0.17.0

**Standortverläufe**
- Der Server zeichnet die Verläufe von Trackern, Zielen, Fahrzeugen und Fahndern auf, auch wenn kein Telefon offen
  ist. Jeder Punkt merkt sich seine Quelle: GPS, Tracker, A-Position, ÖPNV-Fahrt, Besatzung oder von Hand. Wechselt
  ein Ziel zwischen Bus, Zielfahrzeug und A, ergibt das eine durchgehende Spur
- Aufzeichnen ist je Tracker, Ziel und Fahrzeug abschaltbar, für sich selbst unter „Mehr“. Abschalten löscht nichts,
  es wird nur nichts Neues aufgezeichnet. Der eigene Verlauf entsteht nur im Dienst
- Aufbewahrung einstellbar (Standard 30 Tage) unter „Mehr › GPS-Tracker“
- Verlauf auf der Karte: Zeitraum wählen (letzte Stunde bis letzte Nacht oder frei), mehrere Spuren gleichzeitig.
  Abschnitte sind nach Quelle gefärbt, Lücken gestrichelt und Standzeiten markiert. Die Zeitleiste zeigt, wo jeder zu
  einem Zeitpunkt war. Antippen der Spur zeigt Zeit, Geschwindigkeit, Quelle und Standzeit

**Tracker**
- Eigene Ansicht je Tracker („Bearbeiten“ oder antippen) mit Zustand: Verbindung, letzter Kontakt, Akku,
  Mobilfunk, Satelliten, Zündung, Stromversorgung und Alarme, soweit das Gerät sie meldet
- Befehle über die Datenverbindung: Sendeintervall, Alarm scharf und unscharf, eigene H02-Befehle
- SMS-Befehle direkt aus der App: Server und Port, Datenverbindung, Intervall, APN, Einstellungen abfragen
- Letzte Nachrichten im Rohformat, um zu sehen, was ein Gerät tatsächlich schickt
- Akku und Verbindung auch in der Trackerliste
- Wird ein Tracker vom Ziel getrennt oder gelöscht, bleibt das Ziel an der letzten Trackerposition stehen
- SinoTrack: Positionsmeldungen aller Arten werden gelesen (auch V8), die Felder werden am Muster erkannt statt an
  festen Stellen
- SinoTrack V8: Satelliten, Mobilfunkempfang, Akkuspannung und Akkustand aus den Zusatzfeldern; „verbunden“, solange
  er sich in den letzten zwei Minuten gemeldet hat (er baut je Meldung eine neue Verbindung auf)

**Fahrzeuge**
- „Im Einsatz“ gilt je Instanz statt serverweit; neue Instanzen beginnen ohne aktive Fahrzeuge
- Sitzen mehrere im Fahrzeug, gibt der zuerst Eingestiegene den Standort vor, auch über Instanzen hinweg

**SOS**
- Der Knopf wächst beim Halten wie die anderen Glasknöpfe, der weiße Ring ist wieder zu sehen

**Karte, ÖPNV und Navigation**
- Kompass und Anheften: Die App führt die Kamera selbst nach; kein Sprung mehr nach der Kamerafahrt. Norden-Ansicht
  weiter weg
- Navigation zu Zielen im Bus oder zum Bus selbst: direkt zum Fahrzeug oder 1 bis 3 Halte voraus
- Selbst einsteigen: Fahrzeug, Strecke und Haltestellen wie beim Übernehmen auswählbar
- Übernommene Fahrzeuge behalten die Farbe aus der ÖPNV-Karte; in der Ansicht steht das Liniensymbol oben, ohne
  doppelte Zeile

## 0.16.0

**Karte und Navigation**
- Anheften springt nicht mehr: Verliert die Nachführung kurz den Standort, bleibt die Karte stehen, statt auf
  „alles zeigen“ zu springen
- Navigation: eigener Pfeil etwas näher an der unteren Leiste (Mittelding)
- SOS: der Ring füllt sich beim Halten innen im roten Glasknopf, kein dauerhafter Ring mehr außen
- Entzerrte Symbole: kleiner Punkt am echten Ort mit dünner Linie zum verschobenen Symbol; der Wechsel beim
  Zoomen gleitet
- „Hinführen“ im Profil anderer Fahnder: Symbol weiß auf Blau (war Blau auf Blau)

**Suche und Fortbewegung**
- Querstraßen schon nach „Straße /“ bzw. „Straße Ecke“, Filter beim Weitertippen ohne Wartezeit; Anschriften,
  Örtlichkeiten und Haltestellen getrennt
- Erste Navigationsroute: Apples Vorgabe nur, wenn sie gegenüber der direkten Route plausibel ist; ruhigeres
  Neuberechnen am Anfang
- Eigene Fortbewegung „ÖPNV“ öffnet die ÖPNV-Karte: Fahrzeug antippen oder suchen und „Einsteigen“

**Ziele**
- Dreier-Umschalter der Zielperson mit Symbolen wie bei den Kräften
- „Zu Objekten navigieren“: Live-Kennzeichen auch für Ziele an der A-Position, an einem Tracker, im ÖPNV oder in
  einem Zielfahrzeug mit Live-Standort
- Wird die A abgegeben oder wechselt sie, bleiben Ziele, die ihr gefolgt sind, an der letzten Position stehen

**Profil**
- Abmelden entfernt das eigene Profil auf dem Server; kein doppeltes Profil mehr beim Wiederanmelden
- Beim Anlegen eines Profils lässt sich ein bestehendes (nicht verbundenes) Profil übernehmen, z. B. das eigene
  von vor dem Abmelden


## 0.15.0

**Karte**
- Standortknopf: angeheftet blaues Glas mit weiß gefülltem Pfeil; Wegschieben löst die Kopplung schon bei
  deutlich kleinerer Bewegung; in Fahrtrichtung flacher gekippt (40°); kein Herauszoomen mehr nach der
  Animation – in Fahrtrichtung bleibt es nah, Norden oben mit mehr Überblick
- Eigener Standort wieder zum Bildschirm ausgerichtet (nicht mehr flach), mit Symbol zu Fuß/Auto/Bahn und
  darunter der eigenen Beschriftung (Spitzname, Funkrufname, Spitzname mit Linie)
- Fahrzeuge der Kräfte mit Insassen beschriftet, z. B. „P 35/24 (Falke, Adler)“
- SOS wieder als Liquid Glass mit Schrift; beim Halten füllt sich nur der äußere weiße Ring
- Tempolimit immer sichtbar, sobald es für die Straße bekannt ist (OpenStreetMap über den eigenen Server), in
  derselben Größe wie die Knöpfe
- Plus-Menü: ÖPNV als eigene Kategorie; Zielperson und Zielfahrzeug als „mit dynamischem Standort“ gekennzeichnet
- Vorschau beim Setzen sieht schon aus wie das spätere Symbol (Marker, Zielperson, Zielfahrzeug)

**Ziele**
- Unter „Hinführen“: Umschalter zu Fuß / Fahrzeug / ÖPNV wie bei den Kräften und der Knopf „Standortquelle“
  (von Hand setzen, an Tracker binden, der A-Position folgen) – je Ziel einzeln
- Zielfahrzeug zeigt seine Insassen (mit „Hinführen“), beschriftet mit Kennzeichen und Namen
- Zielperson im ÖPNV: rotes Symbol mit Bahn am Fahrzeug, beschriftet mit Name und Linie
- Zielliste ohne grünen „Standort gesetzt“-Hinweis
- Markierungen (Marker, Beschriftung, Linie, Pfeil, Fläche, Kreis) sind nur noch statisch, ohne Tracker

**ÖPNV**
- Übernehmen aus der ÖPNV-Karte ergibt eine ÖPNV-Strecke mit einzeln zuschaltbaren Ebenen Fahrzeug, Strecke,
  Haltestellen (später in der Strecke änderbar); nur das Fahrzeug verschwindet nach der Ankunft
- Fehler „Too big: expected string to have <=20 characters“ beim Übernehmen behoben
- Fahrzeugkarte mit Linienschild und Richtung; Haltestellen mit Haltestellensymbol; „Nur die Linie“ entfällt
- Gruppen und Mehrfachauswahl entfallen


## 0.14.0

**Karte**
- SOS-Knopf: wieder mit Aufschrift; beim Halten füllt er sich weiß, außen läuft ein Ring
- Standortknopf neu, aufgebaut wie im Tesla:
  - In der Mitte zeigt der Pfeil immer nach oben, darum dreht sich die Kompassrose mit den Himmelsrichtungen so,
    wie die Karte ausgerichtet ist.
  - Angeheftet ist der Pfeil gefüllt, frei ist er hohl.
  - Der erste Druck heftet immer an: in Fahrtrichtung, nah und flach wie eine Navi-App. Der nächste wechselt zu
    Norden oben, senkrecht von oben, und zurück.
  - Zoomen und Drehen gehen mit zwei Fingern; kleine seitliche Bewegungen lösen die Kopplung nicht, erst
    bewusstes Wegschieben. Die Plus/Minus-Knöpfe entfallen.
- Eigener Standort als flach auf der Karte liegender Kreis (kippt mit der Karte), immer gleich groß, mit Symbol
  zu Fuß, Auto oder Bahn
- Einheitliche Symbole: Kräfte und eigene Fahrzeuge blau-lila, Ziele rot, jeweils als abgerundetes Quadrat mit
  dem Symbol der Fortbewegung bzw. Zielart (Haus für Objekte)
- Eine Zielperson in einem Zielfahrzeug, Gebäude oder ÖPNV-Fahrzeug erscheint nicht mehr als eigenes Symbol;
  ihr Name steht am Fahrzeug
- A-Knopf, Dreier-Umschalter und Lageleiste so hoch wie die runden Knöpfe und die Suchleiste
- Plus-Menü: ÖPNV ist ein einziger Eintrag (die ÖPNV-Karte), darüber Fahrzeuge, Strecken und Haltestellen;
  Kacheln einzeilig; beim Übernehmen ein Umschalter (Fahrzeug, Strecke, Beides) statt Häkchen
- Ort setzen sieht überall gleich aus: Antippen, Vorschau-Nadel, Leiste mit „Übernehmen“ – auf der Lagekarte und
  bei der Standortwahl eines Ziels

**Suche**
- Straßen und Adressen stehen immer vorn, dann Örtlichkeiten, dann Haltestellen
- Kreuzungen auch mit „Ecke“, „x“ oder „und“ („Heegbarg Ecke Wentzelplatz“); Tipp- und Hörfehler in Straßennamen
  werden der ähnlichsten Straße der Umgebung zugeordnet („Hegbark Ecke Wenzelplatz“ findet die Kreuzung) und
  richtig geschrieben angezeigt
- Die Eingabe selbst wird immer mitgeprüft, auch wenn Apple Karten sie nicht vervollständigt

**Ziele und Kräfte**
- Ziele-Tab wie der Kräfte-Tab: getrennte Abschnitte für Zielfahrzeuge, Zielpersonen und Zielobjekte, je Ziel ein
  Schalter zum Ein- und Ausblenden auf der Karte
- Suche in Kräfte (Spitzname, Funkrufname, Kennzeichen) und Ziele (Name, Kennzeichen, Anschrift), Treffer bleiben
  nach Abschnitten getrennt
- Zielperson steigt ein wie eine Kraft: „Fahrzeug“, „ÖPNV“ oder „Gebäude“ öffnet dieselbe Auswahl wie die
  Fahrzeugwahl der Kräfte, mit „Anderes Fahrzeug“ und „Neues Zielfahrzeug“
- Kräfte-Tab mit Plus zum Anlegen von Fahrzeugen; Fahrzeug- und Zielbilder quadratisch
- Kräfte, Ziele, Chat und Mehr mit gleichem Kopf: großer Titel, Plus auf gleicher Höhe, Suchfeld darunter

**Server**
- Verwaiste Dateien (gelöschte Nachrichten, Ziele, Markierungen) werden nach einem Tag aufgeräumt
- ÖPNV-Zwischenspeicher fest begrenzt

**Technik**
- Codebasis aufgeräumt: Routen, Datenablage und Migrationen des Servers getrennt; Lagekarte, Kartenebenen,
  Bedienelemente, Datenmodell und Zielansichten der App in thematische Dateien aufgeteilt; ungenutzter Code entfernt;
  strengere Compiler-Prüfung; neue Tests


## 0.13.0

**Instanzen**
- Instanzenmenü unter Mehr: eigene Einsätze anlegen, öffnen, beitreten, verlassen, umbenennen und löschen;
  Mitglied in mehreren, geöffnet ist immer genau eine; die Hauptlage bleibt immer bestehen
- Jede Instanz hat eigene Lage, Ziele, Chats, A-Position, Notruf, Funkkanal und Bestreifung; Kräfte sieht man in
  der Instanz, in der sie gerade arbeiten
- A-Position und Notruf in einer anderen eigenen Instanz kommen als Hinweis mit „Öffnen“, im Hintergrund als
  iOS-Mitteilung mit „Instanz öffnen“
- Dauerhafte Orte gelten in allen Instanzen und werden im eigenen Sonderbereich „Dauerhafte Orte bearbeiten“
  geändert (statt des Schalters unter Mehr); dort sind nur die Werkzeuge für Markierungen sichtbar
- Sonderbereich „Paket vorbereiten“: Pakete anlegen, bearbeiten, löschen; Bibliothek auf dem Server;
  „Übernehmen“ kopiert den Inhalt unwiderruflich als eigenständige Objekte in den geöffneten Einsatz
- Lage-Layer jeder Instanz lässt sich leeren, aber nicht löschen
- Kommandozentrale: Bereich „Instanzen“ mit Einsätzen und Paketen, Anzeige der geöffneten Instanz

**Navigation**
- Querstraßen: Die nächste kreuzende Straße steht mit Entfernung im Navi-Banner (OpenStreetMap über den
  eigenen Server)

**ÖPNV**
- Linienschilder im HVV-Stil in allen ÖPNV-Listen (Fortbewegung, Liniensuche, Linie, Fahrzeug), gleich egal
  wie die Linie angelegt wurde
- ÖPNV-Strecke in einzelne Abschnitte zwischen den Halten teilen; Abschnitte sind einzeln löschbar
- Positionsberechnung der ÖPNV-Fahrzeuge deutlich schneller (zwischengespeichert, ohne CLLocation), damit die
  Karte bei vielen übernommenen Fahrten nicht stockt

**Tracker**
- PAJ-Tracker mit eigenem Konto: E-Mail und Passwort gelten nur für diesen Tracker, werden verschlüsselt
  gespeichert; beim Anlegen wird geprüft, ob das Gerät zum Konto gehört („Gerät nicht in diesem Konto“)

**Kommandozentrale**
- Lebensdauer und Fotos bzw. Dateien an Markierungen bearbeitbar, PAJ-Tracker mit eigenem Konto anlegen


## 0.11.0

**ÖPNV deutschlandweit (Transitous, Daten DELFI u. a., Echtzeit wo verfügbar)**
- Neue ÖPNV-Karte im Plus-Menü, angelehnt an Travic: fahrende Fahrzeuge in Linienfarbe bewegen sich live,
  Haltestellen mit Abfahrten; Suche nach Linien (alle Fahrzeuge der Linie) und Haltestellen
- Fahrzeug antippen: hervorgehoben mit Linienverlauf und Halten, Verspätung; wählen, was übernommen wird –
  Fahrzeug, Strecke, Haltestellen, beliebig kombiniert; mehrere Teile werden eine Gruppe
- Übernommene Fahrzeuge fahren nach echtem Fahrplan; der Server führt Verspätungen jede Minute nach
- Haltestelle antippen: Abfahrten ansehen, eine Fahrt daraus wählen oder die Haltestelle übernehmen
- ÖPNV in der Navigation: beste Verbindung mit Bus und Bahn als Fahrtenkette in der App
- Haltestellen in der Ortssuche jetzt auch außerhalb Hamburgs

**Gruppen und Haltestellen**
- Lange drücken auf eine Markierung oder Fläche startet die Mehrfachauswahl; Leiste mit Gruppieren,
  Auflösen, Löschen; keine verschachtelten Gruppen
- Objekte in einer Gruppe zeigen über dem Detailfenster eine Gruppenleiste (auflösen, alle löschen)
- „Haltestelle“ als eigene Markierung; beim Setzen werden echte Haltestellen in der Nähe zur Zuordnung angeboten


## 0.10.0

**Karte**
- Ein Knopf für Kompass und Standort: erst zentrieren und folgen (Norden oben), dann Gerätekompass; zeigt die
  Nordrichtung, wenn die Karte gedreht ist; Verschieben löst die Kopplung, zwei Finger drehen frei
- Runde Knöpfe und Suchleiste so groß wie Apples Kompassrose
- Bestreifung als dezente orange Spur, mehrfach bestreifte Abschnitte kräftiger (begrenzt)
- Langes Drücken auf einen Ort: „Navigieren“ oder „Hier anlegen“
- Übereinanderliegende Symbole werden auseinandergerückt und sind einzeln antippbar
- Andere Kräfte als eckige Marker mit Symbol der Fortbewegung (wie der eigene, runde Standortpunkt)
- Navigation: eigener Standort wird nicht mehr von der unteren Leiste verdeckt
- Display bleibt an, solange Sentinel im Vordergrund ist

**Markierungen**
- Pfeile als neue Markierung; Flächen, Kreise und Linien ohne Griff in der Mitte, direkt antippbar
- Beschriftung direkt in Flächen und Kreisen, bei schmalen Flächen entlang der längsten Seite
- ÖPNV-Fahrzeuge bewegen sich wieder sichtbar auf der Karte (Takt war seit 0.7 verloren gegangen)

**Suche**
- Haltestellen in der Ortssuche (mit Linien); Kreuzungen und Hausnummern nur, wenn es sie wirklich gibt

**Ziele**
- Zielperson unterwegs: zu Fuß, ÖPNV, Fahrzeug oder Gebäude; zugeordnet folgt sie dem Fahrzeug bzw. Objekt,
  Vorschläge nach Entfernung
- Zielpersonen, -fahrzeuge und -objekte in den Kartenebenen einzeln ein- und ausblendbar

**Bedienung**
- SOS: weiße Tortenfüllung und Ring beim Halten; „Navigieren“ statt „Hierhin navigieren“


## 0.9.0

**Karte**
- Standort-Nachführung und Kompass nativ von Apple Karten: flüssig ohne Sprünge, Kompassrose im Original-Look
- Standortknopf schaltet wie in Apple Karten: aus → folgen → folgen mit Blickrichtung → aus
- Neuer Ort (Marker, Ziel, Verschieben): erst orangefarbene Vorschau, „Übernehmen“ setzt ihn; erneutes Tippen verschiebt
- Suchtreffer: nur Karte und Treffer-Feld sichtbar, bis navigiert, angelegt oder geschlossen wird

**Bedienung**
- Fortbewegung wieder als natives Segment mit gleitender Auswahl; „Anderes Fahrzeug“ als eigener Bereich „Sonstiges“
- SOS-Ring bleibt beim Halten sichtbar; SOS-Balken ohne Farbverlauf; „Hinführen“-Symbol weiß und gut lesbar
- App gesperrt mit Erklärung, wenn App und Server nicht dieselbe Version haben

**ÖPNV und Fahndung**
- ÖPNV-Linie wird immer komplett von Anfang bis Ende angelegt
- Busnummern weiß auf HVV-Rot, U-Bahn und Bus eckig, S-Bahn rund
- Kein „Abgebrochen“-Fehler mehr beim Tippen im Linien-Editor
- Fahndungsraum: „Jetzt“ bzw. „Hier und jetzt“ direkt in der Ansicht; Zeitknöpfe als einmalige Aktion; keine Fotos
  bei Fahndungsraum und Haltestellen im Umkreis

**Stabilität**
- Neuberechnete Routen werden auf dem Hauptthread übernommen (mögliche Absturzursache in der Navigation)


## 0.8.0

**Karte und Navigation**
- Fahrmodus ohne Navigation mit normalem Standortpunkt und Straßenbanner; Navi-Pfeil nur in der Navigation;
  nach dem Beenden der Navigation endet auch der Fahrmodus
- Eigener Standort im Fahrzeug bzw. ÖPNV als Standortpunkt mit Auto- bzw. Bahn-/Bus-Symbol
- Kompass: Antippen wechselt zwischen Norden oben und Gerätekompass; von Hand gedreht bleibt die Drehung
- Einheitliches Symbol für alle „Hinführen“/„Hierhin navigieren“-Knöpfe
- Hinweis, wenn App und Server nicht dieselbe Version (Haupt-/Nebenversion) haben

**Anlegen und Suche**
- Plus öffnet ein großes Auswahlmenü mit Kacheln; „Hier anlegen“ am Suchtreffer nutzt dasselbe Menü
- Beim Setzen eines Orts nur Karte und Suchleiste; die Suchleiste sucht dann den Ort
- Suchtreffer-Feld mit zwei gleichen Knöpfen und zuverlässigem Schließen

**Bedienung**
- Dreier-Auswahl Fortbewegung aus Glas-Teilen mit Druckeffekt; SOS-Ring sitzt außen um den Knopf
- „Anderes Fahrzeug“ beim Einsteigen (nicht in der Liste)
- Ziele: Titel und Plus in einer Zeile, doppelter Anlegen-Knopf entfernt

**Lage und Ebenen**
- „Lage zurücksetzen“ entfernt; stattdessen „Lage-Ebene leeren“ in den Kartenebenen
- Bestreifung wird beim Ausschalten von „Bestreifte Wege“ zurückgesetzt
- Fahndungsraum-Schalter nur, wenn ein Fahndungsraum besteht; ÖPNV-Linien ohne Navigieren-Knopf


## 0.7.0

**ÖPNV**
- Linien folgen dem tatsächlichen Fahrweg (Straßen, Gleise aus OpenStreetMap) in der offiziellen Linienfarbe;
  Fahrzeuge fahren auf diesem Weg
- Ein Haltestellensymbol überall (H-Schild, S- und U-Bahn-Logo): Haltestellen im Umkreis, ÖPNV-Linie, Überschlagen
- Linienkennzeichen in den Farben aus OpenStreetMap; Apple-eigene Haltestellen-Symbole ausgeblendet
- ÖPNV-Linie und -Fahrzeug: ohne Antippen anlegen, Linien rund um den Kartenausschnitt, Suche nach Nummer nach Entfernung sortiert

**Karte und Navigation**
- Fortbewegung als Glas-Auswahl im Stil der Tab-Leiste, auch in der Navigation (Auto, zu Fuß, ÖPNV);
  ÖPNV zeigt die Ankunft mit Bus und Bahn und öffnet die Verbindung in Apple Karten
- SOS-Knopf in Liquid Glass; Kompassknopf als Kompassrose mit rotem N, Norden als Pfeil mit N
- Ausrichtung „Kurs“ dreht die Karte im Stand mit dem Gerätekompass
- Navi-Pfeil liegt flach auf der Karte und zeigt in Fahrtrichtung; verschwindet nicht mehr
- 3D-Haken folgt auch dem Kippen mit zwei Fingern, die Karte springt nicht mehr zurück
- Sonderrechte: Route immer rot
- Spracheingabe für das Ziel (auf dem Gerät), z. B. „Navigiere zur A-Position“ oder „Fahr zum Hauptbahnhof“
- Hinweise oben flach ohne Farbverlauf

**Suche und Anlegen**
- Suchtreffer: Karte springt hin, unten ein Feld mit „Hierhin navigieren“ und „Hier anlegen“
- Beim Setzen eines Orts (Plus-Menü, Ziel-Standort, Verschieben) Lupe zum Suchen statt Antippen

**Fehler**
- Sehr breite Fotos sprengen die Fotoliste nicht mehr


## 0.6.0

**Navigation neu auf dem quelloffenen Navigationskern Ferrostar**
- Ferrostar übernimmt die Navi-Logik: Standort auf die Route legen, Abweichung erkennen, sofort neu berechnen,
  Hinweise im richtigen Moment weiterschalten; der Eigenbau ist entfernt
- Routen kommen vom eigenen Server (Valhalla); ohne Sonderrechte gibt Apple Karten den Weg mit aktueller
  Verkehrslage vor, die Ankunftszeit berücksichtigt den Verkehr
- Sonderrechte: Der Server rechnet beide Varianten und führt nur dann gegen Einbahnstraßen oder Abbiegeverbote,
  wenn das mindestens 45 Sekunden und 12 % der Fahrzeit spart (keine „Abkürzung“ mehr über die Gegenfahrbahn)
- Tempolimit als Verkehrszeichen neben der eigenen Geschwindigkeit, Fahrspuren im Abbiegehinweis, soweit bekannt
- Bewegte Ziele (A, Kräfte) werden laufend nachgeführt
- Keine Sprachansagen

**Hinweise und Notruf**
- Hinweise oben im Bild in drei Stufen (grün, gelb, rot) mit passender Vibration, rot kräftig und mehrfach;
  im Hintergrund als iOS-Mitteilung (A übernommen oder frei, Notruf, neue Nachrichten)
- SOS-Knopf auf der Karte (1,5 s gedrückt halten): Bei allen anderen startet sofort die Navigation mit
  Sonderrechten zum Absender; roter Balken, solange der Notruf läuft; beenden durch Absender oder Zentrale
- Kommandozentrale zeigt den Notruf als roten Balken mit „Auf der Karte zeigen“ und „Notruf beenden“

**ÖPNV auf der Karte**
- Neue Objekte im Plus-Menü: „ÖPNV-Linie“ (Abschnitt einer Linie mit allen Halten) und „ÖPNV-Fahrzeug“
- Linie wählen: Vorschläge in der Nähe des angetippten Orts oder Suche nach Name, jede Richtung eigener Eintrag;
  Start- und Endhalt in der Haltestellenliste antippen
- ÖPNV-Linie: Schalter „Fahrzeuge im Takt einblenden“ (Takt und eine Abfahrtszeit); Fahrzeuge erscheinen, sobald sie
  den Abschnitt befahren, und verschwinden am Ende; antippen legt sie als ÖPNV-Fahrzeug an oder führt hin
- ÖPNV-Fahrzeug: Abfahrt am Starthalt, fährt bis zur Endhaltestelle, löscht sich danach selbst; Hinführen folgt ihm
  live; „Strecke als ÖPNV-Linie anlegen“ in der Ansicht
- Positionen nach typischem Tempo der Verkehrsart geschätzt, noch ohne Fahrplan- oder Echtzeitdaten
- Zu Objekten navigieren: „live“-Hinweis bei beweglichen Zielen; „Zur Linie der A: nächste Haltestelle“

**Fahndungsraum**
- ÖPNV-Fluchtraum entlang der tatsächlichen Linien: zu Fuß zu nahen Halten, Bus und Bahn mit typischem Tempo,
  Umsteigen, vom letzten Halt zu Fuß weiter; als zusammenhängende Fläche statt Kreis (ohne Fahrpläne, Wartezeit pauschal)
- Letzte Sichtung: Datum und Uhrzeit plus Knöpfe „Jetzt“ und „vor 5/10/15/30/45/60“ Minuten
- Nach dem Verschieben fragt die App, ob die Sichtung auf jetzt gesetzt werden soll

**Ziele und Markierungen**
- Antippen öffnet immer erst die Ansicht (Marker, Formen, Ziele, Kräfte): links „Schließen“, rechts „Bearbeiten“;
  Verschieben und Löschen gibt es im Bearbeiten-Fenster
- Lebensdauer für Markierungen (Standard unbegrenzt, sonst 15 Minuten bis 7 Tage): danach löschen sie sich selbst
- Adresssuche: Antippen eines Treffers fragt „Hierhin navigieren“, „Auf der Karte zeigen“ oder „Hier anlegen …“;
  der gezeigte Treffer bleibt als Stecknadel auf der Karte und bietet die Auswahl beim Antippen erneut an
- Fotos (Kamera oder Mediathek) und Dateien an Markierungen und Zielen; beim Antippen sichtbar und zu öffnen
- Einheitliche Fotoliste überall (bis 100): das leere Bild mit Kamera fügt hinzu (aufnehmen, Mediathek, Datei),
  Antippen eines Fotos bietet Ansehen, Ersetzen, Titelbild und Entfernen; kein Drei-Punkte-Knopf mehr.
  Bei Zielen ist das erste Foto das Titelbild; frühere Einzelbilder (Bild, Fahrzeugbild) sind übernommen
- Ziele: ein gemeinsames Freitextfeld „Notizen“ statt Merkmale, Sachverhalt, Hinweise und Maßnahmen
  (bestehende Texte mit Überschrift zusammengeführt); Geburtsdatum als Textfeld, leer heißt unbekannt
- Ziele: Standort über ein Menü festlegen oder ändern – auf der Karte oder per Adresse wählen, Anschrift übernehmen,
  eigener Standort, GPS-Tracker, entfernen; mit Kartenvorschau des gesetzten Standorts
- Adresssuche: „Hier anlegen …“ legt am Treffer Marker, Text, Kreis, Fahndungsraum, Haltestellen oder ein Ziel an
- Ziel-Editor ohne Artauswahl (die Art steht beim Anlegen fest) und mit passenden Feldern je Art:
  Zielobjekt = Gebäude (Anschrift, Beschreibung, Bild), Zielfahrzeug = Fahrzeugdaten, Zielperson = Personendaten

**Kartenausrichtung**
- Kompassknopf schaltet durch: Fahrtrichtung (Standard), Norden, Übersicht der ganzen Route
- Mit zwei Fingern gedreht bleibt die Ausrichtung fest, bis man am Kompass wieder umschaltet

## 0.5.0

**Navigation und Fahrmodus**
- Fahrmodus (Standortknopf, Navigation): Kamera gleitet gleichmäßig zwischen den GPS-Meldungen, gekippt und in
  Fahrtrichtung; der eigene Navi-Pfeil sitzt fest in der Bildmitte statt in Sprüngen über die Karte zu hüpfen
- Straße und Fahrtrichtung mit festem Abstand unter dem Pfeil, nie mehr im Symbol
- Geschwindigkeitsanzeige im Fahrmodus und in der Navigation
- Breite Routenlinie mit Rand; die gefahrene Strecke verschwindet hinter einem
- Abbiegehinweise passen zur Stelle: Manöver werden im Linienzug gesucht statt aufsummiert (vorher verrutschten
  sie mit jedem Schritt)
- Adresssuche prüft Straße und Hausnummer; „Hegbarg 1“ führt nie mehr ohne Rückfrage zu „Hempbarg 1“

**Karte**
- Runde Knöpfe wieder so hoch wie die Suchleiste, eigener Kompass in derselben Größe mit Tippfeedback,
  ohne Wirbeln über Nord
- 3D wieder im Kartenstil-Menü schaltbar
- A-Knopf mit klarem, einfarbigem A-Symbol
- Eigenes Symbol (Fahrzeug) bewegt sich flüssig wie der Systempunkt
- Haltestellen mit S-Bahn-, U-Bahn- und Haltestellensymbol, Linien als farbige Liniennummern
- Umkreis der Haltestellen-Markierung per Schieberegler oder Eingabe

## 0.4.0

**Eigener Standort**
- Sitzt man im Fahrzeug, wird der eigene Punkt zum Fahrzeug (kein zweites Symbol mehr darüber)
- In der Navigation ein Navi-Pfeil in Fahrtrichtung statt des Standardpunkts
- Straßenschild mit Abstand unter dem eigenen Symbol und immer mit Fahrtrichtung (im Stand per Kompass)

**Karte**
- Runde Knöpfe wieder 44 pt, nativer Kompass immer sichtbar, Plus-Knopf unten in der Spalte
- Karte immer in 3D, Kartenstil-Knopf ohne 2D/3D; eigenes Symbol für „auf mich zentrieren“
- Fortbewegung (nur Symbole, halbe Breite) und A-Knopf in einer Zeile; A wieder als echtes Symbol
- Apples Rechtshinweis klein unter der Tableiste
- Suche: Suchleiste für Adressen, Objekte-Knopf für die Objektliste, kein Umschalter mehr
- Bestreifte Wege erst ab dem Einschalten

**Navigation**
- Abweichen und Überfahren des Ziels wird schneller erkannt und neu berechnet
- „Route wird neu berechnet …“ mit Ladeanzeige im Abbiegehinweis
- Sonderrechte in Rot, ohne zusätzlichen Hinweistext

**Listen und Chat**
- Ganz durchwischen löscht Ziele, Fahrzeuge und Chaträume direkt
- Eigene Nachrichten lassen sich löschen (gedrückt halten), der allgemeine Chatraum lässt sich leeren
- Schalter einheitlich grün

## 0.3.0

**Aussehen und Bedienung**
- Akzentfarbe wieder Systemblau, in der App, im App-Icon und in der Kommandozentrale
- Runde Kartenknöpfe einheitlich groß, keine Überlagerung mehr: eigener Kompass (nur wenn nicht genordet),
  Kartenstil, 2D/3D und Verkehrslage in einem Knopf; Ebenen enthalten nur noch Ebenen und Anzeigen
- Neuer hervorgehobener Knopf neben der Suche: zu Objekten navigieren
- A-Position: ein Knopf mit gleichem Wortlaut („übernehmen“, „wirklich übernehmen?“, „abgeben“);
  die eigene A lässt sich auch über den A-Pin abgeben
- Fortbewegung als Dreier-Auswahl direkt auf der Karte; nur Fahrzeug und ÖPNV öffnen eine Auswahl
- Mehr aufgeräumt: ein Schalter „Im Dienst“ (teilt den Standort), Fortbewegung und Bestreifung dort entfernt,
  „Dauerhafte Orte bearbeiten“ mit gleichbleibendem Text
- Fahndungsraum: Zeitwahl als iOS-Segmentsteuerung

**Navigation und Suche**
- Navi-Ansicht nah am eigenen Standort, in Fahrtrichtung und gekippt; verschiebt man die Karte, bleibt sie stehen,
  der Standortknopf holt die Führung zurück
- Abbiegehinweis ohne Farbverlauf, ruhig wie in Apple Karten; „Beenden“ einzeilig
- Ohne Sonderrechte rechnet Apple Karten auf dem Gerät; mit Sonderrechten das eigene Wegenetz, Ankunftszeit mit
  rund 50 % höherem Tempo
- Adressvorschläge nur aus der Nähe; Hausnummer vorn („3 Heg…“) wird an die vervollständigte Straße gehängt

**Lage**
- Fahrzeugposition: Sitzt jemand drin, ist dessen Telefon die Quelle, der Tracker nur ohne Besatzung
- Neue Markierung „Haltestellen im Umkreis“: zeigt alle Bus- und Bahnhaltestellen mit Linien; beim Fahndungsraum
  optional gleich mitsetzen
- Haltestellen beim überschlagenden Anfahren mit Haltestellenschild

**Chat**
- Sprachnachrichten mit Wellenform bei Aufnahme und Wiedergabe

**Listen und Dialoge**
- Ziele und Fahrzeuge per Wischen löschen
- Bestätigungen als zentrierte iOS-Hinweise statt Sprechblasen
- Fahrzeuge zeigen in Liste und Karte nur den Funkrufnamen; aus 0.1 übernommene Fahrzeuge erhalten den
  Funkrufnamen ihres Trackers, falls dieser einen gültigen trägt

**Robustheit**
- Unbekannte Einträge eines neueren Servers werden übersprungen statt den ganzen Lagestand zu verwerfen

## 0.2.2

- Neues App-Icon: Schild mit Schriftzug SENTINEL auf Schwarz, wie der Startbildschirm; auch in SideStore und als Favicon der Kommandozentrale

## 0.2.1

- App hing beim Start (Logo, schwarzer Bildschirm oder „Verbinde mit dem Server“): Die Karte wurde bei jeder
  Kamerabewegung neu berechnet; das Straßenschild unter dem eigenen Punkt ist jetzt eine Kartenannotation
- Einheitliche Höhen und Breiten aller Leisten und Knöpfe, Lageleiste nur noch auf der Karte
- Spitzname im Avatar zentriert, Chat-Eingabe angeglichen
- Rundgang-Test läuft mit echtem Standort im Simulator

## 0.2.0

**Grundlegend neu**
- Keine Modi mehr: eine Hauptkarte, Fahndungsfunktionen als Kartenelemente
- Fahnder und Fahrzeuge getrennt: Fahnder mit Spitznamen, Fahrzeuge mit Funkrufnamen, je Einsatz aktiv schaltbar
- Fortbewegung je Fahnder: zu Fuß, Fahrzeug (Auswahl) oder ÖPNV (Linie und Richtung, Vorschläge in der Nähe);
  Einsteigen/Aussteigen entfällt, das Fahrzeug bleibt beim letzten Wechsel stehen
- Ruhemodus: Fahnder schalten sich selbst ab, dann wird kein Standort geteilt

**Karte und Navigation**
- Navi-Ansicht mit nächstem Manöver, Entfernung, Ankunftszeit und Sonderrechte-Schalter
- Suche: Adressen mit Autovervollständigung (Hausnummer vorn oder hinten), Kreuzungen mit „&“ oder „/“,
  Objekte der Lage mit der A-Position ganz oben; Navigation folgt bewegten Zielen
- Überschlagendes Anfahren der nächsten Haltestellen, wenn die A im ÖPNV fährt
- Aktuelle Straße und Fahrtrichtung unter dem eigenen Standort
- Kartenstile Karte, Hybrid, Satellit mit 3D-Gelände; Verkehrslage zuschaltbar
- Plus-Knopf rechts oben unter dem Kompass: Fahndungsraum (mit Zeitpunkt), Zielperson, Zielfahrzeug, Zielobjekt,
  Marker, Beschriftung, Linie, Fläche, Kreis; Marker können einem Tracker folgen
- Look-Around-Vorschau für Anschriften von Zielobjekten
- Bestreifung wird immer aufgezeichnet und von jedem selbst eingeblendet (behebt fehlende Aufzeichnung)
- Dauerhafte Orte gegen versehentliches Bearbeiten gesperrt; Rückgängig/Wiederholen entfernt

**Chat**
- Chaträume anlegen und löschen, Fotos, Kamera, Dateien und Sprachnachrichten

**Verwaltung**
- Alle Einstellungen auch in der App: Ebenen und Pakete, Argus-Import, Tracker (umbenennen, löschen,
  Sendeintervall bei SinoTrack), PAJ, Geräte und Zugangscode, Lage zurücksetzen
- Tab „Team“ heißt jetzt „Kräfte“; neues Logo
- Kommandozentrale: OpenStreetMap-Kacheln laden wieder (Herkunftsangabe)

## 0.1.1

- Kommandozentrale im neuen Erscheinungsbild (nach dem Vorbild von Trace), hell und dunkel nach Systemeinstellung,
  mit Lageband, Bereichsleiste und dauerhafter Kräfteliste
- Routenführung mit Sonderrechten: Einbahnstraßen und Abbiegeverbote werden auf Wunsch ignoriert, physische Sperren
  bleiben beachtet; gerechnet wird auf dem eigenen Wegenetz
- Apple Maps in der Kommandozentrale vorbereitet (aktiv, sobald ein MapKit-Schlüssel hinterlegt ist), OpenStreetMap als Rückfall
- Releases entstehen automatisch, sobald eine neue Versionsnummer auf `main` landet

## 0.1.0

Erste Testversion: gemeinsame Lage, Modi Observation/Fahndung/Oberfläche, A-Position, Bestreifung, Weg-Zeit-Flächen,
Zielpersonen, Fahrzeuge, Markierungen mit Rückgängig/Wiederholen, Chat, Tracker (SinoTrack, PAJ), Argus-Import,
Kommandozentrale, SideStore-Quelle.
