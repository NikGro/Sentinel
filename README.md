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
Projekte, in denen man sich verirren kann. Vorbereitetes entsteht als *Paket* (Entwurfs-Ebene) in der
Kommandozentrale und wird bei Bedarf in die Lage geladen. Ebenen lassen sich je Gerät ein- und ausblenden.

**Drei Modi, ein Umschalter.** Der Modus gilt für alle und wechselt ohne Datenverlust.

| Modus | Besonderheiten |
| --- | --- |
| Observation | A-Position (Übernahme mit zweitem Druck zur Bestätigung), dynamische Routenführung zur A |
| Fahndung | Bestreifung (wo war wer schon), letzter bekannter Standort, Weg-Zeit-Flächen für Fuß, Kfz und ÖPNV |
| Oberfläche | nur Kräfte, Markierungen und Ebenen (z. B. Argus-Predict-Prognose) |

Beim Wechsel von Observation zu Fahndung wird die A-Position zum letzten bekannten Standort; beim Rückwechsel
bleiben Standort und Bestreifung gespeichert. Hängt an der Zielperson ein Tracker, führt er den Standort nach.

**Weitere Funktionen**

- Profile (Name, Funkrufname mit Formatprüfung, Dienststelle, Bild, Handynummer), Anruf aus der Schnellübersicht
- Fahrzeuge als eigene Objekte mit Ein- und Aussteigen, optional mit GPS-Tracker
- Zielpersonen mit Bild, Personalien, Fahrzeug, Sachverhalt, Hinweisen, Maßnahmen und optionalem Tracker
- Marker, Beschriftungen, Linien, Flächen und Kreise; jeder bearbeitet alles, eigene Schritte sind rückgängig zu machen
- Lageleiste mit Modus, Funkkanal (1 bis 5 Ziffern), A-Position und Verbindungszustand in jeder Ansicht
- Chat, GPS-Tracker (SinoTrack direkt ohne Hersteller-Server, PAJ über das PAJ-Portal), Import aus Argus Predict
- Kommandozentrale im Browser: Lage führen, Pakete vorplanen, Geräte und Tracker verwalten

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
- ÖPNV in der Weg-Zeit-Berechnung ist ein Näherungsmodell; Fuß und Kfz rechnen auf dem echten Wegenetz (bis 120 bzw. 40 Minuten, danach Näherung).
- Die PAJ-Anbindung folgt der öffentlichen Schnittstellenbeschreibung und ist noch nicht mit echten Geräten erprobt.
- iOS gibt Apps die eigene Rufnummer nicht preis. Die Nummer wird deshalb aus der eigenen Kontaktkarte übernommen.
- Apple Maps in der Kommandozentrale ist vorbereitet, aber mangels Schlüssel noch nicht gegen Apple erprobt; bis dahin läuft OpenStreetMap.
- Noch offen: Telefonkonferenz, Phantombild per KI auf dem Gerät, eigene Tracker-Firmware.
