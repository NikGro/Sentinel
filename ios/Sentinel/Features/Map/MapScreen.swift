import MapKit
import SwiftUI

/// Was auf der Karte angetippt wurde und als Kurzübersicht erscheint.
enum MapSelection: Identifiable, Hashable {
    case member(String)
    case vehicle(String)
    case target(String)
    /// Angetippte Fläche ohne eigenen Griff, z. B. eine Argus-Prognosezelle.
    case cell(String)

    var id: String {
        switch self {
        case .member(let id): "member-\(id)"
        case .vehicle(let id): "vehicle-\(id)"
        case .target(let id): "target-\(id)"
        case .cell(let id): "cell-\(id)"
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
    @Namespace private var mapScope
    /// In der Navi-Ansicht folgt die Kamera nah und in Fahrtrichtung, bis man die Karte selbst verschiebt.
    /// Fahrmodus: Die Kamera folgt einem selbst gekippt und in Fahrtrichtung; der eigene Pfeil sitzt fest in der Bildmitte.
    /// Wer die Karte verschiebt, beendet ihn; der Standortknopf startet ihn wieder.
    @State private var followsMe = false
    /// Ausrichtung der Karte: Standard ist in Fahrtrichtung.
    @State private var orientation: MapOrientation = .course
    /// Die letzte Kamerabewegung kam vom Finger (nicht von der App): Neigung danach als 2D/3D-Einstellung übernehmen.
    @State private var userMovedCamera = false
    @State private var bottomAreaHeight: CGFloat = 120
    @State private var now = Date.now
    @State private var topAreaHeight: CGFloat = 60

    var body: some View {
        MapReader { proxy in
            Map(position: $camera, scope: mapScope) {
                if !followsMe {
                    MyLocationLayer(lage: lage, route: route, locationService: location, cameraState: cameraState)
                }
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
            }
            .mapStyle(mapStyle)
            .mapControls {
                MapScaleView()
            }
            // Karte bis an den unteren Rand: Apples Rechtshinweis sitzt dann klein unter der Tableiste
            // statt über den Bedienelementen.
            .ignoresSafeArea(.container, edges: .bottom)
            .onMapCameraChange(frequency: .continuous) { context in cameraState.update(context.camera) }
            .simultaneousGesture(DragGesture(minimumDistance: 12).onChanged { _ in
                userMovedCamera = true
                if followsMe { followsMe = false }
            })
            .onMapCameraChange(frequency: .onEnd) { context in
                // Mit zwei Fingern gekippt: Haken bei „3D-Ansicht“ im Kartenstil-Menü mitziehen.
                guard userMovedCamera else { return }
                userMovedCamera = false
                guard orientation != .overview else { return }
                let is3D = context.camera.pitch > 10
                if settings.prefers3D != is3D { settings.prefers3D = is3D }
            }
            // Mit zwei Fingern gedreht: diese Ausrichtung gilt, bis man am Kompass wieder umschaltet.
            .simultaneousGesture(RotateGesture().onEnded { _ in
                orientation = .fixed(cameraState.heading)
            })
            .overlay {
                if followsMe {
                    FollowPuckOverlay(
                        proxy: proxy,
                        state: cameraState,
                        inVehicle: { if case .vehicle = myLocationStyle { true } else { false } }(),
                        holdsA: lage.holdsA,
                        label: locationContext.summary
                    )
                }
            }
            .onTapGesture { point in
                guard let coordinate = proxy.convert(point, from: .local) else { return }
                if tapMode == .none {
                    // Tipp auf eine freie Stelle einer Form. Symbole darüber (Kräfte, Fahrzeuge, Ziele, Marker)
                    // fangen ihren Tipp selbst ab und kommen hier gar nicht erst an.
                    let nearSymbol = symbolCoordinates.contains { symbol in
                        guard let screen = proxy.convert(symbol, to: .local) else { return false }
                        return hypot(screen.x - point.x, screen.y - point.y) < 26
                    }
                    if !nearSymbol, let id = shape(at: GeoPoint(coordinate)), let object = lage.mapObjects[id] {
                        if object.data.wert != nil { selection = .cell(id) } else { openEditor(for: id) }
                    }
                    return
                }
                handleTap(GeoPoint(coordinate))
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { topArea }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomArea
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { bottomAreaHeight = $0 }
        }
        .overlay(alignment: .bottomLeading) {
            if followsMe || route.isActive {
                HStack(spacing: Theme.barSpacing) {
                    if let speed = location.current?.speed, speed >= 0 {
                        SpeedBadge(metersPerSecond: speed)
                    }
                    if route.isActive, let limit = route.speedLimit {
                        SpeedLimitSign(kmh: limit)
                    }
                }
                .padding(.leading, Theme.barInset)
                .padding(.bottom, bottomAreaHeight + Theme.barSpacing)
            }
        }
        .overlay(alignment: .topTrailing) { sideButtons }
        .mapScope(mapScope)
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
        .task(id: CoverageKey(enabled: settings.showsCoverage, since: settings.coverageSince, generation: lage.coverageGeneration)) {
            guard settings.showsCoverage else {
                fahndung.clearCoverage()
                return
            }
            while !Task.isCancelled {
                await fahndung.reloadCoverage(since: settings.coverageSince)
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
            followsMe = true
            followMe(duration: 0.8)
        }
        .task {
            // Beim Öffnen: auf den eigenen Standort, gekippt wie in einer Navi-App.
            for _ in 0..<40 where location.current == nil { try? await Task.sleep(for: .milliseconds(250)) }
            if let current = location.current {
                camera = .camera(MapCamera(centerCoordinate: current.coordinate, distance: 1200, heading: 0, pitch: settings.prefers3D ? 55 : 0))
            }
        }
        .onChange(of: location.current?.timestamp) { _, _ in
            // Gleichmäßig bis zur nächsten Meldung weitergleiten: so bewegt sich die Karte flüssig statt in Sprüngen.
            if followsMe, route.snappedLocation == nil { followMe(duration: 1.0) }
        }
        .onChange(of: route.snappedLocation?.timestamp) { _, _ in
            // In der Navigation folgt die Kamera dem auf die Straße gelegten Standort.
            if followsMe { followMe(duration: 1.0) }
        }
        .sensoryFeedback(.impact, trigger: lage.operation.a?.memberId)
    }

    private struct CoverageKey: Equatable {
        let enabled: Bool
        let since: Double
        let generation: Int
    }

    private var mapStyle: MapStyle {
        switch settings.mapStyle {
        case .standard: .standard(elevation: .realistic, pointsOfInterest: .all, showsTraffic: settings.showsTraffic)
        case .hybrid: .hybrid(elevation: .realistic, pointsOfInterest: .all, showsTraffic: settings.showsTraffic)
        case .satellit: .imagery(elevation: .realistic)
        }
    }

    private var isFollowing: Bool { followsMe }

    // MARK: Statuszeile unter dem eigenen Standort

    /// Wie der eigene Standort erscheint: Navi-Pfeil in der Navigation, Fahrzeug, wenn man drinsitzt, sonst Punkt.
    private var myLocationStyle: MyLocationLayer.Style {
        if route.isActive { return .navigation }
        if let me = lage.me, let vehicle = lage.vehicle(of: me.data) { return .vehicle(callsign: vehicle.data.funkrufname) }
        return .dot
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
                CompassButton(state: cameraState, mode: orientation) { cycleOrientation() }
                MapStyleButton { on in
                    if followsMe {
                        followMe(duration: 0.6)
                    } else {
                        withAnimation(.easeInOut(duration: 0.6)) { camera = .camera(cameraState.camera(pitch: on ? 55 : 0)) }
                    }
                }
                MapRoundButton(title: "Ebenen", symbol: "square.3.layers.3d") { showsLayers = true }
                MapRoundButton(
                    title: "Auf eigenen Standort zentrieren",
                    symbol: followsMe ? "location.circle.fill" : "location.circle"
                ) {
                    if orientation == .overview { orientation = .course }
                    followsMe = true
                    followMe(duration: 0.8)
                }
                if let a = lage.aPosition, !lage.holdsA {
                    Button {
                        withAnimation { camera = .camera(MapCamera(centerCoordinate: a.point.coordinate, distance: 900, heading: 0, pitch: 55)) }
                    } label: {
                        ASymbol(size: 26)
                            .frame(width: Theme.roundButton, height: Theme.roundButton)
                            .contentShape(.circle)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .accessibilityLabel("A-Position zeigen")
                }
                AddMenu { action in
                    switch action {
                    case .shape(let shape): tapMode = .drawing(shape, points: [])
                    case .target(let art): tapMode = .newTarget(art)
                    }
                }
            }
        }
        .padding(.trailing, Theme.barInset)
        .padding(.top, topAreaHeight + Theme.barSpacing)
    }

    /// Kamera auf den eigenen Standort: nah, in Fahrtrichtung, gekippt (falls 3D an), je nach Tempo etwas weiter heraus.
    /// Lineare Animation über die Zeit bis zur nächsten Meldung, damit die Bewegung durchgehend wirkt.
    private func followMe(duration: Double) {
        guard let current = route.snappedLocation ?? location.current else { return }
        if orientation == .overview { orientation = .course }
        let speed = max(location.current?.speed ?? current.speed, 0)
        let distance = route.isActive ? min(max(350 + speed * 28, 350), 1400) : min(max(600 + speed * 20, 600), 1500)
        let heading: CLLocationDirection = switch orientation {
        case .course, .overview: current.course >= 0 && speed > 1 ? current.course : cameraState.heading
        case .north: 0
        case .fixed(let value): value
        }
        let next = MapCamera(centerCoordinate: current.coordinate, distance: distance, heading: heading, pitch: settings.prefers3D ? 55 : 0)
        withAnimation(.linear(duration: duration)) { camera = .camera(next) }
    }

    /// Kompass durchschalten: Fahrtrichtung → Norden → Übersicht (nur mit Route) → Fahrtrichtung.
    private func cycleOrientation() {
        switch orientation {
        case .course:
            orientation = .north
        case .north:
            orientation = route.route != nil ? .overview : .course
        case .overview, .fixed:
            orientation = .course
        }
        applyOrientation()
    }

    private func applyOrientation() {
        switch orientation {
        case .overview:
            followsMe = false
            guard let coordinates = route.route?.coordinates, !coordinates.isEmpty else { return }
            var rect = MKMapRect.null
            for coordinate in coordinates + [location.current?.coordinate].compactMap({ $0 }) {
                let point = MKMapPoint(coordinate)
                rect = rect.union(MKMapRect(x: point.x, y: point.y, width: 0, height: 0))
            }
            let padding = max(rect.width, rect.height) * 0.2 + 500
            withAnimation(.easeInOut(duration: 0.8)) { camera = .rect(rect.insetBy(dx: -padding, dy: -padding)) }
        case .course:
            followsMe = true
            followMe(duration: 0.6)
        case .north, .fixed:
            if followsMe {
                followMe(duration: 0.6)
            } else {
                let heading: CLLocationDirection = if case .fixed(let value) = orientation { value } else { 0 }
                withAnimation(.easeInOut(duration: 0.5)) { camera = .camera(cameraState.camera(heading: heading)) }
            }
        }
    }

    // MARK: Untere Leiste

    private var bottomArea: some View {
        VStack(spacing: Theme.barSpacing) {
            if route.isActive {
                NavigationBottomBar()
            } else {
                HStack(spacing: Theme.barSpacing) {
                    MobilityControl { mobilityChoice = $0 }
                    APositionControl()
                    ToAButton()
                }
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

    /// Alle antippbaren Symbole; Tipps in ihrer Nähe gehören ihnen und nicht der Fläche dahinter.
    private var symbolCoordinates: [CLLocationCoordinate2D] {
        forcePins.map(\.coordinate)
            + (vehiclePins + targetPins).map(\.coordinate)
            + handles.map(\.coordinate)
            + nearbyStops.map(\.point.coordinate)
            + lage.operation.ueberschlagen.naechste.map(\.point.coordinate)
            + [location.current?.coordinate].compactMap { $0 }
    }

    /// Gezeichnete Form unter dem Finger: Linien (mit etwas Spielraum), Flächen, Kreise, Prognosezellen.
    /// Bei Überlappung gewinnt die kleinste, denn sie ist die gezielt gemeinte.
    private func shape(at point: GeoPoint) -> String? {
        // Spielraum für Linien: etwa 22 Bildpunkte, abhängig von der Zoomstufe.
        let tolerance = max(8, cameraState.distance / 45)
        var best: (id: String, size: Double)?
        for object in visibleObjects {
            let data = object.data
            let size: Double?
            switch data.typ {
            case .flaeche where data.punkte.count >= 3:
                size = Self.contains(data.punkte, point) ? Self.area(data.punkte) : nil
            case .kreis, .haltestellen:
                guard let center = data.punkte.first else { continue }
                let radius = data.radius ?? 100
                size = center.distance(to: point) <= radius ? Double.pi * radius * radius : nil
            case .linie where data.punkte.count >= 2:
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
                label: vehicle.data.funkrufname,
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
            object.data.punkte.first.map { (point: $0, radius: object.data.radius ?? 500) }
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
        // Bereits gefahrene Strecke verschwindet hinter einem.
        var remaining = Array(current.coordinates.dropFirst(min(route.progressIndex, current.coordinates.count - 2)))
        if let here = location.current?.coordinate { remaining.insert(here, at: 0) }
        return [RouteLine(polyline: MKPolyline(coordinates: remaining, count: remaining.count), specialRights: current.usesSpecialRights)]
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
