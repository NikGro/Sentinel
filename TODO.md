# Offene Punkte

Wünsche, Fehler und technische Arbeiten werden hier gesammelt und zu festen Zeitpunkten gebündelt umgesetzt,
statt jede Änderung sofort einzubauen. Erledigtes wandert mit Version ins CHANGELOG.

## Geplant

### Nach 0.41 offen

- **Standortspur wechselt weiter die Dicke (Screenshots 27.11., 17:21):** Dieselbe Stelle wird beim Fahren mal dicker,
  mal dünner. Prüfen:
  - Geklärt: nur eine Standortspur (die blaue Linie); die rote daneben ist Apples Verkehrslage (Stau). Die Dicke der
    blauen Spur wechselt an derselben Stelle zwischen zwei Aufnahmen: Ursache liegt im Zeichnen.
  - SwiftUI-MapKit legt Linien mit Farbverlauf beim Neuaufbau neu an und zeichnet sie kurz mit anderer Breite/Deckkraft.
    Saubere Lösung statt weiterer Versuche in SwiftUI: die Standortspur als eigenes Overlay direkt in die MKMapView
    (die MapEngine hält sie) mit eigenem Renderer (`MKGradientPolylineRenderer`, feste Breite in Punkten), Punkte nur
    anhängen statt neu anlegen.
- **Performance prüfen (0.40: nur gezielt, Messung steht aus):** Kartenbildschirm messen (Instruments: Time Profiler, SwiftUI-Updates, Hitches). Kandidaten:
  `MapScreen` baut bei jeder Standort- und Kameraänderung viel neu; Ebenen auf eigene beobachtbare Objekte aufteilen
  (wie Routenlinie/Spurende); teure Berechnungen (Clustern/Auseinanderrücken, Spur-Farbverläufe, Häufigkeit über alle
  Spuren, ÖPNV-Fahrzeuge mit 30 Hz) zwischenspeichern; Anzahl der Annotationen begrenzen.
- **Stau auf der Route einfärben (ohne Sonderrechte):** Abschnitte mit stockendem Verkehr auf der Routenlinie gelb bzw.
  orange (nicht rot, das ist Sonderrechten vorbehalten).
  - Stand: Apple Karten zeigt die Verkehrslage nur als Kartenebene; je Abschnitt gibt MapKit sie nicht heraus.
  - Sauberer Weg: TomTom (Schlüssel ohnehin für Sperrungen) liefert zur Route Verkehrsabschnitte mit Verzögerung
    (Routing-API mit `sectionType=traffic`, die eigene Route als Stützpunkte) bzw. Fließgeschwindigkeiten je Abschnitt.
    Server fragt das je neu berechneter Route einmal ab und gibt die Abschnitte mit; die App färbt sie ein. Erst angehen,
    wenn der TomTom-Schlüssel hinterlegt ist; Kontingent beachten.
- **Prüfung auf Umwege und Behelfslösungen:** Einmal alles durchgehen, wo wir mit Tricks statt auf direktem Weg arbeiten,
  und je Stelle entscheiden: behalten (begründet), sauber ersetzen oder streichen. Bekannte Kandidaten:
  - Apples Route als Folge von Durchfahrtspunkten für Valhalla (Staus ohne Sonderrechte; mit TomTom-Verkehr ersetzbar).
  - Eigene Kartensteuerung (MapEngine) mit eigenen Gesten statt der MapKit-Bedienung; eigener Punkt vom Bildschirm
    gezeichnet; Kameramitte versetzt, damit der Pfeil höher sitzt (Versatz je Bild nachgemessen).
  - Routenlinie aus Lot und Vorlauf statt aus dem Fortschritt des Navigationskerns.
  - Sperrungen als Meidepunkte entlang der Strecke (statt Flächen) wegen Valhalla-Grenzen.
  - Parallel-Modus: Straße des Ziels über Meidepunkte, Fallback bei großem Umweg.
  - Wenden-Variante: zusätzliche Route ohne Startrichtung zum Vergleich.
  - Straße am eigenen Punkt: Server-Straßenverzeichnis mit Apples Umkehrsuche als Rückfall.
  - Vorlauf/Kreuzungen: Apples Umkehrsuche für die Straße des Ziels.
- **SOS als kritischer Alarm:** Drückt ein Fahnder SOS, soll bei allen anderen außerhalb der App eine Mitteilung mit
  Alarmpriorität kommen, leise (etwa 10 % Lautstärke), aber immer hörbar, auch im Stumm- und Fokus-Modus.
  - Stand: Die App schickt bei SOS schon eine lokale Mitteilung als „Dringend“ (time-sensitive), sofern sie im
    Hintergrund noch läuft (Standort im Hintergrund hält sie meist wach). Sie durchbricht Fokus, aber nicht den
    Stummschalter.
  - Immer hörbar mit eigener Lautstärke geht nur als „kritischer Hinweis“ (Critical Alert, `criticalSoundVolume` z. B.
    0.1). Dafür braucht die App eine Berechtigung, die Apple nur auf Antrag vergibt (Behörden, Gesundheit, Sicherheit),
    und ein bezahltes Entwicklerkonto; mit SideStore und kostenlosem Konto nicht möglich. Ebenso fehlt ohne bezahltes
    Konto echter Push (APNs), wenn die App ganz beendet ist.
  - Vorgehen: Antrag bei Apple prüfen (Behördennutzung begründen); bis dahin die bestehende Mitteilung mit
    eigenem, gut hörbarem Ton und Wiederholung absichern.
- **Staus mit Sonderrechten:** Ohne Sonderrechte folgt die Route Apples Weg mit Verkehrslage. Mit Sonderrechten
  rechnet nur Valhalla; ein Hinweis bei deutlich schnellerer Apple-Route wäre möglich.
- **Beziehungen:** Protokollierung von Änderungen gehört zum Ereignisprotokoll in Runde 2 (Datenschutz); bisher
  stehen nur „zuletzt geändert von“ und Status/Herkunft am Datensatz.

### Beobachten

- **Straßenverzeichnis beobachten:** Läuft mit 2 GB Container-Speicher, Node.js darf bis 1,5 GB nutzen. Stand
  22.11.: 286 MB im Betrieb, kein Neustart seit dem Update. Das nächste wöchentliche Neuladen über Overpass ist um
  den 27.11.; danach den Speicher prüfen. Wird es knapp, die Straßen in SQLite statt im Arbeitsspeicher halten.
- **Fahrspuren beim Abbiegehinweis beobachten:** Die Anzeige gibt es; bei Gelegenheit prüfen, ob sie zuverlässig
  erscheint.
- **SinoTrack per USB:** Mit dem echten Tracker prüfen, ob er die Befehle über USB annimmt (Baudrate, Befehlsform).
  Den Stand aus dem Desktop-Chat abgleichen und die APN der Beach SIM als Beispiel eintragen.
- **Kreuzungssuche nach dem Update prüfen:** Kommen plausible Straßenecken jetzt zuverlässig, auch nach dem ersten Buchstaben der zweiten Straße? Falls nicht: Beispiel nachstellen.

### Karte, Kompass und Navigation

- **App-Absturz während aktiver Navigation (0.9: mögliche Ursache abgesichert):** Dafür ist ein Absturzbericht nötig, zu finden unter Einstellungen › Datenschutz & Sicherheit › Analyse & Verbesserungen › Analysedaten › „Sentinel-…“.

### Marker und Oberfläche

- **Zielperson: Karte friert ein (0.13: ÖPNV-Positionsberechnung als wahrscheinliche Ursache stark beschleunigt):** Offene Rückfrage, welches Symbol genau gemeint ist: im Plus-Menü, im Editor („Unterwegs“) oder auf der Karte. Mit 0.13 erneut prüfen.


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


### Verbindliche Architektur- und Umsetzungsregeln (für die Umsetzung ohne zusätzlichen Gesprächskontext)

Dieser Abschnitt konkretisiert die obigen Anforderungen. Er ist zusammen mit ihnen als verbindliche fachliche Spezifikation zu lesen. Bei Unklarheiten gelten die folgenden Grundsätze; keine abweichenden Rollen, parallelen Logs oder stillen automatischen Datenübernahmen einführen.

- **Rollen und Zuständigkeiten:**
  - Es bleiben genau zwei globale Rollen: `Nutzer` und `Admin`. Keine dritte Rolle, insbesondere keine separate Datenschutzbeauftragten-Rolle, und kein zusätzliches rollenähnliches Berechtigungsmodell einführen.
  - Ein Nutzer darf in den Instanzen, denen er angehört, die für den operativen Betrieb erforderliche Context-Token-Verwaltung durchführen: Maßnahme/Token anlegen, aktivieren, wechseln und beenden. Ein Admin kann dies ebenfalls und hat zusätzlich die administrativen Rechte für Benutzerverwaltung und Datenschutzverwaltung. Admins dürfen die operativen Rechte normaler Nutzer ebenfalls ausüben.
  - Die Zugehörigkeit zu einer Instanz begrenzt, auf welche Instanzen ein Nutzer operativ zugreifen und dort Tokens verwalten kann. Admin-Rechte für Datenschutzverwaltung gelten systemweit. Diese Begrenzung ist keine dritte Rolle.
  - Serverseitige Autorisierung ist maßgeblich; ausgeblendete UI-Elemente allein sind keine Zugriffssicherung.

- **Context Token ist der operative Maßnahmenkontext:**
  - Ein Token ist ein unveränderlicher Datensatz für genau eine konkrete Maßnahme. Alle Pflichtangaben werden beim Anlegen vollständig erfasst und vor Aktivierung geprüft. Nach Aktivierung werden seine maßgeblichen Inhalte nicht editiert. Korrektur oder Maßnahmenwechsel erfolgen durch Beenden und Anlegen eines neuen Tokens.
  - Pro Instanz kann zu einem Zeitpunkt höchstens ein Token aktiv sein. Die Aktivierung eines neuen Tokens und die Beendigung des vorherigen Tokens müssen als ein konsistenter serverseitiger Vorgang erfolgen; es darf keinen Zustand mit zwei aktiven Tokens geben.
  - Token-Historie einschließlich Ersteller, Aktivierungs-/Beendigungszeitpunkt, Ablauf und Status bleibt unveränderlich nachvollziehbar. Die 24-Stunden-Höchstlaufzeit wird serverseitig erzwungen; nach Ablauf ist der Token nicht mehr aktiv und der operative Zugriff gesperrt, bis ein neuer Token aktiviert wurde.
  - Jeder operative Request muss serverseitig den aktiven Token der betreffenden Instanz ermitteln und prüfen. Ein vom Client mitgesendeter Token oder Kontext darf niemals ungeprüft als maßgeblich akzeptiert werden.
  - Tokenwechsel ist ein harter Kontextwechsel, keine Fortsetzung der alten Maßnahme: Bestehende kontextgebundene Objekte und Beziehungen werden für den neuen operativen Kontext zunächst deaktiviert/ausgeblendet. Es findet keine automatische Übernahme statt.

- **Objekte, Beziehungen und kontextbezogene Aktivierung:**
  - Ein fachliches Objekt (z. B. Person, Fahrzeug, Adresse, Marker oder Punkt) und seine Verwendung in einer konkreten Maßnahme sind getrennt zu modellieren. Die Aktivierung für eine Maßnahme darf nicht einfach ein globales Aktivierungsfeld am Objekt sein, das alte und neue Kontexte vermischt.
  - Beim Tokenwechsel werden alle bisherigen operativen Verknüpfungen/Verwendungen in der Instanz für den neuen Kontext zunächst inaktiv. Ein Nutzer kann anschließend gezielt eine benötigte Person, ein Fahrzeug, einen Marker, einen Punkt oder eine Beziehung für den neuen Token-Kontext freigeben. Diese Freigabe erzeugt bzw. aktiviert eine eigene nachvollziehbare kontextbezogene Zuordnung zum neuen Token; sie überschreibt niemals die ursprüngliche Erhebung, Herkunft oder frühere Zuordnung.
  - Die Reaktivierung eines Objekts bedeutet nur, dass es im neuen Kontext verwendet werden darf, sofern die dafür erforderliche Prüfung/Zulässigkeit vorliegt. Sie setzt keine Frist zurück, löscht keine Sperre aus einem anderen Kontext und macht eine unzulässige Weiterverarbeitung nicht zulässig.
  - Beziehungen sind eigenständige kontextbezogene Datensätze. Eine Beziehung hat ihre eigene Herkunft, ihren Status, ihre Erstellungs-/Änderungshistorie und gegebenenfalls eigene Prüffristen. Eine Beziehung kann gesperrt oder entfernt werden, ohne das verknüpfte Fahrzeug oder die andere Person pauschal zu sperren.
  - Personenbezogene Informationen einer gesperrten/gelöschten Person dürfen auch nicht über Fahrzeugansichten, Suchtreffer, Marker, Kartenlayer, Exporte, Verlauf oder andere indirekte Ansichten weiter sichtbar oder nutzbar sein. Die Sperr-/Löschentscheidung muss deshalb alle Ansichten und Abfragewege berücksichtigen, nicht nur den Personendatensatz.
  - Ein Fahrzeug bleibt nur dann verfügbar, wenn seine eigene Verarbeitung und die noch vorhandenen Beziehungen/Daten weiterhin zulässig sind. Ist nur eine Person oder eine Beziehung betroffen, wird nur dieser Datenanteil gesperrt; das gesamte Fahrzeug wird nicht automatisch gesperrt.

- **Ein einziges vollständiges Ereignisprotokoll:**
  - Es gibt genau ein fachliches Ereignisprotokoll und ein gemeinsames Ereignismodell. Kategorien wie System, Sicherheit, Nutzeraktion, Tracker, Objektänderung oder Datenschutz sind lediglich Ereignistypen/Kategorien innerhalb dieses Logs, keine getrennten Speicher oder Subsysteme.
  - Jede relevante Aktion muss über eine zentrale serverseitige Logging-Schnittstelle protokolliert werden. Direkte Datenbankänderungen an relevanten fachlichen Daten ohne zugehörigen Log-Eintrag sind unzulässig. Logging darf nicht nur in einzelnen UI-Aktionen implementiert werden; auch API-, Hintergrund-, Import-, Tracker- und Admin-Prozesse müssen erfasst werden.
  - Ein Ereignis enthält mindestens: eindeutige Ereignis-ID, Zeitstempel (UTC), Akteur/Quelle, Nutzer-ID falls vorhanden, Instanz, Ereignistyp, betroffene Objekt-/Beziehungs-IDs, Aktion, Ergebnis, Fehlerdetails soweit sicher, vorherigen und neuen Zustand bzw. die relevanten Änderungswerte sowie den Kontextbezug.
  - Bei einem Ereignis innerhalb einer aktiven Maßnahme werden Token-ID und ein unveränderlicher Snapshot aller maßgeblichen Token-Felder direkt im Ereignis gespeichert. Nicht nur auf eine veränderbare Token-Tabelle oder eine Token-ID verweisen. So bleibt der damalige Kontext auch nach Tokenablauf oder späteren Änderungen anderer Datensätze rekonstruierbar.
  - Ereignisse ohne aktiven Token werden ausdrücklich als tokenlos gekennzeichnet und enthalten, soweit vorhanden, den Bezug zum vorherigen oder neu angelegten Token. Fehlgeschlagene Anmeldungen werden ebenfalls protokolliert, auch wenn kein Nutzer authentifiziert werden konnte; dabei niemals Passwörter, Session-Cookies, Zugangstoken oder andere Geheimnisse speichern.
  - Bei asynchronen Vorgängen (insbesondere Tracker- und Hintergrundereignissen) wird der zum tatsächlichen Eingang/Annahmezeitpunkt gültige Kontextbezug festgehalten. Kann ein Ereignis mangels aktivem Token nicht operativ verarbeitet oder gespeichert werden, wird die Zurückweisung als tokenloses Sicherheits-/Systemereignis protokolliert; die Nutzdaten dürfen dadurch nicht unzulässig in den operativen Datenbestand gelangen.
  - Fachliche Änderung und zugehöriger Log-Eintrag müssen soweit technisch möglich in derselben Datenbanktransaktion geschrieben werden. Schlägt das Protokollieren fehl, darf die fachliche Änderung nicht stillschweigend erfolgreich abgeschlossen werden. Für externe/asynchrone Vorgänge ist ein zuverlässiges Wiederholungs-/Outbox-Verfahren vorzusehen, damit Ereignisse nicht verloren gehen.
  - Das Log ist gegen nachträgliche unbemerkte Veränderung und unberechtigte Löschung zu schützen. Einsicht, Suche, Export und administrative Log-Verwaltung werden selbst wieder im selben Log protokolliert. Vollständigkeit ist mit automatisierten Tests für alle relevanten Aktionsarten nachzuweisen.
  - Vollständigkeit bedeutet nicht, Geheimnisse oder unnötige Inhalte zu speichern: Zugangsdaten, Passwörter, kryptografische Schlüssel und Session-Geheimnisse sind immer ausgeschlossen. Personenbezogene Logdaten werden nach einem rechtlich freigegebenen, konfigurierbaren Aufbewahrungs- und Löschkonzept behandelt.

- **Zwei strikt getrennte Zugriffswege:**
  - Der operative Zugriffsweg setzt eine authentifizierte Sitzung, passende Instanzmitgliedschaft/Berechtigung und einen gültigen aktiven Context Token voraus. Er umfasst Anzeige, Suche, Abfrage, Erstellung, Änderung, Aktivierung, Nutzung, Navigation, Export und operative Verarbeitung eingehender Tracker-Daten.
  - Der administrative Datenschutz-/Systemzugriffsweg ist ausschließlich Admins vorbehalten und funktioniert auch ohne aktiven Token. Er ist auf die notwendigen Verwaltungs- und Schutzaufgaben beschränkt: Nutzerverwaltung, Tokenverwaltung, Datenschutz-Prüfbereich, Fristenentscheidungen, Sperren, Löschen, zulässige Kontextübernahmen, Sicherheits-/Anmeldeverwaltung, Backup und Wiederherstellung.
  - Der administrative Zugriffsweg darf nicht dazu verwendet werden, operative Inhalte ohne gültigen Token anzusehen, zu durchsuchen, zu exportieren oder anderweitig für die Maßnahme zu nutzen. Wo ein Admin zur Prüfung einen Datensatz einsehen muss, muss dies über eine ausdrücklich dafür vorgesehene, zweckgebundene Datenschutzansicht erfolgen und im zentralen Log erscheinen.
  - Jede API-Route und jeder Hintergrundprozess muss eindeutig einem der beiden Zugriffswege zugeordnet und serverseitig abgesichert sein. Es darf keine unklassifizierte dritte Zugriffsmöglichkeit geben.

- **Datenschutz-Verarbeitungskontext ist nicht dasselbe wie Context Token:**
  - Der Context Token beschreibt die konkrete operative Maßnahme einer Instanz. Ein Datenschutz-Verarbeitungskontext beschreibt dagegen die rechtliche Einordnung einer Verarbeitung bzw. einer Übernahme im Datenschutz-Prüfprozess.
  - Das Anlegen oder Ändern eines Datenschutz-Verarbeitungskontexts erzeugt nicht automatisch einen operativen Context Token. Ebenso ersetzt oder ändert ein operativer Tokenwechsel nicht den ursprünglichen Datenschutz-Verarbeitungskontext eines Datensatzes.
  - Eine Übernahme in einen neuen Datenschutz-Verarbeitungskontext ist eine eigenständige, vom Admin dokumentierte Entscheidung. Sie bleibt unabhängig von Instanz und aktivem Token. Die ursprüngliche Herkunft und alle bisherigen Kontexte bleiben historisch verknüpft.
  - Wenn übernommene Daten später in einer konkreten operativen Maßnahme verwendet werden sollen, ist zusätzlich ein gültiger operativer Context Token dieser Instanz erforderlich. Erst die explizite, protokollierte Freigabe/Zuordnung verbindet die zulässige Datenverwendung mit dieser Maßnahme.

- **Prüffristen, Sperrungen, Löschungen und Wiederherstellung:**
  - Fristen werden anhand der rechtlich freigegebenen Regelkonfiguration berechnet und beziehen sich auf den jeweils maßgeblichen ursprünglichen Erhebungs-/Verarbeitungsvorgang sowie die betroffene Person bzw. den betroffenen Daten-/Beziehungsanteil. Ein Tokenwechsel, eine Reaktivierung, eine Kopie oder ein Backup setzt diese Fristen nicht zurück.
  - Eine fällige Prüfung erzeugt einen administrativen Prüfauftrag. Bis zur Entscheidung ist der betroffene Datenanteil operativ gesperrt. Eine nicht bearbeitete Erinnerung führt nicht automatisch zur Löschung; eine unabhängig bestehende gesetzliche Löschpflicht wird trotzdem unverzüglich umgesetzt.
  - Die Entscheidung **Behalten** verlängert/erlaubt die Speicherung nur, soweit die einschlägigen gesetzlichen Voraussetzungen und Höchstgrenzen dies zulassen; die kurze Begründung und die Regelversion werden protokolliert. **Löschen** entfernt die betroffenen Daten aus allen operativen Ansichten und Datenbeständen, soweit keine rechtlich zulässige getrennte Nachweispflicht besteht. **In neuen Kontext übernehmen** erstellt eine neue Verarbeitungsvorgangs-Verknüpfung, erhält die Herkunft und Historie und setzt keine alte Frist zurück.
  - Löschungen müssen alle Kopien, Indizes, Caches, Suchdaten, Karten-/Verlaufsansichten, Exporte und Beziehungen berücksichtigen. Für unvermeidbare Backup-Restbestände gilt das Tombstone-/Löschlistenverfahren: Nach jeder Wiederherstellung werden zwischenzeitlich vollzogene Löschungen und Sperrungen erneut angewendet, bevor der Datenbestand wieder operativ freigegeben wird.
  - Ein wiederhergestelltes System bleibt bis zum Abschluss der Integritätsprüfung, erneuten Anwendung der Lösch-/Sperrinformationen und Prüfung des aktiven Tokenstatus im Wartungs-/Administrationsmodus. Es darf nicht mit alten aktiven Tokens oder bereits gelöschten Datensätzen in den operativen Betrieb zurückkehren.

- **Verbindliche Umsetzungstests:**
  - Tokenwechsel: alter Token wird beendet, neuer Token aktiv; alle bisherigen kontextbezogenen Verwendungen sind zunächst ausgeblendet/inaktiv; kein Objekt wird automatisch übernommen; jede einzeln freigegebene Verwendung erhält neuen Kontextbezug und Log-Eintrag.
  - Tokenablauf/fehlender Token: operative API-Aufrufe und Tracker-Persistierung werden serverseitig abgewiesen; tokenlose Ablehnungsereignisse werden protokolliert.
  - Logging: für jede relevante erfolgreiche und fehlgeschlagene Aktion entsteht genau ein nachvollziehbarer Eintrag mit Akteur, Ereignisinhalt und korrektem Token-Snapshot bzw. explizitem tokenlosem Status.
  - Datenschutzsperre: Wird eine von mehreren mit einem Fahrzeug verknüpften Personen gesperrt oder gelöscht, ist diese Person samt Beziehung in sämtlichen Ansichten nicht mehr operativ sichtbar/nutzbar; das Fahrzeug und andere zulässige Beziehungen bleiben verfügbar.
  - Rollen: Nutzer können keine Admin-Funktionen aufrufen; Admins können Benutzer- und Datenschutzverwaltung durchführen. Es existieren keine weiteren Rollen.
  - Kontextübernahme: Eine Datenschutzübernahme ist ohne aktiven Instanz-Token möglich, erzeugt keinen automatischen Token, erhält die Herkunft und erfordert für spätere operative Nutzung eine gesonderte Freigabe unter gültigem Token.
  - Backup-Wiederherstellung: Nach Restore werden Löschungen/Sperrungen erneut angewendet; bis dahin bleibt der operative Zugriff gesperrt.

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
