# Abgleich Neubau gegen die Funktionsliste (REVIEW-NEUBAU.md, Abschnitt 2)

Stand: 28.11.2026. Geprüft wurde der Code der neuen Apps (`android/`, `apple/`), des Kerns (`kern/`) und des Webs.
„Fertig“ heißt: gebaut, auf beiden Plattformen in CI grün (Build und Starttest), Regeln im Kern mit Tests. Durch
Bedienung geprüft ist noch nichts davon; dafür braucht es den Server mit den neuen Diensten.

## Fertig (beide Plattformen gleich)

- Einrichtung, Anmeldung (Schlüssel im Keystore bzw. Schlüsselbund), Abmelden, Profil anlegen, Wiederverbinden,
  Entzug des Zugangs.
- App-Sperre (Fingerabdruck/Face ID bzw. Gerätecode, Frist wählbar).
- Hauptmenü: Instanzen öffnen, anlegen, umbenennen, löschen, beitreten, verlassen; Pakete bearbeiten, übernehmen.
- Karte: eigene Kacheln, hell/dunkel, 3D-Gebäude, Verkehr und Sperrungen, Kameraführung (Anheften, Norden, lösen
  durch Gesten), Cluster, Auffächern, Lebensdauer, Flächenbeschriftung, Antippen über die Engine.
- Ebenen-Auswahl: Verkehr, ÖPNV live, Bestreifung, Weg-Zeit (Fuß/Kfz/ÖPNV).
- Plus-Menü, Setzen-Modus mit gelber Leiste, Vorschau, Mehrpunkt mit „Fertig“, Markierung verschieben, Standortspur.
- Editoren: Markierung (Farbe, Symbol, Radius, Geofence-Ziele, Ebene, Lebensdauer), neues Ziel.
- Kurzübersicht je Art mit Aktionen (Hinführen, Bearbeiten, Verschieben, Standort setzen, Anrufen, Details, Verlauf),
  Straßenbild bei Zielen und Markierungen.
- Suche: Anschriften, Kreuzungen, Orte, Einrichtungen (eigene Ortssuche), Objekte der Lage (A zuerst).
- Navigation: Ferrostar 0.59 auf beiden Plattformen, Verkehrsführung über TomTom, Sonderrechte, Sperrungen,
  Nachführung bewegter Ziele, Vorlauf, Parallel, Tempolimit, Navi-Leisten oben und unten, Verkehrsfaktor.
- ÖPNV live: Fahrzeuge, Haltestellen, Abfahrten, Fahrtverlauf, als Strecke bzw. Haltestelle übernehmen.
- Ziele: Liste nach Gruppen, Ansicht mit allen Angaben, Geburtsdatum/Alter, Standortquelle (Hand, Tracker, A),
  Unterwegs (zu Fuß, Fahrzeug, Gebäude, ÖPNV), Gruppe, Sichtbarkeit, Beziehungen, Fotos (Titelbild) und Dateien.
- Kräfte: Liste mit Status, Kraftansicht (Anrufen, Karte), eigenes Fahrzeug wählen, Fahrzeuge in den Einsatz nehmen.
- Verlauf je Kraft, Fahrzeug, Ziel (Zeiträume, Zeitregler, Standzeiten, behalten); Spur-Markierungen laufend.
- Meldungen (Notruf, Geofence, A-Wechsel) als Banner und Systemmitteilung; SOS erst nach 1,5 s Halten.
- Daueranzeige im Dienst (Live-Aktivität, Android-Benachrichtigung) mit Statuszeile aus dem Kern.
- Mehr: Profil, Funkkanal und Lage, Version, Abmelden.
- Web: eigene Karte mit gemeinsamem Stil, Lage über den gemeinsamen Kern; Apple Maps entfernt.
- Lange drücken auf die Karte (Umkehrsuche, Hinführen, Hier anlegen); Notruf-Leiste; Versionsabgleich mit
  Sperrbildschirm; Sichtschutz im App-Umschalter; Lageübersicht; Tempo und Tempolimit ohne Navigation.
- ÖPNV als Fortbewegung, selbst bzw. Zielperson einsteigen; Navigation zu Zielen im ÖPNV mit 1–2 Halten voraus.
- Ziele: Suche, Gruppen anlegen/bearbeiten/löschen, Auswahlmodus, Insassen, Anschrift mit Vorschlägen,
  Aufzeichnung je Ziel. Kräfte: Suche, Fahrzeugflotte bearbeiten. Profil übernehmen bei der Einrichtung.
- Karte: Grundkarte Satellit (TomTom-Luftbild über den eigenen Server), 3D an/aus, Zielarten und Gruppen
  ausblenden (Android, iOS, Web); mehrfach tippen schaltet durch; Fahndungsraum verschieben mit Rückfrage
  zum Sichtungszeitpunkt.

## Offen (nach Wichtigkeit)

**Einsatzbetrieb**
3. Navigation zu einem Ziel im ÖPNV: überschlagendes Anfahren (Halte voraus ist fertig).

**Karte**
14. Punkt auf Linie bzw. Spur antippen (Wert an der Stelle; Durchschalten übereinanderliegender Formen ist fertig).
16. Sonderbereiche sichtbar machen: „Dauerhafte Orte bearbeiten“, „Paket vorbereiten“ (Leiste mit „Fertig“,
    eingeschränkte Funktionen).

**ÖPNV, Navigation, Suche**
17. ÖPNV-Strecke im Editor anlegen (Linie suchen, Richtung, Start/Ende, Abfahrt, Takt); Linien- und
    Haltestellensuche in der Live-Ansicht.
18. Querstraßen als Sprechblasen während der Navigation; Zielfahne.
19. Zu Fuß/ÖPNV: Verbindung mit Bus und Bahn als Schrittfolge.
20. Spracheingabe in der Suche; „live“-Kennzeichen bei bewegten Treffern.

**Verlauf, Tracker, Verwaltung**
21. Verlauf: Tracker als Quelle, freier Zeitraum von–bis, Werte an angetippter Stelle.
22. Tracker: Zustand, Befehle, SMS, Zuordnung.
23. Verwaltung in der App: Geräte und Zugangscode, PAJ-Konto, Ebenen, Argus-Import, Lage zurücksetzen
    (heute in Sentinel Web vorhanden).

**Bewusst nicht**
- Chat (in der alten App ausgeblendet), Demo-Lage, Entwickler-Kamera-Overlay.
