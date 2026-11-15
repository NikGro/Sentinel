# Betrieb

## Bereitstellung (Docker, z. B. Synology)

```bash
docker network create sentinel            # einmalig
cd deploy
cp .env.example .env                      # Werte eintragen, Datei mit chmod 600 schützen
mkdir -p data && chown 10001:10001 data
docker compose up -d --build
```

Beim ersten Start entsteht `data/ERSTZUGANG.txt` mit dem Verwaltungspasswort der Kommandozentrale und dem
Zugangscode für Fahnder. Beides nach der ersten Anmeldung unter *System* ändern, die Datei löschen.

Davor gehört ein Reverse Proxy mit TLS, der auf `127.0.0.1:8790` weiterleitet und WebSockets durchreicht
(Kopfzeilen `Upgrade` und `Connection`). Für lange Verbindungen die Lese-Zeitüberschreitung hoch setzen (3600 s).

### Weg-Zeit-Berechnung auf dem Wegenetz (optional)

```bash
cd deploy/valhalla && docker compose up -d   # lädt Kartendaten und baut das Wegenetz (dauert)
```

Ohne Valhalla rechnet der Server mit dem Näherungsmodell. Der Kartenausschnitt steht in `tile_urls`.

### Apple Maps in der Kommandozentrale (optional)

Die iPhone-App nutzt Apple Maps von Haus aus. Im Browser verlangt Apple einen MapKit-JS-Schlüssel, den es nur
mit Mitgliedschaft im Apple Developer Program gibt. Ohne Schlüssel zeigt die Kommandozentrale OpenStreetMap.

1. Im Apple-Entwicklerkonto unter *Certificates, Identifiers & Profiles* → *Keys* einen Schlüssel mit *MapKit JS*
   anlegen und die `.p8`-Datei laden. Key-ID und Team-ID notieren.
2. Datei als `deploy/data/AuthKey.p8` ablegen (`chown 10001:10001`, `chmod 600`).
3. In `deploy/.env` `SENTINEL_MAPKIT_TEAM_ID`, `SENTINEL_MAPKIT_KEY_ID` und `SENTINEL_MAPKIT_KEY_FILE=/data/AuthKey.p8` setzen.
4. `docker compose up -d`. Unter *System* steht danach „Karte: Apple Maps“.

Der private Schlüssel bleibt auf dem Server. Der Browser erhält nur Tokens mit 30 Minuten Laufzeit, die an die eigene
Adresse gebunden sind. Ist Apple nicht erreichbar, fällt die Anzeige auf OpenStreetMap zurück.
Hinweis: Diese Anbindung ist ohne Schlüssel entstanden und deshalb noch nicht gegen Apple erprobt.

### Tracker

Für SinoTrack muss TCP-Port 5013 vom Router auf den Server weitergeleitet sein. Siehe [TRACKER.md](TRACKER.md).

## App-Verteilung über SideStore

Der Server stellt unter `/sidestore/source.json` eine SideStore-Quelle bereit. Neue Versionen lädt die Pipeline
(`.github/workflows/ios.yml`) hoch, wenn im Repository das Secret `SENTINEL_DEPLOY_TOKEN` gesetzt ist (derselbe
Wert wie in `deploy/.env`) und auf `main` gebaut oder der Lauf von Hand gestartet wird. Die Serveradresse lässt
sich über die Repository-Variable `SENTINEL_URL` ändern.

Von Hand:

```bash
curl -X POST "https://<server>/api/v1/deploy/release?version=0.1.0&build=1" \
  -H "Authorization: Bearer <Deploy-Token>" -H "Content-Type: application/octet-stream" \
  --data-binary @Sentinel.ipa
```

## Sicherung

Alles Wichtige liegt in `deploy/data` (`sentinel.sqlite` samt `-wal`, `releases/`). Für eine saubere Kopie im
laufenden Betrieb: `sqlite3 sentinel.sqlite ".backup sicherung.sqlite"` oder den Container kurz anhalten.
In der Kommandozentrale lässt sich die Lage zusätzlich als JSON sichern (*Lage* → *Lage vorher sichern*).

## Aktualisieren

```bash
git pull && cd deploy && docker compose up -d --build
```

Das Datenbankschema wird beim Start automatisch fortgeschrieben.
