import MapKit
import SwiftUI

// Aufbereitung der Lage für die Karte: sichtbare Objekte, Symbole, Flächen und Routen.

extension MapScreen {
    // MARK: Aufbereitung für die Karte

    /// Sonderbereich (dauerhafte Orte oder Paket): nur Werkzeuge zum Anlegen und Bearbeiten, kein Einsatzbetrieb.
    var reducedTools: Bool { model.editsPermanentLayer || lage.isPackageArea }

    /// Nur geladene Ebenen erscheinen auf der Karte; Entwürfe bleiben in der Ebenenliste.
    var visibleObjects: [Versioned<MapObject>] {
        lage.mapObjects.values.filter { object in
            // Beim Bearbeiten der dauerhaften Orte ist nur diese Ebene zu sehen.
            if model.editsPermanentLayer, object.data.layerId != Layer.dauerhaftId { return false }
            guard let layer = lage.layers[object.data.layerId], !object.data.isExpired() else { return false }
            return layer.data.isLive && !settings.hiddenLayers.contains(object.data.layerId)
        }
    }

    func objects(_ shape: MapObject.Shape) -> [Versioned<MapObject>] {
        visibleObjects.filter { $0.data.typ == shape && $0.data.punkte.count >= shape.minimumPoints }
    }

    /// Antippbare Griffe. Prognosezellen (mit Kennwert) bekommen keinen, sonst würde die Karte überladen.
    var handles: [ObjectHandle] {
        // Die Standortspur hat keinen eigenen Punkt: Die Linie selbst ist das Objekt und antippbar.
        visibleObjects.filter { $0.data.wert == nil && !$0.data.punkte.isEmpty && $0.data.typ.hasHandle && !$0.data.isOwnTrack }.map { object in
            ObjectHandle(
                id: object.id,
                object: object.data,
                coordinate: lage.position(ofObject: object.data).coordinate,
                locked: !settings.canEdit(layerId: object.data.layerId)
            )
        }
    }

    var forcePins: [ForcePin] {
        var pins: [ForcePin] = []
        var crews: [String: (names: [String], position: Position, isA: Bool, stale: Bool)] = [:]
        guard !reducedTools else { return [] }
        for member in lage.activeMembers {
            guard let position = lage.positions[member.id] else { continue }
            let isA = lage.operation.a?.memberId == member.id
            let stale = !lage.isOnline(member.id) || now.timeIntervalSince(position.date) > 120
            if let vehicle = lage.vehicle(of: member.data) {
                // Das eigene Fahrzeug zeigt der eigene Standort, kein zweites Symbol darüber.
                if let me = lage.me, lage.vehicle(of: me.data)?.id == vehicle.id { continue }
                var crew = crews[vehicle.id] ?? (names: [], position: position, isA: false, stale: true)
                crew.names.append(member.data.spitzname)
                if position.ts > crew.position.ts { crew.position = position }
                crew.isA = crew.isA || isA
                crew.stale = crew.stale && stale
                crews[vehicle.id] = crew
                continue
            }
            // Der eigene Standort hat sein eigenes Symbol (mit A, falls man sie hält).
            if member.id == lage.selfId { continue }
            pins.append(ForcePin(
                id: member.id,
                label: lage.label(of: member.data),
                coordinate: position.point.coordinate,
                isA: isA,
                isStale: stale,
                symbol: member.data.fortbewegung.symbolName,
                target: .member(member.id)
            ))
        }
        for (vehicleId, crew) in crews {
            guard let vehicle = lage.vehicles[vehicleId] else { continue }
            let point = lage.position(ofVehicle: vehicle)?.point ?? crew.position.point
            pins.append(ForcePin(
                id: "fz-\(vehicleId)",
                // Funkrufname und wer drinsitzt, z. B. „P 35/24 (Falke, Adler)“.
                label: "\(vehicle.data.funkrufname) (\(crew.names.joined(separator: ", ")))",
                coordinate: point.coordinate,
                isA: crew.isA,
                isStale: crew.stale,
                symbol: "car.fill",
                target: .vehicle(vehicleId)
            ))
        }
        return pins
    }

    var vehiclePins: [SymbolPin] {
        guard !reducedTools else { return [] }
        return lage.activeVehicles.compactMap { vehicle in
            guard lage.occupants(of: vehicle.id).isEmpty, let position = lage.position(ofVehicle: vehicle) else { return nil }
            return SymbolPin(id: vehicle.id, title: vehicle.data.funkrufname, symbol: Fortbewegung.fahrzeug.symbolName, color: Theme.force, coordinate: position.point.coordinate, selection: .vehicle(vehicle.id))
        }
    }

    /// Ziele als rote Symbole. Eine Zielperson in einem Zielfahrzeug oder Gebäude hat kein eigenes Symbol: Sie steckt
    /// darin, dessen Beschriftung ihren Namen trägt (wie bei den Kräften: „HH-AB 123 (Max)“). Im ÖPNV steht sie mit
    /// Bahnsymbol am Fahrzeug, beschriftet mit Name und Linie („Max (S1)“).
    var targetPins: [SymbolPin] {
        guard !model.editsPermanentLayer else { return [] }
        return lage.sortedTargets.compactMap { target in
            guard !settings.hiddenTargetKinds.contains(target.data.art.rawValue), lage.isTargetVisible(target.id) else { return nil }
            if let binding = target.data.bindung, binding.art == .fahrzeug || binding.art == .objekt, let id = binding.zielId, lage.targets[id] != nil { return nil }
            // Im ÖPNV-Fahrzeug zeichnet die ÖPNV-Ebene die Zielperson an der geglätteten Fahrzeugposition.
            if let binding = target.data.bindung, binding.art == .oepnv, let id = binding.zielId, let vehicle = lage.mapObjects[id]?.data,
               vehicle.typ == .oepnvfahrzeug || vehicle.hasRealVehicle, Self.transitVehicleShown(vehicle, at: .now) { return nil }
            guard let position = lage.position(ofTarget: target) else { return nil }
            return SymbolPin(id: target.id, title: targetLabel(target), symbol: target.data.mapSymbol, color: Theme.target, coordinate: position.point.coordinate, selection: .target(target.id))
        }
    }

    /// Wird das ÖPNV-Fahrzeug gerade gezeichnet (fünf Minuten vor Abfahrt bis fünf nach Ankunft)? Gleiche Regel wie in
    /// `transitPins`; sonst bleibt die Zielperson mit eigenem Symbol stehen.
    static func transitVehicleShown(_ object: MapObject, at date: Date) -> Bool {
        guard let times = object.fahrt?.zeiten.compactMap({ $0 }), let start = times.first, let end = times.last else { return true }
        let t = date.timeIntervalSince1970 * 1000
        let margin = TransitSimulation.standing * 1000
        return t >= start - margin && t <= end + margin
    }

    /// Beschriftung eines Ziels auf der Karte.
    func targetLabel(_ target: Versioned<Target>) -> String {
        let data = target.data
        if data.bindung?.art == .oepnv, let id = data.bindung?.zielId, let line = lage.mapObjects[id]?.data.linie {
            return "\(data.displayName) (\(line.ref))"
        }
        let inside = lage.passengers(of: target.id).map(\.data.displayName)
        let name = data.art == .fahrzeug && !data.kennzeichen.isEmpty ? data.kennzeichen : data.displayName
        return inside.isEmpty ? name : "\(name) (\(inside.joined(separator: ", ")))"
    }

    var stopCircles: [(point: GeoPoint, radius: Double)] {
        objects(.haltestellen).compactMap { object in
            object.data.punkte.first.map { (point: $0, radius: object.data.radius ?? 500) }
        }
    }

    /// Ziel-Haltestelle der laufenden Navigation (überschlagend oder „Halte voraus“), sonst keine.
    var highlightedStops: [HighlightedStop] {
        guard route.isActive, let target = route.target else { return [] }
        let stop: (point: GeoPoint, name: String)?
        switch target {
        case .leapfrog:
            stop = lage.myLeapfrogStop.map { ($0.point, $0.name) }
        case .ahead:
            stop = route.destination.map { ($0, route.title) }
        default:
            stop = nil
        }
        guard let stop else { return [] }
        return [HighlightedStop(point: stop.point, name: stop.name, onMap: stopSymbolExists(near: stop.point))]
    }

    /// Steht nahe der Stelle schon ein Haltestellensymbol (angelegte Haltestelle, Halte einer ÖPNV-Strecke oder
    /// Haltestellen im Umkreis)?
    func stopSymbolExists(near point: GeoPoint) -> Bool {
        let radius = 30.0
        if objects(.haltestelle).contains(where: { $0.data.anchor.distance(to: point) < radius }) { return true }
        if objects(.oepnvlinie).contains(where: { $0.data.showsStops && $0.data.punkte.contains { $0.distance(to: point) < radius } }) { return true }
        return nearbyStops.contains { $0.point.distance(to: point) < radius }
    }

    var nearbyStops: [NearbyStop] {
        var seen = Set<String>()
        return stopCircles.flatMap { fahndung.nearbyStops[FahndungStore.stopsKey($0.point, radius: $0.radius)] ?? [] }
            .filter { seen.insert($0.id).inserted }
    }

    var enabledReachModes: [ReachMode] {
        ReachMode.allCases.filter(settings.isReachEnabled)
    }

    var reachInputs: [FahndungStore.ReachInput] {
        objects(.fahndungsraum).compactMap { object in
            guard let since = object.data.since, let point = object.data.punkte.first else { return nil }
            return FahndungStore.ReachInput(id: object.id, point: point, since: since)
        }
    }

    var reachRings: [ReachRing] {
        fahndung.reachAreas.flatMap { roomId, areas in
            areas.filter { settings.isReachEnabled($0.modus) }.flatMap { area in
                area.ringe.enumerated().map { index, ring in
                    ReachRing(
                        id: "\(roomId)-\(area.modus.rawValue)-\(index)",
                        mode: area.modus,
                        coordinates: ring.filter { $0.count >= 2 }.map { CLLocationCoordinate2D(latitude: $0[0], longitude: $0[1]) }
                    )
                }
            }
        }
    }

    var coverageSegments: [CoverageSegment] {
        guard settings.showsCoverage else { return [] }
        return fahndung.segments.filter { $0.points.count > 1 }
    }

    var draftPoints: [DraftPoint] {
        guard case .drawing(_, let points) = tapMode else { return [] }
        return points.enumerated().map { DraftPoint(id: $0.offset, coordinate: $0.element.coordinate) }
    }

    var draftOutline: [RouteLine] {
        guard case .drawing(_, let points) = tapMode, points.count > 1 else { return [] }
        let coordinates = points.map(\.coordinate)
        return [RouteLine(polyline: MKPolyline(coordinates: coordinates, count: coordinates.count), specialRights: false)]
    }
}
