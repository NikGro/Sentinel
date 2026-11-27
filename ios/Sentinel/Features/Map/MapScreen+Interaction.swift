import MapKit
import SwiftUI

// Tippen, Zeichnen und Anlegen auf der Karte.

extension MapScreen {
    // MARK: Tippen und Zeichnen

    func handleTap(_ point: GeoPoint) {
        switch tapMode {
        case .none:
            break
        case .placingTarget(let id):
            if var target = lage.targets[id]?.data {
                target.standort = TimedPoint(point)
                target.quelle = .hand
                lage.put(target, id: id)
            }
            tapMode = .none
        case .newTarget(let art):
            var target = Target(art: art)
            target.standort = TimedPoint(point)
            tapMode = .none
            targetEditor = TargetEditorContext(id: LageStore.newId(), target: target, isNew: true)
        case .moving(let objectId):
            guard var object = lage.mapObjects[objectId]?.data, settings.canEdit(layerId: object.layerId) else {
                tapMode = .none
                return
            }
            let anchor = object.anchor
            let dLat = point.lat - anchor.lat
            let dLon = point.lon - anchor.lon
            object.punkte = object.punkte.map { GeoPoint(lat: $0.lat + dLat, lon: $0.lon + dLon) }
            lage.saveMapObject(object, id: objectId)
            tapMode = .none
            // Neuer Ort einer Sichtung: fragen, ob sie auch jetzt war.
            if object.typ == .fahndungsraum { movedRoom = objectId }
        case .drawing(let shape, var points):
            points.append(point)
            if shape.isMultiPoint {
                tapMode = .drawing(shape, points: points)
            } else {
                finishDrawing(shape, points)
            }
        }
    }

    func finishDrawing(_ shape: MapObject.Shape, _ points: [GeoPoint]) {
        guard points.count >= shape.minimumPoints else { return }
        tapMode = .none
        editor = EditorContext(id: LageStore.newId(), object: draft(shape, points), isNew: true)
    }

    /// Versatz für übereinanderliegende Symbole (Kräfte, Fahrzeuge, Ziele, Marker).
    /// Herausgezoomt Cluster, nah dran auseinandergerückte Punkte.
    var clusterLayout: ClusterLayout {
        // Abhängigkeit von der abgestuften Zoomstufe: Bei spürbarem Zoomen wird sofort neu aufgeteilt.
        _ = cameraState.zoomStep
        let items = forcePins.map { ($0.id, $0.coordinate) } + (vehiclePins + targetPins).map { ($0.id, $0.coordinate) } + handles.map { ($0.id, $0.coordinate) }
        // Art je Symbol für die Farbe der Cluster.
        var kinds: [String: String] = [:]
        for pin in forcePins { kinds[pin.id] = "kraft" }
        for pin in vehiclePins { kinds[pin.id] = "kraft" }
        for pin in targetPins { kinds[pin.id] = "ziel" }
        for handle in handles { kinds[handle.id] = "marker:" + handle.object.farbe.uppercased() }
        return ClusterLayout(items.map { (id: $0.0, coordinate: $0.1) }, metersPerPoint: cameraState.distance / 700, kinds: kinds)
    }

    /// Cluster angetippt: so weit hineinzoomen, dass alle Punkte darin zu sehen sind.
    func zoom(into cluster: MapCluster) {
        let lats = cluster.members.map(\.latitude), lons = cluster.members.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(), let minLon = lons.min(), let maxLon = lons.max() else { return }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(latitudeDelta: max((maxLat - minLat) * 2.5, 0.003), longitudeDelta: max((maxLon - minLon) * 2.5, 0.003))
        engine.show(MKCoordinateRegion(center: center, span: span), duration: 0.5)
    }

    var hasTransit: Bool { visibleObjects.contains { $0.data.typ.isTransit } }

    /// Angelegte ÖPNV-Fahrzeuge und die im Takt eingeblendeten auf ÖPNV-Linien.
    func transitPins(at transitNow: Date) -> [TransitVehiclePin] {
        var pins: [TransitVehiclePin] = []
        // Fahrzeuge nach echtem Fahrplan: eigene ÖPNV-Fahrzeuge und Strecken mit eingeschalteter Fahrzeug-Ebene.
        for object in objects(.oepnvfahrzeug) + objects(.oepnvlinie).filter(\.data.hasRealVehicle) {
            guard let line = object.data.linie else { continue }
            // Echte Fahrt: das Fahrzeug ist ab fünf Minuten vor der Abfahrt bis fünf Minuten nach der Ankunft zu sehen.
            if let times = object.data.fahrt?.zeiten.compactMap({ $0 }), let start = times.first, let end = times.last {
                let t = transitNow.timeIntervalSince1970 * 1000
                let margin = TransitSimulation.standing * 1000
                if t < start - margin || t > end + margin { continue }
            }
            // Nach echten Zeiten mit dem Fahrmodell (`TransitMotion`), bei neuer Echtzeit weich nachgeführt.
            let point: GeoPoint = if let fahrt = object.data.fahrt,
                let motion = TransitSimulation.motion(object.data.punkte, path: object.data.weg ?? [], times: fahrt.zeiten, typ: line.typ) {
                transitSmoother.point(id: object.id, motion: motion, at: transitNow)
            } else {
                lage.position(ofObject: object.data, at: transitNow)
            }
            // Sitzt eine (sichtbare) Zielperson darin, steht nur ihr Symbol hier.
            let rider = lage.sortedTargets.first { target in
                target.data.bindung?.art == .oepnv && target.data.bindung?.zielId == object.id
                    && lage.isTargetVisible(target.id) && !settings.hiddenTargetKinds.contains(target.data.art.rawValue)
            }
            pins.append(TransitVehiclePin(
                id: object.id, objectId: object.id, lineObjectId: nil,
                coordinate: point.coordinate,
                line: line, color: Color(hex: object.data.transitHex), departure: object.data.since ?? transitNow,
                rider: rider.map { (id: $0.id, label: targetLabel($0), symbol: $0.data.mapSymbol) }
            ))
        }
        for object in objects(.oepnvlinie) {
            guard let line = object.data.linie else { continue }
            for vehicle in TransitSimulation.vehicles(on: object.data, at: transitNow) {
                pins.append(TransitVehiclePin(
                    id: "\(object.id)-\(Int(vehicle.departure.timeIntervalSince1970))", objectId: nil, lineObjectId: object.id,
                    coordinate: vehicle.state.point.coordinate, line: line, color: Color(hex: object.data.transitHex), departure: vehicle.departure
                ))
            }
        }
        return pins
    }

    /// Ein im Takt eingeblendetes Fahrzeug als eigenes Objekt anlegen; es löscht sich nach der Ankunft selbst.
    func createVehicle(from pin: TransitVehiclePin) -> String? {
        guard let lineId = pin.lineObjectId, let section = lage.mapObjects[lineId]?.data else { return nil }
        var vehicle = MapObject(layerId: Layer.lageId, typ: .oepnvfahrzeug, titel: "\(pin.line.ref) → \(pin.line.richtung)", farbe: section.farbe, punkte: section.punkte, zeit: (pin.departure.timeIntervalSince1970 * 1000).rounded())
        vehicle.linie = pin.line
        vehicle.haltNamen = section.haltNamen
        vehicle.weg = section.weg
        let end = pin.departure.addingTimeInterval(TransitSimulation.duration(section.punkte, typ: pin.line.typ, path: section.weg ?? []) + 300)
        vehicle.ablauf = (end.timeIntervalSince1970 * 1000).rounded()
        let id = LageStore.newId()
        lage.saveMapObject(vehicle, id: id)
        return id
    }

    /// Neue Markierung mit den Vorgaben ihrer Art.
    func draft(_ shape: MapObject.Shape, _ points: [GeoPoint]) -> MapObject {
        let isRoom = shape == .fahndungsraum
        return MapObject(
            layerId: settings.defaultLayerId,
            typ: shape,
            farbe: isRoom ? "#C97C7C" : shape == .geofence ? "#FF453A" : shape == .haltestellen || shape.isTransit ? "#0A84FF" : "#FF9F0A",
            punkte: points,
            radius: shape == .kreis || shape == .geofence ? 150 : shape == .haltestellen ? 500 : nil,
            zeit: isRoom || shape.isTransit ? (Date.now.timeIntervalSince1970 * 1000).rounded() : nil
        )
    }

    /// Gibt es das angezeigte Objekt noch? (`true` ohne Auswahl.)
    var selectionExists: Bool {
        switch selection {
        case nil: true
        case .member(let id): lage.members[id] != nil
        case .vehicle(let id): lage.vehicles[id] != nil
        case .target(let id): lage.targets[id] != nil
        case .object(let id): lage.mapObjects[id] != nil
        }
    }

    /// Liegt ein Tipp auf einem Symbol (Kräfte, Fahrzeuge, Ziele, Marker, ÖPNV, Haltestellen, Cluster, eigener
    /// Standort)? Dann gehört er dem Symbol und nicht der Form darunter. Auseinandergerückte Symbole werden an ihrer
    /// gezeichneten Stelle geprüft, nicht an ihrer Koordinate; gebündelte über ihren Cluster.
    func tapHitsSymbol(_ point: CGPoint, proxy: MapProxy) -> Bool {
        let layout = clusterLayout
        let placed: [(id: String?, coordinate: CLLocationCoordinate2D)] =
            forcePins.map { ($0.id, $0.coordinate) }
            + (vehiclePins + targetPins).map { ($0.id, $0.coordinate) }
            + handles.map { ($0.id, $0.coordinate) }
            + transitPins(at: .now).map { (nil, $0.coordinate) }
            + nearbyStops.map { (nil, $0.point.coordinate) }
            + lage.operation.ueberschlagen.naechste.map { (nil, $0.point.coordinate) }
            + [location.current?.coordinate].compactMap { $0 }.map { (nil, $0) }
            + layout.clusters.map { (nil, $0.coordinate) }
        for item in placed {
            if let id = item.id, layout.hidden.contains(id) { continue }
            guard let screen = proxy.convert(item.coordinate, to: .local) else { continue }
            let offset = item.id.flatMap { layout.offsets[$0] } ?? .zero
            if hypot(screen.x + offset.width - point.x, screen.y + offset.height - point.y) < 26 { return true }
        }
        return false
    }

    /// Auseinandergerücktes Symbol an der angetippten Stelle (am echten Ort plus Bildschirmversatz gemessen): was es
    /// öffnet, sonst `nil`. Das nächstgelegene gewinnt.
    func displacedSymbol(at point: CGPoint, proxy: MapProxy) -> (() -> Void)? {
        let offsets = clusterLayout.offsets
        guard !offsets.isEmpty else { return nil }
        var candidates: [(id: String, coordinate: CLLocationCoordinate2D, open: () -> Void)] = []
        for pin in forcePins where offsets[pin.id] != nil {
            candidates.append((pin.id, pin.coordinate, { present(pin.target, low: false) }))
        }
        for pin in vehiclePins + targetPins where offsets[pin.id] != nil {
            candidates.append((pin.id, pin.coordinate, { present(pin.selection, low: false) }))
        }
        for handle in handles where offsets[handle.id] != nil {
            candidates.append((handle.id, handle.coordinate, { openEditor(for: handle.id) }))
        }
        var best: (distance: CGFloat, open: () -> Void)?
        for candidate in candidates {
            guard let offset = offsets[candidate.id], let screen = proxy.convert(candidate.coordinate, to: .local) else { continue }
            let distance = hypot(screen.x + offset.width - point.x, screen.y + offset.height - point.y)
            if distance < 26, best == nil || distance < best!.distance { best = (distance, candidate.open) }
        }
        return best?.open
    }

    /// Gezeichnete Form unter dem Finger: Linien (mit etwas Spielraum), Flächen, Kreise, Prognosezellen.
    /// Bei Überlappung gewinnt die kleinste, denn sie ist die gezielt gemeinte.
    /// Alle Formen an einer Stelle, die kleinste zuerst (Linien vor Flächen).
    func shapes(at point: GeoPoint) -> [String] {
        let tolerance = max(8, cameraState.distance / 45)
        var found: [(id: String, size: Double)] = []
        for object in visibleObjects {
            let data = object.data
            let size: Double?
            switch data.typ {
            case .flaeche where data.punkte.count >= 3, .geofence where data.radius == nil && data.punkte.count >= 3:
                size = Self.contains(data.punkte, point) ? Self.area(data.punkte) : nil
            case .kreis, .haltestellen, .geofence:
                guard let center = data.punkte.first else { continue }
                let radius = data.radius ?? 100
                size = center.distance(to: point) <= radius ? Double.pi * radius * radius : nil
            case .oepnvlinie:
                // Nur Sichtbares ist antippbar (wie in `TransitLayer` gezeichnet): Linienverlauf nur mit eingeschalteter
                // Strecke, Halte nur mit eingeschalteten Haltestellen. Das Fahrzeug hat sein eigenes Symbol.
                let path = (data.weg?.count ?? 0) >= 2 ? data.weg! : data.punkte
                let onPath = data.showsPath && path.count >= 2 && Self.distance(from: point, toLine: path) <= tolerance
                let onStop = data.showsStops && data.punkte.contains { $0.distance(to: point) <= tolerance * 1.5 }
                size = onPath || onStop ? 0 : nil
            case .linie where data.punkte.count >= 2, .pfeil where data.punkte.count >= 2:
                size = Self.distance(from: point, toLine: data.punkte) <= tolerance ? 0 : nil
            default:
                size = nil
            }
            if let size { found.append((object.id, size)) }
        }
        return found.sorted { $0.size < $1.size }.map(\.id)
    }

    /// Nächster Punkt auf einer Linie zur angetippten Stelle (auf dem Bildschirm gemessen), für den Punkt auf der
    /// Strecke. `nil` bei Flächen und Kreisen.
    func pointOnLine(of id: String, near tap: CGPoint, proxy: MapProxy) -> GeoPoint? {
        guard let data = lage.mapObjects[id]?.data, [.linie, .oepnvlinie, .pfeil].contains(data.typ) else { return nil }
        let line = data.typ == .oepnvlinie && (data.weg?.count ?? 0) >= 2 ? data.weg! : data.punkte
        let screen = line.map { proxy.convert($0.coordinate, to: .local) }
        var best: (point: CGPoint, d: CGFloat)?
        for i in 0..<max(screen.count - 1, 0) {
            guard let a = screen[i], let b = screen[i + 1] else { continue }
            let dx = b.x - a.x, dy = b.y - a.y
            let l2 = dx * dx + dy * dy
            let t = l2 > 0 ? min(max(((tap.x - a.x) * dx + (tap.y - a.y) * dy) / l2, 0), 1) : 0
            let p = CGPoint(x: a.x + dx * t, y: a.y + dy * t)
            let d = hypot(tap.x - p.x, tap.y - p.y)
            if best == nil || d < best!.d { best = (p, d) }
        }
        guard let best, let coordinate = proxy.convert(best.point, from: .local) else { return nil }
        return GeoPoint(coordinate)
    }

    /// Angetippte Stelle: Standortverläufe und Formen dort. Mehrfaches Tippen auf dieselbe Stelle schaltet der Reihe
    /// nach durch, was dort übereinanderliegt. Linien und Verläufe bekommen einen Punkt auf der Strecke, die Kamera
    /// rückt ihn zwischen Suchleiste und das (niedrige) Fenster unten.
    func selectShapeOrTrack(at tap: CGPoint, proxy: MapProxy) {
        guard let coordinate = proxy.convert(tap, from: .local) else { return }
        let tracks = storedTracks.hits(near: tap, proxy: proxy)
        let shapeIds = shapes(at: GeoPoint(coordinate))
        let keys = tracks.map { "spur:\($0.trackId)" } + shapeIds.map { "form:\($0)" }
        guard !keys.isEmpty else {
            storedTracks.selected = nil
            return
        }
        var index = 0
        if let last = lastShapeTap, hypot(last.point.x - tap.x, last.point.y - tap.y) < 30, Set(last.keys) == Set(keys),
           Date.now.timeIntervalSince(last.at) < 15 {
            index = (last.index + 1) % keys.count
        }
        lastShapeTap = ShapeTap(point: tap, keys: keys, index: index, at: .now)
        if index < tracks.count {
            let hit = tracks[index]
            storedTracks.selected = (hit.trackId, hit.index, hit.fraction)
            guard let track = storedTracks.selectedTrack, let objectId = hit.trackId.split(separator: "|").first.map(String.init),
                  lage.mapObjects[objectId] != nil else { return }
            tapMarker = track.spur.sample(index: hit.index, fraction: hit.fraction).punkt.point
            present(.object(objectId), low: true)
        } else {
            let id = shapeIds[index - tracks.count]
            storedTracks.selected = nil
            tapMarker = pointOnLine(of: id, near: tap, proxy: proxy)
            guard lage.mapObjects[id] != nil, tapMode == .none else { return }
            present(.object(id), low: tapMarker != nil)
        }
        focusTapMarker()
    }

    /// Angetippte Stelle eines abgelegten Standortverlaufs für die Kurzübersicht.
    var selectedTrackPoint: TrackPoint? {
        guard let selected = storedTracks.selected, let track = storedTracks.selectedTrack, track.spur.punkte.indices.contains(selected.index) else { return nil }
        return TrackPoint(spur: track.spur, index: selected.index, fraction: selected.fraction, title: model.title(of: track.spur.subject))
    }

    /// Kurzübersicht öffnen; nach einem Tipp auf eine Strecke zunächst niedrig.
    func present(_ new: MapSelection, low: Bool) {
        quickLookDetent = low ? QuickLookHeight.low : .medium
        selection = new
    }

    /// Den Punkt auf der Strecke mittig zwischen Suchleiste und Oberkante des niedrigen Fensters zeigen.
    func focusTapMarker() {
        guard let point = tapMarker else { return }
        let view = cameraState.camera()
        let height = engine.windowHeight ?? 800
        engine.fly(to: MapCamera(centerCoordinate: point.coordinate, distance: view.distance, heading: view.heading, pitch: view.pitch),
                   betweenTop: showsHistory ? 60 : topBarBottom, bottom: height * (1 - QuickLookHeight.lowFraction), duration: 0.45)
    }

    func shape(at point: GeoPoint) -> String? {
        // Spielraum für Linien: etwa 22 Bildpunkte, abhängig von der Zoomstufe.
        let tolerance = max(8, cameraState.distance / 45)
        var best: (id: String, size: Double)?
        for object in visibleObjects {
            let data = object.data
            let size: Double?
            switch data.typ {
            case .flaeche where data.punkte.count >= 3, .geofence where data.radius == nil && data.punkte.count >= 3:
                size = Self.contains(data.punkte, point) ? Self.area(data.punkte) : nil
            case .kreis, .haltestellen, .geofence:
                guard let center = data.punkte.first else { continue }
                let radius = data.radius ?? 100
                size = center.distance(to: point) <= radius ? Double.pi * radius * radius : nil
            case .linie where data.punkte.count >= 2, .oepnvlinie where data.punkte.count >= 2, .pfeil where data.punkte.count >= 2:
                size = Self.distance(from: point, toLine: data.punkte) <= tolerance ? 0 : nil
            default:
                size = nil
            }
            if let size, size < (best?.size ?? .greatestFiniteMagnitude) { best = (object.id, size) }
        }
        return best?.id
    }

    /// Fläche eines Vielecks in Quadratmetern (für kleine Flächen genügend genau).
    static func area(_ polygon: [GeoPoint]) -> Double {
        guard let origin = polygon.first else { return 0 }
        let k = cos(origin.lat * .pi / 180) * 111_320
        var sum = 0.0
        for i in polygon.indices {
            let a = polygon[i], b = polygon[(i + 1) % polygon.count]
            sum += (a.lon * k) * (b.lat * 110_540) - (b.lon * k) * (a.lat * 110_540)
        }
        return abs(sum) / 2
    }

    /// Kürzester Abstand eines Punkts zu einem Linienzug in Metern.
    static func distance(from point: GeoPoint, toLine line: [GeoPoint]) -> Double {
        let k = cos(point.lat * .pi / 180)
        var best = Double.greatestFiniteMagnitude
        for i in 0..<(line.count - 1) {
            let a = line[i], b = line[i + 1]
            let ax = a.lon * k, ay = a.lat, bx = b.lon * k, by = b.lat
            let px = point.lon * k, py = point.lat
            let dx = bx - ax, dy = by - ay
            let length = dx * dx + dy * dy
            let t = length == 0 ? 0 : max(0, min(1, ((px - ax) * dx + (py - ay) * dy) / length))
            best = min(best, GeoPoint(lat: ay + t * dy, lon: (ax + t * dx) / k).distance(to: point))
        }
        return best
    }

    /// Punkt-in-Fläche nach dem Strahlverfahren (für kleine Flächen in Breite/Länge ausreichend genau).
    static func contains(_ polygon: [GeoPoint], _ point: GeoPoint) -> Bool {
        guard polygon.count >= 3 else { return false }
        var inside = false
        var j = polygon.count - 1
        for i in polygon.indices {
            let a = polygon[i], b = polygon[j]
            if (a.lat > point.lat) != (b.lat > point.lat),
               point.lon < (b.lon - a.lon) * (point.lat - a.lat) / (b.lat - a.lat) + a.lon {
                inside.toggle()
            }
            j = i
        }
        return inside
    }

    /// Gedrückter Ort: Feld mit Navigieren und Anlegen; der Name kommt aus der Umkehrsuche nach.
    func pressed(at point: GeoPoint) {
        searchPin = SearchPin(point: point, title: "Markierter Ort")
        focus(on: point, keepingView: true)
        Task {
            let placemarks = try? await CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: point.lat, longitude: point.lon), preferredLocale: Locale(identifier: "de_DE"))
            guard let place = placemarks?.first, searchPin?.point == point else { return }
            let street = [place.thoroughfare, place.subThoroughfare].compactMap { $0 }.joined(separator: " ")
            let title = street.isEmpty ? (place.name ?? "Markierter Ort") : street
            searchPin = SearchPin(point: point, title: title)
        }
    }

    /// Suchtreffer auf der Karte zeigen, ohne loszufahren.
    func show(_ pin: SearchPin) {
        searchPin = pin
        // Ein anderer Ort: nicht mehr am eigenen Standort angeheftet.
        focus(on: pin.point, keepingView: false)
    }

    /// Ort mittig zwischen Suchleiste und dem Fenster unten zeigen (nicht in der Bildmitte, die das Fenster verdeckt).
    /// `keepingView`: Abstand, Richtung und Neigung bleiben (gedrückter Ort); sonst nah heran wie bei einem Suchtreffer.
    /// Wächst das Fenster danach noch, rückt der Ort mit derselben Ansicht nach (`refocusSearchPin`).
    func focus(on point: GeoPoint, keepingView: Bool) {
        searchPinFocusedAt = .now
        let view = keepingView
            ? cameraState.camera()
            : MapCamera(centerCoordinate: point.coordinate, distance: 900, heading: 0, pitch: settings.prefers3D ? 55 : 0)
        let target = MapCamera(centerCoordinate: point.coordinate, distance: view.distance, heading: view.heading, pitch: view.pitch)
        searchPinView = target
        engine.fly(to: target, betweenTop: topBarBottom, bottom: bottomBarTop, duration: keepingView ? 0.45 : 0.8)
    }

    func refocusSearchPin() {
        guard let target = searchPinView, searchPin != nil, Date.now.timeIntervalSince(searchPinFocusedAt) < 2.5, !engine.isGestureActive else { return }
        engine.fly(to: target, betweenTop: topBarBottom, bottom: bottomBarTop, duration: 0.35)
    }

    /// Markierung oder Ziel an einem Suchtreffer anlegen; der Editor öffnet sich, sobald das Suchfenster zu ist.
    func create(_ kind: PlaceableKind, at point: GeoPoint, title: String, delayed: Bool = true) {
        show(SearchPin(point: point, title: title))
        searchPin = nil
        Task {
            if delayed { try? await Task.sleep(for: .milliseconds(450)) }
            switch kind {
            case .shape(let shape):
                var object = draft(shape, [point])
                if shape == .marker || shape == .text { object.titel = String(title.prefix(80)) }
                editor = EditorContext(id: LageStore.newId(), object: object, isNew: true)
            case .target(let art):
                var target = Target(art: art)
                target.standort = TimedPoint(point)
                if art == .objekt { target.anschrift = String(title.prefix(200)) }
                targetEditor = TargetEditorContext(id: LageStore.newId(), target: target, isNew: true)
            }
        }
    }

    /// Bestehende Markierungen öffnen erst die Ansicht; bearbeitet wird über deren Bearbeiten-Knopf.
    func openEditor(for id: String) {
        guard tapMode == .none, lage.mapObjects[id] != nil else { return }
        tapMarker = nil
        present(.object(id), low: false)
    }

    /// Wie die Vorschau beim Setzen aussieht: schon wie das spätere Symbol.
    func previewLook(at point: GeoPoint) -> PlacementPreview.Look {
        switch tapMode {
        case .newTarget(let art):
            return .target(Target(art: art))
        case .drawing(let shape, _) where shape == .marker || shape == .fahndungsraum || shape == .haltestellen || shape == .haltestelle:
            return .object(draft(shape, [point]))
        default:
            return .pin
        }
    }
}
