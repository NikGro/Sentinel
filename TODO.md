# Offene Punkte

Wünsche und Ideen werden hier gesammelt und zu festen Zeitpunkten gebündelt umgesetzt,
statt jede Änderung sofort einzubauen. Erledigtes wandert mit Version ins CHANGELOG.

## Geplant

### Offen aus der Runde nach 0.6.0
- **Querstraßen in der Navigation:** Valhalla liefert die Namen kreuzender Straßen nicht mit; braucht eigene
  Abfrage der Kreuzungen entlang der Route (OSM). Noch nicht umgesetzt.
- **ÖPNV-Navigation in der App:** derzeit Ankunft über Apple Karten und Übergabe dorthin; eigene Führung erst
  mit Fahrplänen (siehe ÖPNV unten).
- **Lage zurücksetzen:** gibt es unter Mehr → Einsatz („Funkkanal, Einsatzinfos, Lage zurücksetzen“).

### Tracker
- **PAJ-Tracker mit eigenem Konto je Tracker:** Beim Hinzufügen nicht nur die Geräte-ID, sondern einmalig
  E-Mail und Passwort des PAJ-Kontos angeben, dem das Gerät gehört (jeder Fahnder hat sein eigenes Konto).
  Zugangsdaten nur für diesen Tracker speichern, nicht global in Sentinel. Beim Anlegen prüfen, ob die ID
  wirklich zu diesem Konto gehört, sonst „Gerät nicht in diesem Konto“ anzeigen.
- **SinoTrack „Test“ (7026222172) sendet nicht:** Portweiterleitung TCP 5013 im Router zur Synology und die
  SMS-Einrichtung des Geräts (öffentliche Adresse, Port 5013, Protokoll H02) prüfen.

### ÖPNV
- **Echte Fahrpläne statt Schätzung:** offene HVV-Fahrpläne (GTFS, Hamburger Transparenzportal) auf dem
  Server einlesen, echte Abfahrten zur Auswahl anbieten, Fahrzeugpositionen nach Fahrplan setzen.
- **Echtzeit, wo vorhanden:** Verspätungen aus GTFS-Realtime (DELFI / gtfs.de) einrechnen.
  geOps wird bewusst nicht genutzt (kostenfrei nur für Tests).

### Offen aus früheren Runden
- **Buslinien-Symbole:** Screenshot nötig, wo die „roten Diamanten“ erscheinen, und wie es bei der HVV aussieht.
- **Auf dem Gerät prüfen:** Ferrostar-Navigation, Fahrzeug-Symbol nach dem Aussteigen, Fotoliste, Standort-Menü.
- **Kommandozentrale:** Lebensdauer und weitere Fotos auch dort bearbeitbar machen.
