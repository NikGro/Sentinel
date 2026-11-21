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
                TransitAheadPicker()
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
                    animateCamera(cameraState.camera(pitch: on ? 55 : 0))
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
                        showsHistoryPicker = true
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

    /// Heftet die Karte an den eigenen Standort: nah und flach in Fahrtrichtung oder senkrecht mit Norden oben.
    /// Erst fährt die Kamera dorthin, dann führt `followTick` sie mit jeder Standortmeldung nach.
    func pinCamera(_ mode: CameraPin) {
        pin = mode
        // In der Navigation wie in üblichen Navis: etwas höher für mehr Überblick, deutlich gekippt.
        let navigating = route.isActive && mode == .heading
        followDistance = navigating ? CameraPin.navigationDistance : mode.distance
        followPitch = navigating ? CameraPin.navigationPitch : mode.pitch
        guard let current = location.current else { return }
        let heading = mode == .heading ? (myCourse ?? cameraState.heading) : 0
        animateCamera(MapCamera(centerCoordinate: current.coordinate, distance: followDistance ?? mode.distance, heading: heading, pitch: followPitch ?? mode.pitch))
    }

    /// Bewegt die Kamera. Angeheftet führt die App sie danach selbst nach (siehe `followTick`).
    func animateCamera(_ target: MapCamera) {
        cameraAnimating = true
        lastFollowTarget = target
        // Angeheftet gelten Zoomstufe und Neigung der neuen Ansicht ab jetzt auch für das Nachführen (z. B. 2D/3D-Knopf).
        if pin != nil {
            followDistance = target.distance
            followPitch = target.pitch
        }
        withAnimation(.easeInOut(duration: 0.5)) { camera = .camera(target) }
        Task {
            try? await Task.sleep(for: .milliseconds(750))
            cameraAnimating = false
        }
    }

    /// Angeheftet: Kamera auf den eigenen Standort nachführen, mit der gespeicherten Zoomstufe und Neigung; in
    /// Fahrtrichtung gedreht nach Kurs (in Fahrt) bzw. Gerätekompass (im Stand), Norden oben ohne Drehung. Die App führt
    /// selbst nach, statt an Apples Nachführung zu übergeben: Die setzt beim Übergeben ihre eigene Zoomstufe und springt.
    func followTick() {
        guard let mode = pin, !cameraAnimating, touch.phase == .idle, let current = location.current else { return }
        let heading = mode == .heading ? (myCourse ?? cameraState.heading) : cameraState.heading
        // Gespeicherte Zoomstufe und Neigung statt der gerade gemeldeten: Während einer Kamerafahrt meldet die Karte
        // Zwischenwerte, die sonst als neue Zoomstufe hängen blieben.
        let target = MapCamera(centerCoordinate: current.coordinate, distance: followDistance ?? cameraState.distance, heading: heading,
                               pitch: followPitch ?? cameraState.pitch)
        // Steht man still, nicht ständig neu animieren (sonst kommt die Karte nie zur Ruhe).
        if let last = lastFollowTarget,
           GeoPoint(last.centerCoordinate).distance(to: GeoPoint(target.centerCoordinate)) < 1,
           abs(last.heading - target.heading) < 1.5, abs(last.distance - target.distance) < 1, abs(last.pitch - target.pitch) < 1 {
            return
        }
        lastFollowTarget = target
        // So lange gleiten wie bis zur nächsten Meldung (aus dem letzten Abstand geschätzt): fließend statt stückweise.
        // Nach einer Geste dagegen kurz und weich zurück zum Standort.
        let afterGesture = nextFollowDuration
        nextFollowDuration = nil
        let interval = afterGesture ?? min(max(Date.now.timeIntervalSince(lastFollowAt), 0.3), 2.5)
        lastFollowAt = .now
        withAnimation(afterGesture == nil ? .linear(duration: interval) : .easeOut(duration: interval)) { camera = .camera(target) }
    }

    /// Rückfallebene: Weicht die Kamera ohne eigene Kamerafahrt deutlich von der Nachführung ab, kann das nur eine
    /// Geste sein. Großzügige Schwellen, denn mit Geländehöhe meldet die Karte leicht andere Werte als gesetzt.
    func isUserCameraChange(_ current: MapCamera) -> Bool {
        if let distance = followDistance, abs(current.distance - distance) > distance * 0.12 { return true }
        if let pitch = followPitch, abs(current.pitch - pitch) > 6 { return true }
        if let target = lastFollowTarget {
            let offset = GeoPoint(current.centerCoordinate).distance(to: GeoPoint(target.centerCoordinate))
            if offset > max(target.distance * 0.25, 60) { return true }
        }
        return false
    }

    /// Alle Finger sind von der Karte: Bei zwei Fingern auf das Ende der Kamerabewegung (mit Schwung) warten, ein
    /// wischender Finger löst die Kopplung sofort, ein bloßes Antippen ändert nichts.
    func touchesEnded() {
        switch touch.phase {
        case .touching(let fingers, let travel):
            if fingers >= 2 {
                touch.phase = .settling(fingers: fingers)
                // Kommt keine Kamerabewegung mehr (Finger lagen nur auf), nicht ewig warten.
                Task {
                    try? await Task.sleep(for: .milliseconds(900))
                    if case .settling = touch.phase { settleGesture(cameraState.camera()) }
                }
            } else if travel > 12, pin != nil {
                // Verschoben: frei, die Karte bleibt, wie sie ist.
                pin = nil
                touch.phase = .idle
            } else {
                touch.phase = .idle
                followTick()
            }
        default:
            break
        }
    }

    /// Nach Zoomen, Neigen oder Drehen: Kopplung bleibt, Zoomstufe und Neigung gelten ab jetzt für das Nachführen,
    /// und die Kamera gleitet zurück auf den eigenen Standort (MapKit zoomt um den Punkt zwischen den Fingern).
    func settleGesture(_ current: MapCamera) {
        touch.phase = .idle
        guard pin != nil else { return }
        followDistance = current.distance
        followPitch = current.pitch
        lastFollowTarget = nil
        nextFollowDuration = 0.35
        followTick()
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
