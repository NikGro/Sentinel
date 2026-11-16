# Änderungen

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
