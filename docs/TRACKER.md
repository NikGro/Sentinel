# GPS-Tracker

Tracker werden in der Kommandozentrale unter *Tracker* angelegt und anschließend einer Zielperson oder einem
Fahrzeug zugeordnet. Im Fahndungsmodus führt ein Tracker an der Zielperson den letzten bekannten Standort nach.

## SinoTrack (ST-901, ST-903 und baugleiche Geräte mit H02-Protokoll)

Die Tracker senden direkt an den Sentinel-Server. Der Server des Herstellers ist nicht beteiligt.

1. Router: TCP-Port 5013 auf den Server weiterleiten. Im Tracker wird der Domainname eingetragen, nicht die
   IP-Adresse; eine Portfreigabe ersetzt das aber nicht (siehe unten).
2. SIM mit Datentarif einlegen, dann per SMS an die Nummer der SIM (Standardpasswort `0000`):

   | SMS | Wirkung |
   | --- | --- |
   | `8040000 sentinel.example.org 5013` | Zielserver und Port |
   | `8030000 <APN>` | Zugangspunkt des Mobilfunkanbieters, z. B. `internet` |
   | `8050000 20` | Sendeintervall in Sekunden |
   | `RCONF` | zeigt die aktuelle Einstellung |

3. Sobald sich der Tracker meldet, erscheint seine Kennung in der Kommandozentrale unter *Unbekannte Tracker*
   und lässt sich mit einem Klick übernehmen.

Hinweise: Das Protokoll ist unverschlüsselt und kennt keine Anmeldung. Der Server nimmt nur Positionen bekannter
Kennungen an und begrenzt Verbindungen und Nachrichtengröße. Das Standardpasswort des Trackers sollte geändert werden
(`777<neu><alt>`), damit niemand per SMS den Zielserver umstellt.

### Warum ein Domainname die Portfreigabe nicht ersetzt

Die Tracker sprechen kein HTTP, sondern senden rohe TCP-Daten. Ein DNS-Eintrag (auch ein CNAME) sagt dem Tracker
nur, unter welcher Adresse der Server zu finden ist. Erreichen muss er ihn weiterhin über einen Port, den der
Router durchlässt. Der Reverse Proxy für die Weboberfläche (Port 443) versteht nur HTTPS und kann das
Tracker-Protokoll nicht annehmen.

Wer keinen weiteren Port öffnen möchte, hat zwei Möglichkeiten:

- Ein Protokollweiche vor Port 443 (z. B. `sslh` oder HAProxy), die TLS an den Webserver und alles andere an
  Port 5013 reicht. Das greift in den Zugang aller übrigen Dienste auf dem Server ein und will geplant sein.
- Ein kleiner Mietserver als Relais, der die Trackerdaten annimmt und über eine ausgehende, verschlüsselte
  Verbindung an Sentinel weitergibt. Dann ist zu Hause gar kein Tracker-Port offen.

## PAJ

PAJ-Geräte melden sich ausschließlich beim Hersteller. Sentinel holt dort alle 20 Sekunden die letzte Position ab.
Dazu in der Kommandozentrale unter *Tracker* → *PAJ-Portal* die Zugangsdaten des PAJ-Kontos hinterlegen
(sie werden verschlüsselt gespeichert), *Geräte abrufen* und die gewünschten Geräte übernehmen.

Diese Anbindung ist nach der öffentlichen Schnittstellenbeschreibung umgesetzt und noch nicht mit echten Geräten erprobt.

## Eigene Firmware

Ein eigener Tracker muss nur das H02-Textformat sprechen, dann ist auf dem Server nichts zu ändern:

```
*HQ,<Kennung>,V1,<HHMMSS>,A,<DDMM.MMMM>,<N|S>,<DDDMM.MMMM>,<E|W>,<Knoten>,<Kurs>,<DDMMYY>,<Status>#
```

Zeit und Datum in UTC. Weitere Anbieter lassen sich in `server/src/trackers/` ergänzen; sie rufen lediglich
`lage.reportTrackerPosition(anbieter, kennung, position)` auf.
