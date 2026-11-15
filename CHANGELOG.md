# Änderungen

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
