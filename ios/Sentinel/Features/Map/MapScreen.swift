import MapKit
import SwiftUI

/// Was auf der Karte angetippt wurde und als Kurzübersicht erscheint.
enum MapSelection: Identifiable, Hashable {
    case member(String)
    case vehicle(String)
    case target(String)
    /// Angetippte Fläche ohne eigenen Griff, z. B. eine Argus-Prognosezelle.
    case object(String)

    var id: String {
        switch self {
        case .member(let id): "member-\(id)"
        case .vehicle(let id): "vehicle-\(id)"
        case .target(let id): "target-\(id)"
        case .object(let id): "object-\(id)"
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

    /// Einzelner Ort: erst als Vorschau zeigen, dann bestätigen.
    var needsConfirmation: Bool {
        switch self {
        case .none: false
        case .drawing(let shape, _): !shape.isMultiPoint
        case .moving, .newTarget, .placingTarget: true
        }
    }

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

/// Was sich an einem Ort (z. B. einem Suchtreffer) direkt anlegen lässt.
enum PlaceableKind: Hashable, Identifiable {
    case shape(MapObject.Shape)
    case target(ZielArt)

    static let all: [PlaceableKind] = [
        .shape(.marker), .shape(.text), .shape(.kreis), .shape(.fahndungsraum), .shape(.haltestellen), .shape(.oepnvlinie), .shape(.oepnvfahrzeug),
        .target(.person), .target(.fahrzeug), .target(.objekt),
    ]

    var id: String {
        switch self {
        case .shape(let shape): "shape-\(shape.rawValue)"
        case .target(let art): "target-\(art.rawValue)"
        }
    }

    var title: String {
        switch self {
        case .shape(.haltestellen): "Haltestellen im Umkreis"
        case .shape(let shape): shape.title
        case .target(let art): art.title
        }
    }
}

struct SearchPin: Equatable {
    let point: GeoPoint
    let title: String
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
    /// Folgt die Karte dem eigenen Standort (nativ von Apple Karten, flüssig)? Verschieben beendet es von selbst.
    private var followsMe: Bool { camera.followsUserLocation }
    /// Die letzte Kamerabewegung kam vom Finger (nicht von der App): Neigung danach als 2D/3D-Einstellung übernehmen.
    @State private var userMovedCamera = false
    /// Gerade verschobener Fahndungsraum, für die Rückfrage zum Sichtungszeitpunkt.
    @State private var movedRoom: String?
    @State private var bottomAreaHeight: CGFloat = 120
    @State private var now = Date.now
    @State private var topAreaHeight: CGFloat = 60
    /// Über die Suche gezeigter Ort; Antippen bietet Navigation oder Marker an.
    @State private var searchPin: SearchPin?
    /// Ort für das gerade gewählte Werkzeug über die Adresssuche statt per Tipp bestimmen.
    @State private var pickingBySearch = false
    /// Deutschlandweite ÖPNV-Karte.
    @State private var showsTransitMap = false
    /// Mehrfachauswahl für Gruppen (per langem Drücken); leer = keine Auswahl.
    @State private var selectedObjects: Set<String> = []
    @State private var confirmsGroupDelete = false
    /// Vorschau des neuen Orts: erst „Übernehmen“ setzt ihn endgültig; erneutes Tippen verschiebt die Vorschau.
    @State private var pendingPoint: GeoPoint?
    /// Takt für die geschätzten ÖPNV-Fahrzeuge (alle 2 Sekunden, solange welche sichtbar sind).
    @State private var transitNow = Date.now
    /// Angetipptes, nur im Takt eingeblendetes Fahrzeug.
    @State private var virtualVehicle: TransitVehiclePin?

    var body: some View {
        dialogs(sheets(mainBody))
    }

    /// Alle Fenster über der Karte.
    private func sheets(_ content: some View) -> some View {
        content
        .alert("\(selectedObjects.count) Objekte für alle löschen?", isPresented: $confirmsGroupDelete) {
            Button("Abbrechen", role: .cancel) {}
            Button("Löschen", role: .destructive) {
                for id in selectedObjects { lage.deleteMapObject(id: id) }
                selectedObjects = []
            }
        }
        .fullScreenCover(isPresented: $showsTransitMap) {
            TransitExplorer(start: GeoPoint(cameraState.center))
        }
        .sheet(isPresented: $pickingBySearch) {
            SearchSheet(mode: .adresse, navigate: { _ in }, pick: { point, _ in
                withAnimation(.easeInOut(duration: 0.6)) {
                    camera = .camera(MapCamera(centerCoordinate: point.coordinate, distance: 900, heading: 0, pitch: settings.prefers3D ? 55 : 0))
                }
                // Erst wenn das Suchfenster zu ist, sonst kollidiert es mit dem Editor-Fenster.
                Task {
                    try? await Task.sleep(for: .milliseconds(450))
                    if tapMode.needsConfirmation { pendingPoint = point } else { handleTap(point) }
                }
            })
            .presentationDetents([.fraction(0.94)])
        }
        .sheet(item: $selection) { selection in
            QuickLookSheet(selection: selection, placeTarget: { targetId in
                tapMode = .placingTarget(targetId)
            }, moveObject: { objectId in
                self.selection = nil
                tapMode = .moving(objectId: objectId)
            })
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
            SearchSheet(mode: mode, navigate: { target in
                searchPin = nil
                model.navigate(to: target)
            }, showOnMap: { point, title in
                show(SearchPin(point: point, title: title))
            }, create: { point, title, kind in
                create(kind, at: point, title: title)
            })
            // Knapp unter voller Höhe bleibt das Fenster im Glas-Stil wie die Detailfenster.
            .presentationDetents([.fraction(0.94)])
        }
        .sheet(item: $mobilityChoice) { mode in
            MobilitySheet(initialMode: mode)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showsSituation) {
            SituationSheet()
        }
    }

    /// Rückfragen zu Suchtreffern und ÖPNV-Fahrzeugen, getrennt vom Rest, damit der Compiler die Ansicht schafft.
    private func dialogs(_ content: some View) -> some View {
        content
        // Takt für die ÖPNV-Fahrzeuge: alle zwei Sekunden, gleitend, solange welche sichtbar sind.
        .task(id: hasTransit) {
            while hasTransit, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                withAnimation(.linear(duration: 2)) { transitNow = .now }
            }
        }
        .confirmationDialog(
            virtualVehicle.map { "\($0.line.ref) Richtung \($0.line.richtung)" } ?? "",
            isPresented: Binding(get: { virtualVehicle != nil }, set: { if !$0 { virtualVehicle = nil } }),
            titleVisibility: .visible,
            presenting: virtualVehicle
        ) { pin in
            Button("Als ÖPNV-Fahrzeug anlegen") { _ = createVehicle(from: pin) }
            Button("Hinführen") {
                if let id = createVehicle(from: pin) { model.navigate(to: .object(id)) }
            }
        } message: { pin in
            Text("Im Takt geschätzt, Abfahrt am ersten Halt \(Format.time(pin.departure)). Keine Echtzeitdaten.")
        }
    }

    private var mainBody: some View {
        MapReader { proxy in
            Map(position: $camera, scope: mapScope) {
                // Im Fahrmodus ohne Navigation bleibt der normale Standortpunkt; nur in der Navigation ersetzt ihn der Navi-Pfeil.
                if true {
                    MyLocationLayer(lage: lage, route: route, locationService: location, cameraState: cameraState)
                }
                if let pendingPoint {
                    Marker("Neuer Ort", systemImage: "mappin", coordinate: pendingPoint.coordinate)
                        .tint(.orange)
                }
                if let searchPin {
                    Marker(searchPin.title, systemImage: "magnifyingglass", coordinate: searchPin.point.coordinate)
                        .tint(.red)
                }
                CoverageLayer(runs: CoverageRun.cached(coverageSegments))
                ReachLayer(rings: reachRings)
                MapObjectsLayer(lines: objects(.linie) + objects(.pfeil), areas: objects(.flaeche), circles: objects(.kreis) + objects(.haltestellen), handles: handles, offsets: clutterOffsets, selected: selectedObjects) { id in
                    openEditor(for: id)
                } onLongPress: { id in
                    toggleSelection(id)
                }
                TransitLayer(sections: objects(.oepnvlinie), vehicles: transitPins, showsStopNames: cameraState.distance < 5000, groupsWithStops: Set(objects(.haltestelle).compactMap(\.data.gruppe))) { pin in
                    if let id = pin.objectId { openEditor(for: id) } else { virtualVehicle = pin }
                }
                AreaLabelLayer(objects: objects(.flaeche) + objects(.kreis), metersPerPoint: cameraState.distance / 700)
                NearbyStopsLayer(stops: nearbyStops)
                RouteLayer(lines: routeLines)
                StopsLayer(stops: lage.operation.ueberschlagen.naechste, mine: lage.myLeapfrogStop, line: lage.aHolder?.data.oepnv.map { NearbyStop.Line(ref: $0.linie, typ: "", farbe: nil) })
                SymbolLayer(pins: vehiclePins + targetPins, offsets: clutterOffsets) { selection = $0 }
                ForcesLayer(pins: forcePins, offsets: clutterOffsets) { selection = $0 }
                DraftLayer(points: draftPoints, outline: draftOutline)
            }
            .mapStyle(mapStyle)
            .mapControls {
                MapScaleView()
            }
            // Karte bis an den unteren Rand: Apples Rechtshinweis sitzt dann klein unter der Tableiste
            // statt über den Bedienelementen.
            // In der Navigation zählt die untere Leiste zum sicheren Bereich: MapKit setzt den eigenen Standort
            // dann darüber, statt ihn verdecken zu lassen.
            .ignoresSafeArea(.container, edges: route.isActive ? Edge.Set() : .bottom)
            .onMapCameraChange(frequency: .continuous) { context in cameraState.update(context.camera) }
            .simultaneousGesture(DragGesture(minimumDistance: 12).onChanged { _ in
                userMovedCamera = true
            })
            .onMapCameraChange(frequency: .onEnd) { context in
                // Gekippt (auch mit zwei Fingern, das meldet keine Wischgeste): Haken bei „3D-Ansicht“ mitziehen.
                // Die App selbst setzt nur 0° oder 55°; MapKit begrenzt die Neigung beim Herauszoomen, bleibt aber über 10°.
                userMovedCamera = false
                let is3D = context.camera.pitch > 10
                if settings.prefers3D != is3D { settings.prefers3D = is3D }
            }
            .overlay {
                if followsMe {
                    FollowPuckOverlay(
                        showsArrow: false,
                        proxy: proxy,
                        state: cameraState,
                        inVehicle: { if case .vehicle = myLocationStyle { true } else { false } }(),
                        holdsA: lage.holdsA,
                        label: locationContext.summary,
                        course: myCourse
                    )
                }
            }
            // Langes Drücken auf einen Ort: wie ein Suchtreffer „Navigieren“ oder „Hier anlegen“ anbieten.
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.5)
                    .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
                    .onEnded { value in
                        guard tapMode == .none, case .second(true, let drag?) = value,
                              let coordinate = proxy.convert(drag.location, from: .local) else { return }
                        // Auf einer Form: zur Mehrfachauswahl; sonst Ort für Navigieren oder Anlegen.
                        if let id = shape(at: GeoPoint(coordinate)) { toggleSelection(id) } else { pressed(at: GeoPoint(coordinate)) }
                    }
            )
            .onTapGesture { point in
                guard let coordinate = proxy.convert(point, from: .local) else { return }
                if tapMode == .none {
                    // Tipp auf eine freie Stelle einer Form. Symbole darüber (Kräfte, Fahrzeuge, Ziele, Marker)
                    // fangen ihren Tipp selbst ab und kommen hier gar nicht erst an.
                    let nearSymbol = symbolCoordinates.contains { symbol in
                        guard let screen = proxy.convert(symbol, to: .local) else { return false }
                        return hypot(screen.x - point.x, screen.y - point.y) < 26
                    }
                    if !nearSymbol, let id = shape(at: GeoPoint(coordinate)) {
                        if lage.mapObjects[id] != nil { openEditor(for: id) }
                    }
                    return
                }
                if tapMode.needsConfirmation {
                    withAnimation(.snappy) { pendingPoint = GeoPoint(coordinate) }
                } else {
                    handleTap(GeoPoint(coordinate))
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { topArea }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // Beim Setzen eines Orts nur Karte und Suchleiste: alles Übrige ausgeblendet.
            Group { if tapMode == .none { bottomArea } }
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
        .overlay(alignment: .topTrailing) { if tapMode == .none, searchPin == nil { sideButtons } }
        .mapScope(mapScope)
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
            // Navigation: nah, gekippt, in Blickrichtung folgen. Danach nicht im Fahrmodus hängen bleiben.
            if active { startFollowing(heading: true) } else if followsMe { camera = .camera(cameraState.camera()) }
        }
        .task {
            // Beim Öffnen: auf den eigenen Standort, gekippt wie in einer Navi-App.
            for _ in 0..<40 where location.current == nil { try? await Task.sleep(for: .milliseconds(250)) }
            if let current = location.current {
                camera = .camera(MapCamera(centerCoordinate: current.coordinate, distance: 1200, heading: 0, pitch: settings.prefers3D ? 55 : 0))
            }
        }
        .sensoryFeedback(.impact, trigger: lage.operation.a?.memberId)
        .alert("Sichtung jetzt?", isPresented: Binding(get: { movedRoom != nil }, set: { if !$0 { movedRoom = nil } })) {
            Button("Zeit beibehalten", role: .cancel) {}
            Button("Auf jetzt setzen") {
                if let id = movedRoom, var room = lage.mapObjects[id]?.data {
                    room.zeit = (Date.now.timeIntervalSince1970 * 1000).rounded()
                    lage.saveMapObject(room, id: id)
                }
            }
        } message: {
            Text("Der Fahndungsraum wurde an einen neuen Ort verschoben. Soll die letzte Sichtung auf jetzt gesetzt werden?")
        }
    }

    private struct CoverageKey: Equatable {
        let enabled: Bool
        let since: Double
        let generation: Int
    }

    private var mapStyle: MapStyle {
        switch settings.mapStyle {
        case .standard: .standard(elevation: .realistic, pointsOfInterest: .excluding([.publicTransport]), showsTraffic: settings.showsTraffic)
        case .hybrid: .hybrid(elevation: .realistic, pointsOfInterest: .excluding([.publicTransport]), showsTraffic: settings.showsTraffic)
        case .satellit: .imagery(elevation: .realistic)
        }
    }

    private var isFollowing: Bool { followsMe }

    // MARK: Statuszeile unter dem eigenen Standort

    /// Wie der eigene Standort erscheint: Navi-Pfeil in der Navigation, Fahrzeug, wenn man drinsitzt, sonst Punkt.
    private var myLocationStyle: MyLocationLayer.Style { .of(lage, navigating: route.isActive) }

    // MARK: Obere Leiste

    private var topArea: some View {
        VStack(spacing: 8) {
            if route.isActive {
                NavigationBanner()
            } else {
                HStack(spacing: Theme.barSpacing) {
                // Beim Setzen eines Orts sucht die Leiste den Ort für das Werkzeug.
                Button { if tapMode == .none { searchMode = .adresse } else { pickingBySearch = true } } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                        Text(tapMode == .none ? "Suchen oder navigieren" : "Ort oder Adresse suchen")
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .font(.body)
                    .padding(.horizontal, 18)
                    .frame(height: Theme.roundButton)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .capsule)
                .accessibilityLabel(tapMode == .none ? "Suchen oder navigieren" : "Ort oder Adresse suchen")
                    if tapMode == .none {
                        MapRoundButton(title: "Zu Objekten navigieren", symbol: "location.viewfinder", prominent: true) { searchMode = .objekte }
                    }
                }
            }

            SOSBanner { memberId in
                model.navigate(to: .member(memberId))
                route.specialRights = true
            }

            if let hint = tapMode.hint {
                HStack(spacing: 12) {
                    Label(hint, systemImage: "hand.tap.fill")
                        .font(.footnote.weight(.semibold))
                    Spacer(minLength: 0)
                    if let point = pendingPoint {
                        Button("Übernehmen") {
                            pendingPoint = nil
                            handleTap(point)
                        }
                        .buttonStyle(.glassProminent)
                        .fontWeight(.semibold)
                    }
                    if case .drawing(let shape, let points) = tapMode, shape.isMultiPoint {
                        Button("Fertig") { finishDrawing(shape, points) }
                            .disabled(points.count < shape.minimumPoints)
                            .fontWeight(.semibold)
                    }
                    Button("Abbrechen", systemImage: "xmark.circle.fill") {
                        pendingPoint = nil
                        tapMode = .none
                    }
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
                SOSButton()
                // Ein Knopf für Kompass und Standort: erst zentrieren und folgen (Norden oben),
                // dann zwischen Norden oben und Gerätekompass wechseln. Verschieben löst die Kopplung.
                LocationCompassButton(state: cameraState, following: followsMe, heading: camera.followsUserHeading) {
                    if !followsMe {
                        startFollowing(heading: false, north: true)
                    } else if camera.followsUserHeading {
                        startFollowing(heading: false, north: true)
                    } else {
                        camera = .userLocation(followsHeading: true, fallback: .automatic)
                    }
                }
                MapStyleButton { on in
                    let heading = camera.followsUserHeading
                    let following = followsMe
                    withAnimation(.easeInOut(duration: 0.6)) { camera = .camera(cameraState.camera(pitch: on ? 55 : 0)) }
                    if following {
                        Task {
                            try? await Task.sleep(for: .milliseconds(650))
                            camera = .userLocation(followsHeading: heading, fallback: .automatic)
                        }
                    }
                }
                MapRoundButton(title: "Ebenen", symbol: "square.3.layers.3d") { showsLayers = true }
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
                    case .transitMap:
                        showsTransitMap = true
                    case .shape(let shape) where shape.isTransit:
                        // ÖPNV: kein Antippen nötig, Linien werden rund um den Kartenausschnitt vorgeschlagen.
                        editor = EditorContext(id: LageStore.newId(), object: draft(shape, [GeoPoint(cameraState.center)]), isNew: true)
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
    /// Eigene Bewegungs- bzw. Blickrichtung für den Navi-Pfeil.
    private var myCourse: CLLocationDirection? {
        if let current = route.snappedLocation ?? location.current, current.course >= 0, current.speed > 1 { return current.course }
        return locationContext.compassDegrees
    }

    /// Fahrmodus: erst nah und gekippt auf den Standort, dann der nativen, flüssigen Nachführung übergeben.
    private func startFollowing(heading: Bool, north: Bool = false) {
        if let current = location.current {
            withAnimation(.easeInOut(duration: 0.6)) {
                camera = .camera(MapCamera(
                    centerCoordinate: current.coordinate,
                    distance: followsMe ? cameraState.distance : (route.isActive ? 700 : 1000),
                    heading: north ? 0 : cameraState.heading,
                    pitch: settings.prefers3D ? 55 : 0
                ))
            }
        }
        Task {
            try? await Task.sleep(for: .milliseconds(650))
            camera = .userLocation(followsHeading: heading, fallback: .automatic)
        }
    }

    // MARK: Untere Leiste

    private var bottomArea: some View {
        VStack(spacing: Theme.barSpacing) {
            if let pin = searchPin, !route.isActive {
                SearchPinCard(pin: pin, navigate: {
                    searchPin = nil
                    model.navigate(to: .point(pin.point, title: pin.title))
                }, create: { kind in
                    create(kind, at: pin.point, title: pin.title, delayed: false)
                }, close: { searchPin = nil })
            }
            if !selectedObjects.isEmpty {
                GroupToolbar(
                    count: selectedObjects.count,
                    hasGroup: selectedObjects.contains { lage.mapObjects[$0]?.data.gruppe != nil },
                    group: groupSelection,
                    ungroup: ungroupSelection,
                    delete: { confirmsGroupDelete = true },
                    done: { selectedObjects = [] }
                )
            } else if route.isActive {
                NavigationBottomBar()
            } else if searchPin == nil {
                HStack(spacing: Theme.barSpacing) {
                    MobilityControl { mobilityChoice = $0 }
                    APositionControl()
                    ToAButton()
                }
            }
            if searchPin == nil {
                SituationBar { showsSituation = true }
            }
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

    private func finishDrawing(_ shape: MapObject.Shape, _ points: [GeoPoint]) {
        guard points.count >= shape.minimumPoints else { return }
        tapMode = .none
        editor = EditorContext(id: LageStore.newId(), object: draft(shape, points), isNew: true)
    }

    /// Versatz für übereinanderliegende Symbole (Kräfte, Fahrzeuge, Ziele, Marker).
    private var clutterOffsets: [String: CGSize] {
        let items = forcePins.map { ($0.id, $0.coordinate) } + (vehiclePins + targetPins).map { ($0.id, $0.coordinate) } + handles.map { ($0.id, $0.coordinate) }
        return Declutter.offsets(items.map { (id: $0.0, coordinate: $0.1) }, metersPerPoint: cameraState.distance / 700)
    }

    private var hasTransit: Bool { visibleObjects.contains { $0.data.typ.isTransit } }

    /// Angelegte ÖPNV-Fahrzeuge und die im Takt eingeblendeten auf ÖPNV-Linien.
    private var transitPins: [TransitVehiclePin] {
        var pins: [TransitVehiclePin] = []
        for object in objects(.oepnvfahrzeug) {
            guard let line = object.data.linie else { continue }
            pins.append(TransitVehiclePin(
                id: object.id, objectId: object.id, lineObjectId: nil,
                coordinate: lage.position(ofObject: object.data, at: transitNow).coordinate,
                line: line, color: Color(hex: object.data.farbe), departure: object.data.since ?? transitNow
            ))
        }
        for object in objects(.oepnvlinie) {
            guard let line = object.data.linie else { continue }
            for vehicle in TransitSimulation.vehicles(on: object.data, at: transitNow) {
                pins.append(TransitVehiclePin(
                    id: "\(object.id)-\(Int(vehicle.departure.timeIntervalSince1970))", objectId: nil, lineObjectId: object.id,
                    coordinate: vehicle.state.point.coordinate, line: line, color: Color(hex: object.data.farbe), departure: vehicle.departure
                ))
            }
        }
        return pins
    }

    /// Ein im Takt eingeblendetes Fahrzeug als eigenes Objekt anlegen; es löscht sich nach der Ankunft selbst.
    private func createVehicle(from pin: TransitVehiclePin) -> String? {
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
    private func draft(_ shape: MapObject.Shape, _ points: [GeoPoint]) -> MapObject {
        let isRoom = shape == .fahndungsraum
        return MapObject(
            layerId: Layer.lageId,
            typ: shape,
            farbe: isRoom ? "#C97C7C" : shape == .haltestellen || shape.isTransit ? "#0A84FF" : "#FF9F0A",
            punkte: points,
            radius: shape == .kreis ? 150 : shape == .haltestellen ? 500 : nil,
            zeit: isRoom || shape.isTransit ? (Date.now.timeIntervalSince1970 * 1000).rounded() : nil
        )
    }

    /// Alle antippbaren Symbole; Tipps in ihrer Nähe gehören ihnen und nicht der Fläche dahinter.
    private var symbolCoordinates: [CLLocationCoordinate2D] {
        forcePins.map(\.coordinate)
            + (vehiclePins + targetPins).map(\.coordinate)
            + handles.map(\.coordinate)
            + transitPins.map(\.coordinate)
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
    private func pressed(at point: GeoPoint) {
        searchPin = SearchPin(point: point, title: "Markierter Ort")
        Task {
            let placemarks = try? await CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: point.lat, longitude: point.lon), preferredLocale: Locale(identifier: "de_DE"))
            guard let place = placemarks?.first, searchPin?.point == point else { return }
            let street = [place.thoroughfare, place.subThoroughfare].compactMap { $0 }.joined(separator: " ")
            let title = street.isEmpty ? (place.name ?? "Markierter Ort") : street
            searchPin = SearchPin(point: point, title: title)
        }
    }

    /// Suchtreffer auf der Karte zeigen, ohne loszufahren.
    private func show(_ pin: SearchPin) {
        searchPin = pin
        withAnimation(.easeInOut(duration: 0.8)) {
            camera = .camera(MapCamera(centerCoordinate: pin.point.coordinate, distance: 900, heading: 0, pitch: settings.prefers3D ? 55 : 0))
        }
    }

    /// Markierung oder Ziel an einem Suchtreffer anlegen; der Editor öffnet sich, sobald das Suchfenster zu ist.
    private func create(_ kind: PlaceableKind, at point: GeoPoint, title: String, delayed: Bool = true) {
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
    private func openEditor(for id: String) {
        guard tapMode == .none, lage.mapObjects[id] != nil else { return }
        if !selectedObjects.isEmpty {
            toggleSelection(id)
            return
        }
        selection = .object(id)
    }

    private func toggleSelection(_ id: String) {
        guard tapMode == .none, let object = lage.mapObjects[id], settings.canEdit(layerId: object.data.layerId) else { return }
        withAnimation(.snappy) {
            if selectedObjects.contains(id) { selectedObjects.remove(id) } else { selectedObjects.insert(id) }
        }
    }

    /// Ausgewählte Objekte zu einer neuen Gruppe zusammenfassen (keine Verschachtelung: alte Zugehörigkeit entfällt).
    private func groupSelection() {
        let group = LageStore.newId()
        for id in selectedObjects {
            guard var object = lage.mapObjects[id]?.data else { continue }
            object.gruppe = group
            lage.saveMapObject(object, id: id)
        }
        selectedObjects = []
    }

    /// Gruppen der ausgewählten Objekte auflösen: alle Mitglieder werden wieder eigenständig.
    private func ungroupSelection() {
        let groups = Set(selectedObjects.compactMap { lage.mapObjects[$0]?.data.gruppe })
        for object in lage.mapObjects.values where object.data.gruppe.map(groups.contains) == true {
            var data = object.data
            data.gruppe = nil
            lage.saveMapObject(data, id: object.id)
        }
        selectedObjects = []
    }

    // MARK: Aufbereitung für die Karte

    /// Nur geladene Ebenen erscheinen auf der Karte; Entwürfe bleiben in der Ebenenliste.
    private var visibleObjects: [Versioned<MapObject>] {
        lage.mapObjects.values.filter { object in
            guard let layer = lage.layers[object.data.layerId], !object.data.isExpired() else { return false }
            return layer.data.isLive && !settings.hiddenLayers.contains(object.data.layerId)
        }
    }

    private func objects(_ shape: MapObject.Shape) -> [Versioned<MapObject>] {
        visibleObjects.filter { $0.data.typ == shape && $0.data.punkte.count >= shape.minimumPoints }
    }

    /// Antippbare Griffe. Prognosezellen (mit Kennwert) bekommen keinen, sonst würde die Karte überladen.
    private var handles: [ObjectHandle] {
        visibleObjects.filter { $0.data.wert == nil && !$0.data.punkte.isEmpty && $0.data.typ.hasHandle }.map { object in
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
            guard !settings.hiddenTargetKinds.contains(target.data.art.rawValue), let position = lage.position(ofTarget: target) else { return nil }
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
        return [RouteLine(polyline: MKPolyline(coordinates: remaining, count: remaining.count), specialRights: route.specialRights)]
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
