# Offene Punkte

Wünsche, Fehler und technische Arbeiten werden hier gesammelt und zu festen Zeitpunkten gebündelt umgesetzt,
statt jede Änderung sofort einzubauen. Erledigtes wandert mit Version ins CHANGELOG.

## Geplant

### Instanzen und mandantengetrennte Arbeitsbereiche

- **Instanzenverwaltung im Hauptmenü:** Im Hauptmenü eine Instanzenübersicht einführen, in der Nutzer neue Instanzen erstellen, bestehende Instanzen löschen, anderen Instanzen beitreten und Instanzen wieder verlassen können.
- **Mehrere Mitgliedschaften, genau eine aktive Instanz:** Nutzer können gleichzeitig Mitglied in mehreren Instanzen sein, aber immer nur eine Instanz aktiv geöffnet bzw. ausgewählt haben. Der Wechsel zwischen den Instanzen muss einfach möglich sein.
- **Ereignisbenachrichtigungen aus anderen Instanzen:** Bei wichtigen Ereignissen in einer anderen Instanz – insbesondere beim Anlegen einer A-Position und beim Auslösen eines SOS – eine actionable Benachrichtigung anzeigen. Ist die App geöffnet, als Banner in der App; läuft sie im Hintergrund oder ist geschlossen, als iOS-Push-Mitteilung. Die Aktion der Mitteilung öffnet direkt die betreffende Instanz.
- **Persistenter Objekt-Layer global über alle Instanzen:** Der persistente Objekt-Layer ist instanzübergreifend und seine Inhalte stehen in allen normalen Instanzen zur Verfügung.
- **Persistenter Objekt-Layer als eigener Bereich im Instanzenmenü:** Die bisherige Freischaltung bzw. Bearbeitung über den Tab „Mehr“ entfällt. Stattdessen erscheint der persistente Objekt-Layer im Instanzenmenü als eigener, optisch klar von den normalen Instanzen getrennter Eintrag.
- **Reduzierter Werkzeugmodus für den persistenten Objekt-Layer:** Beim Öffnen dieses Bereichs werden sämtliche normalen instanzbezogenen Werkzeuge und Elemente ausgeblendet. Sichtbar bleiben ausschließlich die Funktionen, die zum Erstellen und Bearbeiten von Markern und Kartenelementen des persistenten Objekt-Layers benötigt werden.
- **„Paket vorbereiten“ als zweiter Sonderbereich im Instanzenmenü:** Neben „Persistenten Layer bearbeiten“ einen eigenen Menüpunkt „Paket vorbereiten“ anbieten. Dieser öffnet ebenfalls einen isolierten Bearbeitungsbereich, der wie eine eigene Instanz funktioniert, aber ausschließlich der Vorbereitung von Layer-Paketen dient.
- **Objekt-Pakete verwalten:** In diesem Bereich können Nutzer Objekt-Pakete anlegen, bearbeiten und löschen. Die Pakete werden dauerhaft in einer serverweiten Bibliothek gespeichert und stehen damit instanzübergreifend zum Import bereit.
- **Pakete in bestehende Instanzen importieren:** Ein gespeichertes Objekt-Paket kann in eine bereits bestehende Instanz geladen werden.
- **Import wandelt Paketobjekte in Instanz-Member um:** Nach dem Import werden die enthaltenen Objekte zu regulären, in der Zielinstanz bearbeitbaren Membern. Sie sind danach eigenständige Instanzobjekte und nicht mehr an das ursprüngliche Paket gebunden.
- **Import ist nicht rückgängig zu machen:** Der Import ist eine irreversible Übernahme. Es darf keine Funktion geben, mit der sich der Import zurücknehmen oder die importierten Instanzobjekte automatisch wieder aus der Instanz entfernen lassen.
- **Lage-Layer pro Instanz geschützt:** Jede normale Instanz besitzt ihren eigenen Lage-Layer. Dieser kann nicht gelöscht oder entfernt werden, darf aber vollständig geleert (gecleared) werden.

### Karte, Kompass und Navigation


- **Querstraßen in der Navigation:** Namen kreuzender Straßen entlang der Route anzeigen. Valhalla liefert diese nicht mit; dafür ist eine eigene Abfrage der Kreuzungen entlang der Route (OSM) erforderlich.
- **App-Absturz während aktiver Navigation untersuchen (0.9: mögliche Ursache beim Neuberechnen abgesichert; Absturzbericht nötig – Einstellungen › Datenschutz & Sicherheit › Analyse & Verbesserungen › Analysedaten › „Sentinel-…“):** Die App ist während einer laufenden Navigation abgestürzt. Crash-Ursache anhand von Crash-Logs und reproduzierbaren Navigationsabläufen ermitteln und beheben. Navigation gezielt auf längere Laufzeit, häufige Positions-/Routenupdates, Wechsel zwischen Vorder- und Hintergrund sowie ungültige oder ausbleibende Standortdaten testen. Sicherstellen, dass ein einzelner fehlerhafter Standort- oder Routen-Update die App nicht zum Absturz bringt.

### Marker, Suche und Ortsauswahl

- **Marker direkt auf 3D-Gebäudefassaden platzieren (geprüft: mit Apple MapKit nicht machbar – Markierungen liegen immer am Boden, Fassadenhöhen sind nicht abfragbar; nur mit eigener 3D-Engine und fotorealistischen 3D-Kacheln, z. B. Google Photorealistic 3D Tiles mit CesiumJS, sehr aufwendig):** Auf einer realistisch dargestellten 3D-Satellitenkarte soll es möglich sein, Kartenelemente direkt auf einer Gebäudefassade zu zeichnen bzw. zu platzieren – beispielsweise ein Rechteck um bestimmte Fenster, die zu einer Zielwohnung gehören. Das Element soll an der tatsächlichen Fassadenposition haften und sich mit der 3D-Kameraperspektive korrekt darstellen. Diese Funktion ist ausdrücklich für die realistische 3D-Satellitenansicht gedacht: In der vereinfachten 3D-Kartenansicht mit schematischen Gebäudekörpern („Würfeln“), die keine realistischen Fassaden oder Fenster zeigen, ist eine solche fensterbezogene Markierung nicht sinnvoll und soll daher nicht angeboten bzw. dort nicht als unterstützt dargestellt werden. Die technische Machbarkeit und geeignete Interaktion für das Zeichnen auf Fassaden prüfen.

### Bedienoberfläche und Liquid Glass

- **Zielperson-Icon-Auswahl darf Karte nicht einfrieren (Rückfrage: welches Icon genau – im Plus-Menü, im Editor oder auf der Karte?):** Beim Anlegen einer Zielperson friert die Karte ein, sobald das Icon angetippt wird. Ursache für den UI-/Map-Freeze beheben und die Icon-Auswahl ohne Blockieren der Karteninteraktion ermöglichen.

### ÖPNV, Linien und Fahrzeuge

- **Linien als einzelne Haltestellen und Streckenobjekte modellieren (0.11: Haltestellen als eigene, einzeln löschbare Markierungen in einer Gruppe mit der Strecke; offen: Strecke in einzeln löschbare Abschnitte teilen):** Eine erzeugte Linie soll aus regulären Haltestellen-Pins und den verbindenden Linien-/Streckenobjekten bestehen, statt als unteilbares Gesamtobjekt verwaltet zu werden. Einzelne Haltestellen oder Streckenabschnitte müssen separat löschbar sein.

- **HVV-konforme Linien- und Haltestellensymbole:** Die derzeit falschen ÖPNV-Icons durch die offiziellen bzw. auf HVV-Fahrplänen verwendeten Symbole ersetzen. Geeignete SVG-Quellen prüfen (unter anderem Wikipedia, sofern Lizenz und Gestaltung passen). Für Bus, Regionalbahn, S-Bahn und U-Bahn die passenden Symbole verwenden.
- **Symbole in sämtlichen ÖPNV-Listen:** Überall, wo ÖPNV-Verbindungen oder Linien aufgelistet werden, muss das jeweils passende HVV-Verkehrsmittelsymbol erscheinen.
- **Konsistente Symbole unabhängig vom Erstellungsweg:** Linien- und Haltestellensymbole müssen gleich aussehen, unabhängig davon, ob eine Linie manuell oder beispielsweise aus einer A-Position heraus erzeugt wurde.

### Lage, Karten-Layer und Bestreifung

### Tracker

- **PAJ-Tracker mit eigenem Konto je Tracker:** Beim Hinzufügen nicht nur die Geräte-ID, sondern einmalig E-Mail und Passwort des PAJ-Kontos angeben, dem das Gerät gehört (jeder Fahnder hat sein eigenes Konto). Zugangsdaten nur für diesen Tracker speichern, nicht global in Sentinel. Beim Anlegen prüfen, ob die ID wirklich zu diesem Konto gehört, sonst „Gerät nicht in diesem Konto“ anzeigen.
- **SinoTrack „Test“ (7026222172) sendet nicht:** Portweiterleitung TCP 5013 im Router zur Synology und die SMS-Einrichtung des Geräts (öffentliche Adresse, Port 5013, Protokoll H02) prüfen.

### App-/Server-Kompatibilität

### Codebase-Qualität und Architektur

- **Vollständige Codebase-Überprüfung und Bereinigung:** Die gesamte Codebase architektonisch überprüfen, aufräumen und bereinigen. Insbesondere auf Best Practices, Fehler, technische Schulden und unsaubere Muster achten, die durch wiederholte Revisionen und nachträgliche Änderungen entstanden sind.
- **Produktionsreife Struktur herstellen:** Verantwortlichkeiten und Modulgrenzen prüfen, Duplikate und unnötige Komplexität reduzieren, ineffiziente Abläufe identifizieren und die Codebasis konsistent, wartbar, effizient und klar strukturiert gestalten.
- **Qualität absichern:** Relevante Tests ergänzen bzw. aktualisieren und kritische App-/Server-Schnittstellen sowie Navigations-, Karten- und ÖPNV-Flows nach der Bereinigung gezielt prüfen.

### Noch praktisch zu überprüfen

- **Auf dem Gerät prüfen:** Ferrostar-Navigation, Fahrzeugsymbol nach dem Aussteigen, Fotoliste und Standort-Menü.
- **Kommandozentrale:** Lebensdauer und weitere Fotos auch dort bearbeitbar machen.

## Umsetzungsreihenfolge

Die offenen Punkte aus diesem Dokument einschließlich der bereits zuvor gesammelten Aufgaben sollen in die gebündelte Umsetzung einfließen. Vor größeren UI-Änderungen bestehende Komponenten und Zustandsübergänge prüfen, damit keine bereits behobenen Fehler erneut entstehen. Die Codebase-Überprüfung soll als technische Grundlage dienen; anschließend die funktionalen Änderungen in zusammenhängenden Bereichen umsetzen und jeweils testen.
