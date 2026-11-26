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

- **Zwei Rollen: Nutzer und Admin:**
  - Es gibt ausschließlich die Rollen **Nutzer** und **Admin**. Keine zusätzlichen Rollen oder separaten Datenschutzbeauftragten-Rollen einführen.
  - Admins sind zugleich normale Nutzer und übernehmen zusätzlich die vollständige Benutzerverwaltung sowie die administrativen Datenschutzaufgaben (insbesondere Datenschutzprüfungen, Fristenentscheidungen, Sperrungen und Löschungen).
  - Nutzer können ausschließlich durch Admins angelegt werden. Name und Dienststelle werden beim Anlegen durch Admins festgelegt und können nur durch Admins geändert werden.
  - Handynummer, Spitzname und Profilbild bleiben durch den jeweiligen Nutzer selbst änderbar.
  - Admin-Werkzeuge zum Bearbeiten, Sperren und Entsperren, Löschen sowie Widerrufen und Wiederherstellen von Benutzerzugängen/Berechtigungen.
  - Rollen und Berechtigungen serverseitig strikt durchsetzen; administrative Funktionen dürfen nicht durch normale Nutzer aufrufbar sein. Admin-Aktionen werden im zentralen Ereignisprotokoll erfasst.
- **Datenbankverschlüsselung:** Verschlüsselung ruhender Datenbankdaten implementieren; Schlüssel getrennt von Datenbank und Backups verwalten.
- **GPS-Tracker-Verbindung absichern:** Prüfen, ob die Tracker-Firmware eine verschlüsselte Verbindung unterstützt. Wenn möglich TLS mit gegenseitiger Geräteauthentifizierung oder ein geeignetes Verfahren mit individueller Gerätekennung und individuellem Schlüssel statt alleiniger Tracker-ID umsetzen; Replay-Schutz und sichere Schlüsselverwaltung berücksichtigen. Einschränkungen der vorhandenen SinoTrack-Firmware dokumentieren.
- **Einheitliches, möglichst vollständiges Ereignisprotokoll (System, Sicherheit und Datenschutz):**
  - Genau **ein zentrales Log** für alle relevanten System-, Sicherheits-, Benutzer-, Objekt- und Datenschutzereignisse. Ein gemeinsames Datenmodell, eine zentrale Logging-Schnittstelle und eine gemeinsame Log-Ansicht; keine getrennten System- und Datenschutzlogs oder parallelen Protokoll-Untersysteme.
  - Das Logging so vollständig und zentral in den relevanten Backend-Abläufen verankern, dass wichtige Ereignisse nicht versehentlich unprotokolliert bleiben. Nicht nur ausgewählte Datenschutzaktionen, sondern sämtliche relevanten Zustandsänderungen und Aktionen erfassen.
  - Dazu gehören insbesondere erfolgreiche/fehlgeschlagene Anmeldungen und Abmeldungen, Sitzungs- und Berechtigungsereignisse, Zugriffe und Abfragen, Erstellen/Ändern/Aktivieren/Deaktivieren/Löschen von Markern, Punkten und sonstigen Objekten, Beziehungen, Paketimporte/-änderungen, Tracker-Aktionen und eingehende Positionsereignisse, Exporte, Navigation bzw. Nutzung relevanter Daten, Benutzer-/Admin-Aktionen, Context-Token-Verwaltung, Sperrungen/Freigaben sowie alle Datenschutzprüfungen und -entscheidungen.
  - Jeden Eintrag mit möglichst vollständigem, für die spätere Rekonstruktion ausreichendem Ereignisinhalt speichern: Zeitstempel, Ereignistyp, ausführender Akteur, betroffene Instanz und Objekte, Aktion/Änderung, vorheriger und neuer Zustand soweit relevant, Ergebnis/Fehlerstatus sowie technische Zusatzinformationen zum Systemzustand, soweit sie für Verständnis und Fehlersuche relevant sind.
  - Bei jeder Aktion mit angemeldetem Nutzer diesen Nutzer festhalten. Bei Ereignissen ohne authentifizierten Nutzer (z. B. fehlgeschlagene Anmeldung oder automatischer System-/Tracker-Vorgang) den verfügbaren Akteur bzw. Ursprung eindeutig kennzeichnen. Bei fehlgeschlagenen Anmeldungen nur sichere Identifikations-/Versuchsangaben protokollieren, niemals Passwörter, Zugangstoken oder andere Geheimnisse.
  - **Jede Aktion wird automatisch mit dem zu diesem Zeitpunkt aktiven Context Token verknüpft.** Im Log müssen Token-ID und ein unveränderlicher Snapshot der vollständigen maßgeblichen Token-Inhalte zum Aktionszeitpunkt enthalten sein. So lässt sich später jede Aktion ihrem konkreten operativen Maßnahmekontext zuordnen, auch wenn der Token längst beendet ist. Gibt es für ein Ereignis bewusst keinen aktiven Token (z. B. Anmeldung, Tokenverwaltung vor Aktivierung oder zulässige administrative Datenschutzaktion), wird dies ausdrücklich als tokenlos protokolliert; soweit vorhanden, werden vorheriger und/oder neu angelegter Token zusätzlich referenziert.
  - Datenschutzentscheidungen sind normale Ereignisse desselben Logs: Prüfer, Zeitpunkt, betroffene Person/Objekte/Beziehungen, Entscheidung, erforderliche Begründung und gegebenenfalls alter sowie neuer Verarbeitungskontext werden erfasst.
  - Log-Zugriffe, Suchen, Einsichtnahmen, Exporte und administrative Änderungen am Protokoll ebenfalls protokollieren. Gemeinsame Suche/Filter nach Zeitraum, Nutzer, Ereignistyp, Objekt, Instanz und Context Token; Kategorien dienen nur der Darstellung und Auswertung.
  - Protokoll vor unberechtigter Veränderung und Löschung schützen. Vollständigkeit durch zentrale Logging-Funktionen und Tests absichern, die prüfen, dass relevante Aktionen tatsächlich einen Log-Eintrag erzeugen.
  - Aufbewahrung möglichst vollständig und langfristig planen; konkrete Speicher- und Löschfristen müssen jedoch rechtlich festgelegt und konfigurierbar sein. Keine pauschale unbegrenzte Speicherung personenbezogener Logdaten allein aus technischen Gründen.
- **Automatische Backups:** Automatisiertes Backup-System mit Verschlüsselung, restriktiven Zugriffen, definierten Aufbewahrungs- und Löschfristen sowie regelmäßigen Wiederherstellungstests implementieren. Backups und enthaltene personenbezogene Daten in das Datenschutz- und Löschkonzept einbeziehen.
- **Rechtsgrundlagen-/Maßnahmenkonzept:** Noch offen. Gestaltung der dauerhaften KASOD-Grundinstanz, personenbezogener Anzeigen und Abfragen sowie anlassbezogener Maßnahmenkontexte erst nach weiterer rechtlicher Klärung festlegen.
- **Context Tokens und operative Instanzsperre (datenschutzrechtliche Umsetzung):**
  - Context Tokens werden zentral und gut sichtbar im Verwaltungsbereich der jeweiligen Instanz verwaltet. Dort können berechtigte Nutzer Tokens anlegen, prüfen, aktivieren, wechseln und beenden sowie die unveränderbare Token-Historie einsehen. Es gibt maximal **einen aktiven Token je Instanz**; feste Höchstlaufzeit 24 Stunden.
  - **Ein Context Token steht immer für genau eine konkrete Maßnahme.** Er enthält den operativen Kontext (Rechtsregime, Rechtsgrundlage, Zweck, konkrete Maßnahme, Begründung, Vorgangskennung und verantwortliche Stelle). Ein Token umfasst nicht mehrere Maßnahmen. Sobald eine andere Maßnahme beginnt, wird ein neuer Token angelegt; der bisherige Token wird beendet und unveränderbar historisiert. Änderungen am Kontext erfolgen niemals still am bestehenden Token.
  - Der aktive Token ist der verbindliche Kontext für sämtliche operativen Aktionen der Instanz. Jede Aktion wird automatisch mit dem zu diesem Zeitpunkt aktiven Token im **einheitlichen Ereignisprotokoll** erfasst. Der Log-Eintrag enthält den handelnden Nutzer sowie den unveränderlichen Snapshot der maßgeblichen Token-Inhalte. Kontextangaben müssen nicht bei jeder Aktion erneut eingegeben werden.
  - **Beim Aktivieren eines neuen Tokens werden zunächst sämtliche bereits vorhandenen datenschutzrelevanten Objekte und Inhalte der Instanz deaktiviert bzw. für den operativen Betrieb ausgeblendet** – insbesondere Zielpersonen, Zielfahrzeuge, Marker, Punkte, Beziehungen und sonstige maßnahmenbezogene Daten. Sie werden nicht automatisch in die neue Maßnahme übernommen.
  - Berechtigte Nutzer können anschließend benötigte Objekte einzeln und bewusst für den neuen Maßnahmenkontext wieder aktivieren. Jede einzelne Reaktivierung ist eine eigene Aktion, wird dem neuen aktiven Token zugeordnet und im zentralen Log dokumentiert. Die ursprüngliche Herkunft und der bisherige Kontext eines Objekts bleiben dabei erhalten; die Reaktivierung setzt keine ursprüngliche Erhebungs- oder Prüffrist zurück und ersetzt keine erforderliche datenschutzrechtliche Prüfung.
  - Ohne aktiven Token ist die Instanz serverseitig für operative Datenzugriffe gesperrt: keine operative Anzeige, Suche, Abfrage, Erstellung, Änderung, Nutzung, Exporte oder Speicherung eingehender Tracker-Positionen.
  - Es gibt genau zwei technische Zugriffswege: **operativer Zugriff** nur mit aktivem Token; **eng begrenzter administrativer Datenschutz-/Systemzugriff** ohne aktiven Token. Letzterer ist ausschließlich für notwendige Verwaltungs- und Schutzfunktionen vorgesehen, insbesondere Tokenverwaltung, Sicherheits-/Anmeldeereignisse, Datenschutzprüfungen, Sperrungen, Löschungen, Backups, Wiederherstellung und Sicherheitsmaßnahmen. Er darf nicht als Umgehung der operativen Tokensperre dienen. Auch diese Vorgänge werden im zentralen Log erfasst und als tokenlos bzw. mit dem betroffenen alten/neuen Token gekennzeichnet.
  - Datensätze behalten dauerhaft ihren ursprünglichen Erhebungs-/Maßnahmenbezug, ihre Herkunft und Datenkennzeichnung. Tokenwechsel oder Reaktivierung setzen keine Prüffrist zurück und legitimieren keine neue Verwendung automatisch.
- **Universelles Beziehungsmodell für Sentinel-Objekte (datenschutzrechtliche Umsetzung):**
  - Fest eingebaute Zuordnungsfelder wie „Halter“ beim Fahrzeug oder „Bewohner“ bei einer Anschrift entfernen.
  - Stattdessen ein universelles Beziehungssystem einführen, mit dem alle relevanten Objekttypen miteinander verknüpft werden können: Personen, Fahrzeuge, Anschriften/Gebäude und sonstige Zielobjekte.
  - Beziehung mit optionaler Bezeichnung (z. B. Halter, Fahrer, Insasse, regelmäßiger Nutzer, Bewohner, Eigentümer, regelmäßiger Aufenthaltsort, Zulassungsanschrift) und optionalem Freitext. Beziehungen sind von beiden Objektseiten aus sichtbar und bearbeitbar; Änderungen/Beendigungen werden nachvollziehbar protokolliert.
  - Beziehungen dürfen nicht automatisch als gesicherte Tatsachen gelten; Herkunft/Status müssen nachvollziehbar bleiben.
  - Jede Erstellung, Änderung, Beendigung, Aktivierung, Deaktivierung und Löschung einer Beziehung ist eine normale Aktion und wird automatisch im zentralen Ereignisprotokoll mit dem gerade aktiven Context Token, dem ausführenden Nutzer sowie den relevanten alten/neuen Beziehungsangaben erfasst. Es gibt dafür kein separates Beziehungs- oder Datenschutzlog und keine zusätzliche manuelle Kontextangabe: Der aktive Token ist der dokumentierte Maßnahmenbezug der Änderung.
  - Objekte dürfen auch ohne Personenbeziehung angelegt werden. Kein generisches Personen- oder Platzhalterobjekt einführen. Fehlende Beziehung ist lediglich der technische Status „nicht zugeordnet / Personenbezug ungeklärt“ und beweist nicht, dass tatsächlich kein mittelbarer Personenbezug besteht.
- **Datenschutz-Prüffristen und Administrator-Prüfbereich (datenschutzrechtliche Umsetzung):**
  - Für Datensätze anhand des ursprünglichen Erhebungs-/Verarbeitungskontexts, Rechtsregimes, Rechtsgrundlage, Zwecks, Datenart und betroffener Personen ein konfigurierbares, behördlich freizugebendes Fristenregelwerk anwenden. Alterskategorie an den tatsächlich betroffenen Personen festmachen, nicht pauschal am Objekttyp. Mehrere betroffene Personen getrennt berücksichtigen.
  - Prüffristen und Sperrungen möglichst auf die konkret betroffene Person bzw. den betroffenen Beziehungs-/Datenanteil anwenden, nicht pauschal auf ein gesamtes Objekt. Beispiel: Sind zwei Personen mit einem Fahrzeug verknüpft und ist nur der Kontext einer Person abgelaufen, wird zunächst diese Person bzw. ihre Beziehung im betreffenden Kontext gesperrt. Das Fahrzeug und eine andere weiterhin zulässig nutzbare Personenbeziehung bleiben verfügbar, sofern für sie eine eigenständige zulässige Grundlage besteht.
  - Eine Person, deren Daten im betreffenden Kontext gesperrt oder gelöscht werden müssen, darf nicht allein deshalb weiterhin über eine Beziehung oder Detailansicht des Fahrzeugs sichtbar bzw. nutzbar bleiben. Die betroffene Person/Beziehung ist in den Fahrzeugeinstellungen für das Setzen und Bearbeiten von Beziehungen entsprechend zu sperren und – wenn die Datenschutzentscheidung dies verlangt – dort ebenfalls zu entfernen. Das Fahrzeug selbst wird nur dann zusätzlich gesperrt, wenn seine eigene Verarbeitung oder die verbleibenden Informationen ebenfalls nicht mehr zulässig sind. Alle Sperr-, Entfernungs- und Löschschritte werden im zentralen Ereignisprotokoll dokumentiert.
  - Für noch nicht zugeordnete Objekte (z. B. Fahrzeug ohne bekannte Person, Anschrift ohne bekannte Bewohner) eine kurze Auffang-Prüffrist vorsehen; 30 Tage zunächst nur als vorgeschlagene interne Regel, konfigurierbar und vor Produktiveinsatz behördlich freizugeben. Fehlende Zuordnung darf nicht mit fehlendem Personenbezug gleichgesetzt werden.
  - Eigenständige Datenschutz-/Speicherfristenansicht in der Web-Administratoroberfläche; offene, fällige und überfällige Prüfungen mit Datensatz, Herkunft, Kontext, Fristenregel und betroffenen Beziehungen anzeigen. In der App genügt optional eine eingeschränkte Ansicht.
  - Bei Erreichen der Prüffrist Datensatz einfrieren: keine operative Anzeige, Abfrage oder Weiterverwendung; nur berechtigte administrative Prüfung. Keine automatische Löschung allein wegen eines unbearbeiteten Prüftermins. Gesetzliche Löschpflichten bzw. festgestellte fehlende Erforderlichkeit müssen davon unabhängig unverzüglich umgesetzt werden.
  - Für die Prüfung drei einfache Entscheidungen vorsehen: **Behalten** (nur solange die einschlägige gesetzliche Speichergrenze und deren Voraussetzungen es zulassen; kurze Begründung verpflichtend, keine erneute vollständige Kontextbegründung), **Löschen** (keine Begründung erforderlich) und – wenn die bisherige Speicher-/Prüfgrenze erreicht ist – **In neuen Kontext übernehmen**.
  - „In neuen Kontext übernehmen“ ist ausdrücklich unabhängig von Instanzen und Context Tokens. Die berechtigte Person füllt dafür einen eigenständigen neuen Kontext aus (Rechtsregime, Rechtsgrundlage, Zweck, Maßnahme und Begründung); es wird kein gerade aktiver Instanz-Token übernommen oder vorausgesetzt.
  - Bei Übernahme können vorhandene Objekt-/Sachangaben zur Vermeidung doppelter manueller Eingabe übernommen werden. Sentinel legt jedoch einen neuen, eigenständig dokumentierten Verarbeitungsvorgang mit Verknüpfung zur ursprünglichen Herkunft und vollständiger Historie an. Rechtlich ist die bloße Übernahme vorhandener Informationen grundsätzlich Weiterverarbeitung, keine automatische Neuerhebung; Zulässigkeit der neuen Verwendung muss geprüft werden. Keine rückwirkende Legitimierung und kein Zurücksetzen der ursprünglichen Historie.
  - Prüfentscheidungen mit Prüfer, Zeitpunkt und Begründung (bei Behalten/Übernahme) protokollieren. Interne Erinnerungs-/Eskalationsfristen konfigurierbar halten; keine pauschale automatische Löschung nur wegen Nichtbearbeitung einer Benachrichtigung.
  - Gesetzliche Maximal-/Prüffristen, interne Prüffristen und tatsächliche Löschpflichten technisch klar unterscheiden. Fristen und Rechtsregeln nicht im Code erfinden oder fest verdrahten; behördliche Freigabe und Anpassbarkeit vorsehen.
  - **Löschungen bei Backups und Wiederherstellung berücksichtigen:** Ein bereits rechtswirksam gelöschter Datensatz darf nicht durch das Einspielen eines älteren Backups unbemerkt wieder in den operativen Datenbestand gelangen. Dafür einen geeigneten, separat geschützten Lösch-/Sperrstatus bzw. eine Löschliste (Tombstones) vorsehen, die nach einer Wiederherstellung erneut angewendet wird. Auch Wiederherstellung und erneute Anwendung der Löschungen im zentralen Ereignisprotokoll erfassen.

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
