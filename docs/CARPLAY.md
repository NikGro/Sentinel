# CarPlay für Sentinel – Machbarkeit und Konzept

Stand: November 2026

## Ergebnis

Eine CarPlay-Version ist technisch gut denkbar, aber **mit der heutigen Verteilung über SideStore nicht
umsetzbar**. CarPlay-Funktionen setzen eine von Apple vergebene Berechtigung (Entitlement) voraus, z. B.
`com.apple.developer.carplay-maps` für Navigations-Apps. Diese Berechtigung wird nur auf Antrag über ein
bezahltes Apple-Entwicklerkonto erteilt, nach Prüfung durch Apple und Zustimmung zum CarPlay-Zusatzvertrag.
Eine unsignierte bzw. mit persönlichem Konto per SideStore signierte App kann sie nicht enthalten.

Voraussetzungen für einen späteren Schritt:

1. Apple-Developer-Program-Mitgliedschaft (Organisation, z. B. die Dienststelle), Signatur über TestFlight
   oder Ad-hoc/Enterprise statt SideStore.
2. Antrag auf das Navigations-Entitlement mit Beschreibung des Anwendungsfalls. Apple ordnet jede App
   genau einer Kategorie zu; Mischformen sind nicht vorgesehen, Bearbeitungszeiten von Wochen sind üblich.
3. Prüfung, ob eine Behörden-App mit Lagekarte als „Navigation“ eingestuft wird (Sentinel führt zu Zielen,
   zeigt aber auch eigene Kartenebenen – das muss im Antrag begründet werden).

## Was in CarPlay sinnvoll wäre

Im Fahrzeug zählt: wenig Ablenkung, große Ziele, Sprachbedienung. Apple erzwingt dafür feste Vorlagen
(Templates); freie eigene Oberflächen sind außer der Kartenfläche nicht erlaubt.

| Funktion | CarPlay-Vorlage | Bemerkung |
| --- | --- | --- |
| Lagekarte mit eigener Position, A-Position, Kräften, Fahndungsraum | Kartenfläche (`CPMapTemplate`) | Inhalt der Karte frei gezeichnet, Bedienknöpfe fest |
| Zur A-Position / zu Kräften / zu Zielen navigieren | Liste (`CPListTemplate`) → Route | Bestehende Ferrostar-Navigation wird weiterverwendet |
| Sonderrechte ein/aus | Kartenknopf | ein Tipp |
| SOS | Kartenknopf mit Rückfrage (`CPAlertTemplate`) | Gedrückthalten ist in CarPlay nicht möglich, daher Bestätigung |
| Hinweise (A übernommen, SOS, Nachrichten) | Banner / Alert | nur kurz, Text vorlesbar |
| Chat | – | in CarPlay nur über Siri-Nachrichten erlaubt, nicht als eigene Ansicht |
| Markierungen anlegen, Ziele bearbeiten | – | im Fahrzeug bewusst nicht; bleibt dem iPhone vorbehalten |

## Technischer Aufwand (bei erteilter Berechtigung)

- Eigene Szene `CPTemplateApplicationSceneDelegate`, Kartenfläche mit MapKit-Inhalt der App.
- Navigation: `CPNavigationSession` mit Manövern aus Ferrostar (Abbiegehinweise, Entfernung, Ankunft).
- Daten: dieselben Stores (`LageStore`, `RouteFollower`) wie die iPhone-App, kein eigener Server-Teil.
- Geschätzt einige Tage Umsetzung plus Apples Prüfung.

## Empfehlung

Erst wenn eine Verteilung über ein Apple-Entwicklerkonto der Organisation möglich ist, das Entitlement
beantragen. Bis dahin bleibt Sentinel auf dem iPhone; im Fahrzeug funktioniert es über eine Halterung mit
der bestehenden Navi-Ansicht.

Quellen: Apple, „Requesting CarPlay entitlements“ (developer.apple.com/documentation/carplay/requesting-carplay-entitlements),
„Preparing your iOS app for CarPlay development“.
