import MapKit
import SwiftUI

/// Die Lagekarte: Kräfte, Fahrzeuge, Ziele, Markierungen und eine Navigation wie in einer Navi-App.
struct MapScreen: View {
    @Environment(AppModel.self) var model
    @Environment(LageStore.self) var lage
    @Environment(LocalSettings.self) var settings
    @Environment(FahndungStore.self) var fahndung
    @Environment(RouteFollower.self) var route
    @Environment(LocationService.self) var location
    @Environment(LocationContext.self) var locationContext

    @State var camera: MapCameraPosition = .userLocation(fallback: .automatic)
    @State var selection: MapSelection?
    @State var tapMode: MapTapMode = .none
    @State var editor: EditorContext?
    @State var targetEditor: TargetEditorContext?
    @State var showsLayers = false
    @State var mobilityChoice: Fortbewegung?
    /// Eigene Fortbewegung ÖPNV: Fahrzeug auf der ÖPNV-Karte wählen und einsteigen.
    @State var boardsTransit = false
    @State var searchMode: SearchSheet.Mode?
    @State var showsSituation = false
    @State var cameraState = MapCameraState()
    @Namespace var mapScope
    /// Angeheftet am eigenen Standort (in Fahrtrichtung oder Norden oben); `nil` = frei.
    @State var pin: CameraPin?
    /// Die App bewegt die Kamera gerade selbst; solange zählt eine Kamerabewegung nicht als Verschieben.
    @State var cameraAnimating = false
    /// Bis wann Kamerabewegungen von der App selbst stammen (Anheften, Nachführen); danach ist es der Finger.
    @State var programmaticUntil = Date.distantPast
    /// Zoomstufe und Neigung beim Anheften; das Nachführen hält sie, bis man selbst zoomt oder kippt.
    @State var followDistance: CLLocationDistance?
    @State var followPitch: Double?
    /// Zuletzt angesteuerte Kamera beim Nachführen, um Wiederholungen ohne Bewegung auszulassen.
    @State var lastFollowTarget: MapCamera?
    /// Zeitpunkt der letzten Nachführung: Die nächste Fahrt dauert so lange wie der Abstand der Standortmeldungen,
    /// damit die Kamera gleichmäßig mitläuft statt ruckweise.
    @State var lastFollowAt = Date.distantPast
    /// Tempolimit der Straße am eigenen Standort (OpenStreetMap), auch ohne Navigation.
    @State var roadSpeedLimit: Int?
    /// Rasterzelle (~100 m) des eigenen Standorts; ein Wechsel fragt das Tempolimit neu ab.
    var speedLimitCell: String {
        guard let c = location.current?.coordinate else { return "" }
        return "\((c.latitude * 1000).rounded()),\((c.longitude * 600).rounded())"
    }
    var followsMe: Bool { pin != nil }
    /// Die letzte Kamerabewegung kam vom Finger (nicht von der App): Neigung danach als 2D/3D-Einstellung übernehmen.
    @State var userMovedCamera = false
    /// Gerade verschobener Fahndungsraum, für die Rückfrage zum Sichtungszeitpunkt.
    @State var movedRoom: String?
    @State var bottomAreaHeight: CGFloat = 120
    @State var now = Date.now
    @State var topAreaHeight: CGFloat = 60
    /// Über die Suche gezeigter Ort; Antippen bietet Navigation oder Marker an.
    @State var searchPin: SearchPin?
    /// Ort für das gerade gewählte Werkzeug über die Adresssuche statt per Tipp bestimmen.
    @State var pickingBySearch = false
    /// Deutschlandweite ÖPNV-Karte.
    @State var showsTransitMap = false
    /// Vorschau des neuen Orts: erst „Übernehmen“ setzt ihn endgültig; erneutes Tippen verschiebt die Vorschau.
    @State var pendingPoint: GeoPoint?
    /// Takt für die geschätzten ÖPNV-Fahrzeuge (alle 2 Sekunden, solange welche sichtbar sind).
    @State var transitNow = Date.now
    /// Angetipptes, nur im Takt eingeblendetes Fahrzeug.
    @State var virtualVehicle: TransitVehiclePin?
    /// Verlaufsmodus: gezeigte Spuren, Zeitraum und Zeitleiste.
    @State var history = HistoryState()
    @State var showsHistoryPicker = false
    var showsHistory: Bool { !model.historySubjects.isEmpty }

    var body: some View {
        dialogs(sheets(mainBody))
    }

    /// Alle Fenster über der Karte.
    func sheets(_ content: some View) -> some View {
        content
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
        .sheet(isPresented: $showsHistoryPicker) { HistoryPickerSheet() }
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
        .fullScreenCover(isPresented: $boardsTransit) {
            TransitExplorer(start: GeoPoint(cameraState.center)) { trip in
                lage.setMobility(.oepnv, transit: OepnvFahrt(linienId: trip.tripId, linie: trip.name, richtung: trip.headsign))
            }
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
    func dialogs(_ content: some View) -> some View {
        content
        // Takt für die ÖPNV-Fahrzeuge: alle zwei Sekunden, gleitend, solange welche sichtbar sind.
        // Verlauf: bei jeder Änderung von Spuren oder Zeitraum neu laden, solange er offen ist alle 30 Sekunden.
        .task(id: history.loadKey(model.historySubjects)) {
            guard showsHistory else { return }
            let firstLoad = history.spuren.isEmpty
            await history.load(model.historySubjects, client: model.client)
            if firstLoad { fitHistory() }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { return }
                await history.load(model.historySubjects, client: model.client)
            }
        }
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

    var mainBody: some View {
        // Einmal je Darstellung: welche Punkte gebündelt bzw. auseinandergerückt werden.
        let layout = clusterLayout
        return MapReader { proxy in
            Map(position: $camera, scope: mapScope) {
                // Im Fahrmodus ohne Navigation bleibt der normale Standortpunkt; nur in der Navigation ersetzt ihn der Navi-Pfeil.
                if true {
                    MyLocationLayer(lage: lage, route: route, locationService: location, cameraState: cameraState)
                }
                if let pendingPoint { PlacementPreview(point: pendingPoint, look: previewLook(at: pendingPoint)) }
                if let searchPin {
                    Marker(searchPin.title, systemImage: "magnifyingglass", coordinate: searchPin.point.coordinate)
                        .tint(.red)
                }
                CoverageLayer(runs: CoverageRun.cached(coverageSegments))
                ReachLayer(rings: reachRings)
                MapObjectsLayer(lines: objects(.linie) + objects(.pfeil), areas: objects(.flaeche), circles: objects(.kreis) + objects(.haltestellen), handles: handles.filter { !layout.hidden.contains($0.id) }, offsets: layout.offsets) { id in
                    openEditor(for: id)
                }
                TransitLayer(sections: objects(.oepnvlinie), vehicles: transitPins, showsStopNames: cameraState.distance < 5000) { pin in
                    if let id = pin.objectId { openEditor(for: id) } else { virtualVehicle = pin }
                }
                AreaLabelLayer(objects: objects(.flaeche) + objects(.kreis), metersPerPoint: cameraState.distance / 700)
                NearbyStopsLayer(stops: nearbyStops)
                // ÖPNV: die Verbindung Schritt für Schritt statt der Fußroute zum Ziel.
                if route.transit, let plan = route.transitPlan {
                    TransitPlanLayer(plan: plan)
                }
                if !route.transit || route.transitPlan == nil {
                    RouteLayer(lines: routeLines)
                }
                if showsHistory {
                    HistoryLayer(state: history) { model.title(of: $0) }
                }
                StopsLayer(stops: lage.operation.ueberschlagen.naechste, mine: lage.myLeapfrogStop, line: lage.aHolder?.data.oepnv.map { NearbyStop.Line(ref: $0.linie, typ: "", farbe: nil) })
                SymbolLayer(pins: (vehiclePins + targetPins).filter { !layout.hidden.contains($0.id) }, offsets: layout.offsets) { selection = $0 }
                ForcesLayer(pins: forcePins.filter { !layout.hidden.contains($0.id) }, offsets: layout.offsets) { selection = $0 }
                ClusterLayer(clusters: layout.clusters) { zoom(into: $0) }
                DraftLayer(points: draftPoints, outline: draftOutline)
            }
            .mapStyle(mapStyle)
            .mapControls {
                MapScaleView()
            }
            // Karte bis an den unteren Rand: Apples Rechtshinweis sitzt dann klein unter der Tableiste
            // statt über den Bedienelementen.
            // In der Navigation sitzt der eigene Pfeil etwas über der unteren Leiste: halb so viel Abstand wie deren Höhe.
            .safeAreaPadding(.bottom, route.isActive ? bottomAreaHeight * 0.5 : 0)
            // Apples Rechtshinweis sitzt unten links; etwas Abstand zu den runden Bildschirmecken, damit er nicht abschneidet.
            .safeAreaPadding(.horizontal, 14)
            .ignoresSafeArea(.container, edges: .bottom)
            .onMapCameraChange(frequency: .continuous) { context in
                cameraState.update(context.camera)
                if pin != nil, !cameraAnimating, !userMovedCamera, isUserCameraChange(context.camera) { userMovedCamera = true }
            }
            .simultaneousGesture(DragGesture(minimumDistance: 4).onChanged { _ in
                userMovedCamera = true
            })
            // Auch Zoomen und Drehen mit zwei Fingern: Solange die Hand auf der Karte ist, führt die App nicht nach.
            .simultaneousGesture(MagnifyGesture().onChanged { _ in userMovedCamera = true })
            .simultaneousGesture(RotateGesture().onChanged { _ in userMovedCamera = true })
            .onMapCameraChange(frequency: .onEnd) { context in
                // Gekippt (auch mit zwei Fingern, das meldet keine Wischgeste): Haken bei „3D-Ansicht“ mitziehen.
                let byUser = userMovedCamera
                userMovedCamera = false
                let is3D = context.camera.pitch > 10
                if settings.prefers3D != is3D { settings.prefers3D = is3D }
                // Nur nach eigenen Gesten prüfen, nicht nach den Bewegungen der Nachführung.
                if byUser { keepPinAfterGesture(context.camera) }
            }
            .onChange(of: location.current?.timestamp) { followTick() }
            .onChange(of: locationContext.compassDegrees) {
                // Im Stand dreht der Gerätekompass die Karte; in Fahrt der Kurs (kommt mit dem Standort).
                if pin == .heading, (location.current?.speed ?? 0) < 1 { followTick() }
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
                        // Ort für Navigieren oder Anlegen.
                        pressed(at: GeoPoint(coordinate))
                    }
            )
            .onTapGesture { point in
                guard let coordinate = proxy.convert(point, from: .local) else { return }
                // Verlauf: Tipp auf die Spur zeigt die Daten dieses Punkts.
                if tapMode == .none, showsHistory, history.select(near: point, proxy: proxy) { return }
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
            // Tempo beim Anheften bzw. in der Navigation; das Tempolimit immer, sobald es für die Straße bekannt ist.
            HStack(spacing: Theme.barSpacing) {
                if followsMe || route.isActive, let speed = location.current?.speed, speed >= 0 {
                    SpeedBadge(metersPerSecond: speed)
                }
                if let limit = route.speedLimit ?? roadSpeedLimit {
                    SpeedLimitSign(kmh: limit)
                }
            }
            .padding(.leading, Theme.barInset)
            .padding(.bottom, bottomAreaHeight + Theme.barSpacing)
        }
        .task(id: speedLimitCell) {
            // Je etwa 100 m neu nachfragen; der Server speichert zwischen.
            guard !route.isActive, let point = location.current.map({ GeoPoint($0.coordinate) }), let client = model.client else { return }
            if let limit = try? await client.speedLimit(at: point) { roadSpeedLimit = limit } else if !Task.isCancelled { roadSpeedLimit = nil }
        }
        .overlay(alignment: .topTrailing) { if tapMode == .none, searchPin == nil { sideButtons } }
        .overlay(alignment: .topLeading) {
            if settings.showsCameraDebug {
                CameraDebugOverlay(state: cameraState, pin: pin, navigating: route.isActive)
                    .padding(.leading, Theme.barInset)
                    .padding(.top, topAreaHeight + Theme.barSpacing)
            }
        }
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
            if active {
                pinCamera(.heading)
            } else if followsMe {
                pin = nil
                camera = .camera(cameraState.camera())
            }
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
}
