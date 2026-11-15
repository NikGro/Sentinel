# Architektur

```
 iPhone (SwiftUI)  ──┐                      ┌── SinoTrack-Tracker (H02 über TCP 5013)
 iPhone (SwiftUI)  ──┼─ HTTPS / WebSocket ──┤
 Kommandozentrale  ──┘   Reverse Proxy      ├── PAJ-Portal (Abruf alle 20 s)
                              │             ├── Valhalla (Wegenetz, nur intern)
                        Sentinel-Server ────┴── Argus Predict (Datenordner, nur lesend)
                              │
                           SQLite
```

## Grundsätze

- **Der Server ist die einzige Quelle der Wahrheit.** Clients schicken Änderungswünsche, der Server prüft sie gegen
  das Schema (`server/src/schemas.ts`), speichert und verteilt das Ergebnis an alle. Auch der Absender übernimmt
  erst die Antwort des Servers.
- **Eine Lage je Server** (`server/src/lage.ts`). Vorbereitete Inhalte sind Ebenen im Status `entwurf`; sie werden
  nur an die Kommandozentrale verteilt, bis sie geladen werden.
- **Objekte und Kommandos.** Gemeinsame Objekte (Profil, Fahrzeug, Markierung, Zielperson, Tracker, Ebene, Nachricht)
  werden als Ganzes geschrieben, es gilt der letzte Stand. Alles mit Fachlogik (Moduswechsel, A-Position,
  Ein-/Aussteigen, letzter Standort, Zurücksetzen) läuft über Kommandos, die nur der Server ausführt.
- **Rückgängig/Wiederholen** führt jeder Client für die eigenen Schritte an Markierungen (`UndoStack`).

## Server (`server/src`)

| Datei | Aufgabe |
| --- | --- |
| `schemas.ts` | Datenmodell und Eingabeprüfung |
| `lage.ts` | Fachlogik der Lage, Moduswechsel, Bestreifung |
| `hub.ts` | WebSocket-Verteiler, Sichtbarkeit von Entwürfen |
| `auth.ts`, `security.ts` | Geräte, Sitzungen, Hashes, Ratenbegrenzung, Tresor |
| `http/` | Routen: öffentlich, Geräte, Kommandozentrale |
| `reach/reach.ts` | Weg-Zeit-Flächen (Valhalla, sonst Näherungsmodell) |
| `trackers/` | H02-Empfang (SinoTrack), PAJ-Abruf |
| `argus.ts` | Import von Argus-Predict-Prognosen |
| `release.ts` | App-Versionen und SideStore-Quelle |

### Protokoll (WebSocket `/api/v1/ws`, JSON)

Client → Server: `put {kind,id,data}`, `del {kind,id}`, `pos {p}`, `cmd {name,args}`, `ping`
Server → Client: `snapshot`, `put`, `del`, `operation`, `pos`, `tpos`, `online`, `bestreifungReset`, `ack`, `err`

## iOS-App (`ios/Sentinel`)

| Ordner | Inhalt |
| --- | --- |
| `App/` | Einstieg, Zusammenbau der Dienste (`AppModel`), Hauptnavigation |
| `Core/Domain` | Datenmodell, Funkrufname, Rückgängig-Verlauf (reine Logik, getestet) |
| `Core/Networking` | HTTP-Zugriff, WebSocket mit Wiederaufbau, Protokoll |
| `Core/Persistence` | Schlüsselbund, Geräteeinstellungen |
| `Core/Services` | Lage (`LageStore`), Standort, Fotos, Routenführung, Fahndungsdaten, App-Sperre |
| `Features/` | Ansichten je Bereich: Karte, Ziele, Team, Chat, Lageübersicht, Einstellungen |
| `Shared/` | Wiederverwendete Bausteine und Gestaltung |

Die Ansichten lesen ausschließlich aus beobachtbaren Diensten (`@Observable`) und rufen deren Methoden auf.
Navigation: fünf Tabs (Lage, Ziele, Team, Chat, Mehr), darüber die Lageleiste als Tab-Zubehör.
