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

- **Kompassrose wie in Apple Karten:** Die Kompassrose soll sich wie das native Apple-Maps-Verhalten verhalten und beim manuellen Drehen anzeigen, welche Himmelsrichtung aktuell oben liegt. Antippen wechselt zwischen „Norden oben“ und Ausrichtung gemäß Gerätekompass. Im Modus „Norden oben“ bleibt die Karte nach Norden fixiert; bei manueller Drehung bleibt sie auf der eingestellten Rotation fixiert.
- **Sanfte Kartenrotation und Positionsverfolgung:** Kompassdrehung und Nachführen der eigenen Position müssen flüssig animiert werden. Die aktuelle Umsetzung ruckelt bzw. springt in kleinen Schritten.
- **„Am Fahren“-Ansicht als Live-Positionsmodus:** Der Button soll die Karte auf den aktuellen eigenen Standort zurücksetzen und die Ansicht anschließend an die Live-Position koppeln. Solange diese Kopplung aktiv ist, werden das Banner mit aktueller Straße und Ausrichtung eingeblendet. Die Ansicht muss sich jederzeit wieder verlassen lassen.
- **„Am Fahren“-Ansicht nach Navigation korrekt verlassen:** Nach Beenden einer Routenführung darf die App nicht in der „Am Fahren“-Ansicht festhängen. Wechsel durch Navigation bzw. den Ansichts-Button muss zuverlässig funktionieren.
- **Eigenes Standort-Icon beibehalten:** In der „Am Fahren“-Ansicht bleibt das native Apple-Maps-Standortsymbol erhalten. Das Navigationssymbol mit Richtungspfeil wird ausschließlich während einer aktiven Navigation verwendet.
- **Fahrzeug- und ÖPNV-Symbole für eigene und fremde Positionen:** Beim Einsteigen soll das eigene Standortsymbol zu einem dem nativen Standortsymbol ähnlichen Fahrzeug-Icon wechseln, idealerweise dasselbe Grundsymbol mit kleinem Auto-Symbol darin. Für ÖPNV entsprechend. Die Symboländerung soll sowohl für die eigene Position als auch für andere Nutzer/Fahrzeuge konsistent dargestellt werden.
- **Navigationspfeil auf der Karte:** Das eigene Richtungssymbol soll flach auf der Kartenebene liegen und nicht relativ zum Bildschirm ausgerichtet sein.
- **Querstraßen in der Navigation:** Namen kreuzender Straßen entlang der Route anzeigen. Valhalla liefert diese nicht mit; dafür ist eine eigene Abfrage der Kreuzungen entlang der Route (OSM) erforderlich.
- **Spracheingabe für Navigation:** Eine Spracheingabe zum Starten bzw. Eingeben eines Navigationsziels ergänzen, sofern technisch sinnvoll.
- **„Dorthin navigieren“-Buttons vereinheitlichen:** Alle entsprechenden Buttons an den verschiedenen Stellen müssen ein konsistentes, passendes Icon erhalten. Das bisherige Kompass-Pfeil-Icon mit dem dünnen Strich darüber soll durch eine optisch bessere Variante ersetzt werden.
- **ÖPNV-Navigation in der App:** Derzeit wird die Ankunft über Apple Karten abgewickelt. Eine eigene Führung in Sentinel soll perspektivisch mit echten Fahrplandaten umgesetzt werden.

### Marker, Suche und Ortsauswahl

- **Marker-Auswahl als großes Menü:** Beim Setzen eines Markers – sowohl über den runden Button in der normalen Kartenansicht als auch über den Ortsdialog – soll keine kleine aufklappende Liste erscheinen, sondern ein richtiges, großes Auswahlmenü.
- **Kartenoberfläche während des Marker-Setzens reduzieren:** Während ein Marker gesetzt wird, werden alle nicht benötigten UI-Elemente ausgeblendet. Nur die obere Suchleiste bleibt sichtbar.
- **Suchleiste für normale Marker umfunktionieren:** Im Marker-Setzmodus dient die obere Suchleiste zur Suche nach einem Standort bzw. einer Adresse. Der Marker wird anschließend an der gefundenen Position gesetzt.
- **Suchleiste für ÖPNV-Marker umfunktionieren:** Beim Setzen eines ÖPNV-Markers wird die Suchleiste als Teil des Popups zur Suche nach einer ÖPNV-Verbindung verwendet.
- **Orts-Popup überarbeiten:** Nach der Suche einer Örtlichkeit erscheint ein Dialog zur Auswahl zwischen „Dorthin navigieren“ und „Neuen Marker setzen“. Die Buttons sind aktuell unschön zweigeteilt; das Design soll vereinheitlicht werden. Außerdem muss sich das Popup zuverlässig schließen lassen.

### Bedienoberfläche und Liquid Glass

- **Ziele-Tab aufräumen:** Im Tab „Ziele“ den Plus-Button oben auf dieselbe Höhe wie den Seitentitel setzen. Den zusätzlichen blauen, mittig platzierten Button zum Hinzufügen von Zielen entfernen, da er dieselbe Funktion wie der Plus-Button erfüllt.
- **SOS-Button:** Der weiße Ring, der beim Gedrückthalten erscheint, muss korrekt um den Button liegen. Mögliche Ursache ist die Button-Animation während des Drückens; Animation und Ringpositionierung prüfen.
- **Verkehrsmittel-Toggle:** Der dreiteilige Toggle soll wieder denselben Liquid-Glass-Gedrückthalten-Effekt wie die Navigationsleiste besitzen. Seine Höhe muss mit dem Button „A übernehmen“ übereinstimmen.
- **Fahrzeugauswahl:** In der Liste zur Auswahl des Fahrzeugs beim Einsteigen eine Option für ein generisches Fahrzeug ergänzen.

### ÖPNV, Linien und Fahrzeuge

- **HVV-konforme Linien- und Haltestellensymbole:** Die derzeit falschen ÖPNV-Icons durch die offiziellen bzw. auf HVV-Fahrplänen verwendeten Symbole ersetzen. Geeignete SVG-Quellen prüfen (unter anderem Wikipedia, sofern Lizenz und Gestaltung passen). Für Bus, Regionalbahn, S-Bahn und U-Bahn die passenden Symbole verwenden.
- **Symbole in sämtlichen ÖPNV-Listen:** Überall, wo ÖPNV-Verbindungen oder Linien aufgelistet werden, muss das jeweils passende HVV-Verkehrsmittelsymbol erscheinen.
- **Konsistente Symbole unabhängig vom Erstellungsweg:** Linien- und Haltestellensymbole müssen gleich aussehen, unabhängig davon, ob eine Linie manuell oder beispielsweise aus einer A-Position heraus erzeugt wurde.
- **Kein Navigieren-Button auf einer ÖPNV-Linie:** Bei einer neu angelegten ÖPNV-Linie den Button „Dorthin navigieren“ entfernen, da eine Linie kein einzelner Zielort ist.
- **Echte Fahrpläne statt Schätzung:** Offene HVV-Fahrpläne (GTFS, Hamburger Transparenzportal) auf dem Server einlesen, echte Abfahrten zur Auswahl anbieten und Fahrzeugpositionen anhand des Fahrplans setzen.
- **Echtzeit, wo vorhanden:** Verspätungen aus GTFS-Realtime (DELFI / gtfs.de) einrechnen. geOps wird bewusst nicht genutzt (kostenfrei nur für Tests).
- **ÖPNV-Routen entlang des tatsächlichen Streckenverlaufs:** Neu angelegte ÖPNV-Routen zeigen derzeit gerade Linien zwischen Haltestellen. Stattdessen muss der tatsächliche Verlauf entlang der Straßen bzw. des Streckennetzes dargestellt werden.
- **ÖPNV-Fahrzeuge zuverlässig bewegen:** Angelegte Fahrzeuge (z. B. Busse) zeigen aktuell schnell springende orange Verbindungswarnungen; außerdem bleiben ihre Icons am Startpunkt stehen oder bewegen sich nicht zuverlässig. Verbindungsstatus, Zeitplanung/Interpolation und Positionsupdates prüfen, damit sich Fahrzeuge innerhalb sinnvoller Zeiträume flüssig entlang ihrer Strecke bewegen.

### Lage, Karten-Layer und Bestreifung

- **Fahndungsraum-Optionen nur bei aktivem Fahndungsmarker anzeigen:** Die Optionen für fußläufige Fahndung, ÖPNV und Pkw in den Einstellungen zur Sichtbarkeit der Layer nur einblenden, wenn aktuell ein Fahndungsmarker aktiv ist. Ohne aktiven Fahndungsmarker sollen diese Toggles ausgeblendet sein.
- **Kein globaler „Lage zurücksetzen“-Button:** Die Funktion zum vollständigen Zurücksetzen der Lage soll aus der Oberfläche entfernt werden.
- **Lage-Karten-Layer leeren:** Stattdessen eine Funktion zum Leeren des Lage-Karten-Layers ergänzen. Der Button gehört in das Untermenü der Karten-Layer.
- **Lage bearbeiten vereinfachen:** Im Untermenü zum Bearbeiten der Lage bleiben nur die Textfelder zum Bearbeiten. Dort gibt es weder einen Button zum Zurücksetzen der gesamten Lage noch einen Button zum Zurücksetzen der Bestreifung.
- **Bestreifung automatisch zurücksetzen:** Das Zurücksetzen der Bestreifung erfolgt automatisch, sobald der Toggle zum Markieren der gefahrenen Strecke ausgeschaltet wird.

### Tracker

- **PAJ-Tracker mit eigenem Konto je Tracker:** Beim Hinzufügen nicht nur die Geräte-ID, sondern einmalig E-Mail und Passwort des PAJ-Kontos angeben, dem das Gerät gehört (jeder Fahnder hat sein eigenes Konto). Zugangsdaten nur für diesen Tracker speichern, nicht global in Sentinel. Beim Anlegen prüfen, ob die ID wirklich zu diesem Konto gehört, sonst „Gerät nicht in diesem Konto“ anzeigen.
- **SinoTrack „Test“ (7026222172) sendet nicht:** Portweiterleitung TCP 5013 im Router zur Synology und die SMS-Einrichtung des Geräts (öffentliche Adresse, Port 5013, Protokoll H02) prüfen.

### App-/Server-Kompatibilität

- **App- und Server-Version abgleichen:** Einen verbindlichen Versionsabgleich zwischen App und Server einführen. Die App muss einen verständlichen Fehler anzeigen, wenn der Server nicht die erwartete bzw. kompatible Version hat. Dadurch sollen Fehler vermieden werden, die durch einen veralteten oder inkompatiblen Server entstehen, obwohl sie in einer neueren Version bereits behoben wurden. Kompatibilitätsstrategie und Verhalten bei nicht unterstützten Versionen definieren.

### Codebase-Qualität und Architektur

- **Vollständige Codebase-Überprüfung und Bereinigung:** Die gesamte Codebase architektonisch überprüfen, aufräumen und bereinigen. Insbesondere auf Best Practices, Fehler, technische Schulden und unsaubere Muster achten, die durch wiederholte Revisionen und nachträgliche Änderungen entstanden sind.
- **Produktionsreife Struktur herstellen:** Verantwortlichkeiten und Modulgrenzen prüfen, Duplikate und unnötige Komplexität reduzieren, ineffiziente Abläufe identifizieren und die Codebasis konsistent, wartbar, effizient und klar strukturiert gestalten.
- **Qualität absichern:** Relevante Tests ergänzen bzw. aktualisieren und kritische App-/Server-Schnittstellen sowie Navigations-, Karten- und ÖPNV-Flows nach der Bereinigung gezielt prüfen.

### Noch praktisch zu überprüfen

- **Auf dem Gerät prüfen:** Ferrostar-Navigation, Fahrzeugsymbol nach dem Aussteigen, Fotoliste und Standort-Menü.
- **Kommandozentrale:** Lebensdauer und weitere Fotos auch dort bearbeitbar machen.

## Umsetzungsreihenfolge

Die offenen Punkte aus diesem Dokument einschließlich der bereits zuvor gesammelten Aufgaben sollen in die gebündelte Umsetzung einfließen. Vor größeren UI-Änderungen bestehende Komponenten und Zustandsübergänge prüfen, damit keine bereits behobenen Fehler erneut entstehen. Die Codebase-Überprüfung soll als technische Grundlage dienen; anschließend die funktionalen Änderungen in zusammenhängenden Bereichen umsetzen und jeweils testen.
