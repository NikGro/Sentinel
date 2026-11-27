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
final class KartenSteuerung {
    fileprivate weak var karte: MLNMapView?

    func zeigen(_ p: GeoPunkt, zoom: Double = 16) {
        karte?.setCenter(CLLocationCoordinate2D(latitude: p.lat, longitude: p.lon), zoomLevel: zoom, animated: true)
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
    let beiAuswahl: (KartenObjekt) -> Void
    @Environment(\.colorScheme) private var farbschema

    func makeCoordinator() -> Koordinator { Koordinator(modell: modell, beiAuswahl: beiAuswahl) }

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
        context.coordinator.aktualisieren(stand: modell.stand, ort: modell.standort.aktuell)
    }

    @MainActor
    final class Koordinator: NSObject, MLNMapViewDelegate {
        let modell: AppModell
        var beiAuswahl: (KartenObjekt) -> Void
        weak var karte: MLNMapView?
        private var stil: MLNStyle?
        private let szene = Szene()
        private var zoom: Double = 14.5
        private var takt: Timer?
        private var letzterStand: LageStand?

        init(modell: AppModell, beiAuswahl: @escaping (KartenObjekt) -> Void) {
            self.modell = modell
            self.beiAuswahl = beiAuswahl
        }

        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            stil = style
            aktualisieren(stand: modell.stand, ort: modell.standort.aktuell, erzwingen: true)
            // ÖPNV-Fahrzeuge flüssig (zehnmal je Sekunde), nur diese Quelle.
            takt = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.oepnvTakt() }
            }
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
