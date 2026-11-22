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
                        startPin(mode, distance: mapHandle.mapView?.camera.centerCoordinateDistance ?? followDistance ?? mode.distance, pitch: on ? 55 : 0)
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
    /// Die Karte setzt die Startansicht und übernimmt dann mit ihrer eingebauten Verfolgung (siehe `MapViewHandle`):
    /// Zoomen und Kippen behalten die Kopplung, Verschieben oder Herausdrehen beendet sie.
    func pinCamera(_ mode: CameraPin) {
        // In der Navigation wie in üblichen Navis: etwas höher für mehr Überblick, deutlich gekippt.
        let navigating = route.isActive && mode == .heading
        let distance = navigating ? CameraPin.navigationDistance : mode.distance
        let pitch = navigating ? CameraPin.navigationPitch : mode.pitch
        startPin(mode, distance: distance, pitch: pitch)
    }

    /// Anheften mit gegebenem Abstand und Winkel (auch für den 2D/3D-Knopf, der angeheftet nur den Winkel ändert).
    func startPin(_ mode: CameraPin, distance: CLLocationDistance, pitch: Double) {
        pin = mode
        followDistance = distance
        followPitch = pitch
        guard let current = location.current else { return }
        let heading = mode == .heading ? (myCourse ?? cameraState.heading) : 0
        trackingHandover = .now
        if mapHandle.track(center: current.coordinate, distance: distance, pitch: pitch, heading: heading, followsHeading: mode == .heading) {
            nativeTracking = true
            return
        }
        // Rückfall ohne MapKit-Karte: eigene Nachführung.
        nativeTracking = false
        animateCamera(MapCamera(centerCoordinate: current.coordinate, distance: distance, heading: heading, pitch: pitch))
    }

    /// Hat die Karte ihre Verfolgung beendet? Verschieben beendet sie ganz, Herausdrehen aus der Kompass-Ausrichtung
    /// stuft sie zu „nur folgen“ herab; beides heißt hier: frei. Kurz nach dem Übergeben nicht prüfen, da läuft die
    /// Kamerafahrt noch ohne Verfolgung.
    func checkNativeTracking() {
        guard nativeTracking, let mode = pin, Date.now.timeIntervalSince(trackingHandover) > 1.2,
              let tracking = mapHandle.trackingMode else { return }
        let lost = tracking == .none || (mode == .heading && tracking != .followWithHeading)
        if lost { pin = nil }
    }

    /// Bewegt die Kamera. Ohne MapKit-Verfolgung führt die App sie danach selbst nach (siehe `followTick`).
    func animateCamera(_ target: MapCamera) {
        cameraAnimating = true
        lastFollowTarget = target
        withAnimation(.easeInOut(duration: 0.5)) { camera = .camera(target) }
        Task {
            try? await Task.sleep(for: .milliseconds(750))
            cameraAnimating = false
        }
    }

    /// Rückfall, falls keine MapKit-Karte zu finden ist: Kamera auf den eigenen Standort nachführen.
    func followTick() {
        guard !nativeTracking, let mode = pin, !cameraAnimating, let current = location.current else { return }
        let heading = mode == .heading ? (myCourse ?? cameraState.heading) : cameraState.heading
        let target = MapCamera(centerCoordinate: current.coordinate, distance: followDistance ?? cameraState.distance, heading: heading,
                               pitch: followPitch ?? cameraState.pitch)
        if let last = lastFollowTarget,
           GeoPoint(last.centerCoordinate).distance(to: GeoPoint(target.centerCoordinate)) < 1,
           abs(last.heading - target.heading) < 1.5 {
            return
        }
        lastFollowTarget = target
        let interval = min(max(Date.now.timeIntervalSince(lastFollowAt), 0.3), 2.5)
        lastFollowAt = .now
        withAnimation(.linear(duration: interval)) { camera = .camera(target) }
    }

    /// Rückfall: Weicht die Kamera deutlich von der Nachführung ab, war es eine Geste; dann frei.
    func fallbackGestureCheck(_ current: MapCamera) {
        guard !nativeTracking, pin != nil, !cameraAnimating, let target = lastFollowTarget else { return }
        let offset = GeoPoint(current.centerCoordinate).distance(to: GeoPoint(target.centerCoordinate))
        if offset > max(target.distance * 0.25, 60) { pin = nil }
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
