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
        GlassEffectContainer(spacing: Theme.barSpacing) {
            VStack(spacing: Theme.barSpacing) {
                if !reducedTools { SOSButton() }
                // Ein Knopf für Standort und Kompass: heftet immer an und wechselt dann zwischen Fahrtrichtung und
                // Norden oben. Zoomen und Drehen gehen mit zwei Fingern; erst bewusstes Verschieben löst die Kopplung.
                LocationCompassButton(state: cameraState, pin: pin) {
                    pinCamera(pin == .heading ? .north : .heading)
                }
                MapStyleButton { on in
                    animateCamera(cameraState.camera(pitch: on ? 55 : 0))
                }
                MapRoundButton(title: "Ebenen", symbol: "square.3.layers.3d") { showsLayers = true }
                if !reducedTools, let a = lage.aPosition, !lage.holdsA {
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
                AddMenu(scope: model.editsPermanentLayer ? .places : (lage.isPackageArea ? .package : .all)) { action in
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

    /// Eigene Bewegungs- bzw. Blickrichtung für den Navi-Pfeil.
    var myCourse: CLLocationDirection? {
        if let current = route.snappedLocation ?? location.current, current.course >= 0, current.speed > 1 { return current.course }
        return locationContext.compassDegrees
    }

    /// Zoomt, während die Karte dem Standort folgt, und bleibt dabei gekoppelt.
    /// Heftet die Karte an den eigenen Standort: nah und flach in Fahrtrichtung oder senkrecht mit Norden oben.
    /// Erst fährt die Kamera dorthin, dann übernimmt die flüssige Nachführung von Apple Karten.
    func pinCamera(_ mode: CameraPin) {
        pin = mode
        guard let current = location.current else {
            camera = .userLocation(followsHeading: mode == .heading, fallback: .camera(cameraState.camera()))
            return
        }
        let heading = mode == .heading ? (myCourse ?? cameraState.heading) : 0
        animateCamera(MapCamera(centerCoordinate: current.coordinate, distance: mode.distance, heading: heading, pitch: mode.pitch))
    }

    /// Bewegt die Kamera; ist sie angeheftet, übernimmt danach wieder die Nachführung.
    func animateCamera(_ target: MapCamera) {
        cameraAnimating = true
        withAnimation(.easeInOut(duration: 0.5)) { camera = .camera(target) }
        // Fest nach der Animationsdauer übergeben (die Abschlussmeldung kommt bei der Karte nicht zuverlässig).
        Task {
            try? await Task.sleep(for: .milliseconds(560))
            cameraAnimating = false
            if let pin { follow(pin, distance: target.distance) }
        }
    }

    /// Übergibt an die flüssige Nachführung von Apple Karten. Die setzt sonst ihre eigene Zoomstufe; deshalb wird die
    /// gewünschte Entfernung für einen Moment festgehalten und danach wieder freigegeben (Zoomen mit zwei Fingern).
    func follow(_ mode: CameraPin, distance: CLLocationDistance) {
        // Ohne Standort bleibt die Karte, wo sie ist (statt auf „alles zeigen“ zu springen).
        cameraBounds = MapCameraBounds(minimumDistance: distance * 0.9, maximumDistance: distance * 1.1)
        camera = .userLocation(followsHeading: mode == .heading, fallback: .camera(cameraState.camera()))
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            cameraBounds = nil
        }
    }

    /// Nach einer Geste: Ist die Karte nur gezoomt, gedreht oder leicht verrutscht (Mitte nah am eigenen Standort),
    /// bleibt sie angeheftet. Wer sie spürbar wegschiebt, löst die Kopplung; die Karte bleibt dann, wie sie ist.
    func keepPinAfterGesture(_ current: MapCamera) {
        guard let mode = pin, !cameraAnimating, !camera.followsUserLocation else { return }
        guard let here = location.current?.coordinate else { return }
        let offset = GeoPoint(current.centerCoordinate).distance(to: GeoPoint(here))
        if offset < max(current.distance * 0.06, 12) {
            follow(mode, distance: current.distance)
        } else {
            pin = nil
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
            if route.isActive {
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
            if searchPin == nil, !reducedTools {
                SituationBar { showsSituation = true }
            }
        }
        .padding(.horizontal, Theme.barInset)
        .padding(.bottom, Theme.barSpacing)
        .animation(.snappy, value: route.isActive)
    }
}
