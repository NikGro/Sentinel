import MapLibre
import SentinelKern
import SwiftUI
import UIKit

/// Antippbare Ebenen des gemeinsamen Stils.
private let antippbar: Set<String> = [
    "lage-cluster", "lage-symbole", "lage-symbole-zeichen", "lage-oepnv-fahrzeuge", "lage-halte",
    "lage-linien", "lage-oepnv-kante", "lage-spuren", "lage-standortspur", "lage-flaechen",
]

/// Steuerung der Karte von außen (Kamera, Verkehrslage).
@MainActor
@Observable
final class KartenSteuerung {
    @ObservationIgnored fileprivate weak var karte: MLNMapView?
    @ObservationIgnored let fuehrung = Kamerafuehrung()
    @ObservationIgnored fileprivate var gesteAktiv = false
    /// Angeheftet (für den Standort-/Kompassknopf).
    private(set) var anheftung: Anheftung = .frei

    /// Standort-/Kompassknopf: heftet an (Fahrtrichtung), erneut getippt Norden oben, dann wieder Fahrtrichtung.
    func anheftenUmschalten(ort: CLLocation?) {
        let naechste: Anheftung = fuehrung.anheftung == .richtung ? .norden : .richtung
        fuehrung.anheften(art: naechste, lat: ort?.coordinate.latitude ?? 53.5)
        anheftung = fuehrung.anheftung
        if let ort { folgen(ort, sofort: true) }
    }

    fileprivate func folgen(_ ort: CLLocation, sofort: Bool = false) {
        guard let karte, !gesteAktiv else { return }
        let punkt = GeoPunkt(lat: ort.coordinate.latitude, lon: ort.coordinate.longitude)
        let tempo: KotlinDouble? = ort.speed >= 0 ? KotlinDouble(value: ort.speed) : nil
        let kurs: KotlinDouble? = ort.course >= 0 ? KotlinDouble(value: ort.course) : nil
        guard let ziel = fuehrung.ziel(ort: punkt, tempo: tempo, kurs: kurs, kompass: nil) else { return }
        let kamera = MLNMapCamera()
        kamera.centerCoordinate = CLLocationCoordinate2D(latitude: ziel.mitte.lat, longitude: ziel.mitte.lon)
        kamera.heading = ziel.richtung
        kamera.pitch = ziel.neigung
        // Höhe aus der Zoomstufe (MapLibre rechnet Kamera in Metern über Grund).
        kamera.altitude = MLNAltitudeForZoomLevel(ziel.zoom, ziel.neigung, ziel.mitte.lat, karte.bounds.size)
        karte.fly(to: kamera, withDuration: sofort ? 0.6 : Double(Kamerafuehrung.companion.FAHRT_MS) / 1000, completionHandler: nil)
    }

    fileprivate func geste(verschoben: Double, gedreht: Double) {
        if fuehrung.geste(verschobenPunkte: verschoben, gedrehtGrad: gedreht) { anheftung = .frei }
    }

    func zeigen(_ p: GeoPunkt, zoom: Double = 16) {
        karte?.setCenter(CLLocationCoordinate2D(latitude: p.lat, longitude: p.lon), zoomLevel: zoom, animated: true)
    }

    /// Hebt einen Ort hervor (Suchtreffer, gedrückter Ort); `nil` entfernt die Markierung.
    func markieren(_ p: GeoPunkt?) {
        guard let quelle = karte?.style?.source(withIdentifier: Quellen.shared.AUSWAHL) as? MLNShapeSource else { return }
        if let p {
            let punkt = MLNPointFeature()
            punkt.coordinate = CLLocationCoordinate2D(latitude: p.lat, longitude: p.lon)
            quelle.shape = MLNShapeCollectionFeature(shapes: [punkt])
        } else {
            quelle.shape = MLNShapeCollectionFeature(shapes: [])
        }
    }

    func norden() {
        karte?.setDirection(0, animated: true)
    }

    func verkehr(_ an: Bool) {
        guard let style = karte?.style else { return }
        for id in ["verkehr-fluss", "verkehr-sperrung", "verkehr-meldung-punkt"] {
            style.layer(withIdentifier: id)?.isVisible = an
        }
    }
}

/// Lagekarte mit der eigenen Karten-Engine (MapLibre) und dem gemeinsamen Stil des Servers. Die Daten kommen aus der
/// Karten-Szene des Kerns; Antippen fragt die Engine, welches Objekt dort gezeichnet ist (eine Stelle für alles).
struct LageKarte: UIViewRepresentable {
    let modell: AppModell
    let steuerung: KartenSteuerung
    /// Platzierungsmodus: Tipps setzen Punkte (`beiTipp`), die Vorschau erscheint in `s-entwurf`.
    var platzierung: Platzierung? = nil
    var beiTipp: (GeoPunkt) -> Void = { _ in }
    let beiAuswahl: (KartenObjekt) -> Void
    @Environment(\.colorScheme) private var farbschema

    func makeCoordinator() -> Koordinator { Koordinator(modell: modell, steuerung: steuerung, beiAuswahl: beiAuswahl) }

    func makeUIView(context: Context) -> MLNMapView {
        let server = modell.zugang?.server ?? ""
        let stil = URL(string: "\(server)/karte/stil/\(farbschema == .dark ? "dunkel" : "hell").json")
        let karte = MLNMapView(frame: .zero, styleURL: stil)
        karte.delegate = context.coordinator
        karte.compassView.isHidden = true
        karte.logoView.isHidden = true
        karte.attributionButtonPosition = .bottomLeft
        karte.showsUserLocation = false
        let start = modell.standort.aktuell?.coordinate ?? CLLocationCoordinate2D(latitude: 53.5511, longitude: 9.9937)
        karte.setCenter(start, zoomLevel: 14.5, animated: false)
        let tipp = UITapGestureRecognizer(target: context.coordinator, action: #selector(Koordinator.getippt(_:)))
        // Eigene Tipps nach den Gesten der Karte auswerten (Doppeltipp zum Zoomen bleibt erhalten).
        for g in karte.gestureRecognizers ?? [] where (g as? UITapGestureRecognizer)?.numberOfTapsRequired == 2 {
            tipp.require(toFail: g)
        }
        karte.addGestureRecognizer(tipp)
        steuerung.karte = karte
        context.coordinator.karte = karte
        return karte
    }

    func updateUIView(_ karte: MLNMapView, context: Context) {
        context.coordinator.beiAuswahl = beiAuswahl
        context.coordinator.beiTipp = beiTipp
        context.coordinator.entwurf(platzierung)
        context.coordinator.aktualisieren(stand: modell.stand, ort: modell.standort.aktuell)
    }

    @MainActor
    final class Koordinator: NSObject, MLNMapViewDelegate {
        let modell: AppModell
        weak var steuerung: KartenSteuerung?
        var beiAuswahl: (KartenObjekt) -> Void
        var beiTipp: (GeoPunkt) -> Void = { _ in }
        private var platzierung: Platzierung?
        private var letzteVorschau = ""
        weak var karte: MLNMapView?
        private var stil: MLNStyle?
        private let szene = Szene()
        private var zoom: Double = 14.5
        private var takt: Timer?
        private var letzterStand: LageStand?
        private var letzterOrt: Date?

        init(modell: AppModell, steuerung: KartenSteuerung, beiAuswahl: @escaping (KartenObjekt) -> Void) {
            self.modell = modell
            self.steuerung = steuerung
            self.beiAuswahl = beiAuswahl
        }

        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            stil = style
            aktualisieren(stand: modell.stand, ort: modell.standort.aktuell, erzwingen: true)
            letzteVorschau = ""
            entwurf(platzierung)
            // ÖPNV-Fahrzeuge flüssig (zehnmal je Sekunde), nur diese Quelle.
            takt = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.oepnvTakt() }
            }
        }

        private var startMitte: CLLocationCoordinate2D?
        private var startRichtung: Double = 0

        func mapView(_ mapView: MLNMapView, regionWillChangeWith reason: MLNCameraChangeReason, animated: Bool) {
            let geste: MLNCameraChangeReason = [.gesturePan, .gesturePinch, .gestureRotate, .gestureTilt, .gestureZoomIn, .gestureZoomOut, .gestureOneFingerZoom]
            guard !reason.intersection(geste).isEmpty else { return }
            steuerung?.gesteAktiv = true
            startMitte = mapView.centerCoordinate
            startRichtung = mapView.direction
        }

        func mapView(_ mapView: MLNMapView, regionIsChangingWith reason: MLNCameraChangeReason) {
            guard let steuerung, steuerung.gesteAktiv, let start = startMitte else { return }
            let p = mapView.convert(start, toPointTo: mapView)
            let mitte = CGPoint(x: mapView.bounds.midX, y: mapView.bounds.midY)
            let strecke = reason.contains(.gesturePan) ? Double(hypot(p.x - mitte.x, p.y - mitte.y)) : 0
            let gedreht = reason.contains(.gestureRotate) ? mapView.direction - startRichtung : 0
            steuerung.geste(verschoben: strecke, gedreht: gedreht)
        }

        func mapView(_ mapView: MLNMapView, regionDidChangeWith reason: MLNCameraChangeReason, animated: Bool) {
            guard let steuerung, steuerung.gesteAktiv else { return }
            steuerung.gesteAktiv = false
            // Zoomen und Kippen: neue Sollwerte, angeheftet bleibt es.
            steuerung.fuehrung.nutzerZoom(zoom: mapView.zoomLevel, neigung: mapView.camera.pitch)
        }

        func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
            let neu = mapView.zoomLevel
            // Auffächern nur bei merklicher Änderung neu berechnen.
            if abs(neu - zoom) > 0.25 {
                zoom = neu
                aktualisieren(stand: modell.stand, ort: modell.standort.aktuell, erzwingen: true)
            }
        }

        /// Bilder, die der gemeinsame Stil anfordert, erst bei Bedarf erzeugen.
        func mapView(_ mapView: MLNMapView, didFailToLoadImage imageName: String) -> UIImage? {
            Kartenbilder.bild(imageName)
        }

        func aktualisieren(stand: LageStand, ort: CLLocation?, erzwingen: Bool = false) {
            guard let stil else { return }
            if erzwingen || letzterStand !== stand {
                letzterStand = stand
                let jetzt = Int64(Date.now.timeIntervalSince1970 * 1000)
                for (id, json) in Bruecke.shared.quellen(szene: szene, stand: stand, jetztMs: jetzt, zoom: zoom) {
                    setzen(stil, id, json)
                }
            }
            let punkt = ort.map { GeoPunkt(lat: $0.coordinate.latitude, lon: $0.coordinate.longitude) }
            let richtung: KotlinDouble? = (ort?.course ?? -1) >= 0 ? KotlinDouble(value: ort!.course) : nil
            setzen(stil, Quellen.shared.ICH, szene.ich(p: punkt, richtung: richtung, darstellung: "punkt", mitA: stand.haeltA))
            // Angeheftet: Kamera folgt dem Standort.
            if let ort, ort.timestamp != letzterOrt {
                letzterOrt = ort.timestamp
                steuerung?.folgen(ort)
            }
        }

        /// Entwurf im Platzierungsmodus (gelbe Vorschau); nur bei Änderung neu setzen.
        func entwurf(_ p: Platzierung?) {
            platzierung = p
            guard let stil else { return }
            let json = p?.vorschau(radius: nil) ?? #"{"type":"FeatureCollection","features":[]}"#
            guard json != letzteVorschau else { return }
            letzteVorschau = json
            setzen(stil, Quellen.shared.ENTWURF, json)
        }

        private func oepnvTakt() {
            guard let stil else { return }
            let jetzt = Int64(Date.now.timeIntervalSince1970 * 1000)
            setzen(stil, Quellen.shared.OEPNV_FAHRZEUGE, Bruecke.shared.oepnvFahrzeuge(szene: szene, stand: modell.stand, jetztMs: jetzt))
        }

        private func setzen(_ stil: MLNStyle, _ id: String, _ json: String) {
            guard let quelle = stil.source(withIdentifier: id) as? MLNShapeSource, let daten = json.data(using: .utf8) else { return }
            quelle.shape = try? MLNShape(data: daten, encoding: String.Encoding.utf8.rawValue)
        }

        @objc func getippt(_ g: UITapGestureRecognizer) {
            guard let karte else { return }
            let p = g.location(in: karte)
            // Platzierungsmodus: jeder Tipp setzt einen Punkt, nichts wird ausgewählt.
            if platzierung != nil {
                let k = karte.convert(p, toCoordinateFrom: karte)
                beiTipp(GeoPunkt(lat: k.latitude, lon: k.longitude))
                return
            }
            let r: CGFloat = 24
            let merkmale = karte.visibleFeatures(in: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r), styleLayerIdentifiers: antippbar)
            guard let erstes = merkmale.first(where: { $0.attribute(forKey: "id") != nil || $0.attribute(forKey: "point_count") != nil }) else { return }
            if erstes.attribute(forKey: "point_count") != nil {
                karte.setCenter(erstes.coordinate, zoomLevel: karte.zoomLevel + 2, animated: true)
            } else if let id = erstes.attribute(forKey: "id") as? String, let objekt = KartenObjekt.companion.von(schluessel: id) {
                beiAuswahl(objekt)
            }
        }
    }
}
