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

- **Kompassrose nativ wie iOS gestalten:** Die aktuelle Kompassrose entspricht trotz mehrfacher Überarbeitung weiterhin nicht der nativen iOS-/Apple-Karten-Optik. Gestaltung, Proportionen, Typografie, Symbole und Zustände nochmals anhand des nativen Vorbilds umsetzen statt die bisherige Eigeninterpretation fortzuführen.
- **Kompassorientierung wirklich flüssig machen:** Die Kompassausrichtung ist weiterhin hakelig. Sensorwerte und Kartenrotation müssen geglättet und ohne sichtbare Sprünge bzw. Verzögerungen ineinander überführt werden.
- **Zentrierung auf eigenen Standort als abschaltbarer Toggle:** Die Funktion zum Zentrieren auf die eigene Position muss sich auch wieder ausschalten lassen. Nach dem Ausschalten bleibt die Kamera an der zuletzt erreichten Kartenposition stehen und folgt dem Standort nicht weiter.
- **Vorschau beim Setzen neuer Objektpositionen:** Wird der Ort eines neuen Objekts über die Suchleiste gewählt oder durch Tippen auf die Karte gesetzt, erscheint zunächst nur ein verschiebbarer/änderbarer Vorschau-Pin. Erst nach Betätigung eines Bestätigungsbuttons wird die Position endgültig übernommen.
- **Suchtreffer-Popup in reduzierte Ansicht überführen:** Der „Hierhin navigieren“-Button nach einer Ortssuche ist weiterhin zweiteilig und soll zu einer einheitlichen Aktion werden. Solange das Popup mit der Entscheidung „Navigieren“ oder „Neuen Punkt anlegen“ geöffnet ist, soll die übrige UI in eine reduzierte Ansicht wechseln. Diese bleibt bestehen, bis eine Entscheidung getroffen oder das Popup geschlossen wird.
- **Überlappende Kartenobjekte entzerren:** Liegen zwei oder mehr Punkte exakt oder nahezu übereinander, eine entzerrte Auswahl-/Darstellung anbieten. Alle Punkte und ihre Bezeichnungstexte müssen einzeln erkennbar und auswählbar sein, ohne sich gegenseitig zu verdecken.

- **Kompassrose wie in Apple Karten (0.8: zwei Modi Norden/Kompass, Rose zeigt Richtung; noch prüfen):** Die Kompassrose soll sich wie das native Apple-Maps-Verhalten verhalten und beim manuellen Drehen anzeigen, welche Himmelsrichtung aktuell oben liegt. Antippen wechselt zwischen „Norden oben“ und Ausrichtung gemäß Gerätekompass. Im Modus „Norden oben“ bleibt die Karte nach Norden fixiert; bei manueller Drehung bleibt sie auf der eingestellten Rotation fixiert.
- **Sanfte Kartenrotation und Positionsverfolgung:** Kompassdrehung und Nachführen der eigenen Position müssen flüssig animiert werden. Die aktuelle Umsetzung ruckelt bzw. springt in kleinen Schritten.
- **„Am Fahren“-Ansicht als Live-Positionsmodus:** Der Button soll die Karte auf den aktuellen eigenen Standort zurücksetzen und die Ansicht anschließend an die Live-Position koppeln. Solange diese Kopplung aktiv ist, werden das Banner mit aktueller Straße und Ausrichtung eingeblendet. Die Ansicht muss sich jederzeit wieder verlassen lassen.
- **Fahrzeug- und ÖPNV-Symbole für eigene und fremde Positionen (0.8: eigene Position erledigt, fremde Kräfte offen):** Beim Einsteigen soll das eigene Standortsymbol zu einem dem nativen Standortsymbol ähnlichen Fahrzeug-Icon wechseln, idealerweise dasselbe Grundsymbol mit kleinem Auto-Symbol darin. Für ÖPNV entsprechend. Die Symboländerung soll sowohl für die eigene Position als auch für andere Nutzer/Fahrzeuge konsistent dargestellt werden.
- **Querstraßen in der Navigation:** Namen kreuzender Straßen entlang der Route anzeigen. Valhalla liefert diese nicht mit; dafür ist eine eigene Abfrage der Kreuzungen entlang der Route (OSM) erforderlich.
- **ÖPNV-Navigation in der App:** Derzeit wird die Ankunft über Apple Karten abgewickelt. Eine eigene Führung in Sentinel soll perspektivisch mit echten Fahrplandaten umgesetzt werden.

### Marker, Suche und Ortsauswahl

- **Suchleiste für ÖPNV-Marker umfunktionieren:** Beim Setzen eines ÖPNV-Markers wird die Suchleiste als Teil des Popups zur Suche nach einer ÖPNV-Verbindung verwendet.

### Bedienoberfläche und Liquid Glass

- **SOS-Button: weißen Haltering sichtbar halten:** Der weiße Fortschritts-/Halte-Ring beim gedrückten SOS-Button ist auch nach der letzten Revision nicht sichtbar, weil sich der Button während des Haltens vergrößert. Ring und Button-Geometrie so korrigieren, dass der Ring während des gesamten Haltevorgangs sichtbar bleibt und nicht abgeschnitten oder überdeckt wird.
- **SOS-Banner ohne Farbverlauf:** Den Gradient-Hintergrund des Notruf-/SOS-Banners entfernen; stattdessen eine einheitliche, zum übrigen UI passende Fläche verwenden.
- **Drei-Wege-Auswahl wieder als natives iOS-Schieberelement:** Die Auswahl für Fußweg, ÖPNV und Pkw darf nicht aus drei separaten Buttons bestehen. Als natives wirkendes, zusammenhängendes Segment-/Schieberelement mit beweglichem Auswahlindikator umsetzen – ausdrücklich kein Satz einzelner Buttons.
- **„Sonstiges / anderes Fahrzeug“ optisch von der Fahrzeugflotte trennen:** In der Verkehrsmittel-/Fahrzeugauswahlliste soll dieser Eintrag als eigener, klar abgesetzter Bereich erscheinen und nicht wie ein reguläres Flottenfahrzeug wirken.
- **Icon-Kontrast im „Hinführen“-Button:** In Objekt-Popups ist das Icon im blauen „Hinführen“-Button kaum sichtbar, weil es nahezu dieselbe blaue Farbe wie der Button hat. Icon-Farbe und Kontrast korrigieren.
- **Fotos bei bestimmten Pins deaktivieren:** Bei „Haltestellen im Umkreis“-Pins und beim Fahndungsraum keine Funktion zum Hinzufügen von Fotos anbieten.
- **Warnbanner-Darstellung reparieren:** Die fehlerhafte Warntext-/Banner-Darstellung aus dem angehängten Screenshot (ÖPNV-Linien-Editor: „Server nicht erreichbar: Abgebrochen“) korrigieren. Text, Icon, Farben, Abstände und Darstellung müssen stabil und sauber sein; keine fehlerhafte bzw. störende Darstellung.
- **Zielperson-Icon-Auswahl darf Karte nicht einfrieren:** Beim Anlegen einer Zielperson friert die Karte ein, sobald das Icon angetippt wird. Ursache für den UI-/Map-Freeze beheben und die Icon-Auswahl ohne Blockieren der Karteninteraktion ermöglichen.


### ÖPNV, Linien und Fahrzeuge

- **Liniennummern im HVV-Stil darstellen:** Liniennummern dürfen nicht als abgerundetes weißes Rechteck erscheinen. Die Linien-Badges sollen wie im angehängten HVV-Kartenausschnitt aussehen: kräftig roter Hintergrund mit weißer Liniennummer und der passenden typischen Form.
- **ÖPNV-Linie vollständig erzeugen:** Beim Anlegen einer ÖPNV-Linie soll die gesamte Linie von Anfang bis Ende automatisch erzeugt werden. Keine manuelle Auswahl von Start- und Endhaltestelle mehr verlangen.
- **Linien als einzelne Haltestellen und Streckenobjekte modellieren:** Eine erzeugte Linie soll aus regulären Haltestellen-Pins und den verbindenden Linien-/Streckenobjekten bestehen, statt als unteilbares Gesamtobjekt verwaltet zu werden. Einzelne Haltestellen oder Streckenabschnitte müssen separat löschbar sein.
- **Haltestellen-Pin manuell anlegen und zuordnen:** „Haltestelle“ als eigenständige Pin-Art zur manuellen Erstellung anbieten. Nach dem Setzen/Bestätigen sollen passende reale bzw. benachbarte Haltestellen ermittelt und dem bestätigten Haltestellen-Pin zugeordnet bzw. als solche übernommen werden können.
- **ÖPNV-Linie als Gruppe erzeugen:** Beim automatischen Erzeugen einer Linie alle zugehörigen Haltestellen und Streckenobjekte direkt als gemeinsame Gruppe anlegen.
- **Gruppierungsfunktion für Kartenobjekte:** Mehrere ausgewählte Punkte und Formen zu einer Gruppe zusammenfassen. Gruppen lassen sich gruppieren (erstellen), auflösen oder als Ganzes löschen. Keine verschachtelten Gruppen zulassen.
- **Gruppen-Toolbar bei Einzelobjekten:** Wird ein Objekt innerhalb einer Gruppe angetippt, bleibt dessen normales Detailfenster verfügbar. Zusätzlich darüber eine schmale Toolbar mit den Gruppenaktionen anzeigen.
- **Mehrfachauswahl per Gedrückthalten:** Objekte durch längeres Drücken auswählen können. Sobald mehrere Objekte ausgewählt sind, die Gruppen-Toolbar mit den passenden Gruppenaktionen einblenden.

- **HVV-konforme Linien- und Haltestellensymbole:** Die derzeit falschen ÖPNV-Icons durch die offiziellen bzw. auf HVV-Fahrplänen verwendeten Symbole ersetzen. Geeignete SVG-Quellen prüfen (unter anderem Wikipedia, sofern Lizenz und Gestaltung passen). Für Bus, Regionalbahn, S-Bahn und U-Bahn die passenden Symbole verwenden.
- **Symbole in sämtlichen ÖPNV-Listen:** Überall, wo ÖPNV-Verbindungen oder Linien aufgelistet werden, muss das jeweils passende HVV-Verkehrsmittelsymbol erscheinen.
- **Konsistente Symbole unabhängig vom Erstellungsweg:** Linien- und Haltestellensymbole müssen gleich aussehen, unabhängig davon, ob eine Linie manuell oder beispielsweise aus einer A-Position heraus erzeugt wurde.
- **Echte Fahrpläne statt Schätzung:** Offene HVV-Fahrpläne (GTFS, Hamburger Transparenzportal) auf dem Server einlesen, echte Abfahrten zur Auswahl anbieten und Fahrzeugpositionen anhand des Fahrplans setzen.
- **Echtzeit, wo vorhanden:** Verspätungen aus GTFS-Realtime (DELFI / gtfs.de) einrechnen. geOps wird bewusst nicht genutzt (kostenfrei nur für Tests).
- **ÖPNV-Fahrzeuge zuverlässig bewegen (Rückfrage: Wo genau erscheinen die orangen Warnungen? Screenshot hilft):** Angelegte Fahrzeuge (z. B. Busse) zeigen aktuell schnell springende orange Verbindungswarnungen; außerdem bleiben ihre Icons am Startpunkt stehen oder bewegen sich nicht zuverlässig. Verbindungsstatus, Zeitplanung/Interpolation und Positionsupdates prüfen, damit sich Fahrzeuge innerhalb sinnvoller Zeiträume flüssig entlang ihrer Strecke bewegen.

### Lage, Karten-Layer und Bestreifung

- **Fahndungsraum-Optionen nur bei aktivem Fahndungsmarker anzeigen:** Die Optionen für fußläufige Fahndung, ÖPNV und Pkw in den Einstellungen zur Sichtbarkeit der Layer nur einblenden, wenn aktuell ein Fahndungsmarker aktiv ist. Ohne aktiven Fahndungsmarker sollen diese Toggles ausgeblendet sein.
- **Fahndungsraum direkt aus der Übersicht aktualisieren:** In der Fahndungsraum-Übersicht einen Aktualisieren-Button bereitstellen, der Standort und Uhrzeit erneut abfragt und die Daten aktualisiert. Dafür darf nicht erst in den Bearbeitungsmodus gewechselt werden müssen.
- **Zeit-Voreinstellungen als einmalige Aktionen:** Schnellaktionen wie „Jetzt“, „Vor 5 Minuten“ usw. sollen keine dauerhaft ausgewählten Zustände wie bei einem Auswahl-Selector haben. Jeder Button löst lediglich einmalig das Setzen der entsprechenden Uhrzeit aus und bleibt danach nicht ausgewählt.

### Tracker

- **PAJ-Tracker mit eigenem Konto je Tracker:** Beim Hinzufügen nicht nur die Geräte-ID, sondern einmalig E-Mail und Passwort des PAJ-Kontos angeben, dem das Gerät gehört (jeder Fahnder hat sein eigenes Konto). Zugangsdaten nur für diesen Tracker speichern, nicht global in Sentinel. Beim Anlegen prüfen, ob die ID wirklich zu diesem Konto gehört, sonst „Gerät nicht in diesem Konto“ anzeigen.
- **SinoTrack „Test“ (7026222172) sendet nicht:** Portweiterleitung TCP 5013 im Router zur Synology und die SMS-Einrichtung des Geräts (öffentliche Adresse, Port 5013, Protokoll H02) prüfen.

### App-/Server-Kompatibilität

- **Bei Versions-Mismatch App vollständig sperren:** Wenn App- und Serverversion nicht kompatibel sind, darf nicht lediglich ein Warnbanner angezeigt werden. Die App muss den normalen Zugriff bzw. die Bedienung vollständig sperren und klar erklären, dass zunächst eine kompatible Version installiert/ausgerollt werden muss.

### Codebase-Qualität und Architektur

- **Vollständige Codebase-Überprüfung und Bereinigung:** Die gesamte Codebase architektonisch überprüfen, aufräumen und bereinigen. Insbesondere auf Best Practices, Fehler, technische Schulden und unsaubere Muster achten, die durch wiederholte Revisionen und nachträgliche Änderungen entstanden sind.
- **Produktionsreife Struktur herstellen:** Verantwortlichkeiten und Modulgrenzen prüfen, Duplikate und unnötige Komplexität reduzieren, ineffiziente Abläufe identifizieren und die Codebasis konsistent, wartbar, effizient und klar strukturiert gestalten.
- **Qualität absichern:** Relevante Tests ergänzen bzw. aktualisieren und kritische App-/Server-Schnittstellen sowie Navigations-, Karten- und ÖPNV-Flows nach der Bereinigung gezielt prüfen.

### Noch praktisch zu überprüfen

- **Auf dem Gerät prüfen:** Ferrostar-Navigation, Fahrzeugsymbol nach dem Aussteigen, Fotoliste und Standort-Menü.
- **Kommandozentrale:** Lebensdauer und weitere Fotos auch dort bearbeitbar machen.

## Umsetzungsreihenfolge

Die offenen Punkte aus diesem Dokument einschließlich der bereits zuvor gesammelten Aufgaben sollen in die gebündelte Umsetzung einfließen. Vor größeren UI-Änderungen bestehende Komponenten und Zustandsübergänge prüfen, damit keine bereits behobenen Fehler erneut entstehen. Die Codebase-Überprüfung soll als technische Grundlage dienen; anschließend die funktionalen Änderungen in zusammenhängenden Bereichen umsetzen und jeweils testen.
