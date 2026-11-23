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

    /// Eigene Kartensteuerung: Gesten, Nachführen und Kamerafahrten an einer Stelle (siehe `MapEngine`).
    @State var engine = MapEngine()
    @State var selection: MapSelection?
    /// Punkt auf einer angetippten Strecke (Linie, ÖPNV-Strecke, Standortverlauf).
    @State var tapMarker: GeoPoint?
    @State var lastShapeTap: ShapeTap?
    @State var quickLookDetent: PresentationDetent = .medium
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
    var pin: CameraPin? { engine.pin }

    @State var ownMarkerOptions = OwnMarkerOptions()
    /// Tempolimit der Straße am eigenen Standort (OpenStreetMap), auch ohne Navigation.
    @State var roadSpeedLimit: Int?
    /// Rasterzelle (~100 m) des eigenen Standorts; ein Wechsel fragt das Tempolimit neu ab.
    var speedLimitCell: String {
        guard let c = location.current?.coordinate else { return "" }
        return "\((c.latitude * 1000).rounded()),\((c.longitude * 600).rounded())"
    }
    var followsMe: Bool { pin != nil }
    /// Gerade verschobener Fahndungsraum, für die Rückfrage zum Sichtungszeitpunkt.
    @State var movedRoom: String?
    @State var bottomAreaHeight: CGFloat = 120
    @State var now = Date.now
    #if DEBUG
    /// Kamera-Test „Unruhe“ (Umgebungsvariable `SENTINEL_UNRUHE=1`): baut den Kartenbildschirm ab 20 s nach dem Start viermal je Sekunde neu auf, wie es auf
    /// dem Gerät durch Kompass, GPS und Positionen der anderen Kräfte ständig passiert.
    @State var debugUnrest = 0
    #endif
    @State var topAreaHeight: CGFloat = 60
    /// Unterkante der Suchleiste und Oberkante des Bereichs unten, in Fensterkoordinaten (für das Zeigen eines Orts
    /// mittig dazwischen).
    @State var topBarBottom: CGFloat = 120
    @State var bottomBarTop: CGFloat = 600
    /// Wann zuletzt ein Ort (Suchtreffer, gedrückter Ort) in die freie Mitte gerückt wurde.
    @State var searchPinFocusedAt = Date.distantPast
    @State var searchPinView: MapCamera?
    /// Über die Suche gezeigter Ort; Antippen bietet Navigation oder Marker an.
    @State var searchPin: SearchPin?
    /// Ort für das gerade gewählte Werkzeug über die Adresssuche statt per Tipp bestimmen.
    @State var pickingBySearch = false
    /// Deutschlandweite ÖPNV-Karte.
    @State var showsTransitMap = false
    /// Vorschau des neuen Orts: erst „Übernehmen“ setzt ihn endgültig; erneutes Tippen verschiebt die Vorschau.
    @State var pendingPoint: GeoPoint?
    /// Takt für die geschätzten ÖPNV-Fahrzeuge (alle 2 Sekunden, solange welche sichtbar sind).
    /// Zeit für die ÖPNV-Fahrzeuge. Ein eigenes beobachtetes Objekt, das nur die Karte liest: So frischt der Takt nur
    /// die Karte auf und nicht den ganzen Bildschirm samt unterer Leiste (sonst gingen Antipper verloren).
    @State var transitClock = TransitClock()
    @State var transitSmoother = TransitSmoother()
    /// Angetipptes, nur im Takt eingeblendetes Fahrzeug.
    @State var virtualVehicle: TransitVehiclePin?
    /// Verlaufsmodus: gezeigte Spuren, Zeitraum und Zeitleiste.
    @State var history = HistoryState()
    @State var storedTracks = StoredTracks()
    var showsHistory: Bool { model.historyOpen }

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
                engine.fly(to: MapCamera(centerCoordinate: point.coordinate, distance: 900, heading: 0, pitch: settings.prefers3D ? 55 : 0))
                // Erst wenn das Suchfenster zu ist, sonst kollidiert es mit dem Editor-Fenster.
                Task {
                    try? await Task.sleep(for: .milliseconds(450))
                    if tapMode.needsConfirmation { pendingPoint = point } else { handleTap(point) }
                }
            })
            .presentationDetents([.fraction(0.94)])
        }
        // Gelöscht (auch aus dem Bearbeiten-Fenster heraus): die ganze Ansicht samt Bearbeiten sofort schließen.
        // Ein Schließen aus der Ansicht selbst greift nicht, solange das Bearbeiten-Fenster noch darüber liegt.
        .onChange(of: selection == nil) { _, closed in
            // Kurzübersicht zu: Punkt auf der Strecke und Verlaufsstelle weg.
            if closed {
                tapMarker = nil
                storedTracks.selected = nil
            }
        }
        .onChange(of: selectionExists) { _, exists in
            if !exists { selection = nil }
        }
        .sheet(item: $selection) { selection in
            QuickLookSheet(selection: selection, placeTarget: { targetId in
                tapMode = .placingTarget(targetId)
            }, moveObject: { objectId in
                self.selection = nil
                tapMode = .moving(objectId: objectId)
            }, trackPoint: selectedTrackPoint)
            .presentationDetents([QuickLookHeight.low, .medium, .large], selection: $quickLookDetent)
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        }
        // Verlauf: Fenster von unten wie die Kurzübersicht; die Karte bleibt darüber bedienbar.
        .sheet(isPresented: Binding(
            get: { showsHistory && selection == nil && editor == nil },
            set: { open in if !open, showsHistory, selection == nil, editor == nil { model.closeHistory() } }
        )) {
            HistoryPanel(state: history)
                .presentationDetents([QuickLookHeight.low, .medium, .large])
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
        // Takt für die ÖPNV-Fahrzeuge: alle halbe Sekunde, gleitend, solange welche sichtbar sind.
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
        // Dauerhaft gelegte Standortverläufe: bei Änderung neu laden, mitlaufende jede Minute.
        .task(id: StoredTracks.key(objects(.verlauf))) {
            let stored = objects(.verlauf)
            await storedTracks.load(stored, client: model.client)
            while stored.contains(where: { $0.data.zeitBis == nil }), !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled else { return }
                await storedTracks.load(objects(.verlauf), client: model.client)
            }
        }
        .onChange(of: model.historyIntervalRequest) { _, interval in
            guard let interval else { return }
            history.customFrom = interval.lowerBound
            history.customTo = interval.upperBound
            history.range = .custom
            history.selected = nil
            model.historyIntervalRequest = nil
        }
        .task(id: hasTransit) {
            // 30 Schritte je Sekunde ohne Animation: Die Position kommt aus dem vorberechneten Fahrmodell (nur
            // Nachschlagen), eine gleitende Animation wackelte, sobald sich die Kamera bewegt. Die Uhr liest nur die
            // Fahrzeugebene der Karte, Linien, Halte und der übrige Bildschirm werden dabei nicht neu berechnet.
            let clock = ContinuousClock()
            var next = clock.now
            while hasTransit, !Task.isCancelled {
                next += .milliseconds(33)
                try? await clock.sleep(until: next)
                transitClock.now = .now
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
        #if DEBUG
        let _ = debugUnrest
        #endif
        // Einmal je Darstellung: welche Punkte gebündelt bzw. auseinandergerückt werden.
        let layout = clusterLayout
        return MapReader { proxy in
            Map(initialPosition: .userLocation(fallback: .automatic), interactionModes: [], scope: mapScope) {
                // Im Fahrmodus ohne Navigation bleibt der normale Standortpunkt; nur in der Navigation ersetzt ihn der Navi-Pfeil.
                if true {
                    MyLocationLayer(lage: lage, route: route, locationService: location, cameraState: cameraState,
                                    locationContext: locationContext, options: ownMarkerOptions)
                }
                if let pendingPoint { PlacementPreview(point: pendingPoint, look: previewLook(at: pendingPoint)) }
                if let searchPin {
                    Marker(searchPin.title, systemImage: "magnifyingglass", coordinate: searchPin.point.coordinate)
                        .tint(.red)
                }
                CoverageLayer(runs: CoverageRun.cached(coverageSegments))
                ReachLayer(rings: reachRings)
                MapObjectsLayer(lines: objects(.linie) + objects(.pfeil), areas: objects(.flaeche), circles: objects(.kreis) + objects(.haltestellen), geofences: objects(.geofence), handles: handles.filter { !layout.hidden.contains($0.id) }, offsets: layout.offsets) { id in
                    openEditor(for: id)
                }
                TimedTransitLayer(clock: transitClock, sections: objects(.oepnvlinie), pins: { transitPins(at: $0) }, showsStopNames: cameraState.distance < 5000) { pin in
                    if let id = pin.objectId { openEditor(for: id) } else { virtualVehicle = pin }
                }
                AreaLabelLayer(objects: objects(.flaeche) + objects(.kreis) + objects(.geofence), metersPerPoint: cameraState.distance / 700)
                NearbyStopsLayer(stops: nearbyStops)
                // ÖPNV: die Verbindung Schritt für Schritt statt der Fußroute zum Ziel.
                if route.transit, let plan = route.transitPlan {
                    TransitPlanLayer(plan: plan)
                }
                if !route.transit || route.transitPlan == nil {
                    RouteLayer(lines: routeLines)
                }
                if route.isActive, !route.walking {
                    CrossStreetLayer(streets: route.upcomingCrossStreets)
                }
                StoredTracksLayer(state: storedTracks) { model.title(of: $0) }
                // Angetippte Stelle auf einer Strecke (beim Verlauf zeichnet ihn die Spur selbst).
                if let tapMarker, selection != nil, storedTracks.selected == nil {
                    Annotation("", coordinate: tapMarker.coordinate, anchor: .center) {
                        Circle()
                            .fill(.white)
                            .frame(width: 14, height: 14)
                            .overlay(Circle().stroke(Theme.accent, lineWidth: 4))
                            .shadow(radius: 2)
                            .allowsHitTesting(false)
                    }
                    .annotationTitles(.hidden)
                }
                if showsHistory {
                    HistoryLayer(state: history) { model.title(of: $0) }
                }
                StopsLayer(stops: lage.operation.ueberschlagen.naechste, mine: lage.myLeapfrogStop, line: lage.aHolder?.data.oepnv.map { NearbyStop.Line(ref: $0.linie, typ: "", farbe: nil) })
                SymbolLayer(pins: (vehiclePins + targetPins).filter { !layout.hidden.contains($0.id) }, offsets: layout.offsets) { tapMarker = nil; present($0, low: false) }
                ForcesLayer(pins: forcePins.filter { !layout.hidden.contains($0.id) }, offsets: layout.offsets) { tapMarker = nil; present($0, low: false) }
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
                CameraProbe.shared.record(context.camera, pin: pin, gesture: engine.isGestureActive, puck: engine.pin != nil ? engine.puckOffset : nil, attached: engine.isAttached)
            }
            // Eigene Steuerung: findet über diese Fläche die MapKit-Karte und übernimmt Gesten und Kamera.
            .mapEngine(engine)
            // Angeheftet: eigener Punkt fest in der Bildmitte, von der App gezeichnet (Apples Standortanzeige folgt
            // dem Standort mit eigener Bewegung und zitterte gegen die nachgeführte Kamera).
            .overlay {
                if let point = engine.centerPoint {
                    GeometryReader { geometry in
                        let frame = geometry.frame(in: .global)
                        LiveMyLocationMarker(lage: lage, route: route, locationService: location, cameraState: cameraState,
                                             locationContext: locationContext, options: ownMarkerOptions)
                            .position(x: point.x - frame.minX, y: point.y - frame.minY)
                    }
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                }
            }
            .onChange(of: engine.centerPoint != nil, initial: true) { _, drawn in
                ownMarkerOptions.drawnByScreen = drawn
            }
            .onAppear {
                engine.locationProvider = { [location, route] in route.snappedLocation ?? location.current }
                engine.courseProvider = { myCourse }
                engine.onEvent = { event in
                    switch event {
                    case .panned, .pinched, .rotated, .tilted:
                        // Bild für Bild: nur im Overlay, nicht im Messprotokoll.
                        break
                    case .note(let text):
                        CameraProbe.shared.event(text)
                    case .released(let reason):
                        CameraProbe.shared.event("released " + reason)
                    case .target(let distance, let pitch):
                        CameraProbe.shared.event(String(format: "sollwert d=%.0f p=%.1f", distance, pitch))
                    default:
                        CameraProbe.shared.event("\(event)")
                    }
                }
                CameraProbe.shared.uploader = { [client = model.client] lines in try? await client?.sendCameraDiagnosis(lines) }
            }

            .onMapCameraChange(frequency: .onEnd) { context in
                cameraState.update(context.camera)
                let is3D = context.camera.pitch > 10
                if settings.prefers3D != is3D { settings.prefers3D = is3D }
            }

            .onChange(of: pin, initial: true) { _, new in
                CameraProbe.shared.event("pin \(new.map { $0 == .heading ? "heading" : "north" } ?? "none")")
                ownMarkerOptions.showsStreet = new != nil
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
                if tapMode == .none, showsHistory, history.select(near: point, proxy: proxy) {
                    // Die Stelle mittig zwischen oberen Rand und Fenster rücken.
                    if let selected = history.selected, let spur = history.spuren[selected.key] {
                        tapMarker = spur.sample(index: selected.index, fraction: selected.fraction).punkt.point
                        focusTapMarker()
                        tapMarker = nil
                    }
                    return
                }
                if tapMode == .none {
                    // Tipp auf eine freie Stelle einer Form. Symbole darüber (Kräfte, Fahrzeuge, Ziele, Marker)
                    // fangen ihren Tipp selbst ab und kommen hier gar nicht erst an.
                    let onSymbol = tapHitsSymbol(point, proxy: proxy)
                    // Standortverläufe und Formen an dieser Stelle (mehrfach tippen schaltet durch).
                    if !onSymbol { selectShapeOrTrack(at: point, proxy: proxy) }
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
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { bottomBarTop = $0 }
        }
        // Wächst das Fenster unten noch (Straßenansicht lädt), den Ort gleich nachrücken, solange er frisch ist.
        .onChange(of: bottomBarTop) { refocusSearchPin() }
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
        .overlay(alignment: .topTrailing) {
            if tapMode == .none, searchPin == nil {
                sideButtons
            } else {
                // Reduzierte Ansicht (Ort setzen, Suchtreffer): nur der Kompassknopf, um zum eigenen Standort zu springen.
                LocationCompassButton(state: cameraState, pin: pin) { pinCamera(pin == .heading ? .north : .heading) }
                    .padding(.trailing, Theme.barInset)
                    .padding(.top, topAreaHeight + Theme.barSpacing)
            }
        }
        .overlay(alignment: .topLeading) {
            if settings.showsCameraDebug {
                CameraDebugOverlay(state: cameraState, pin: pin, navigating: route.isActive, engine: engine)
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
        #if DEBUG
        .task {
            guard ProcessInfo.processInfo.environment["SENTINEL_UNRUHE"] == "1" else { return }
            // Erst nach dem Start (sonst findet das Testwerkzeug die Bedienelemente nicht), dann etwa so oft wie
            // Kompassmeldungen auf dem Gerät.
            try? await Task.sleep(for: .seconds(20))
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                debugUnrest &+= 1
            }
        }
        #endif
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
                engine.unpin()
            }
        }
        .task {
            // Beim Öffnen: auf den eigenen Standort, gekippt wie in einer Navi-App.
            for _ in 0..<40 where location.current == nil { try? await Task.sleep(for: .milliseconds(250)) }
            if let current = location.current {
                if engine.pin == nil {
                    engine.jump(to: MapCamera(centerCoordinate: current.coordinate, distance: 1200, heading: 0, pitch: settings.prefers3D ? 55 : 0))
                }
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
