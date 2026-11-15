# Sicherheit

## Transport und Zugang

- Ausschließlich TLS. Die App lehnt unverschlüsselte Serveradressen ab (ATS ohne Ausnahmen), der Proxy setzt HSTS.
- Geräte melden sich einmalig mit dem Zugangscode an und erhalten ein zufälliges Geräte-Token (256 Bit).
  Der Server speichert nur dessen SHA-256. Geräte lassen sich in der Kommandozentrale einzeln sperren; die
  Verbindung wird sofort getrennt, die App entfernt daraufhin alle Daten vom Gerät.
- Kommandozentrale: Passwort (scrypt), Sitzung als Cookie mit `HttpOnly`, `Secure`, `SameSite=Strict`, zwölf Stunden
  gültig. Jede Anfrage mit Cookie muss nachweislich von der eigenen Adresse stammen (Origin-Prüfung).
- Ratenbegrenzung für Anmeldung, Geräteanmeldung, Uploads, Weg-Zeit-Berechnung und je WebSocket-Verbindung.

## Server

- Jede Eingabe wird gegen ein Schema geprüft, unbekannte Felder werden verworfen, Längen sind begrenzt.
- Bilder: Typ wird aus dem Inhalt bestimmt, Abruf nur angemeldet.
- Strenge Kopfzeilen (CSP, `frame-ancestors 'none'`, `nosniff`, kein Referrer), API-Antworten ohne Zwischenspeicherung.
- Container: unprivilegierter Benutzer, schreibgeschütztes Dateisystem, keine Capabilities, `no-new-privileges`.
  Weboberfläche und API lauschen nur lokal hinter dem Reverse Proxy. Valhalla ist nur im internen Netz erreichbar.
- Zugangsdaten Dritter (PAJ) liegen AES-256-GCM-verschlüsselt in der Datenbank.
- Protokoll sicherheitsrelevanter Vorgänge (Anmeldungen, Sperren, Kommandos, Importe).
- Keine Geheimnisse im Repository. Die Pipeline prüft Abhängigkeiten auf bekannte Schwachstellen.

## App

- Token im Schlüsselbund (`AfterFirstUnlockThisDeviceOnly`), kein Abgleich über iCloud oder Backups.
- Keine Fremdbibliotheken, keine Analyse- oder Werbedienste.
- Netzwerkzugriffe ohne Plattencache und ohne Cookies; Bilder liegen nur im Arbeitsspeicher.
- Fotos werden vor dem Hochladen neu gezeichnet: Metadaten einschließlich Aufnahmeort gehen dabei verloren.
- Optionale App-Sperre (Face ID, Touch ID, Gerätecode); im App-Umschalter sind nie Einsatzdaten zu sehen.

## Bewusste Grenzen

- Daten liegen auf dem Server im Klartext in SQLite (Dateirechte 600). Schutz der Platte ist Sache des Betreibers
  (verschlüsseltes Volume empfohlen). Eine Ende-zu-Ende-Verschlüsselung gibt es nicht.
- Kartenkacheln: Die App nutzt Apple Karten, die Kommandozentrale OpenStreetMap. Beide Anbieter sehen, welcher
  Kartenausschnitt geladen wird, aber keine Einsatzdaten. Routen zur A-Position berechnet Apple Karten.
- H02-Tracker senden unverschlüsselt und ohne Anmeldung; angenommen werden nur Positionen bekannter Gerätekennungen.
- Vor einem dienstlichen Einsatz mit echten personenbezogenen Daten: Freigabe durch IT-Sicherheit und Datenschutz.
