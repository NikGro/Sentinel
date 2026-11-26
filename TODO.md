# Offene Punkte

Wünsche, Fehler und technische Arbeiten werden hier gesammelt und zu festen Zeitpunkten gebündelt umgesetzt,
statt jede Änderung sofort einzubauen. Erledigtes wandert mit Version ins CHANGELOG.

## Geplant

### Nächste Runde

- **Straßenverzeichnis beobachten:** Läuft mit 2 GB Container-Speicher, Node.js darf bis 1,5 GB nutzen. Stand
  22.11.: 286 MB im Betrieb, kein Neustart seit dem Update. Das nächste wöchentliche Neuladen über Overpass ist um
  den 27.11.; danach den Speicher prüfen. Wird es knapp, die Straßen in SQLite statt im Arbeitsspeicher halten.
- **Fahrspuren beim Abbiegehinweis beobachten:** Die Anzeige gibt es; bei Gelegenheit prüfen, ob sie zuverlässig
  erscheint.
- **SinoTrack per USB:** Mit dem echten Tracker prüfen, ob er die Befehle über USB annimmt (Baudrate, Befehlsform).
  Den Stand aus dem Desktop-Chat abgleichen und die APN der Beach SIM als Beispiel eintragen.
- **Kreuzungssuche nach dem Update prüfen:** Kommen plausible Straßenecken jetzt zuverlässig, auch nach dem ersten Buchstaben der zweiten Straße? Falls nicht: Beispiel nachstellen.

### Karte, Kompass und Navigation

- (Fix liegt auf dem Arbeitszweig, kommt mit der nächsten Version) Sehr schneller Wisch löste angeheftet nicht, wenn
  zwischen Beginn und Ende keine Bewegung gemeldet wurde (Kamera-Test 0.33).
- **Navigation zu einem Zielfahrzeug mit drei Modi** (wie der Schalter beim ÖPNV): normal, parallel, Vorlauf. Nur
  sinnvoll mit Live-Standort samt Richtung (Tracker oder A-Position), nicht bei von Hand gesetztem Standort.
  - *Vorlauf* (zuerst umsetzen, gut machbar): Straße des Ziels über den Straßenindex/Valhalla bestimmen, in
    Fahrtrichtung die nächste (bzw. übernächste) Kreuzung suchen und dorthin navigieren; ist das Ziel daran vorbei,
    zur nächsten Kreuzung neu berechnen. Annahme: Das Ziel fährt geradeaus weiter.
  - *Parallel* (machbar, heuristisch): Route zu einem Punkt seitlich voraus berechnen und die Straße des Ziels für
    Valhalla sperren (Ausschlussfläche entlang seiner Straße), regelmäßig neu. Gibt es keine Parallelstraße (Umweg zu
    groß, z. B. Landstraße), automatisch normal navigieren.
- Überschlagende Navigation und Navigation zu Haltestellen (1, 2, 3 voraus): Keine zusätzlichen Haltestellenmarker mit
  Nummer daneben (`StopsLayer`), die doppelt neben schon angelegten Haltestellen stehen und nach dem Ende liegen
  bleiben. Stattdessen: Ist die Haltestellenebene eingeschaltet, die Ziel-Haltestelle bzw. die eigene Position im
  Überschlagen dort hervorheben. Ohne Haltestellenebene darf ein Marker erscheinen, der aber wieder verschwindet bzw.
  die Hervorhebung endet, sobald die Navigation endet oder zur nächsten Haltestelle weitergeht.
- **App-Absturz während aktiver Navigation (0.9: mögliche Ursache abgesichert):** Dafür ist ein Absturzbericht nötig, zu finden unter Einstellungen › Datenschutz & Sicherheit › Analyse & Verbesserungen › Analysedaten › „Sentinel-…“.

### Marker und Oberfläche

- **Kurzübersichten als Variante 2** (Skizzen vom 23.11.): Statt der Fenster mit großen „Schließen“/„Bearbeiten“-
  Knöpfen überall schwebende Glaskarten mit kleinen runden Knöpfen (Hinführen blau, Bearbeiten, Schließen) für
  Marker, Objekte, Zielpersonen, Zielfahrzeuge, ÖPNV-Linien und den GPS-Verlauf. Umsetzung als iOS-26-Fenster mit
  Stufen: niedrig schwebend als Karte, hochgezogen halbe Höhe bzw. fast Vollbild mit allen Angaben; Karte dahinter
  in der niedrigen Stufe bedienbar.
- Beschriftung auf Flächen (`AreaLabelLayer`) schwer lesbar wegen Glow: Text in der Farbe der Fläche (deckend, nicht
  transparent) mit festem Rand von wenigen Pixeln statt Glow.
- **Zielperson: Karte friert ein (0.13: ÖPNV-Positionsberechnung als wahrscheinliche Ursache stark beschleunigt):** Offene Rückfrage, welches Symbol genau gemeint ist: im Plus-Menü, im Editor („Unterwegs“) oder auf der Karte. Mit 0.13 erneut prüfen.

### Codebase-Qualität

- **Laufende Bereinigung:** `MapScreen` ist inzwischen auf fünf Dateien verteilt (Hauptdatei gut 400 Zeilen). Offen
  bleiben App-Tests über den UI-Rundgang hinaus, z. B. für die ÖPNV-Bewegung (`TransitSimulation`) und das
  Überschlagen.


### Sicherheit, Administration und Datenschutz

- **Admin-/Benutzertrennung:**
  - Rollen und Berechtigungen serverseitig strikt trennen; administrative Funktionen dürfen nicht durch normale Benutzer aufrufbar sein.
  - Benutzer können ausschließlich durch Admins angelegt werden.
  - Name und Dienststelle werden beim Anlegen durch Admins festgelegt und können nur durch Admins geändert werden.
  - Handynummer, Spitzname und Profilbild bleiben durch den jeweiligen Benutzer selbst änderbar.
  - Admin-Werkzeuge zum Bearbeiten, Sperren und Entsperren, Löschen sowie Widerrufen und Wiederherstellen von Benutzerzugängen/Berechtigungen.
- **Datenbankverschlüsselung:** Verschlüsselung ruhender Datenbankdaten implementieren; Schlüssel getrennt von Datenbank und Backups verwalten.
- **GPS-Tracker-Verbindung absichern:** Prüfen, ob die Tracker-Firmware eine verschlüsselte Verbindung unterstützt. Wenn möglich TLS mit gegenseitiger Geräteauthentifizierung oder ein geeignetes Verfahren mit individueller Gerätekennung und individuellem Schlüssel statt alleiniger Tracker-ID umsetzen; Replay-Schutz und sichere Schlüsselverwaltung berücksichtigen. Einschränkungen der vorhandenen SinoTrack-Firmware dokumentieren.
- **Aktionsprotokoll:** Relevante Benutzer- und Systemaktionen vollständig und nachvollziehbar protokollieren (insbesondere Anmeldungen, Zugriffe/Abfragen, Änderungen, Admin-Aktionen, Freigaben und Exporte). Protokolle gegen Manipulation und unberechtigtes Löschen schützen; Zugriffs- und Löschkonzept festlegen.
- **Automatische Backups:** Automatisiertes Backup-System mit Verschlüsselung, restriktiven Zugriffen, definierten Aufbewahrungs- und Löschfristen sowie regelmäßigen Wiederherstellungstests implementieren. Backups und enthaltene personenbezogene Daten in das Datenschutz- und Löschkonzept einbeziehen.
- **Rechtsgrundlagen-/Maßnahmenkonzept:** Noch offen. Gestaltung der dauerhaften KASOD-Grundinstanz, personenbezogener Anzeigen und Abfragen sowie anlassbezogener Maßnahmenkontexte erst nach weiterer rechtlicher Klärung festlegen.
- **Context Tokens und operative Instanzsperre (datenschutzrechtliche Umsetzung):**
  - Jede Instanz benötigt vor operativer Nutzung einen aktiven Context Token; maximal ein aktiver Token je Instanz, feste Höchstlaufzeit 24 Stunden.
  - Token dokumentiert den operativen Kontext (Rechtsregime, Rechtsgrundlage, Zweck, Maßnahme, Begründung, Vorgangskennung und verantwortliche Stelle). Tokenwechsel beendet und historisiert den vorherigen Token unveränderbar.
  - Ohne aktiven Token ist die Instanz serverseitig vollständig von operativen Datenbankzugriffen entkoppelt: keine Anzeige, Suche, Abfrage, Erstellung, Änderung, Nutzung, Exporte oder Speicherung eingehender Tracker-Positionen.
  - Nur getrennte, eng berechtigte Verwaltungs-/Systemfunktionen bleiben möglich (Tokenverwaltung, Audit, Datenschutzprüfungen, Löschung, Backups, Wiederherstellung und Sicherheit).
  - Alle Aktionen werden dem handelnden Benutzer und dem aktiven Token zugeordnet. Datensätze behalten zusätzlich dauerhaft ihren ursprünglichen Erhebungs-/Maßnahmenbezug, ihre Herkunft und ihre Datenkennzeichnung. Ein Tokenwechsel setzt keine Prüffrist zurück und legitimiert keine neue Verwendung automatisch.
  - Ein Token kann mehrere Maßnahmen umfassen; Daten und Aktionen müssen dennoch einer konkreten Maßnahme zuordenbar bleiben.
- **Universelles Beziehungsmodell für Sentinel-Objekte (datenschutzrechtliche Umsetzung):**
  - Fest eingebaute Zuordnungsfelder wie „Halter“ beim Fahrzeug oder „Bewohner“ bei einer Anschrift entfernen.
  - Stattdessen ein universelles Beziehungssystem einführen, mit dem alle relevanten Objekttypen miteinander verknüpft werden können: Personen, Fahrzeuge, Anschriften/Gebäude und sonstige Zielobjekte.
  - Beziehung mit optionaler Bezeichnung (z. B. Halter, Fahrer, Insasse, regelmäßiger Nutzer, Bewohner, Eigentümer, regelmäßiger Aufenthaltsort, Zulassungsanschrift) und optionalem Freitext. Beziehungen sind von beiden Objektseiten aus sichtbar und bearbeitbar; Änderungen/Beendigungen werden nachvollziehbar protokolliert.
  - Beziehungen dürfen nicht automatisch als gesicherte Tatsachen gelten; Herkunft/Status müssen nachvollziehbar bleiben.
  - Objekte dürfen auch ohne Personenbeziehung angelegt werden. Kein generisches Personen- oder Platzhalterobjekt einführen. Fehlende Beziehung ist lediglich der technische Status „nicht zugeordnet / Personenbezug ungeklärt“ und beweist nicht, dass tatsächlich kein mittelbarer Personenbezug besteht.
- **Datenschutz-Prüffristen und Administrator-Prüfbereich (datenschutzrechtliche Umsetzung):**
  - Für Datensätze anhand des ursprünglichen Erhebungs-/Verarbeitungskontexts, Rechtsregimes, Rechtsgrundlage, Zwecks, Datenart und betroffener Personen ein konfigurierbares, behördlich freizugebendes Fristenregelwerk anwenden. Alterskategorie an den tatsächlich betroffenen Personen festmachen, nicht pauschal am Objekttyp. Mehrere betroffene Personen getrennt berücksichtigen.
  - Für noch nicht zugeordnete Objekte (z. B. Fahrzeug ohne bekannte Person, Anschrift ohne bekannte Bewohner) eine kurze Auffang-Prüffrist vorsehen; 30 Tage zunächst nur als vorgeschlagene interne Regel, konfigurierbar und vor Produktiveinsatz behördlich freizugeben. Fehlende Zuordnung darf nicht mit fehlendem Personenbezug gleichgesetzt werden.
  - Eigenständige Datenschutz-/Speicherfristenansicht in der Web-Administratoroberfläche; offene, fällige und überfällige Prüfungen mit Datensatz, Herkunft, Kontext, Fristenregel und betroffenen Beziehungen anzeigen. In der App genügt optional eine eingeschränkte Ansicht.
  - Bei Erreichen der Prüffrist Datensatz einfrieren: keine operative Anzeige, Abfrage oder Weiterverwendung; nur berechtigte administrative Prüfung. Keine automatische Löschung allein wegen eines unbearbeiteten Prüftermins. Gesetzliche Löschpflichten bzw. festgestellte fehlende Erforderlichkeit müssen davon unabhängig unverzüglich umgesetzt werden.
  - Für die Prüfung drei einfache Entscheidungen vorsehen: **Behalten** (nur solange die einschlägige gesetzliche Speichergrenze und deren Voraussetzungen es zulassen; kurze Begründung verpflichtend, keine erneute vollständige Kontextbegründung), **Löschen** (keine Begründung erforderlich) und – wenn die bisherige Speicher-/Prüfgrenze erreicht ist – **In neuen Kontext übernehmen**.
  - „In neuen Kontext übernehmen“ ist ausdrücklich unabhängig von Instanzen und Context Tokens. Die berechtigte Person füllt dafür einen eigenständigen neuen Kontext aus (Rechtsregime, Rechtsgrundlage, Zweck, Maßnahme und Begründung); es wird kein gerade aktiver Instanz-Token übernommen oder vorausgesetzt.
  - Bei Übernahme können vorhandene Objekt-/Sachangaben zur Vermeidung doppelter manueller Eingabe übernommen werden. Sentinel legt jedoch einen neuen, eigenständig dokumentierten Verarbeitungsvorgang mit Verknüpfung zur ursprünglichen Herkunft und vollständiger Historie an. Rechtlich ist die bloße Übernahme vorhandener Informationen grundsätzlich Weiterverarbeitung, keine automatische Neuerhebung; Zulässigkeit der neuen Verwendung muss geprüft werden. Keine rückwirkende Legitimierung und kein Zurücksetzen der ursprünglichen Historie.
  - Prüfentscheidungen mit Prüfer, Zeitpunkt und Begründung (bei Behalten/Übernahme) protokollieren. Interne Erinnerungs-/Eskalationsfristen konfigurierbar halten; keine pauschale automatische Löschung nur wegen Nichtbearbeitung einer Benachrichtigung.
  - Gesetzliche Maximal-/Prüffristen, interne Prüffristen und tatsächliche Löschpflichten technisch klar unterscheiden. Fristen und Rechtsregeln nicht im Code erfinden oder fest verdrahten; behördliche Freigabe und Anpassbarkeit vorsehen.

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
  - 0.18: Cluster, flacher Navi-Pfeil, Fotoauswahl, ÖPNV-Schritte, Dienst über Instanzen, Kreuzungsvorschläge,
    Sentinel Web mit Zugangscode
  - 0.20: Geofence-Alarm (Verlassen und Betreten), Standortverlauf auf der Karte, reduzierte Verlaufskarte
  - 0.21: Anheften mit Zoomen/Neigen/Verschieben (mit dem Kamerawerte-Overlay), Route von einem Platz aus, ÖPNV-Gleiten,
    Kopfzeilen mit Verlauf
  - 0.22: Antippen und Marker setzen, Verlauf ohne Vorauswahl
  - 0.23: Anheften mit MapKit-Verfolgung (Zoomen, Kippen, Lösen durch Verschieben/Drehen, Navi), ÖPNV-Halten und
    Kurven, Hauptmenü mit zwei Tabs, Argus als Paket
  - 0.24: Überschlagend zu einem ÖPNV-Fahrzeug mit mehreren Fahndern (über Ziel, A und Fahrzeug)
  - 0.25: Querstraßen-Sprechblasen, Antippen von ÖPNV-Fahrzeugen und Datumsfeldern beim ersten Mal
  - 0.26: ÖPNV ohne Wackeln, Haltestellen nah auf der ÖPNV-Karte
  - 0.27: Anheften mit Gesten aus MapKits Erkennern (Zoomen/Kippen behalten, Verschieben/Drehen lösen, kein Pumpen)
