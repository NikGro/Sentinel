# SENTINEL – Gesamt-Review und Neubau-Plan

Stand: App 0.42.1 (in Arbeit), Server 0.42, Sentinel Web 0.42. Grundlage: der gesamte Quelltext (iOS rund 22 300 Zeilen
Swift, Server rund 7 400 Zeilen TypeScript, Web rund 3 500 Zeilen), `docs/Fehlerprotokoll.md`, `TODO.md`, `CHANGELOG.md`
und die Rückmeldungen aus allen Runden. Dieses Dokument ändert nichts am Code; es ist die Entscheidungsgrundlage.

---

## 1. Kurzfassung

**Befund.** Fachlich ist SENTINEL weit und durchdacht: Datenmodell, Server, Synchronisation, Ziele, Instanzen,
ÖPNV-Modell, Navigation mit Sonderrechten. Die Unsauberkeit sitzt an einer Stelle mit vielen Ausläufern: **der Karte**.
Die App zeichnet alles mit Apples SwiftUI-Karte (`Map`). Die gibt weder die Kamera noch das Zeichnen noch die
Treffer-Erkennung wirklich frei. Fast jede Behelfslösung der letzten 40 Versionen ist eine Antwort darauf:
eigene Gesten über dem Ansichtsbaum, Suchen der versteckten Karte, Symbole als einzelne Ansichten statt als
Kartenebene, eigenes Auseinanderrücken samt eigener Tipp-Prüfung, Spur aus hunderten Einzelstücken, eigener Punkt
vom Bildschirm gezeichnet, Takt-Tricks gegen verlorene Antipper.

**Empfehlung.**

1. **Die Karte von Grund auf neu**, so wie Kartenteams (Google, Apple, Esri) es tun: eine eigene Karten-Engine mit
   voller Kontrolle. Konkret **MapLibre Native** (quelloffen, gleiche Engine auf iOS, Android und im Web – Sentinel
   Web nutzt sie schon) mit **eigenen Vektorkacheln auf dem NAS** und der bewährten **eigenen Kamerasteuerung** als
   einziger Stelle, die die Kamera bewegt. Alles auf der Karte wird zu **Datenebenen** (Kräfte, Ziele, Marker, Spuren,
   ÖPNV), nicht zu einzelnen Ansichten. Auseinanderrücken, Cluster, Beschriftungs-Kollision und Treffer-Erkennung
   übernimmt die Engine – eine Stelle für Zeichnen und Antippen.
2. **Den fachlichen Kern einmal schreiben und auf beiden Plattformen nutzen** (Kotlin Multiplatform: Datenmodell,
   Synchronisation, Lage-Regeln, Spur, ÖPNV-Fahrmodell, Suche-Parser). Das ist die Voraussetzung, damit Android und iOS
   wirklich gleich arbeiten und nicht zwei Mal dieselben Fehler gemacht werden.
3. **Oberflächen nativ**: iOS in SwiftUI mit Liquid Glass (wie heute), Android in Jetpack Compose mit
   **Material 3 Expressive**. Gleiche Aufteilung, gleiche Abläufe, gleiche Wörter; nur die Plattform-Optik
   unterscheidet sich.
4. **Server und Sentinel Web bleiben** und werden gezielt aufgeräumt (Kartenkacheln selbst ausliefern,
   Verkehrsdaten, große Dateien teilen). Kein Neubau nötig.
5. **Vorgehen in Schritten mit Gleichstand-Prüfung**: Die neue App muss in jeder Funktion mindestens das können,
   was diese Liste beschreibt (Abschnitt 2 und 3 sind die Abnahmeliste). Die heutige App bleibt bis dahin nutzbar.

---

## 2. Bestandsaufnahme: Funktionsumfang

Alles, was die App heute kann, nach Bereichen. Das ist zugleich die Abnahmeliste für den Neubau.

### 2.1 Zugang, Sicherheit, Lebenszyklus

- Einrichtung: Serveradresse (nur HTTPS, wird vereinheitlicht) und Zugangscode; danach eigenes Profil anlegen oder
  ein bestehendes Profil (eines nicht verbundenen Geräts) übernehmen.
- Anmeldung des Geräts: Token nur im Schlüsselbund, gerätegebunden, nicht in Backups. Abmelden sperrt das Gerät auf
  dem Server, entfernt das eigene Profil und alle Einsatzdaten auf dem Gerät (auch die eigene Spur).
- Versionsabgleich: App und Server müssen in Haupt- und Nebenversion übereinstimmen, sonst Sperrbildschirm
  „Version passt nicht“ mit Abmelden.
- App-Sperre mit Face ID, Touch ID oder Gerätecode beim Verlassen; Sichtschutz (Schild mit SENTINEL) im
  App-Umschalter und bei gesperrter App.
- Verbindungsaufbau mit Anzeige, automatischer Wiederaufbau der Echtzeitverbindung, Entzug des Zugangs durch den
  Server führt zur Abmeldung.
- Demo-Lage für Oberflächentests (nur Testbuilds).

### 2.2 Instanzen und Sonderbereiche (Dienst)

- Hauptmenü außerhalb jeder Instanz: Instanzen öffnen, anlegen, beitreten, verlassen, löschen; Standardinstanz zuerst.
- Im Dienst = in einer Instanz. Außer Dienst nur das Hauptmenü; Standortübertragung und Live-Aktivität enden.
- Sonderbereiche, deutlich andersfarbig: „Dauerhafte Orte bearbeiten“ (nur Markierungen der dauerhaften Ebene) und
  „Paket vorbereiten“ (Vorbereitung ohne Einsatzbetrieb: keine A, kein Notruf, keine Navigation, keine Kräfte, kein
  Chat). Leiste unten auf der Karte zeigt den Bereich und führt mit „Fertig“ zurück.
- Pakete: Bibliothek, bearbeiten wie eine Instanz, in den geöffneten Einsatz übernehmen (Objekte danach eigenständig).
- Hinweise aus anderen Instanzen (A-Wechsel, Notruf) als Banner bzw. Mitteilung; Antippen öffnet die Instanz.

### 2.3 Lagekarte

**Grundkarte und Bedienung**
- Apple-Karte, immer 3D-Gelände und Gebäude; Stil Standard, Hybrid oder Satellit; Verkehrslage zuschaltbar
  (ein Knopf für Stil und Verkehr); 2D/3D-Umschalter.
- Eigene Kamerasteuerung (`MapEngine`): Verschieben, Zoomen, Drehen, Kippen, Schwung; Zwei-Finger-Tippen zoomt
  heraus, Doppeltipp-Halten zoomt stufenlos.
- Standort- und Kompassknopf in einem (Pfeil fest, Kompassrose dreht mit): Anheften in Fahrtrichtung (550 m, schräg
  von hinten) oder Norden oben (1500 m, von oben); Zoomen und Kippen lösen nicht; seitliches Verschieben oder
  Herausdrehen löst. Navigation: eigene Werte, eigener Punkt 40 pt über der Mitte.
- Eigener Standort: blauer Punkt; im Fahrzeug Fahrzeugsymbol; in der Navigation flacher Navi-Pfeil; mit A-Symbol,
  wenn man die A hält; darunter Name, angeheftet zusätzlich Straße, Fahrtrichtung und nächste Querstraße („Ecke …“).
- Tempo (in Bewegung) und Tempolimit der Straße (OpenStreetMap, auch ohne Navigation) unten links.
- Lange drücken auf einen Ort: Karte mit Name (Umkehrsuche), Hinführen, Hier anlegen, Look Around.

**Was auf der Karte steht**
- Kräfte: Fahnder zu Fuß, im ÖPNV (mit Linie), besetzte Fahrzeuge samt Besatzung; Ruhemodus und veraltete
  Positionen gedämpft. Fahrzeuge der Flotte, die im Einsatz sind (Standort aus Telefon der Besatzung, Tracker oder
  Abstellort).
- Ziele: Zielperson, Zielfahrzeug, Zielobjekt (rot, Symbol nach Art bzw. Fortbewegung). Zielperson in Zielfahrzeug
  oder Gebäude ohne eigenes Symbol (Name in der Beschriftung des Trägers); im ÖPNV ihr Symbol am geglätteten Fahrzeug.
- Markierungen: Marker (Symbol und Farbe), Beschriftung, Linie, Pfeil, Fläche, Kreis, Fahndungsraum,
  Haltestellen-Umkreis, Haltestelle, ÖPNV-Strecke (Ebenen Fahrzeug/Strecke/Halte einzeln), ÖPNV-Fahrzeug,
  Geofence, Standortverlauf/Standortspur, Argus-Prognosezellen.
- Beschriftung in Flächen und Kreisen (waagerecht oder entlang der längsten Seite, mit festem weißem Rand).
- Lebensdauer von Markierungen (läuft ab, Countdown in der Ansicht).
- Cluster (herausgezoomt, farbig nach Inhalt), Auseinanderrücken nah herangezoomt (Spalte neben dem echten Ort mit
  Linie und Punkt).
- Bestreifung (wo war wer, Deckkraft nach Häufigkeit, ab Einschaltzeitpunkt), Weg-Zeit-Flächen der Fahndungsräume
  (zu Fuß, Kfz, ÖPNV, wachsend mit der Zeit seit Sichtung), Haltestellen in Umkreisen mit Linien.
- ÖPNV-Fahrzeuge nach Fahrmodell (Kurven, Bremsen, Standzeiten, Fahrplan/Echtzeit), auch im Takt eingeblendete;
  Antippen legt ein eingeblendetes Fahrzeug als Objekt an.
- Ebenen ein-/ausblenden (je Gerät), Zielarten ausblenden, Gruppen ein-/ausblenden (je Instanz).

**Antippen**
- Symbol öffnet Kurzübersicht; Formen und Spuren unter dem Finger (kleinste zuerst), mehrfach tippen schaltet durch;
  Linien und Spuren bekommen einen Punkt auf der Strecke, die Kamera rückt ihn in die freie Mitte.
- Nur Sichtbares ist antippbar.

**Oben und rechts**
- Suchleiste („Suchen oder navigieren“) und runder Knopf „Zu Objekten navigieren“.
- Notruf-Leiste (rot), solange ein Notruf läuft.
- Rechts: SOS (1,5 s halten, Ring füllt sich; eigener Notruf per Tipp mit Rückfrage beenden), Standort/Kompass,
  Stil/Verkehr, Ebenen, „A-Position zeigen“, Plus-Menü.

**Unten**
- A-Position: übernehmen (zweimal drücken), abgeben; „Zur A“, wenn jemand anderes sie hält.
- Fortbewegung als Dreier-Umschalter (zu Fuß sofort, Fahrzeug und ÖPNV mit Auswahl).
- Lageleiste: Funkkanal, A-Position samt Fortbewegung, Einsatzname, Verbindungszustand; öffnet die Lageübersicht.

**Anlegen und Setzen**
- Plus-Menü als großes Kachel-Auswahlmenü: Markierungen, Fahndungsraum, Ziele (mit Standortquelle), ÖPNV,
  Standortverlauf, eigene Standortspur. Umfang nach Bereich (Einsatz, Paket, dauerhafte Orte).
- Setzen-Modus: Karte reduziert auf Suchleiste, gelbe Leiste mit Hinweis, „Übernehmen“ und X; Vorschau zeigt schon
  das spätere Symbol; Mehrpunkt-Formen mit „Fertig“. Ort auch über die Adresssuche.
- Markierung verschieben (Tipp), Fahndungsraum verschieben mit Rückfrage zum Sichtungszeitpunkt.

### 2.4 Suche

- Freie Ortssuche (Apple) mit Autovervollständigung: „12 Musterstraße“ wird verstanden; Kreuzungen mit „/“, „&“,
  „Ecke“, „x“, „und“ – Kreuzungspunkt vom Server, verzeiht Tipp- und Hörfehler; Reihenfolge Anschriften, Orte, Haltestellen.
- Objekte der Lage ansteuern (A immer oben, Kräfte, Fahrzeuge, Ziele, Markierungen), „live“-Kennzeichen für bewegte Ziele.
- Spracheingabe für das Ziel (auf dem Gerät), Füllwörter werden entfernt.
- Treffer auf der Karte zeigen, hinführen oder dort anlegen (Feld wie in Apple Karten).

### 2.5 Navigation

- Ferrostar-Kern: Standort auf die Route, Abweichung, Neuberechnung, Hinweise; Routen vom eigenen Server (Valhalla).
- Ohne Sonderrechte: Apples Weg mit Verkehrslage als Vorgabe (Durchfahrtspunkte), Plausibilitätsprüfung (Umwege,
  Wenden), ehrliche Ankunftszeit (Faktor Apple/Valhalla).
- Mit Sonderrechten: Regelbruch (Einbahnstraße, Abbiegeverbot) nur wenn es spürbar Zeit spart; eigene Linienfarbe.
- Sperrungen: Autobahn GmbH (offene Daten) und TomTom-Meldungen (Schlüssel fehlt noch) als Meidepunkte.
- Bewegte Ziele: Route folgt (Neuberechnung bei Bewegung, gedrosselt). Anfahrt direkt, im Vorlauf (Kreuzung vor dem
  Ziel in seiner Richtung) oder parallel (Nebenstrecke, Straße des Ziels gemieden).
- Ziel im ÖPNV: direkt zum Fahrzeug oder ein bis zwei Halte voraus (rückt mit). Überschlagendes Anfahren, solange die
  A im ÖPNV fährt (Server teilt Halte zu).
- Oberer Teil: nächstes Manöver mit Entfernung, Fahrspuren, Straßenschild; unten Restzeit, Strecke, Ankunft, Ziel,
  Sonderrechte-Schalter, Beenden. Querstraßen als Sprechblasen an der Kreuzung. Zielfahne.
- Zu Fuß bzw. ÖPNV: Verbindung mit Bus und Bahn (Transitous) als Schrittfolge auf Karte und Liste; Apple Karten als Rückfall.
- Sprachansagen bewusst stumm.

### 2.6 ÖPNV

- Deutschlandweite Live-Ansicht (Transitous über eigenen Server): fahrende Fahrzeuge, Haltestellen, Linien- und
  Haltestellensuche, Abfahrten, Fahrt mit Verlauf; übernehmen als ÖPNV-Strecke mit wählbaren Ebenen, Haltestelle
  übernehmen; einsteigen (eigene Fortbewegung) bzw. Zielperson einsteigen lassen.
- ÖPNV-Strecken/-Fahrzeuge auch im Editor anlegen: Linie suchen (in der Nähe oder per Name), Richtung, Start/Ende,
  Abfahrt, Takt; Fahrzeug löscht sich nach Ankunft.
- Linienschilder im Stil der Haltestellenschilder (S grün rund, U Quadrat in Linienfarbe, Bus schwarz auf weiß,
  Regionalbahn grau, Fähre blau), Haltestellensymbole (S-, U-Logo, grünes H im gelben Kreis).
- Echtzeit-Nachführung auf dem Server (Verspätungen).

### 2.7 Ziele

- Liste nach Art (Fahrzeuge, Personen, Objekte), Suche über Name, Kennzeichen, Anschrift; Gruppen als eigene Seiten
  (Name, Symbol, Farbe; je Instanz auf der Karte ein-/ausblendbar; ein Ziel in höchstens einer Gruppe);
  Auswahlmodus (gedrückt halten, Haptik, „Optionen“ und „Fertig“: alle auswählen, zur Gruppe, aus Gruppe entfernen);
  Plus auch in der Gruppe.
- Ansicht: Fotos (Titelbild), Hinführen, Unterwegs (zu Fuß, im Fahrzeug, im ÖPNV, im Gebäude), Standortquelle (von
  Hand, Tracker, A-Position folgen), Insassen bzw. „Im Gebäude“ mit Aussteigen/Verlassen, Beziehungen (beidseitig,
  Freitext), Angaben (Freitext), Look Around (nur Zielobjekte), Verlauf aufzeichnen, Sichtbarkeit je Instanz.
- Bearbeiten: Art, Name/Kennzeichen, Geburtsdatum (Alter), Anschrift mit Autovervollständigung (setzt Standort),
  Fotos und Dateien, Freitext, Standort setzen (Karte oder eigene Standortwahl mit gleicher Suche), Tracker.

### 2.8 Kräfte

- Fahnder (aktiv/Ruhemodus, verbunden, Fortbewegung, anrufen) und Fahrzeugflotte (Funkrufname, Kennzeichen,
  Beschreibung, Foto, Tracker, im Einsatz je Instanz, Besatzung, Standort); Suche.

### 2.9 Lageübersicht, Hinweise, Chat

- Lageübersicht: Einsatzinformationen, Funkkanal setzen, A-Position, Erreichbarkeit der Kräfte mit Anrufen.
- Hinweise in drei Stufen (grün, gelb, rot) mit eigener Vibration; im Hintergrund als Mitteilung, rot als „dringend“;
  Geofence-Alarme vom Server.
- Chat mit Räumen, Bildern, Dateien, Sprachnachrichten mit Wellenform (derzeit ausgeblendet).

### 2.10 Verlauf, Spuren, Tracker, Verwaltung

- Verlaufsmodus: Spuren wählen (Fahnder, Ziele, Fahrzeuge, Tracker), Zeitraum (Vorgaben oder von–bis),
  Abschnitte nach Quelle gefärbt, Lücken gestrichelt, Standzeiten, Werte an angetippter Stelle; als Objekt auf die
  Karte legen. Aufzeichnung je Objekt schaltbar, Aufbewahrung.
- Eigene Standortspur (Farbe nach Alter oder Häufigkeit über alle Fahnder), lokal aufgezeichnet.
- Tracker: SinoTrack (H02) und PAJ; Zustand (Akku, GPS, Verbindung), Befehle (Intervall, Alarm scharf), SMS-Befehle,
  Nachrichten, Zuordnungen, Verlauf.
- Verwaltung in der App: Geräte und Zugangscode, Tracker übernehmen, PAJ-Konto, Ebenen und Pakete, Argus-Predict-Import,
  Funkkanal/Einsatzinformationen/Lage zurücksetzen. Entwickler: Kamera-Overlay, Kamera-Messdaten senden.

### 2.11 Live-Aktivität und Hintergrund

- „SENTINEL teilt deinen Standort“ in Dynamic Island und auf dem Sperrbildschirm (rotes Schild), solange im Dienst.
- Standort im Hintergrund (blaue Anzeige), Herzschlag alle 15 s, Übertragung ab 5 m bzw. Zeitabstand.

### 2.12 Server und Sentinel Web (bleiben)

- Server: Datenmodell und Prüfung, Lage-Regeln, WebSocket-Verteilung, Geräte und Tresor, Tracker-Empfang, Valhalla
  (Routen, Weg-Zeit), Transitous-Anbindung, Straßenverzeichnis, Kreuzungen, Tempolimits, Sperrungen, Argus-Import,
  Spuren, Geofences, SideStore-Quelle und Deploy. 95 automatische Tests.
- Sentinel Web (Kommandozentrale): Karte (MapLibre oder Apple MapKit JS), Lage, Team, Ziele, Tracker, Ebenen,
  Instanzen, Chat, System, USB-Einrichtung.

---

## 3. Bestandsaufnahme: Optik (Gestaltungssystem)

### 3.1 Grundsätze, die gelten sollen

- Plattform zuerst: iOS 26 Liquid Glass (Leisten, Knöpfe und Karten über der Karte aus Glas), Listen im
  System-Stil mit angehobener Farbstufe; durchgehend deutsch, Satzanfänge groß, kurze Verben.
- Gleiche Funktion im gleichen Kontext sieht gleich aus (Review 0.42).

### 3.2 Farben

| Rolle | Wert |
|---|---|
| Akzent (Hinführen, Bestätigen, Auswahl) | Systemblau |
| Kräfte | `#5E5CE6` |
| Ziele | `#FF375F` |
| A-Position, Notruf, Live-Aktivität | Rot |
| Sonderbereiche | Violett |
| Bestreifung | `#FF9F0A` |
| Weg-Zeit: zu Fuß / Kfz / ÖPNV | Grün / Rot / Blau |
| Cluster gemischt | `#5E6A7D` |
| Markierungsfarben | Orange, Rot, Gelb, Grün, Türkis, Blau, Violett, Weiß (System-Töne) |
| Spur | Skala Blau → Grün → Gelb → Rot, 75 % deckend |
| Setzen-Leiste | Glas gelb getönt |

### 3.3 Maße

| Element | Maß |
|---|---|
| Runde Kartenknöpfe, alle Leisten über der Tableiste | 44 pt |
| Runde Knöpfe in Karten über der Karte | 36 pt |
| Seitenabstand bündig mit der Tableiste | 22 pt |
| Abstand gestapelter Leisten | 8 pt |
| Kartensymbol (abgerundetes Quadrat) mit Name darunter | 40 pt + Beschriftung |
| Spurbreite | 7 pt |

### 3.4 Bausteine und wo sie stehen

| Baustein | Form | Kontext |
|---|---|---|
| Runder Glasknopf | 44 pt Kreis, Glas | Kartenrand (Kompass, Stil, Ebenen, A, Plus, Zu Objekten) |
| SOS | rot, Halten mit Ring | Kartenrand oben rechts, auch im Setzen-Modus |
| Suchleiste | Glas-Kapsel 44 pt | Karte oben; in ÖPNV als Linien-/Haltestellensuche |
| Gelbe Setzen-Leiste | Glas gelb, Hinweis, Übernehmen, X | unter der Suchleiste in allen Setzen-Abläufen |
| Kurzübersicht | Fenster von unten (niedrig/mittel/groß), Kopfzeile mit Symbol, Titel, Untertitel, runden Knöpfen (Hinführen blau, Bearbeiten, Schließen); Hintergrund nur in der großen Stufe | alle angetippten Objekte, Verlauf |
| Karte über der Karte | Glas, 22 pt Radius, Schließen 36 pt | Ort/Suchtreffer, ÖPNV-Auswahl, Punkt im Verlauf |
| Großer Aktionsknopf | Glas prominent, volle Breite | Hinführen (Listen), Einsteigen, Übernehmen |
| Zeilen-Aktionsknopf | umrandet, Kapsel | Ende von Listenzeilen |
| Runder Zeilenknopf | umrandet, Kreis, getönt | Anrufen (grün), Aussteigen (rot) |
| Auswahl-Kapseln | blau gefüllt | „Optionen“, „Fertig“ im Auswahlmodus |
| Pillen | Glas-Kapsel mit X, „+“ | ÖPNV-Ebenen, Spuren im Verlauf |
| Dreier-Umschalter | Glas-Segment | Fortbewegung, Unterwegs |
| Tab-Kopf | großer Titel, Aktionen rechts, Suchfeld | Ziele, Kräfte, Mehr |
| Linienschild, Haltestellensymbol | wie an der Haltestelle | überall, wo ÖPNV vorkommt |
| Hinweis-Banner | oben, Farbe der Stufe | ganze App |

### 3.5 Bekannte Brüche (offen)

- Zwei Wege zum Schließen in Fenstern über der Karte (Kopfzeilen-X, früher Leiste unten) – mit 0.42 vereinheitlicht, im
  Neubau als feste Regel.
- Kartensymbole sind SwiftUI-Ansichten: Schatten, Beschriftung und Größe weichen von MapKits eigenen Symbolen ab und
  kollidieren nicht.
- Sentinel Web nutzt eigene Farben und Bausteine; nicht aus einer gemeinsamen Quelle.

---

## 4. Befund: Wo und warum es unsauber ist

### 4.1 Die Wurzel

Apples SwiftUI-Karte (`Map`) ist ein Anzeige-Baustein, keine Karten-Plattform:

- **Kamera**: SwiftUI-Kameraposition und Apples Verfolgung steuern mit; Apple setzt beim Verfolgen eigene Abstände.
  → 13 dokumentierte Versuche, am Ende eigene Gesten-Erkenner, die sich an eine im Ansichtsbaum gesuchte `MKMapView`
  hängen (0.42.1: genau dieses Suchen brach Zoomen und Plus-Menü).
- **Zeichnen**: Daten nur als einzelne Linien und SwiftUI-Ansichten (`Annotation`). Keine Ebenen, keine
  GPU-Symbole, keine Kollision, keine Farbverläufe mit fester Breite.
  → Spur aus hunderten Einzelstücken mit Zwischenspeicher; Symbole als Ansichten; eigenes Auseinanderrücken in drei
  Ansätzen; eigener Punkt vom Bildschirm gezeichnet; Beschriftungen mit acht versetzten Kopien als Rand.
- **Treffer**: Annotationen nehmen Tipps nur in ihrem Rahmen; Formen gar nicht.
  → Treffer-Erkennung an drei Stellen (`tapHitsSymbol`, `displacedSymbol`, `shapes(at:)`) mit eigener Geometrie.
- **Neuaufbau**: Jede Änderung baut den ganzen Kartenbildschirm neu.
  → eigene Uhren-Objekte je Ebene, Takt-Tricks gegen verlorene Antipper, Zoomstufen-Raster.

### 4.2 Behelfslösungen im Einzelnen

| Stelle | Behelf | Ursache | Im Neubau |
|---|---|---|---|
| `MapEngine.attachIfNeeded` | sucht die `MKMapView` im Ansichtsbaum | SwiftUI gibt die Karte nicht heraus | Engine besitzt ihre Kartenansicht direkt |
| Kamera | eigene Erkenner, Anzeige-Versatz für den Pfeil, Nachmessen je Bild | keine Kamera-API mit Innenabstand | Kamera mit `padding` (MapLibre), ein Controller |
| Eigener Punkt | vom Bildschirm gezeichnet, Apples Anzeige versteckt | Rückkopplung Kamera ↔ Apple-Punkt | Standort als eigene Ebene der Engine |
| Symbole | SwiftUI-Ansichten je Objekt | keine Symbolebenen | Symbolebene mit Bildatlas, Kollision |
| Auseinanderrücken | eigenes Raster, Spalten, Versatz, eigene Tipps | keine Kollision | Engine-Kollision + Spinnennetz-Auffächern als Ebene |
| Cluster | eigene Gruppierung je Zoomstufe | – | Cluster der Engine (Supercluster) |
| Treffer | drei eigene Prüfungen | Annotationen/Formen | `queryRenderedFeatures` an einer Stelle |
| Spur | hunderte Stücke, Zwischenspeicher, Endstück, Live-Ende | Verlauf ließ Breite springen | eine Linie mit `line-gradient`, Häufigkeit als Raster-/Heatmap-Ebene |
| ÖPNV-Takt | eigene Uhr je Ebene | Neuaufbau verliert Antipper | Datenquelle aktualisieren, kein Ansichtsneuaufbau |
| Flächenbeschriftung | acht Textkopien als Rand | – | Text mit Halo der Engine, entlang Linien |
| Navigation ohne Sonderrechte | Apples Route als Durchfahrtspunkte | Valhalla kennt keine Staus | Verkehr von TomTom (Flow) als Kosten bzw. Vorgabe |
| Straße am Standort | Server + Apples Umkehrsuche als Rückfall | – | bleibt (Server), Rückfall plattformneutral |
| Dienst/Standort | Prüfung hängt an der Ansicht (`RootView`) | – | Dienst-Steuerung im Kern, unabhängig von Ansichten (behebt „kommt nach Hochwischen wieder“) |
| Live-Aktivität | Kette gegen Wettlauf, Wiederherstellen beim Zurückkehren | – | bleibt im Kern sauber gekapselt |
| Kurzübersicht | Umgebungs-Brücke für Kopfzeilen-Aktionen | Fenster und Inhalt getrennt | einheitliches Fenster-Gerüst mit Aktionen |

### 4.3 Was sauber ist und bleibt

Server (Schema, Kommandos, Hub, Valhalla-, Transitous-, Tracker-Anbindung), WebSocket-Protokoll, Datenmodell,
ÖPNV-Fahrmodell (`TransitMotion`), Spur-Logik (Abschnitte, Lücken, Standzeiten), Suche-Logik (Hausnummer zuerst,
Kreuzungen), Ferrostar-Navigation, Live-Aktivität, Sicherheitsgrundsätze (Schlüsselbund, keine Bilder auf der Platte,
EXIF entfernen), Tests der Domäne.

---

## 5. Zielarchitektur

### 5.1 Überblick

```
┌───────────── iOS (SwiftUI, Liquid Glass) ─────────────┐   ┌──────── Android (Compose, Material 3 Expressive) ────────┐
│ Bildschirme, Fenster, Leisten                          │   │ Bildschirme, Bottom Sheets, Leisten                      │
│ Karten-Ansicht: MapLibre Native (iOS)                  │   │ Karten-Ansicht: MapLibre Native (Android)                │
└───────────────┬────────────────────────────────────────┘   └──────────────────┬──────────────────────────────────────┘
                │            gemeinsamer Kern (Kotlin Multiplatform)             │
                └──────► SentinelCore: Modell · Sync/WebSocket · Lage-Regeln ◄──┘
                         Karten-Szene (was wo gezeichnet wird) · Kamera-Logik
                         Spur · ÖPNV-Fahrmodell · Suche-Parser · Dienst/Standort-Zustand
                                              │
                           Sentinel-Server (bleibt) + Vektorkacheln + Valhalla
```

### 5.2 Karte: eine Engine, ein Kamera-Controller, nur Datenebenen

- **MapLibre Native** auf iOS und Android, MapLibre GL im Web (schon vorhanden). Gleicher Stil (JSON), gleiche
  Ebenen, gleiche Darstellung auf allen drei Plattformen.
- **Grundkarte**: eigene Vektorkacheln Deutschland (OpenStreetMap, z. B. Protomaps/OpenMapTiles als eine
  PMTiles-Datei, rund 3–5 GB) vom eigenen Server; keine Abhängigkeit von Apple oder Google, keine Daten an Dritte.
  Stil in drei Varianten: hell, dunkel (automatisch), Hybrid/Satellit (Luftbild braucht eine lizenzierte Quelle,
  siehe Entscheidungen). 3D-Gebäude als Extrusion; Gelände optional.
- **Kamera-Controller** (Logik im Kern, Ausführung je Plattform): einzige Stelle, die die Kamera setzt. Anheften,
  Folgen mit Vorausrechnung, Sollabstand/-winkel, Lösen durch Verschieben/Drehen, Kamerafahrten, Innenabstände für
  Leisten und Fenster (Punkt sitzt höher, ohne Versatz-Trick). Die heutigen Erkenntnisse (Schwellen, Fingerzähler,
  kein Setzen während Gesten) werden übernommen – nur ohne Ansichtsbaum-Suche.
- **Karten-Szene im Kern**: Aus dem Lagestand entstehen GeoJSON-Quellen (Kräfte, Fahrzeuge, Ziele, Marker, Formen,
  Spuren, ÖPNV, Weg-Zeit, Bestreifung). Die Plattform reicht sie nur an die Engine weiter. Jedes Objekt hat Kennung
  und Art als Eigenschaft.
- **Symbole** aus einem Bildatlas (abgerundetes Quadrat in Gruppenfarbe, Symbol, Name), gleiche Größe überall,
  Kollision und Beschriftungs-Platzierung durch die Engine, Cluster der Engine, Auffächern übereinanderliegender
  Punkte als eigene Ebene mit Linien zum echten Ort (stabil beim Zoomen, keine Ansichten).
- **Antippen an einer Stelle**: Tipp → Abfrage der gezeichneten Objekte unter dem Finger (sichtbar = antippbar,
  automatisch) → Reihenfolge Symbol vor Linie vor Fläche, kleinste Fläche zuerst, mehrfach tippen schaltet durch.
- **Spur**: eine Linie je Spur mit Farbverlauf entlang der Strecke (fester Breite), Häufigkeit über alle Fahnder als
  Raster-/Heatmap-Ebene – der „Pinsel“ ohne Abdunkeln an überlappenden Stellen.
- **Bewegte Objekte** (ÖPNV, eigener Punkt): Positionen aus dem Fahrmodell werden je Bild in die Quelle geschrieben;
  kein Neuaufbau der Oberfläche, kein Verlust von Antippern.
- **Apple-Extras auf iOS** bleiben möglich: Look Around (unabhängig von der Karte), Apple-Suche als zusätzliche Quelle.

### 5.3 Gemeinsamer Kern (Kotlin Multiplatform)

- Datenmodell und Prüfung (aus `schemas.ts` erzeugt bzw. gespiegelt), WebSocket-Protokoll, Wiederaufbau, Lagestand
  mit Ableitungen (Sichtbarkeit, Positionen von Zielen/Fahrzeugen, Ketten), Kommandos.
- Karten-Szene, Kamera-Logik, Treffer-Reihenfolge.
- Spur (Abschnitte, Lücken, Standzeiten, Häufigkeit), ÖPNV-Fahrmodell, Weg-Zeit-Aufbereitung.
- Suche-Parser (Hausnummer zuerst, Kreuzungen), Format (Zeiten, Entfernungen, deutsch).
- Dienst- und Standort-Zustand (im Dienst → Übertragung, Live-Aktivität; außer Dienst → alles aus, auch beim Start
  im Hintergrund).
- Navigation: Ferrostar hat Swift- und Kotlin-Anbindungen; Routenwahl-Logik (Vorlauf, Parallel, Halte voraus) im Kern.
- Tests einmal schreiben, auf beiden Plattformen laufen lassen.

### 5.4 Oberflächen

- **iOS**: SwiftUI, Liquid Glass, wie heute; Bausteine aus Abschnitt 3.4 als feste Komponenten-Bibliothek.
- **Android**: Jetpack Compose, Material 3 Expressive; dieselbe Aufteilung (Tabs unten, Karte mit Leisten, Fenster von
  unten), dieselben Abläufe und Wörter. Zuordnung siehe Abschnitt 7.2.
- **Gestaltungs-Grundwerte** (Farben, Maße, Abstände, Symbol-Zuordnung, Wörter) aus einer gemeinsamen Datei, aus der
  Swift-, Kotlin- und Web-Konstanten erzeugt werden.

### 5.5 Server und Web (bleiben, gezielt verbessern)

- Vektorkacheln und Glyphen/Sprites ausliefern (statt Web-Raster von tile.openstreetmap.org, dessen Nutzungsregeln
  produktiven Einsatz nicht vorsehen).
- Verkehrslage: TomTom Flow als Ebene und für die Routenwahl ohne Sonderrechte (ersetzt Apples Durchfahrtspunkte);
  ohne Schlüssel bleibt es bei Valhalla.
- `lage.ts` (1 200 Zeilen) nach Themen teilen; Schema als Quelle für App-Modelle.
- Web übernimmt Karten-Stil und Ebenen aus derselben Quelle wie die Apps.

---

## 6. Bewertung je Bereich

| Bereich | Heute | Urteil | Begründung |
|---|---|---|---|
| Karte (Anzeige, Ebenen, Symbole) | SwiftUI `Map` + Ansichten | **neu** | Wurzel der Behelfe, Voraussetzung für Android |
| Kamera | `MapEngine` an gesuchter `MKMapView` | **neu (Konzept übernehmen)** | Logik richtig, Anbindung zerbrechlich |
| Treffer/Antippen | drei Prüfungen | **neu** | eine Stelle über die Engine |
| Cluster/Auseinanderrücken | eigene | **neu** | Engine |
| Standortspur | Stücke | **neu** | Verlauf + Heatmap in der Engine |
| ÖPNV-Anzeige/Takt | Uhren je Ebene | **neu** | Quellen statt Neuaufbau |
| ÖPNV-Fahrmodell | `TransitMotion` | behalten (in den Kern) | sauber, getestet |
| Navigation (Ferrostar, Routenwahl) | Swift | aufräumen (Kern) | Verkehr sauber über TomTom |
| Suche | Apple + Server | aufräumen | Parser in den Kern, Apple-Suche nur iOS-Zusatz |
| Datenmodell, Sync, LageStore | Swift | **in den Kern übertragen** | für beide Plattformen |
| Dienst/Standort/Live-Aktivität | an Ansichten gebunden | **neu (Kern)** | Hintergrund-Fehler |
| Listen, Editoren, Ziele, Kräfte, Verwaltung | SwiftUI | behalten, an Kern anschließen | sauber, wenige Behelfe |
| Fenster über der Karte (Kurzübersicht, Karten) | gemischt | aufräumen | ein Fenster-Gerüst |
| Server | TypeScript | behalten, aufräumen | solide, getestet |
| Sentinel Web | Preact + MapLibre | behalten, Stil/Ebenen angleichen | nutzt schon die Ziel-Engine |
| Tests | Domäne, 2 UI-Tests | ausbauen | Gleichstand absichern |

---

## 7. Android

### 7.1 Ziel

Gleicher Funktionsumfang wie iOS, gleiche Aufteilung und Abläufe, Optik Material 3 Expressive. Verteilung als APK
(kein Play Store nötig): Download über die eigene Server-Seite (wie die SideStore-Quelle), Aktualisierung über die
App selbst oder Obtainium.

### 7.2 Zuordnung der Bausteine

| iOS (Liquid Glass) | Android (Material 3 Expressive) |
|---|---|
| Schwebende Tableiste | Navigation Bar (unten) bzw. Floating Toolbar |
| Runder Glasknopf am Kartenrand | Small FAB / Icon Button (tonal) |
| Plus-Knopf hervorgehoben | FAB bzw. FAB-Menü (Expressive) |
| Glas-Suchleiste | Search Bar (Material) |
| Gelbe Setzen-Leiste | Tonale Leiste (Tertiary Container) mit Aktionen |
| Kurzübersicht (Fenster von unten, Stufen) | Standard Bottom Sheet mit Ankerpunkten |
| Fenster/Sheets | Modal Bottom Sheet bzw. Vollbild-Dialog |
| Glas-Segment (Dreier-Umschalter) | Segmented Button / Connected Button Group |
| Pillen | Input Chips / Filter Chips |
| Kapsel-Knöpfe | Filled/Tonal/Outlined Buttons |
| Listen (gruppiert) | Lists mit Sections |
| Hinweis-Banner | Snackbar bzw. eigenes Banner oben |
| Live-Aktivität (Dynamic Island) | Laufende Benachrichtigung des Vordergrund-Dienstes (Standort) |
| Face ID/Touch ID | BiometricPrompt |
| Schlüsselbund | Android Keystore |
| Look Around | entfällt (Alternative: Mapillary, optional) |

### 7.3 Plattform-Besonderheiten

- Standort im Hintergrund: Vordergrund-Dienst mit Benachrichtigung (ersetzt Live-Aktivität), endet außer Dienst.
- Spracheingabe: Android SpeechRecognizer (auf dem Gerät, wo verfügbar).
- Kritischer SOS-Alarm: auf Android über einen Benachrichtigungskanal mit Alarm-Audio möglich (ohne Apple-Antrag).

### 7.4 Testen ohne Android-Gerät

- **Emulator auf dem Windows-Tablet**: Android Studio mit Emulator (x86-64-Tablets mit aktivierter Hardware-
  Virtualisierung; auf ARM-Tablets wie Surface Pro X mit ARM64-Systemabbildern). Die APK wird per Ziehen und Ablegen
  installiert.
- **Automatisch in der Pipeline**: Android-Emulator auf GitHub Actions mit denselben Abläufen wie Rundgang- und
  Kamera-Test (Bildschirmfotos und Video als Artefakt).
- Optional echte Geräte in der Cloud (z. B. Firebase Test Lab), falls gewünscht.

---

## 8. Vorgehen

Jede Phase endet mit einer lauffähigen Version; die heutige iOS-App bleibt bis zur Ablösung im Einsatz.

| Phase | Inhalt | Ergebnis |
|---|---|---|
| 0 | Entscheidungen (Abschnitt 9), Kacheln Deutschland auf dem NAS, Stil hell/dunkel | Grundkarte im Web und auf Testgeräten |
| 1 | Kern (KMP): Modell, Sync, Lagestand, Dienst/Standort, Tests | gleiche Daten auf iOS und Android |
| 2 | Karte neu (iOS zuerst): MapLibre-Ansicht, Kamera-Controller, Szene, Symbole, Antippen, Cluster, Auffächern | neue Lagekarte, Kamera-Test grün |
| 3 | Ebenen: Formen, Spur (Verlauf/Heatmap), ÖPNV, Weg-Zeit, Bestreifung, Setzen-Modus, Suche | Kartenfunktionen vollständig |
| 4 | Navigation auf neuer Karte (Ferrostar, Verkehr) | Navigation vollständig |
| 5 | iOS-Bildschirme an den Kern (Ziele, Kräfte, Verwaltung, Verlauf, Instanzen) | iOS-Gleichstand → Ablösung der alten App |
| 6 | Android-Oberfläche (Compose, Material 3 Expressive) auf demselben Kern | Android-APK mit Gleichstand |
| 7 | Web an Stil und Ebenen angleichen | eine Optik auf allen Plattformen |

Absicherung: Abschnitte 2 und 3 als Abnahmeliste, UI-Abläufe (Rundgang, Kamera, Antippen übereinanderliegender
Symbole, ÖPNV, Spur, Dienst/Hintergrund) für iOS und Android in der Pipeline.

Risiken: Umfang (größter Brocken ist die Karte), Aussehen der eigenen Grundkarte gegenüber Apple Karten (Stilarbeit),
Luftbild-Lizenz, Gewöhnung an das andere Kartenbild.

---

## 9. Entscheidungen

1. **Grundkarte**: eigene OSM-Vektorkacheln auf dem NAS (empfohlen, unabhängig, kostenlos) oder ein Anbieter
   (MapTiler o. ä., Schlüssel, laufende Kosten). Apples Kartenbild entfällt in beiden Fällen.
2. **Luftbild/Hybrid**: weglassen, kostenlose amtliche Quellen (z. B. Landesvermessung, regional unterschiedlich) oder
   ein Anbieter mit Schlüssel.
3. **Gemeinsamer Kern**: Kotlin Multiplatform (empfohlen) oder zwei getrennte Codebasen mit gemeinsamer Spezifikation.
4. **Reihenfolge**: iOS-Karte zuerst neu und dann Android (empfohlen), oder beide parallel.
5. **Verkehrslage**: TomTom-Schlüssel hinterlegen (Verkehr auf der Karte und in der Routenwahl) oder vorerst ohne.
6. **Chat**: im Neubau mitnehmen (ausgeblendet) oder vorerst weglassen.

---

## Anhang: Lehren, die in den Neubau gehören

- Eine einzige Stelle bewegt die Kamera; nie während einer Geste setzen; keine langen Kamerafahrten in der Nachführung.
- Gesten selbst erkennen, nicht aus Kamerawerten erraten; Fingerzähler; Lösen nur durch Verschieben (> 30 pt) oder
  Drehen (> 10°), Zoomen und Kippen lösen nie.
- Was gezeichnet wird, ist antippbar – und nur das; Zeichnen und Treffer aus denselben Daten.
- Bewegte Objekte aus einem Fahrmodell, nicht aus Sprüngen zwischen Meldungen.
- Eigene Spur aus den GPS-Punkten des Geräts; Server nur für davor und für andere.
- Dienststatus steuert Standort und Anzeigen zentral, unabhängig von Ansichten und auch beim Start im Hintergrund.
- Gleiche Funktion im gleichen Kontext sieht gleich aus; Bausteine statt Einzelanfertigungen.
