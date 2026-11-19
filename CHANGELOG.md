# Änderungen

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
