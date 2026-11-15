# SENTINEL

Einsatzwerkzeug für Zivilfahnder: gemeinsame Lagekarte für Observation und Fahndung.

| Baustein | Ort | Technik |
| --- | --- | --- |
| iOS-App | [`ios/`](ios) | SwiftUI, MapKit, iOS 26+, keine Fremdbibliotheken |
| Lageserver | [`server/`](server) | Node.js 24, TypeScript, Fastify, SQLite |
| Kommandozentrale (Web) | [`server/web/`](server/web) | Preact, Apple Maps (MapKit JS) oder OpenStreetMap (MapLibre) |
| Bereitstellung | [`deploy/`](deploy) | Docker Compose, optional Valhalla für die Weg-Zeit-Berechnung |

Weiterführend: [Architektur](docs/ARCHITEKTUR.md) · [Sicherheit](docs/SICHERHEIT.md) · [Betrieb](docs/BETRIEB.md) · [Tracker](docs/TRACKER.md)

## Funktionen

**Eine Lage für alle.** Wer am Server angemeldet ist, arbeitet immer in derselben laufenden Lage. Es gibt keine
Projekte und keine Modi. Vorbereitetes entsteht als *Paket* (Entwurfs-Ebene) und wird bei Bedarf in die Lage geladen.
Ebenen lassen sich je Gerät ein- und ausblenden.

**Kräfte.** Fahnder legen sich in der App selbst an (Spitzname, Dienststelle, Bild, Handynummer) und schalten sich in
den Ruhemodus. Ihre Fortbewegung wählen sie selbst: zu Fuß, in einem Fahrzeug der eigenen Kräfte oder im ÖPNV mit
Linie und Richtung. Fahrzeuge bleiben dauerhaft angelegt (Funkrufname, Kennzeichen, Bild, Tracker), jeder schaltet sie
für den Einsatz ein. Auf der Karte heißt ein Fahnder zu Fuß wie sein Spitzname, im Fahrzeug wie dessen Funkrufname.

**Karte und Navigation.** Navi-Ansicht mit nächstem Manöver, Ankunftszeit und Schalter für Sonderrechte (Einbahnstraßen
und Abbiegeverbote werden ignoriert, Poller nicht). Suche nach Adressen und Kreuzungen („A / B“) oder nach Objekten der
Lage; bewegt sich das Ziel, folgt die Route. Die A-Position steht dabei immer oben. Fährt die A im ÖPNV, fahren
Teilnehmer die kommenden Haltestellen überschlagend an. Unter dem eigenen Standort stehen Straße und Fahrtrichtung.

**Kartenelemente** über das Plus: Fahndungsraum (Weg-Zeit-Flächen zu Fuß, ÖPNV und Kfz ab einem Zeitpunkt),
Zielperson, Zielfahrzeug, Zielobjekt (mit Look-Around-Vorschau), Marker, Beschriftung, Linie, Fläche, Kreis. Ziele und
Marker können einem GPS-Tracker folgen.

**Weiteres:** Bestreifung (immer aufgezeichnet, je Nutzer einblendbar), Chaträume mit Fotos, Dateien und
Sprachnachrichten, GPS-Tracker (SinoTrack direkt, PAJ über das Portal), Argus-Predict-Import, gesperrte Ebene für
dauerhafte Orte, Kommandozentrale im Browser. Alle Einstellungen sind auch in der App erreichbar.

## Installation der App über SideStore

1. In SideStore unter *Quellen* hinzufügen: `https://<server>/sidestore/source.json`
2. SENTINEL installieren, Serveradresse und Zugangscode eingeben, Profil anlegen.

Die Build-Pipeline erzeugt bei jedem Stand eine unsignierte IPA; SideStore signiert sie mit der eigenen Apple-ID.
Einzelheiten in [docs/BETRIEB.md](docs/BETRIEB.md).

## Entwicklung

```bash
# Server und Kommandozentrale
cd server && npm ci && npm ci --prefix web
npm test                 # Tests
npm run dev              # Server auf http://127.0.0.1:8790 (Zugangsdaten: data/ERSTZUGANG.txt)
npm --prefix web run dev # Kommandozentrale mit automatischem Neuladen auf http://127.0.0.1:5173

# iOS (macOS mit aktuellem Xcode)
brew install xcodegen
cd ios && xcodegen generate && open Sentinel.xcodeproj
```

## Stand und bekannte Grenzen

- Die App ist bislang durch Kompilieren und Tests der Fachlogik in der Pipeline geprüft, noch nicht im Einsatz auf Geräten.
- ÖPNV in der Weg-Zeit-Berechnung (Fahndungsraum) ist ein Näherungsmodell; Fuß und Kfz rechnen auf dem echten Wegenetz (bis 120 bzw. 40 Minuten, danach Näherung).
- Die PAJ-Anbindung folgt der öffentlichen Schnittstellenbeschreibung und ist noch nicht mit echten Geräten erprobt.
- iOS gibt Apps die eigene Rufnummer nicht preis. Die Nummer wird deshalb aus der eigenen Kontaktkarte übernommen.
- Apple Maps in der Kommandozentrale ist vorbereitet, aber mangels Schlüssel noch nicht gegen Apple erprobt; bis dahin läuft OpenStreetMap.
- ÖPNV-Linien und Kreuzungssuche stammen aus OpenStreetMap (Overpass-API); Fahrpläne und Verspätungen fließen nicht ein.
- Eine Google-Ortssuche ist nicht eingebunden; dafür wäre ein kostenpflichtiger Google-Schlüssel nötig. Gesucht wird über Apple Karten.
- Das Sendeintervall wird an SinoTrack-Geräte mit dem H02-Befehl S71 geschickt; ob ein Modell ihn umsetzt, ist nicht geprüft.
- Noch offen: Projekte, Telefonkonferenz, Phantombild per KI auf dem Gerät, eigene Tracker-Firmware.
