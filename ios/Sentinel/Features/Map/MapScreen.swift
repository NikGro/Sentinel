import MapKit
import SwiftUI

/// Was auf der Karte angetippt wurde und als Kurzübersicht erscheint.
enum MapSelection: Identifiable, Hashable {
    case member(String)
    case vehicle(String)
    case target(String)
    case lastKnown

    var id: String {
        switch self {
        case .member(let id): "member-\(id)"
        case .vehicle(let id): "vehicle-\(id)"
        case .target(let id): "target-\(id)"
        case .lastKnown: "lkp"
        }
    }
}

/// Was ein Tipp auf die Karte gerade bewirkt.
enum MapTapMode: Equatable {
    case none
    case drawing(MapObject.Shape, points: [GeoPoint])
    case moving(objectId: String)
    case placingLastKnown

    var hint: String? {
        switch self {
        case .none: nil
        case .drawing(let shape, let points):
            shape.isMultiPoint ? "\(shape.title): Punkte antippen (\(points.count) gesetzt)" : "\(shape.title): Ort antippen"
        case .moving: "Neuen Ort antippen"
        case .placingLastKnown: "Letzten bekannten Standort antippen"
        }
    }
}

struct EditorContext: Identifiable {
    let id: String
    let object: MapObject
    let isNew: Bool
}

/// Die Lagekarte: Kräfte, Fahrzeuge, Zielpersonen, Markierungen und die Werkzeuge des jeweiligen Modus.
struct MapScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(LageStore.self) private var lage
    @Environment(LocalSettings.self) private var settings
    @Environment(FahndungStore.self) private var fahndung
    @Environment(RouteFollower.self) private var route
    @Environment(LocationService.self) private var location

    @State private var camera: MapCameraPosition = .userLocation(
        fallback: .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 53.5511, longitude: 9.9937), latitudinalMeters: 12_000, longitudinalMeters: 12_000))
    )
    @State private var selection: MapSelection?
    @State private var tapMode: MapTapMode = .none
    @State private var editor: EditorContext?
    @State private var showsLayers = false
    @State private var pendingMode: Modus?
    @State private var now = Date.now

    private var modus: Modus { lage.operation.modus }

    var body: some View {
        MapReader { proxy in
            Map(position: $camera) {
                UserAnnotation()
                CoverageLayer(segments: coverageSegments)
                ReachLayer(rings: reachRings)
                MapObjectsLayer(lines: objects(.linie), areas: objects(.flaeche), circles: objects(.kreis), handles: handles) { id in
                    openEditor(for: id)
                }
                RouteLayer(lines: routeLines)
                LastKnownLayer(pins: lastKnownPins, faded: modus != .fahndung) { selection = .lastKnown }
                VehiclesLayer(pins: vehiclePins) { selection = .vehicle($0) }
                TargetsLayer(pins: targetPins) { selection = .target($0) }
                MembersLayer(pins: memberPins) { selection = .member($0) }
                DraftLayer(points: draftPoints, outline: draftOutline)
            }
            .mapStyle(settings.mapStyleIsSatellite ? .hybrid(pointsOfInterest: .all, showsTraffic: true) : .standard(pointsOfInterest: .all, showsTraffic: true))
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .onTapGesture { point in
                guard tapMode != .none, let coordinate = proxy.convert(point, from: .local) else { return }
                handleTap(GeoPoint(coordinate))
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { topArea }
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomArea }
        .overlay(alignment: .trailing) { sideButtons }
        .sheet(item: $selection) { selection in
            QuickLookSheet(selection: selection) { tapMode = .placingLastKnown }
                .presentationDetents([.medium, .large])
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        }
        .sheet(item: $editor) { context in
            MapObjectEditor(context: context) { objectId in
                tapMode = .moving(objectId: objectId)
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showsLayers) {
            LayerSheet()
                .presentationDetents([.medium, .large])
        }
        .confirmationDialog(
            "Modus für alle auf „\(pendingMode?.title ?? "")“ ändern?",
            isPresented: Binding(get: { pendingMode != nil }, set: { if !$0 { pendingMode = nil } }),
            titleVisibility: .visible
        ) {
            Button("Modus wechseln") {
                if let pendingMode { lage.setMode(pendingMode) }
            }
        } message: {
            Text(pendingMode?.summary ?? "")
        }
        .task(id: lage.coverageGeneration) {
            if modus == .fahndung { await fahndung.reloadCoverage() } else { fahndung.clearCoverage() }
        }
        .task(id: ReachKey(origin: lage.operation.lkp, modes: enabledReachModes, active: modus == .fahndung && lage.hasSnapshot)) {
            if modus == .fahndung {
                fahndung.trackReach(origin: lage.operation.lkp, modes: enabledReachModes)
            } else {
                fahndung.stopReach()
            }
        }
        .task {
            // Minutentakt für Altersangaben (z. B. "seit 12 Min.") und veraltete Positionen.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(20))
                now = .now
            }
        }
        .onChange(of: modus) { _, newValue in
            if newValue != .observation, route.target == .aPosition { route.stop() }
            if case .placingLastKnown = tapMode, newValue != .fahndung { tapMode = .none }
        }
        .sensoryFeedback(.impact, trigger: lage.operation.a?.memberId)
    }

    private struct ReachKey: Equatable {
        let origin: OperationState.LastKnownPosition?
        let modes: [ReachMode]
        let active: Bool
    }

    // MARK: Obere Leiste

    private var topArea: some View {
        VStack(spacing: 8) {
            Picker("Modus", selection: Binding(get: { modus }, set: { if $0 != modus { pendingMode = $0 } })) {
                ForEach(Modus.allCases) { modus in
                    Text(modus.title).tag(modus)
                }
            }
            .pickerStyle(.segmented)
            .padding(4)
            .glassEffect(.regular, in: .capsule)
            .padding(.horizontal, 16)

            if route.isActive {
                RouteBanner()
                    .padding(.horizontal, 16)
            }

            if let hint = tapMode.hint {
                HStack(spacing: 12) {
                    Label(hint, systemImage: "hand.tap.fill")
                        .font(.footnote.weight(.semibold))
                    Spacer(minLength: 0)
                    if case .drawing(let shape, let points) = tapMode, shape.isMultiPoint {
                        Button("Fertig") { finishDrawing(shape, points) }
                            .disabled(points.count < shape.minimumPoints)
                            .fontWeight(.semibold)
                    }
                    Button("Abbrechen", systemImage: "xmark.circle.fill") { tapMode = .none }
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .glassEffect(.regular.tint(.yellow.opacity(0.25)), in: .rect(cornerRadius: 16))
                .padding(.horizontal, 16)
            }
        }
        .padding(.top, 4)
        .animation(.snappy, value: tapMode)
        .animation(.snappy, value: route.isActive)
    }

    // MARK: Seitliche Knöpfe

    private var sideButtons: some View {
        GlassEffectContainer(spacing: 10) {
            VStack(spacing: 10) {
                MapRoundButton(title: "Ebenen", symbol: "square.3.layers.3d") { showsLayers = true }
                MapRoundButton(title: settings.mapStyleIsSatellite ? "Standardkarte" : "Satellitenbild", symbol: settings.mapStyleIsSatellite ? "map" : "globe.europe.africa") {
                    settings.mapStyleIsSatellite.toggle()
                }
                MapRoundButton(title: "Eigener Standort", symbol: "location.fill") {
                    withAnimation { camera = .userLocation(fallback: .automatic) }
                }
                if modus == .observation, let a = lage.aPosition {
                    MapRoundButton(title: "A-Position zeigen", symbol: "a.circle.fill", tint: Theme.aPosition) {
                        withAnimation { camera = .region(MKCoordinateRegion(center: a.point.coordinate, latitudinalMeters: 800, longitudinalMeters: 800)) }
                    }
                }
            }
        }
        .padding(.trailing, 12)
    }

    // MARK: Untere Leiste

    private var bottomArea: some View {
        VStack(spacing: 8) {
            switch modus {
            case .observation:
                APositionControl()
            case .fahndung:
                FahndungControl(now: now, placeLastKnown: { tapMode = .placingLastKnown })
            case .oberflaeche:
                EmptyView()
            }
            DrawingToolbar { shape in
                tapMode = .drawing(shape, points: [])
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .animation(.snappy, value: modus)
    }

    // MARK: Tippen und Zeichnen

    private func handleTap(_ point: GeoPoint) {
        switch tapMode {
        case .none:
            break
        case .placingLastKnown:
            lage.setLastKnownPosition(point, targetId: lage.operation.lkp?.targetId)
            tapMode = .none
        case .moving(let objectId):
            guard var object = lage.mapObjects[objectId]?.data else {
                tapMode = .none
                return
            }
            let anchor = object.anchor
            let dLat = point.lat - anchor.lat
            let dLon = point.lon - anchor.lon
            object.punkte = object.punkte.map { GeoPoint(lat: $0.lat + dLat, lon: $0.lon + dLon) }
            lage.saveMapObject(object, id: objectId)
            tapMode = .none
        case .drawing(let shape, var points):
            points.append(point)
            if shape.isMultiPoint {
                tapMode = .drawing(shape, points: points)
            } else {
                finishDrawing(shape, points)
            }
        }
    }

    private func finishDrawing(_ shape: MapObject.Shape, _ points: [GeoPoint]) {
        guard points.count >= shape.minimumPoints else { return }
        tapMode = .none
        let object = MapObject(layerId: Layer.lageId, typ: shape, punkte: points, radius: shape == .kreis ? 150 : nil)
        editor = EditorContext(id: LageStore.newId(), object: object, isNew: true)
    }

    private func openEditor(for id: String) {
        guard tapMode == .none, let object = lage.mapObjects[id] else { return }
        editor = EditorContext(id: id, object: object.data, isNew: false)
    }

    // MARK: Aufbereitung für die Karte

    private var visibleObjects: [Versioned<MapObject>] {
        lage.mapObjects.values.filter { !settings.hiddenLayers.contains($0.data.layerId) && lage.layers[$0.data.layerId] != nil }
    }

    private func objects(_ shape: MapObject.Shape) -> [Versioned<MapObject>] {
        visibleObjects.filter { $0.data.typ == shape && $0.data.punkte.count >= shape.minimumPoints }
    }

    /// Antippbare Griffe. Prognosezellen (mit Kennwert) bekommen keinen, sonst würde die Karte überladen.
    private var handles: [Versioned<MapObject>] {
        visibleObjects.filter { $0.data.wert == nil && !$0.data.punkte.isEmpty }
    }

    private var memberPins: [MemberPin] {
        lage.sortedMembers.compactMap { member in
            guard let position = lage.positions[member.id] else { return nil }
            let isA = modus == .observation && lage.operation.a?.memberId == member.id
            // Der eigene Standort erscheint als blauer Punkt; ein eigener Marker nur, wenn man selbst die A hält.
            if member.id == lage.selfId, !isA { return nil }
            return MemberPin(
                id: member.id,
                callsign: member.data.funkrufname,
                coordinate: position.point.coordinate,
                isA: isA,
                isStale: !lage.isOnline(member.id) || now.timeIntervalSince(position.date) > 120,
                inVehicle: member.data.fahrzeugId != nil
            )
        }
    }

    private var vehiclePins: [SymbolPin] {
        lage.sortedVehicles.compactMap { vehicle in
            // Besetzte Fahrzeuge ohne eigenen Tracker zeigt bereits der Marker der Besatzung.
            let occupied = !lage.occupants(of: vehicle.id).isEmpty
            guard let position = lage.position(ofVehicle: vehicle), !occupied || position.source == "Tracker" else { return nil }
            let title = vehicle.data.kennzeichen.isEmpty ? vehicle.data.bezeichnung : vehicle.data.kennzeichen
            return SymbolPin(id: vehicle.id, title: title, subtitle: position.source, coordinate: position.point.coordinate)
        }
    }

    private var targetPins: [SymbolPin] {
        lage.sortedTargets.compactMap { target in
            guard let position = lage.position(ofTarget: target) else { return nil }
            return SymbolPin(id: target.id, title: target.data.displayName, subtitle: "", coordinate: position.point.coordinate)
        }
    }

    private var lastKnownPins: [SymbolPin] {
        guard modus != .oberflaeche, let lkp = lage.operation.lkp else { return [] }
        return [SymbolPin(id: "lkp", title: "Letzter Standort", subtitle: "Zuletzt \(Format.time(lkp.date))", coordinate: lkp.point.coordinate)]
    }

    private var enabledReachModes: [ReachMode] {
        ReachMode.allCases.filter(settings.isReachEnabled)
    }

    private var reachRings: [ReachRing] {
        guard modus == .fahndung else { return [] }
        return fahndung.reachAreas
            .filter { settings.isReachEnabled($0.modus) }
            .flatMap { area in
                area.ringe.enumerated().map { index, ring in
                    ReachRing(
                        id: "\(area.modus.rawValue)-\(index)",
                        mode: area.modus,
                        coordinates: ring.filter { $0.count >= 2 }.map { CLLocationCoordinate2D(latitude: $0[0], longitude: $0[1]) }
                    )
                }
            }
    }

    private var coverageSegments: [CoverageSegment] {
        guard modus == .fahndung, settings.showsCoverage else { return [] }
        return fahndung.segments.filter { $0.points.count > 1 }
    }

    private var routeLines: [RouteLine] {
        route.route.map { [RouteLine(polyline: $0.polyline)] } ?? []
    }

    private var draftPoints: [DraftPoint] {
        guard case .drawing(_, let points) = tapMode else { return [] }
        return points.enumerated().map { DraftPoint(id: $0.offset, coordinate: $0.element.coordinate) }
    }

    private var draftOutline: [RouteLine] {
        guard case .drawing(_, let points) = tapMode, points.count > 1 else { return [] }
        let coordinates = points.map(\.coordinate)
        return [RouteLine(polyline: MKPolyline(coordinates: coordinates, count: coordinates.count))]
    }
}

/// Runder Glasknopf am Kartenrand.
struct MapRoundButton: View {
    let title: String
    let symbol: String
    var tint: Color = .primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
        }
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel(title)
    }
}
