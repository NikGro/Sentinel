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

    var sideButtons: some View {
        GlassEffectContainer(spacing: Theme.barSpacing) {
            VStack(spacing: Theme.barSpacing) {
                if !reducedTools { SOSButton() }
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
                // Beim Folgen: Zoomen per Knopf, ohne dass ein leichtes Verrutschen der Finger die Kopplung löst.
                if followsMe {
                    VStack(spacing: 0) {
                        Button { zoomFollowing(by: 0.6) } label: {
                            Image(systemName: "plus").frame(width: Theme.roundButton, height: Theme.roundButton).contentShape(.rect)
                        }
                        .accessibilityLabel("Näher heranzoomen")
                        Divider().frame(width: 24)
                        Button { zoomFollowing(by: 1.6) } label: {
                            Image(systemName: "minus").frame(width: Theme.roundButton, height: Theme.roundButton).contentShape(.rect)
                        }
                        .accessibilityLabel("Weiter herauszoomen")
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .capsule)
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
    func zoomFollowing(by factor: Double) {
        let heading = camera.followsUserHeading
        let distance = min(max(cameraState.distance * factor, 150), 20_000)
        if let current = location.current {
            withAnimation(.easeInOut(duration: 0.35)) {
                camera = .camera(MapCamera(centerCoordinate: current.coordinate, distance: distance, heading: cameraState.heading, pitch: cameraState.pitch))
            }
        }
        Task {
            try? await Task.sleep(for: .milliseconds(380))
            camera = .userLocation(followsHeading: heading, fallback: .automatic)
        }
    }

    /// Fahrmodus: erst nah und gekippt auf den Standort, dann der nativen, flüssigen Nachführung übergeben.
    func startFollowing(heading: Bool, north: Bool = false) {
        if let current = location.current {
            withAnimation(.easeInOut(duration: 0.6)) {
                camera = .camera(MapCamera(
                    centerCoordinate: current.coordinate,
                    distance: followsMe ? cameraState.distance : (route.isActive ? 450 : 500),
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
            } else if searchPin == nil, reducedTools {
                SpecialAreaBar()
            } else if searchPin == nil {
                HStack(spacing: Theme.barSpacing) {
                    MobilityControl { mobilityChoice = $0 }
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
