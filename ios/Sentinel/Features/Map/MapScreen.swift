import MapKit
import SwiftUI

/// Was auf der Karte angetippt wurde und als Kurzübersicht erscheint.
enum MapSelection: Identifiable, Hashable {
    case member(String)
    case vehicle(String)
    case target(String)

    var id: String {
        switch self {
        case .member(let id): "member-\(id)"
        case .vehicle(let id): "vehicle-\(id)"
        case .target(let id): "target-\(id)"
        }
    }
}

/// Was ein Tipp auf die Karte gerade bewirkt.
enum MapTapMode: Equatable {
    case none
    case drawing(MapObject.Shape, points: [GeoPoint])
    case moving(objectId: String)
    /// Neues Ziel (Person, Fahrzeug, Objekt) an der getippten Stelle anlegen.
    case newTarget(ZielArt)
    /// Standort eines bestehenden Ziels neu setzen.
    case placingTarget(String)

    var hint: String? {
        switch self {
        case .none: nil
        case .drawing(let shape, let points):
            shape.isMultiPoint ? "\(shape.title): Punkte antippen (\(points.count) gesetzt)" : "\(shape.title): Ort antippen"
        case .moving: "Neuen Ort antippen"
        case .newTarget(let art): "\(art.title): Standort antippen"
        case .placingTarget: "Neuen Standort des Ziels antippen"
        }
    }
}

struct EditorContext: Identifiable {
    let id: String
    let object: MapObject
    let isNew: Bool
}

/// Die Lagekarte: Kräfte, Fahrzeuge, Ziele, Markierungen und eine Navigation wie in einer Navi-App.
struct MapScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(LageStore.self) private var lage
    @Environment(LocalSettings.self) private var settings
    @Environment(FahndungStore.self) private var fahndung
    @Environment(RouteFollower.self) private var route
    @Environment(LocationService.self) private var location
    @Environment(LocationContext.self) private var locationContext

    @State private var camera: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var selection: MapSelection?
    @State private var tapMode: MapTapMode = .none
    @State private var editor: EditorContext?
    @State private var targetEditor: TargetEditorContext?
    @State private var showsLayers = false
    @State private var mobilityChoice: Fortbewegung?
    @State private var searchMode: SearchSheet.Mode?
    @State private var showsSituation = false
    @State private var cameraState = MapCameraState()
    /// In der Navi-Ansicht folgt die Kamera nah und in Fahrtrichtung, bis man die Karte selbst verschiebt.
    @State private var navigationFollows = true
    @State private var now = Date.now
    @State private var topAreaHeight: CGFloat = 60

    var body: some View {
        MapReader { proxy in
            Map(position: $camera) {
                UserAnnotation()
                CoverageLayer(segments: coverageSegments)
                ReachLayer(rings: reachRings)
                MapObjectsLayer(lines: objects(.linie), areas: objects(.flaeche), circles: objects(.kreis) + objects(.haltestellen), handles: handles) { id in
                    openEditor(for: id)
                }
                NearbyStopsLayer(stops: nearbyStops)
                RouteLayer(lines: routeLines)
                StopsLayer(stops: lage.operation.ueberschlagen.naechste, mine: lage.myLeapfrogStop)
                SymbolLayer(pins: vehiclePins + targetPins) { selection = $0 }
                ForcesLayer(pins: forcePins) { selection = $0 }
                DraftLayer(points: draftPoints, outline: draftOutline)
                streetLabel
            }
            .mapStyle(mapStyle)
            .mapControls {
                MapScaleView()
            }
            .onMapCameraChange(frequency: .continuous) { context in cameraState.update(context.camera) }
            .simultaneousGesture(DragGesture(minimumDistance: 12).onChanged { _ in
                if route.isActive { navigationFollows = false }
            })
            .onTapGesture { point in
                guard tapMode != .none, let coordinate = proxy.convert(point, from: .local) else { return }
                handleTap(GeoPoint(coordinate))
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { topArea }
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomArea }
        .overlay(alignment: .topTrailing) { sideButtons }
        .sheet(item: $selection) { selection in
            QuickLookSheet(selection: selection) { targetId in
                tapMode = .placingTarget(targetId)
            }
            .presentationDetents([.medium, .large])
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        }
        .sheet(item: $editor) { context in
            MapObjectEditor(context: context) { objectId in
                tapMode = .moving(objectId: objectId)
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $targetEditor) { context in
            TargetEditor(context: context)
        }
        .sheet(isPresented: $showsLayers) {
            LayerSheet()
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $searchMode) { mode in
            SearchSheet(mode: mode) { target in
                model.navigate(to: target)
            }
            .presentationDetents([.large])
        }
        .sheet(item: $mobilityChoice) { mode in
            MobilitySheet(initialMode: mode)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showsSituation) {
            SituationSheet()
        }
        .task(id: CoverageKey(enabled: settings.showsCoverage, generation: lage.coverageGeneration)) {
            guard settings.showsCoverage else {
                fahndung.clearCoverage()
                return
            }
            while !Task.isCancelled {
                await fahndung.reloadCoverage()
                try? await Task.sleep(for: .seconds(60))
            }
        }
        .task(id: reachInputs.map { "\($0.id)|\($0.since.timeIntervalSince1970)|\($0.point.lat)|\($0.point.lon)" }.joined() + enabledReachModes.map(\.rawValue).joined()) {
            fahndung.trackReach(reachInputs, modes: enabledReachModes)
        }
        .task {
            // Takt für Altersangaben und veraltete Positionen.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(20))
                now = .now
            }
        }
        .task(id: stopCircles.map { FahndungStore.stopsKey($0.point, radius: $0.radius) }.joined(separator: ";")) {
            await fahndung.loadStops(for: stopCircles)
        }
        .onChange(of: route.isActive) { _, active in
            navigationFollows = true
            if active { followForNavigation(animated: true) } else { camera = .userLocation(followsHeading: false, fallback: .automatic) }
        }
        .onChange(of: location.current?.timestamp) { _, _ in
            if route.isActive, navigationFollows { followForNavigation(animated: true) }
        }
        .sensoryFeedback(.impact, trigger: lage.operation.a?.memberId)
    }

    private struct CoverageKey: Equatable {
        let enabled: Bool
        let generation: Int
    }

    private var mapStyle: MapStyle {
        switch settings.mapStyle {
        case .standard: .standard(elevation: .realistic, pointsOfInterest: .all, showsTraffic: settings.showsTraffic)
        case .hybrid: .hybrid(elevation: .realistic, pointsOfInterest: .all, showsTraffic: settings.showsTraffic)
        case .satellit: .imagery(elevation: .realistic)
        }
    }

    private var isFollowing: Bool { camera.followsUserLocation }

    // MARK: Statuszeile unter dem eigenen Standort

    /// Straße und Fahrtrichtung direkt unter dem eigenen Punkt. Als Kartenannotation bewegt sie sich mit der Karte,
    /// ohne dass die Ansicht bei jeder Kamerabewegung neu berechnet werden muss.
    @MapContentBuilder private var streetLabel: some MapContent {
        if isFollowing || route.isActive, let summary = locationContext.summary, let current = location.current {
            Annotation("Eigener Standort", coordinate: current.coordinate, anchor: .top) {
                Text(summary)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .glassEffect(.regular, in: .capsule)
                    .fixedSize()
                    .padding(.top, 22)
                    .allowsHitTesting(false)
                    .accessibilityLabel("Eigener Standort: \(summary)")
            }
            .annotationTitles(.hidden)
        }
    }

    // MARK: Obere Leiste

    private var topArea: some View {
        VStack(spacing: 8) {
            if route.isActive {
                NavigationBanner()
            } else {
                HStack(spacing: Theme.barSpacing) {
                Button { searchMode = .adresse } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                        Text("Suchen oder navigieren")
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .font(.body)
                    .padding(.horizontal, 18)
                    .frame(height: Theme.barHeight)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .capsule)
                .accessibilityLabel("Suchen oder navigieren")
                    MapRoundButton(title: "Zu Objekten navigieren", symbol: "location.viewfinder", prominent: true) { searchMode = .objekte }
                }
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
            }
        }
        .padding(.horizontal, Theme.barInset)
        .padding(.top, 4)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { topAreaHeight = $0 }
        .animation(.snappy, value: tapMode)
        .animation(.snappy, value: route.isActive)
    }

    // MARK: Knöpfe am rechten Rand, direkt unter dem Kompass

    private var sideButtons: some View {
        GlassEffectContainer(spacing: Theme.barSpacing) {
            VStack(spacing: Theme.barSpacing) {
                AddMenu { action in
                    switch action {
                    case .shape(let shape): tapMode = .drawing(shape, points: [])
                    case .target(let art): tapMode = .newTarget(art)
                    }
                }
                MapStyleButton(state: cameraState) { pitch in
                    withAnimation { camera = .camera(cameraState.camera(pitch: pitch)) }
                }
                MapRoundButton(title: "Ebenen", symbol: "square.3.layers.3d") { showsLayers = true }
                MapRoundButton(title: isFollowing ? "Standort folgt" : "Eigener Standort", symbol: isFollowing || (route.isActive && navigationFollows) ? "location.fill" : "location") {
                    if route.isActive {
                        navigationFollows = true
                        followForNavigation(animated: true)
                    } else {
                        withAnimation { camera = .userLocation(followsHeading: isFollowing, fallback: .automatic) }
                    }
                }
                if let a = lage.aPosition, !lage.holdsA {
                    Button {
                        withAnimation { camera = .region(MKCoordinateRegion(center: a.point.coordinate, latitudinalMeters: 800, longitudinalMeters: 800)) }
                    } label: {
                        ASymbol(size: 28)
                            .frame(width: Theme.roundButton, height: Theme.roundButton)
                            .contentShape(.circle)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .accessibilityLabel("A-Position zeigen")
                }
                CompassButton(state: cameraState) {
                    withAnimation { camera = .camera(cameraState.camera(heading: 0)) }
                }
            }
        }
        .padding(.trailing, Theme.barInset)
        .padding(.top, topAreaHeight + Theme.barSpacing)
    }

    /// Navi-Kamera: nah am eigenen Standort, in Fahrtrichtung gedreht, je nach Tempo etwas weiter heraus.
    private func followForNavigation(animated: Bool) {
        guard let current = location.current else {
            camera = .userLocation(followsHeading: true, fallback: .automatic)
            return
        }
        let speed = max(current.speed, 0)
        let distance = min(max(350 + speed * 28, 350), 1400)
        let heading = current.course >= 0 && speed > 1 ? current.course : cameraState.heading
        let next = MapCamera(centerCoordinate: current.coordinate, distance: distance, heading: heading, pitch: 55)
        if animated {
            withAnimation(.easeInOut(duration: 0.8)) { camera = .camera(next) }
        } else {
            camera = .camera(next)
        }
    }

    // MARK: Untere Leiste

    private var bottomArea: some View {
        VStack(spacing: Theme.barSpacing) {
            if route.isActive {
                NavigationBottomBar()
            } else {
                APositionControl()
                MobilityControl { mobilityChoice = $0 }
            }
            SituationBar { showsSituation = true }
        }
        .padding(.horizontal, Theme.barInset)
        .padding(.bottom, Theme.barSpacing)
        .animation(.snappy, value: route.isActive)
    }

    // MARK: Tippen und Zeichnen

    private func handleTap(_ point: GeoPoint) {
        switch tapMode {
        case .none:
            break
        case .placingTarget(let id):
            if var target = lage.targets[id]?.data {
                target.standort = TimedPoint(point)
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
        let isRoom = shape == .fahndungsraum
        let object = MapObject(
            layerId: Layer.lageId,
            typ: shape,
            farbe: isRoom ? "#C97C7C" : shape == .haltestellen ? "#0A84FF" : "#FF9F0A",
            punkte: points,
            radius: shape == .kreis ? 150 : shape == .haltestellen ? 500 : nil,
            zeit: isRoom ? (Date.now.timeIntervalSince1970 * 1000).rounded() : nil
        )
        editor = EditorContext(id: LageStore.newId(), object: object, isNew: true)
    }

    private func openEditor(for id: String) {
        guard tapMode == .none, let object = lage.mapObjects[id] else { return }
        editor = EditorContext(id: id, object: object.data, isNew: false)
    }

    // MARK: Aufbereitung für die Karte

    /// Nur geladene Ebenen erscheinen auf der Karte; Entwürfe bleiben in der Ebenenliste.
    private var visibleObjects: [Versioned<MapObject>] {
        lage.mapObjects.values.filter { object in
            guard let layer = lage.layers[object.data.layerId] else { return false }
            return layer.data.isLive && !settings.hiddenLayers.contains(object.data.layerId)
        }
    }

    private func objects(_ shape: MapObject.Shape) -> [Versioned<MapObject>] {
        visibleObjects.filter { $0.data.typ == shape && $0.data.punkte.count >= shape.minimumPoints }
    }

    /// Antippbare Griffe. Prognosezellen (mit Kennwert) bekommen keinen, sonst würde die Karte überladen.
    private var handles: [ObjectHandle] {
        visibleObjects.filter { $0.data.wert == nil && !$0.data.punkte.isEmpty }.map { object in
            ObjectHandle(
                id: object.id,
                object: object.data,
                coordinate: lage.position(ofObject: object.data).coordinate,
                locked: !settings.canEdit(layerId: object.data.layerId)
            )
        }
    }

    private var forcePins: [ForcePin] {
        var pins: [ForcePin] = []
        var crews: [String: (names: [String], position: Position, isA: Bool, stale: Bool)] = [:]
        for member in lage.activeMembers {
            guard let position = lage.positions[member.id] else { continue }
            let isA = lage.operation.a?.memberId == member.id
            let stale = !lage.isOnline(member.id) || now.timeIntervalSince(position.date) > 120
            if let vehicle = lage.vehicle(of: member.data) {
                var crew = crews[vehicle.id] ?? (names: [], position: position, isA: false, stale: true)
                crew.names.append(member.data.spitzname)
                if position.ts > crew.position.ts { crew.position = position }
                crew.isA = crew.isA || isA
                crew.stale = crew.stale && stale
                crews[vehicle.id] = crew
                continue
            }
            // Der eigene Standort erscheint als blauer Punkt; ein eigener Marker nur, wenn man selbst die A hält.
            if member.id == lage.selfId, !isA { continue }
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

    private var vehiclePins: [SymbolPin] {
        lage.activeVehicles.compactMap { vehicle in
            guard lage.occupants(of: vehicle.id).isEmpty, let position = lage.position(ofVehicle: vehicle) else { return nil }
            return SymbolPin(id: vehicle.id, title: vehicle.data.funkrufname, symbol: "car.fill", color: .indigo, coordinate: position.point.coordinate, selection: .vehicle(vehicle.id))
        }
    }

    private var targetPins: [SymbolPin] {
        lage.sortedTargets.compactMap { target in
            guard let position = lage.position(ofTarget: target) else { return nil }
            return SymbolPin(id: target.id, title: target.data.displayName, symbol: target.data.art.symbolName, color: Theme.target, coordinate: position.point.coordinate, selection: .target(target.id))
        }
    }

    private var stopCircles: [(point: GeoPoint, radius: Double)] {
        objects(.haltestellen).compactMap { object in
            object.data.punkte.first.map { ($0, object.data.radius ?? 500) }
        }
    }

    private var nearbyStops: [NearbyStop] {
        var seen = Set<String>()
        return stopCircles.flatMap { fahndung.nearbyStops[FahndungStore.stopsKey($0.point, radius: $0.radius)] ?? [] }
            .filter { seen.insert($0.id).inserted }
    }

    private var enabledReachModes: [ReachMode] {
        ReachMode.allCases.filter(settings.isReachEnabled)
    }

    private var reachInputs: [FahndungStore.ReachInput] {
        objects(.fahndungsraum).compactMap { object in
            guard let since = object.data.since, let point = object.data.punkte.first else { return nil }
            return FahndungStore.ReachInput(id: object.id, point: point, since: since)
        }
    }

    private var reachRings: [ReachRing] {
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

    private var coverageSegments: [CoverageSegment] {
        guard settings.showsCoverage else { return [] }
        return fahndung.segments.filter { $0.points.count > 1 }
    }

    private var routeLines: [RouteLine] {
        guard let current = route.route, current.coordinates.count > 1 else { return [] }
        return [RouteLine(polyline: MKPolyline(coordinates: current.coordinates, count: current.coordinates.count), specialRights: current.usesSpecialRights)]
    }

    private var draftPoints: [DraftPoint] {
        guard case .drawing(_, let points) = tapMode else { return [] }
        return points.enumerated().map { DraftPoint(id: $0.offset, coordinate: $0.element.coordinate) }
    }

    private var draftOutline: [RouteLine] {
        guard case .drawing(_, let points) = tapMode, points.count > 1 else { return [] }
        let coordinates = points.map(\.coordinate)
        return [RouteLine(polyline: MKPolyline(coordinates: coordinates, count: coordinates.count), specialRights: false)]
    }
}
