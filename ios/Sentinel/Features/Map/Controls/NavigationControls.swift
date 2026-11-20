import MapKit
import Observation
import SwiftUI

// Navigation: Banner mit Manöver und Querstraße, untere Leiste, Fahrspuren, Tempo und der Navi-Pfeil.

/// Oberer Teil der Navi-Ansicht: nächstes Manöver mit Entfernung, wie in einer Navi-App.
struct NavigationBanner: View {
    @Environment(RouteFollower.self) private var route

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: route.progress?.maneuverSymbol ?? "arrow.up")
                    .font(.system(size: 38, weight: .bold))
                    .frame(width: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text(headline)
                        .font(.title2.weight(.bold).monospacedDigit())
                    Text(route.progress?.nextInstruction ?? route.failure ?? "Route wird berechnet …")
                        .font(.headline)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            if route.isCalculating {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                    Text(route.route == nil ? "Route wird berechnet …" : "Route wird neu berechnet …")
                        .font(.footnote.weight(.semibold))
                }
                .foregroundStyle(.white.opacity(0.85))
                .transition(.opacity)
            } else {
                if let lanes = route.progress?.lanes, !lanes.isEmpty {
                    LaneRow(lanes: lanes)
                }
                if let following = route.progress?.followingInstruction {
                    Label("Dann: \(following)", systemImage: route.progress?.followingSymbol ?? "arrow.up")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                }
                if let cross = route.nextCrossStreet {
                    Label("Querstraße \(cross.name) · \(Format.distance(cross.distance))", systemImage: "plus")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }
            }
        }
        .animation(.snappy, value: route.isCalculating)
        .foregroundStyle(.white)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(route.specialRights ? Color(hex: "#6E1A1A") : Color(hex: "#1C1C1E"), in: .rect(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.white.opacity(0.08)))
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .combine)
    }

    private var headline: String {
        if let progress = route.progress { return Format.distance(progress.distanceToManeuver) }
        if let beeline = route.beeline { return Format.distance(beeline) }
        return "–"
    }
}

/// Unterer Teil der Navi-Ansicht: Ankunft, Restzeit, Ziel, Sonderrechte und Beenden.
struct NavigationBottomBar: View {
    @Environment(AppModel.self) private var model
    @Environment(RouteFollower.self) private var route
    @Environment(LageStore.self) private var lage

    var body: some View {
        @Bindable var route = route
        VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    if let progress = route.progress {
                        Text("\(Format.time(progress.arrival)) Ankunft")
                            .font(.headline.monospacedDigit())
                        Text("\(Format.duration(progress.remainingTime)), \(Format.distance(progress.remainingDistance))")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    } else {
                        Text(route.failure ?? "Route wird berechnet …")
                            .font(.subheadline)
                    }
                    Text(route.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Button {
                    model.stopNavigation()
                } label: {
                    Text("Beenden")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 18)
                        .frame(height: 44)
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.tint(.red).interactive(), in: .capsule)
            }

            // Dieselbe Dreier-Auswahl wie auf der Karte: Auto, zu Fuß, ÖPNV.
            GlassSegmentedControl(
                items: Fortbewegung.allCases.map { ($0, $0.symbolName, $0.title) },
                selection: route.transit ? .oepnv : (route.walking ? .fuss : .fahrzeug)
            ) { mode in
                route.transit = mode == .oepnv
                route.walking = mode != .fahrzeug
            }

            if route.transit {
                TransitPlanCard()
            }

            if !route.walking {
                Toggle(isOn: $route.specialRights) {
                    Label {
                        Text("Sonderrechte")
                            .font(.subheadline.weight(.semibold))
                    } icon: {
                        Image(systemName: "light.beacon.max.fill")
                            .foregroundStyle(route.specialRights ? Color.red : Color.secondary)
                    }
                }
                .tint(.red)
                .disabled(!lage.routingAvailable)
                .accessibilityHint(lage.routingAvailable ? "Einbahnstraßen und Abbiegeverbote werden ignoriert" : "Auf diesem Server nicht verfügbar")
            }
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

}

/// Fahrspuren am nächsten Manöver; die zu nutzenden hell, die übrigen gedämpft.
struct LaneRow: View {
    let lanes: [LaneHint]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(lanes.enumerated()), id: \.offset) { _, lane in
                Image(systemName: ManeuverSymbol.lane(lane.directions.first ?? "straight"))
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: 26, height: 26)
                    .foregroundStyle(lane.active ? Color.white : Color.white.opacity(0.35))
                    .background(Color.white.opacity(lane.active ? 0.18 : 0.06), in: .rect(cornerRadius: 5))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Spuren: \(lanes.filter(\.active).count) von \(lanes.count) nutzbar")
    }
}

/// Tempolimit im Stil des Verkehrszeichens.
struct SpeedLimitSign: View {
    let kmh: Int

    var body: some View {
        Text("\(kmh)")
            .font(.system(size: kmh >= 100 ? 15 : 18, weight: .heavy, design: .rounded).monospacedDigit())
            .foregroundStyle(.black)
            .frame(width: Theme.roundButton - 6, height: Theme.roundButton - 6)
            .background(.white, in: .circle)
            .overlay(Circle().strokeBorder(Color.red, lineWidth: 5))
            .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
            .accessibilityLabel("Höchstgeschwindigkeit \(kmh) Kilometer pro Stunde")
    }
}

/// Aktuelle Geschwindigkeit, rund wie in einer Navi-App.
struct SpeedBadge: View {
    let metersPerSecond: Double

    var body: some View {
        VStack(spacing: -2) {
            Text("\(Int((metersPerSecond * 3.6).rounded()))")
                .font(.system(size: 20, weight: .bold, design: .rounded).monospacedDigit())
            Text("km/h")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .frame(width: Theme.roundButton, height: Theme.roundButton)
        .glassEffect(.regular, in: .circle)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(Int((metersPerSecond * 3.6).rounded())) Kilometer pro Stunde")
    }
}

/// ÖPNV in der Navigation: beste Verbindung mit Bus und Bahn als Fahrtenkette (Transitous, Echtzeit wo vorhanden).
struct TransitPlanCard: View {
    @Environment(AppModel.self) private var model
    @Environment(RouteFollower.self) private var route
    @State private var plan: TransitPlan?
    @State private var loading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let plan {
                HStack {
                    Text("\(Format.time(Date(timeIntervalSince1970: plan.start / 1000))) – \(Format.time(Date(timeIntervalSince1970: plan.end / 1000)))")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                    Text(plan.transfers == 0 ? "ohne Umstieg" : "\(plan.transfers)× umsteigen")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(plan.legs.enumerated()), id: \.offset) { index, leg in
                            if index > 0 { Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.secondary) }
                            if leg.mode == "WALK" {
                                Label("\(max(1, Int((leg.to.time - leg.from.time) / 60_000))) Min.", systemImage: "figure.walk")
                                    .font(.caption)
                            } else {
                                HStack(spacing: 4) {
                                    LineBadge(line: NearbyStop.Line(ref: leg.name, typ: LiveSegment.osmType(leg.mode, name: leg.name), farbe: nil))
                                    Text("\(Format.time(Date(timeIntervalSince1970: leg.from.time / 1000))) \(leg.from.name)")
                                        .font(.caption)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                }
            } else if loading {
                HStack { ProgressView(); Text("Verbindung wird gesucht …").font(.subheadline) }
            } else {
                HStack {
                    Text("Keine Verbindung gefunden.").font(.subheadline)
                    Spacer()
                    Button("Apple Karten") { route.openInMaps() }.buttonStyle(.glass)
                }
            }
        }
        .task(id: route.destination.map { "\($0.lat),\($0.lon)" }) {
            loading = true
            defer { loading = false }
            guard let client = model.client, let from = model.myPoint, let to = route.destination else { return }
            plan = (try? await client.transitPlans(from: from, to: to))?.first
        }
    }
}

/// Eigener Standort im Fahrmodus: Navi-Pfeil fest an der Kameramitte, darunter Straße und Fahrtrichtung.
/// Weil die Kamera gleichmäßig gleitet, bewegt sich der Pfeil ohne Sprünge.
struct FollowPuckOverlay: View {
    /// Navi-Pfeil nur in der Navigation; sonst nur das Straßenbanner (der Standortpunkt kommt von der Karte).
    var showsArrow = true
    let proxy: MapProxy
    let state: MapCameraState
    let inVehicle: Bool
    let holdsA: Bool
    let label: String?
    var course: CLLocationDirection?

    var body: some View {
        GeometryReader { geometry in
            // Fällt die Umrechnung kurz aus (z. B. während MapKit die Kamera setzt), bleibt der Pfeil in der Mitte statt zu verschwinden.
            let point = proxy.convert(state.center, to: .local) ?? CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            ZStack {
                if showsArrow {
                NavigationArrow()
                    // Flach auf der Karte: in Fahrtrichtung gedreht und mit der Kartenneigung gekippt.
                    .rotationEffect(.degrees((course ?? state.heading) - state.heading))
                    .rotation3DEffect(.degrees(state.pitch), axis: (x: 1, y: 0, z: 0), perspective: 0.4)
                    .overlay(alignment: .topTrailing) {
                        if holdsA {
                            ASymbol(size: 18)
                                .overlay(Circle().stroke(.white, lineWidth: 1.5))
                                .offset(x: 6, y: -6)
                        } else if inVehicle {
                            Image(systemName: "car.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 20, height: 20)
                                .background(Color.indigo, in: .circle)
                                .overlay(Circle().stroke(.white, lineWidth: 1.5))
                                .offset(x: 6, y: -6)
                        }
                    }
                    .position(point)
                }
                if let label {
                    Text(label)
                        .font(.footnote.weight(.semibold))
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .glassEffect(.regular, in: .capsule)
                        .fixedSize()
                        .position(x: point.x, y: point.y + 46)
                }
            }
            .allowsHitTesting(false)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Eigener Standort\(label.map { ": \($0)" } ?? "")")
        }
    }
}

/// Navi-Pfeil: zeigt nach oben, weil sich die Karte im Fahrmodus in Fahrtrichtung dreht.
struct NavigationArrow: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 46, height: 46)
                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
            Circle()
                .fill(Theme.accent)
                .frame(width: 38, height: 38)
            Image(systemName: "location.north.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}
