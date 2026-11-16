# Offene Punkte

Wünsche und Ideen werden hier gesammelt und zu festen Zeitpunkten gebündelt umgesetzt,
statt jede Änderung sofort einzubauen. Erledigtes wandert mit Version ins CHANGELOG.

## Geplant

### Runde nach 0.6.0 (Rückmeldung vom 16.11.)
**ÖPNV-Darstellung**
- Echte HVV-Symbole für Bus, Regionalbahn, S-Bahn, U-Bahn (Form und Farben recherchieren).
- Ein einheitliches Haltestellen-Symbol überall: Haltestellen im Umkreis, ÖPNV-Linie, ÖPNV-Fahrzeug,
  Überschlagen/A im ÖPNV.
- Strecke zwischen den Halten als tatsächlicher Fahrweg (Straße/Gleis aus den OSM-Wegen der Linie),
  in der offiziellen Linienfarbe.
- Linie und Fahrzeug anlegen: neben Antippen auch per Texteingabe suchen (z. B. „369“),
  Treffer nach aktuellem Kartenausschnitt sortiert.

**Karte und Bedienelemente**
- Dreier-Auswahl Fortbewegung im selben Liquid-Glass-Look wie die Tab-Leiste (nur schmaler).
- SOS-Knopf in Liquid Glass, der weiße Ring beim Gedrückthalten bleibt.
- Kompassknopf wie nativ: Norden = Pfeil mit „N“; Kurs = natives Kompass-Symbol mit Strichen und rotem N;
  fest = gedreht. Bei Kurs muss sich die Karte mit dem Gerätekompass drehen (tut sie nicht).
- Fahrmodus: eigenes Symbol verschwindet manchmal (Fehler); Navi-Pfeil flach auf der Karte liegend statt zum Bildschirm.
- 3D-Synchronisation in beide Richtungen: Zwei-Finger-Kippen setzt den Haken und darf nicht zurückspringen.
- Sonderrechts-Navigation: Route immer rot (derzeit nicht).
- Hinweise oben flach ohne Farbverlauf.
- Navigation: Namen der nächsten Querstraßen als kleine Marker; Spracheingabe für das Ziel (natürliche Sprache).
- Beim Navigieren weiterhin die Dreier-Auswahl Auto/zu Fuß/ÖPNV zeigen statt im Drei-Punkte-Menü; ÖPNV-Navigation ergänzen.

**Suche und Anlegen**
- Suchtreffer: keine Sprechblase mehr. Antippen springt mit der Karte hin, unten kleines Feld mit
  „Hierhin navigieren“ und „Hier anlegen“ (wie Apple/Google Maps).
- Standort setzen (Plus-Menü, Ziel „Standort neu setzen“): wahlweise antippen oder über die Suche.

**Fehler**
- Sehr breites Foto in der Fotoliste sprengt die Kachel und lässt sich nicht mehr entfernen.

**Mehr**
- Knopf „Lage zurücksetzen“ unter Mehr (dauerhafte Orte bleiben).

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
