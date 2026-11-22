import MapKit
import SwiftUI

// Leisten und Knöpfe über der Karte: Suche oben, Knöpfe rechts, Fortbewegung, A und Lage unten; Kameraführung.

extension MapScreen {
    var mapStyle: MapStyle {
        switch settings.mapStyle {
        case .standard: .standard(elevation: .realistic, pointsOfInterest: .excluding([.publicTransport]), showsTraffic: settings.showsTraffic)
        case .hybrid: .hybrid(elevation: .realistic, pointsOfInterest: .excluding([.publicTransport]), showsTraffic: settings.showsTraffic)
        case .satellit: .imagery(elevation: .realistic)
        }
    }

    // MARK: Statuszeile unter dem eigenen Standort

    /// Wie der eigene Standort erscheint: Navi-Pfeil in der Navigation, Fahrzeug, wenn man drinsitzt, sonst Punkt.
    var myLocationStyle: MyLocationLayer.Style { .of(lage, navigating: route.isActive) }

    // MARK: Obere Leiste

    var topArea: some View {
        VStack(spacing: 8) {
            if route.isActive {
                NavigationBanner()
            } else if showsHistory, tapMode == .none {
                // Verlauf: reduzierte Karte ohne Suche.
                EmptyView()
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
                    if tapMode == .none, !reducedTools {
                        MapRoundButton(title: "Zu Objekten navigieren", symbol: "location.viewfinder", prominent: true) { searchMode = .objekte }
                    }
                }
            }

            if !reducedTools { SOSBanner { memberId in
                model.navigate(to: .member(memberId))
                route.specialRights = true
            } }

            if let hint = tapMode.hint {
                PlacementBar(hint: hint, canConfirm: pendingPoint != nil, confirm: {
                    if let point = pendingPoint {
                        pendingPoint = nil
                        handleTap(point)
                    }
                }, cancel: {
                    pendingPoint = nil
                    tapMode = .none
                }) {
                    if case .drawing(let shape, let points) = tapMode, shape.isMultiPoint {
                        Button("Fertig") { finishDrawing(shape, points) }
                            .disabled(points.count < shape.minimumPoints)
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .padding(.horizontal, Theme.barInset)
        .padding(.top, 4)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { topAreaHeight = $0 }
        .animation(.snappy, value: tapMode)
        .animation(.snappy, value: route.isActive)
    }

    // MARK: Knöpfe am rechten Rand, direkt unter dem Kompass

    var sideButtons: some View {
        VStack(spacing: Theme.barSpacing) {
        // SOS außerhalb des Glas-Verbunds: Dort zeichnet der Verbund das Glas über Ring und Vergrößerung.
        if !reducedTools { SOSButton() }
        GlassEffectContainer(spacing: Theme.barSpacing) {
            VStack(spacing: Theme.barSpacing) {
                // Ein Knopf für Standort und Kompass: heftet immer an und wechselt dann zwischen Fahrtrichtung und
                // Norden oben. Zoomen und Drehen gehen mit zwei Fingern; erst bewusstes Verschieben löst die Kopplung.
                LocationCompassButton(state: cameraState, pin: pin) {
                    pinCamera(pin == .heading ? .north : .heading)
                }
                // Im Verlauf nur der Kompass, damit die Spuren frei bleiben.
                if !showsHistory {
                MapStyleButton { on in
                    // Angeheftet: nur den Winkel ändern und angeheftet bleiben; sonst um die Bildmitte kippen.
                    if let mode = pin {
                        startPin(mode, distance: followDistance ?? cameraState.distance, pitch: on ? 55 : 0)
                    } else {
                        animateCamera(cameraState.camera(pitch: on ? 55 : 0))
                    }
                }
                MapRoundButton(title: "Ebenen", symbol: "square.3.layers.3d") { showsLayers = true }
                if !reducedTools, let a = lage.aPosition, !lage.holdsA {
                    Button {
                        pin = nil
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
                AddMenu(scope: model.editsPermanentLayer ? .places : (lage.isPackageArea ? .package : .all)) { action in
                    switch action {
                    case .transitMap:
                        showsTransitMap = true
                    case .history:
                        // Direkt in den Verlauf; Spuren kommen dort über das Plus dazu.
                        if route.isActive { model.stopNavigation() }
                        model.historyOpen = true
                    case .shape(let shape) where shape.isTransit:
                        // ÖPNV: kein Antippen nötig, Linien werden rund um den Kartenausschnitt vorgeschlagen.
                        editor = EditorContext(id: LageStore.newId(), object: draft(shape, [GeoPoint(cameraState.center)]), isNew: true)
                    case .shape(let shape): tapMode = .drawing(shape, points: [])
                    case .target(let art): tapMode = .newTarget(art)
                    }
                }
                }
            }
        }
        }
        .padding(.trailing, Theme.barInset)
        .padding(.top, topAreaHeight + Theme.barSpacing)
    }

    /// Karte auf alle gezeigten Spuren einpassen.
    func fitHistory() {
        let points = history.allPoints
        guard let first = points.first else { return }
        var minLat = first.lat, maxLat = first.lat, minLon = first.lon, maxLon = first.lon
        for p in points {
            minLat = min(minLat, p.lat); maxLat = max(maxLat, p.lat)
            minLon = min(minLon, p.lon); maxLon = max(maxLon, p.lon)
        }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        // Rand lassen: die Leiste unten bedeckt einen Teil der Karte.
        let span = MKCoordinateSpan(latitudeDelta: max((maxLat - minLat) * 1.8, 0.004), longitudeDelta: max((maxLon - minLon) * 1.4, 0.004))
        pin = nil
        withAnimation(.easeInOut(duration: 0.6)) { camera = .region(MKCoordinateRegion(center: center, span: span)) }
    }

    /// Eigene Bewegungs- bzw. Blickrichtung für den Navi-Pfeil.
    var myCourse: CLLocationDirection? {
        if let current = route.snappedLocation ?? location.current, current.course >= 0, current.speed > 1 { return current.course }
        return locationContext.compassDegrees
    }

    /// Heftet die Karte an den eigenen Standort: in Kompass-Ausrichtung schräg von hinten, mit Norden oben von oben.
    /// Apples Standortverfolgung übernimmt (siehe `startPin`); welche Geste läuft, melden MapKits eigene Erkenner
    /// (`MapGestureWatcher`).
    func pinCamera(_ mode: CameraPin) {
        // In der Navigation wie in üblichen Navis: etwas höher für mehr Überblick, deutlich gekippt.
        let navigating = route.isActive && mode == .heading
        startPin(mode, distance: navigating ? CameraPin.navigationDistance : mode.distance, pitch: navigating ? CameraPin.navigationPitch : mode.pitch)
    }

    /// Anheften mit gegebenem Abstand und Winkel (auch für den 2D/3D-Knopf, der angeheftet nur den Winkel ändert).
    /// Apples eigene Standortverfolgung übernimmt (`.userLocation`): Sie folgt flüssig und lässt Zoomen, Kippen und
    /// Lösen mit Apples eigenen Gesten zu. Apple wählt beim Einschalten selbst einen Abstand; deshalb erst die gewünschte
    /// Ansicht setzen und den erlaubten Abstand beim Übergeben kurz auf genau diesen Wert begrenzen (`MapCameraBounds`),
    /// danach wieder freigeben. Nur eine Steuerung: SwiftUIs Karte, kein Eingriff an MapKit vorbei.
    func startPin(_ mode: CameraPin, distance: CLLocationDistance, pitch: Double, isRetry: Bool = false) {
        gestures.attachIfNeeded()
        if !isRetry { resetCorrections = 0 }
        pin = mode
        followDistance = distance
        followPitch = pitch
        settling = false
        // Bis zur Übergabe an Apple nicht prüfen (die Kamera fährt erst dorthin).
        trackingHandover = .distantPast
        guard let current = location.current else { return }
        let heading = mode == .heading ? (myCourse ?? cameraState.heading) : 0
        let view = MapCamera(centerCoordinate: current.coordinate, distance: distance, heading: heading, pitch: pitch)
        animateCamera(view)
        pinRequest += 1
        let request = pinRequest
        Task {
            // Erst übergeben, wenn die Anfahrt angekommen ist: Apple behält den Abstand und Winkel, die beim Einschalten
            // eingestellt sind (Kamera-Test: zu früh übergeben, blieb es bei 931 m statt 550 m).
            for _ in 0..<30 {
                try? await Task.sleep(for: .milliseconds(100))
                guard pinRequest == request, pin == mode else { return }
                if !cameraAnimating, abs(cameraState.distance - distance) < distance * 0.05 { break }
            }
            guard pinRequest == request, pin == mode else { return }
            // Ohne Abstandsgrenze: Eine Grenze zwang MapKit, die Kamera zu verstellen, und beendete die Verfolgung
            // (Kamera-Test). Gemessen wird, welchen Abstand Apple beim Einschalten wählt.
            trackingHandover = .now
            CameraProbe.shared.event(String(format: "apple verfolgung an d=%.0f kompass=%d", distance, mode == .heading ? 1 : 0))
            camera = .userLocation(followsHeading: mode == .heading, fallback: .camera(view))
            for wait in [300, 700] {
                try? await Task.sleep(for: .milliseconds(wait))
                CameraProbe.shared.event(String(format: "nach uebergabe d=%.0f verfolgung=%@", cameraState.distance, gestures.trackingDescription))
            }
        }
    }

    /// Kartengesten: Zoomen und Kippen erledigt Apples Verfolgung selbst. Verschieben mit einem Finger oder Herausdrehen
    /// aus der Kompass-Ausrichtung löst die Kopplung; erst nach der Geste wird die Kamera an der aktuellen Stelle gesetzt
    /// und damit Apples Verfolgung beendet (während einer Geste würde das die Geste abbrechen). Der Zustand von SwiftUIs
    /// Kameraposition taugt dafür nicht: Sie meldet schon kurz nach dem Einschalten „folgt nicht“, obwohl die Karte folgt.
    func handleGesture(_ event: MapGestureEvent) {
        switch event {
        case .began:
            multiTouchGesture = false
            lastGestureAt = .now
        case .panned(let distance, let touches):
            if touches >= 2 { multiTouchGesture = true }
            if pin != nil, touches == 1, !multiTouchGesture, distance > 30 {
                pin = nil
                releaseTracking = true
            }
        case .pinched:
            multiTouchGesture = true
        case .rotated(let degrees):
            multiTouchGesture = true
            if pin == .heading, abs(degrees) > 20 {
                pin = nil
                releaseTracking = true
            }
        case .zoomTapped:
            lastGestureAt = .now
            rememberUserView()
        case .allEnded:
            lastGestureAt = .now
            rememberUserView()
            if releaseTracking, pin == nil {
                releaseTracking = false
                CameraProbe.shared.event("apple verfolgung beendet (geste)")
                // Nach dem Ausschwingen an Ort und Stelle festhalten.
                Task {
                    try? await Task.sleep(for: .milliseconds(400))
                    if pin == nil, !gestures.isActive { camera = .camera(cameraState.camera()) }
                }
            }
        }
    }

    /// Nach eigenem Zoomen oder Kippen: Abstand und Winkel nach dem Ausschwingen als neuen Sollwert merken.
    func rememberUserView() {
        guard pin != nil else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            guard pin != nil, !gestures.isActive else { return }
            followDistance = cameraState.distance
            followPitch = cameraState.exactPitch
            CameraProbe.shared.event(String(format: "sollwert d=%.0f p=%.1f", cameraState.distance, cameraState.exactPitch))
        }
    }

    /// Apple setzt beim Verfolgen manchmal von sich aus einen weiten Abstand (Kamera-Test: 550 → 4890 m ohne Geste).
    /// Springt der Abstand ohne Geste deutlich vom Sollwert weg, wird der Sollwert erneut gesetzt und die Verfolgung neu
    /// übergeben, höchstens dreimal je Anheften.
    func correctAppleZoomReset() {
        guard let mode = pin, let target = followDistance, trackingHandover > .distantPast,
              Date.now.timeIntervalSince(trackingHandover) > 1, Date.now.timeIntervalSince(lastGestureAt) > 2,
              !gestures.isActive, !cameraAnimating, resetCorrections < 3 else { return }
        guard abs(cameraState.distance - target) > target * 0.4 else { return }
        resetCorrections += 1
        CameraProbe.shared.event(String(format: "apple abstand zurueck d=%.0f soll=%.0f versuch=%d verfolgung=%@", cameraState.distance, target, resetCorrections, gestures.trackingDescription))
        // Versuch: Abstand an der laufenden Verfolgung ändern statt neu anheften (Neuanheften startet Apples Verfolgung
        // neu, und die setzt jedes Mal wieder etwa 4,9 km: Rein-raus-Schleife auf dem Gerät).
        let stage = resetCorrections - 1
        trackingHandover = .now  // nächster Versuch frühestens in 1 s
        guard gestures.setDistance(target, pitch: followPitch ?? mode.pitch, stage: stage) else {
            startPin(mode, distance: target, pitch: followPitch ?? mode.pitch, isRetry: true)
            return
        }
        Task {
            for wait in [300, 1700] {
                try? await Task.sleep(for: .milliseconds(wait))
                CameraProbe.shared.event(String(format: "apple abstand stufe %d d=%.0f verfolgung=%@ pin=%@", stage, cameraState.distance, gestures.trackingDescription, pin.map { "\($0)" } ?? "none"))
            }
        }
    }

    /// Bewegt die Kamera (Anheften, Sprung zu einem Ort).
    func animateCamera(_ target: MapCamera) {
        cameraAnimating = true
        lastFollowTarget = target
        CameraProbe.shared.event(String(format: "fahrt anheften d=%.0f p=%.0f h=%.0f dauer=0.5", target.distance, target.pitch, target.heading))
        withAnimation(.easeInOut(duration: 0.5)) { camera = .camera(target) }
        Task {
            try? await Task.sleep(for: .milliseconds(650))
            cameraAnimating = false
        }
    }

    // MARK: Untere Leiste

    var bottomArea: some View {
        VStack(spacing: Theme.barSpacing) {
            if let pin = searchPin, !route.isActive {
                SearchPinCard(pin: pin, scope: model.editsPermanentLayer ? .places : (lage.isPackageArea ? .package : .all), navigate: {
                    searchPin = nil
                    model.navigate(to: .point(pin.point, title: pin.title))
                }, create: { kind in
                    create(kind, at: pin.point, title: pin.title, delayed: false)
                }, close: { searchPin = nil })
            }
            if let selected = storedTracks.selected, let track = storedTracks.selectedTrack, track.spur.punkte.indices.contains(selected.index) {
                HistoryPointCard(spur: track.spur, index: selected.index, title: model.title(of: track.spur.subject)) { storedTracks.selected = nil }
            }
            if showsHistory {
                HistoryPanel(state: history, fit: fitHistory)
            } else if route.isActive {
                NavigationBottomBar()
            } else if searchPin == nil, reducedTools {
                SpecialAreaBar()
            } else if searchPin == nil {
                HStack(spacing: Theme.barSpacing) {
                    MobilityControl { mode in
                        if mode == .oepnv { boardsTransit = true } else { mobilityChoice = mode }
                    }
                    APositionControl()
                    ToAButton()
                }
            }
            if searchPin == nil, !reducedTools, !showsHistory {
                SituationBar { showsSituation = true }
            }
        }
        .padding(.horizontal, Theme.barInset)
        .padding(.bottom, Theme.barSpacing)
        .animation(.snappy, value: route.isActive)
    }
}
