import MapKit
import SwiftUI

/// Deutschlandweite ÖPNV-Karte im Stil von Travic: fahrende Fahrzeuge, Linienverläufe und Haltestellen entdecken,
/// suchen, antippen, prüfen und dann gezielt in die Lage übernehmen (Fahrzeug, Strecke, Haltestellen).
/// Daten über den eigenen Server von Transitous (DELFI u. a.), Echtzeit wo verfügbar.
struct TransitExplorer: View {
    let start: GeoPoint
    /// Einsteigen statt Übernehmen: Die gewählte Fahrt wird die eigene Fortbewegung.
    var board: ((TripDetail) -> Void)?

    @Environment(AppModel.self) private var model
    @Environment(LageStore.self) private var lage
    @Environment(\.dismiss) private var dismiss

    enum Selection: Equatable {
        case vehicle(tripId: String)
        case stop(LiveStop)
    }

    enum Part: String, CaseIterable, Identifiable {
        case fahrzeug, strecke, haltestellen
        var id: String { rawValue }
        var title: String {
            switch self {
            case .fahrzeug: "Fahrzeug"
            case .strecke: "Strecke"
            case .haltestellen: "Haltestellen"
            }
        }
        var symbol: String {
            switch self {
            case .fahrzeug: "bus.fill"
            case .strecke: "point.bottomleft.forward.to.point.topright.scurvepath"
            case .haltestellen: "h.circle.fill"
            }
        }
    }

    /// Eigene Kartensteuerung wie auf der Lagekarte (gleiches Gefühl beim Verschieben, Zoomen, Drehen).
    @State private var engine = MapEngine()
    @State private var cameraState = MapCameraState()
    @State private var region: MKCoordinateRegion?
    @State private var segments: [LiveSegment] = []
    @State private var stops: [LiveStop] = []
    @State private var tooLarge = false
    @State private var failure: String?
    /// Uhr für die fahrenden Fahrzeuge; nur die Fahrzeugebene der Karte liest sie (siehe `ClockedContent`).
    @State private var clock = TransitClock()
    @State private var query = ""
    @State private var stopHits: [NearbyStop] = []
    /// Nur Fahrzeuge dieser Linie zeigen (aus Suche oder „Alle Fahrzeuge der Linie“).
    @State private var lineFilter: String?
    @State private var selection: Selection?
    @State private var trip: TripDetail?
    @State private var departures: [LiveDeparture] = []
    @State private var parts: Set<Part> = [.fahrzeug]
    @FocusState private var searching: Bool

    var body: some View {
        NavigationStack {
            Map(initialPosition: .region(MKCoordinateRegion(center: start.coordinate, latitudinalMeters: 2500, longitudinalMeters: 2500)), interactionModes: []) {
                    UserAnnotation()
                    if let trip, trip.points.count >= 2 {
                        MapPolyline(coordinates: trip.points.map(\.coordinate))
                            .stroke(.white, style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
                        MapPolyline(coordinates: trip.points.map(\.coordinate))
                            .stroke(Color(hex: tripColor), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                        ForEach(Array(trip.stops.enumerated()), id: \.offset) { _, stop in
                            Annotation(stop.name, coordinate: stop.point.coordinate, anchor: .center) {
                                StationSymbol(lines: [NearbyStop.Line(ref: trip.name, typ: LiveSegment.osmType(trip.mode, name: trip.name), farbe: nil)], size: 14)
                            }
                        }
                    }
                    ForEach(visibleStops) { stop in
                        Annotation(stop.name, coordinate: stop.point.coordinate, anchor: .center) {
                            // Dasselbe Haltestellensymbol wie auf der Lagekarte.
                            StationSymbol(lines: [], size: selection == .stop(stop) ? 22 : 14)
                                .onTapGesture { select(.stop(stop)) }
                        }
                        .annotationTitles(showsStopNames ? .visible : .hidden)
                    }
                    ClockedContent(clock: clock) { now in
                        ForEach(vehicles(at: now)) { vehicle in
                            Annotation(vehicle.segment.name, coordinate: vehicle.point.coordinate, anchor: .center) {
                                VehicleBadge(segment: vehicle.segment, selected: selection == .vehicle(tripId: vehicle.segment.tripId))
                                    .onTapGesture { select(.vehicle(tripId: vehicle.segment.tripId)) }
                            }
                            .annotationTitles(.hidden)
                        }
                    }
                }
                .mapStyle(.standard(pointsOfInterest: .excludingAll))
                // Eigener Kompassknopf statt Apples Kompass, wie in den übrigen reduzierten Ansichten.
                .mapControls { MapScaleView() }
                .mapEngine(engine)
                .onMapCameraChange(frequency: .continuous) { context in
                    cameraState.update(context.camera)
                }
                .onMapCameraChange(frequency: .onEnd) { context in
                    region = context.region
                }
                // SOS und Kompassknopf an der gewohnten Stelle oben rechts: Antippen springt zum eigenen Standort
                // (Norden oben).
                .overlay(alignment: .topTrailing) {
                    VStack(spacing: Theme.barSpacing) {
                        SOSButton()
                        LocationCompassButton(state: cameraState, pin: nil) {
                            guard let me = model.myPoint else { return }
                            engine.fly(to: MapCamera(centerCoordinate: me.coordinate, distance: 1500, heading: 0, pitch: 0))
                        }
                    }
                    .padding(.trailing, Theme.barInset)
                    .padding(.top, Theme.barSpacing)
                }
            .safeAreaInset(edge: .top, spacing: 0) { searchBar }
            .safeAreaInset(edge: .bottom, spacing: 0) { bottomCard }
            .navigationTitle(board == nil ? "ÖPNV-Karte" : "Fahrzeug wählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
            // Fahrzeuge alle 20 Sekunden neu laden (Echtzeit), Positionen fünfmal je Sekunde weiterrechnen.
            .task(id: region.map { "\($0.center.latitude.rounded(to: 3))|\($0.center.longitude.rounded(to: 3))|\($0.span.latitudeDelta.rounded(to: 3))" }) {
                while !Task.isCancelled {
                    await load()
                    try? await Task.sleep(for: .seconds(20))
                }
            }
            .task {
                while !Task.isCancelled {
                    // Kurze Schritte statt einer Animation je Sekunde: flüssig, auch wenn die Karte zwischendurch neu zeichnet.
                    // Zehn kleine Schritte je Sekunde ohne Animation: ruhig, auch wenn sich die Kamera bewegt.
                    try? await Task.sleep(for: .milliseconds(100))
                    clock.now = .now
                }
            }
            .task(id: query) {
                stopHits = []
                guard query.count >= 3, let client = model.client else { return }
                try? await Task.sleep(for: .milliseconds(300))
                stopHits = (try? await client.searchStops(query, near: region.map { GeoPoint($0.center) } ?? start)) ?? []
            }
        }
    }

    // MARK: Daten

    private func load() async {
        guard let region, let client = model.client else { return }
        let min = GeoPoint(lat: region.center.latitude - region.span.latitudeDelta / 2, lon: region.center.longitude - region.span.longitudeDelta / 2)
        let max = GeoPoint(lat: region.center.latitude + region.span.latitudeDelta / 2, lon: region.center.longitude + region.span.longitudeDelta / 2)
        let zoom = Int((log2(360 / Swift.max(region.span.longitudeDelta, 0.0001))).rounded())
        do {
            let result = try await client.liveVehicles(min: min, max: max, zoom: zoom)
            segments = result.segments
            tooLarge = result.tooLarge
            failure = nil
            // Haltestellen erst nah genug. Bei sehr nahem Zoom einen etwas größeren Ausschnitt laden und bereits geladene
            // behalten: Eine abgebrochene oder fehlgeschlagene Abfrage (die nächste Kartenbewegung bricht sie ab) darf
            // die Haltestellen nicht leeren.
            if region.span.latitudeDelta < 0.03 {
                let padLat = Swift.max(0, 0.02 - region.span.latitudeDelta) / 2, padLon = Swift.max(0, 0.03 - region.span.longitudeDelta) / 2
                let lower = GeoPoint(lat: min.lat - padLat, lon: min.lon - padLon), upper = GeoPoint(lat: max.lat + padLat, lon: max.lon + padLon)
                if let loaded = try? await client.liveStops(min: lower, max: upper), !Task.isCancelled {
                    var merged = Dictionary(stops.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
                    for stop in loaded { merged[stop.id] = stop }
                    // Nur die in der Nähe des Ausschnitts behalten, damit die Karte nicht voll läuft.
                    let center = GeoPoint(region.center)
                    stops = merged.values.filter { $0.point.distance(to: center) < 3000 }.sorted { $0.id < $1.id }
                }
            } else {
                stops = []
            }
        } catch {
            if (error as? URLError)?.code != .cancelled, !(error is CancellationError) { failure = "ÖPNV-Daten zurzeit nicht erreichbar." }
        }
    }

    private var showsStopNames: Bool { (region?.span.latitudeDelta ?? 1) < 0.012 }

    struct LiveVehicle: Identifiable {
        let segment: LiveSegment
        let point: GeoPoint
        var id: String { segment.tripId }
    }

    /// Je Fahrt ein Fahrzeug an seiner aktuellen Position.
    private func vehicles(at now: Date) -> [LiveVehicle] {
        var byTrip: [String: (LiveSegment, GeoPoint)] = [:]
        for segment in segments {
            if let filter = lineFilter, segment.name.caseInsensitiveCompare(filter) != .orderedSame { continue }
            if let point = segment.position(at: now) {
                byTrip[segment.tripId] = (segment, point)
            } else if byTrip[segment.tripId] == nil, now.timeIntervalSince1970 * 1000 < segment.dep, segment.dep - now.timeIntervalSince1970 * 1000 < 90_000 {
                // Steht noch am Halt vor der Abfahrt.
                byTrip[segment.tripId] = (segment, segment.from.point)
            }
        }
        return byTrip.values.map { LiveVehicle(segment: $0.0, point: $0.1) }.sorted { $0.id < $1.id }
    }

    private var visibleStops: [LiveStop] { lineFilter == nil ? stops : [] }

    /// Linien im Ausschnitt, die zur Eingabe passen.
    private var lineHits: [(name: String, mode: String)] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        var seen = Set<String>()
        return segments.compactMap { segment in
            guard segment.name.lowercased().hasPrefix(q), seen.insert(segment.name).inserted else { return nil }
            return (segment.name, segment.mode)
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        .prefix(12).map { $0 }
    }

    /// Dieselbe Farbe wie die Fahrzeugschilder in der Karte (nach Verkehrsart), damit ein übernommenes Fahrzeug
    /// so aussieht wie vorher; die Fahrzeuge der Live-Karte kommen ohne eigene Linienfarbe.
    private var tripColor: String {
        guard let trip else { return "#0A84FF" }
        return LineBadge.routeHex(NearbyStop.Line(ref: trip.name, typ: LiveSegment.osmType(trip.mode, name: trip.name), farbe: nil))
    }

    private func select(_ new: Selection) {
        selection = new
        trip = nil
        departures = []
        searching = false
        Task {
            guard let client = model.client else { return }
            switch new {
            case .vehicle(let tripId):
                parts = [.fahrzeug]
                trip = try? await client.trip(id: tripId)
            case .stop(let stop):
                parts = [.haltestellen]
                departures = (try? await client.departures(stopId: stop.stopId)) ?? []
            }
        }
    }

    // MARK: Suche

    private var searchBar: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Linie oder Haltestelle, z. B. 4, U3, S1, Hauptbahnhof", text: $query)
                    .focused($searching)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                if lineFilter != nil || !query.isEmpty {
                    Button("Zurücksetzen", systemImage: "xmark.circle.fill") {
                        query = ""
                        lineFilter = nil
                    }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: Theme.roundButton)
            .glassEffect(.regular.interactive(), in: .capsule)

            if searching, !(lineHits.isEmpty && stopHits.isEmpty) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(lineHits.indices, id: \.self) { index in
                            let hit = lineHits[index]
                            Button {
                                lineFilter = hit.name
                                query = hit.name
                                searching = false
                                zoomToLine(hit.name)
                            } label: {
                                HStack(spacing: 10) {
                                    LineBadge(line: NearbyStop.Line(ref: hit.name, typ: LiveSegment.osmType(hit.mode, name: hit.name), farbe: nil))
                                    Text("Alle Fahrzeuge der Linie \(hit.name)")
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                        }
                        ForEach(stopHits) { stop in
                            Button {
                                searching = false
                                engine.show(MKCoordinateRegion(center: stop.point.coordinate, latitudinalMeters: 800, longitudinalMeters: 800))
                            } label: {
                                HStack(spacing: 10) {
                                    StationSymbol(lines: stop.linien, size: 18)
                                    Text(stop.name)
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 14)
                }
                .frame(maxHeight: 260)
                .glassEffect(.regular, in: .rect(cornerRadius: 18))
            }
        }
        .padding(.horizontal, Theme.barInset)
        .padding(.vertical, 6)
    }

    private func zoomToLine(_ name: String) {
        let points = segments.filter { $0.name.caseInsensitiveCompare(name) == .orderedSame }.flatMap(\.points)
        guard !points.isEmpty else { return }
        var rect = MKMapRect.null
        for p in points { rect = rect.union(MKMapRect(origin: MKMapPoint(p.coordinate), size: MKMapSize(width: 0, height: 0))) }
        let pad = Swift.max(rect.width, rect.height) * 0.2 + 400
        engine.show(rect.insetBy(dx: -pad, dy: -pad))
    }

    // MARK: Auswahl und Übernahme

    @ViewBuilder private var bottomCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch selection {
            case .vehicle(let tripId):
                vehicleCard(tripId)
            case .stop(let stop):
                stopCard(stop)
            case nil:
                hintCard
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
        .padding(.horizontal, Theme.barInset)
        .padding(.bottom, 6)
    }

    private var hintCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let failure {
                Label(failure, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
            } else if tooLarge {
                Label("Zum Anzeigen der Fahrzeuge näher heranzoomen.", systemImage: "plus.magnifyingglass")
            } else {
                Text("Fahrzeug oder Haltestelle antippen, um es zu übernehmen.")
            }
            Text("Daten: Transitous · DELFI u. a. · Echtzeit, wo verfügbar")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
    }

    @ViewBuilder private func vehicleCard(_ tripId: String) -> some View {
        let segment = segments.first { $0.tripId == tripId }
        // Linienschild (wie überall), daneben nur die Richtung.
        HStack(spacing: 10) {
            if let segment { LineBadge(line: segment.badge, size: 15) }
            VStack(alignment: .leading, spacing: 2) {
                Text(trip?.headsign ?? segment?.to.name ?? "Fahrt")
                    .font(.headline)
                    .lineLimit(1)
                if let segment {
                    Text(segment.realTime ? delayText(segment.delay) : "Fahrplan, keine Echtzeit")
                        .font(.caption)
                        .foregroundStyle(segment.realTime ? ((segment.delay ?? 0) > 120 ? .orange : .green) : .secondary)
                }
            }
            Spacer()
            closeButton
        }
        if trip == nil {
            ProgressView().frame(maxWidth: .infinity)
        }
        if let board {
            // Wie beim Übernehmen: was zusätzlich auf die Lagekarte kommt (nichts gewählt = nur einsteigen).
            partsPicker
            Button {
                if let trip {
                    if !parts.isEmpty { saveLine(trip) }
                    board(trip)
                    dismiss()
                }
            } label: {
                Label("Einsteigen", systemImage: Fortbewegung.oepnv.symbolName)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(trip == nil)
        } else {
            partsPicker
            Button {
                if let trip { adopt(trip) }
            } label: {
                Label("Übernehmen", systemImage: "checkmark")
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(trip == nil || parts.isEmpty)
        }
    }

    @ViewBuilder private func stopCard(_ stop: LiveStop) -> some View {
        HStack {
            StationSymbol(lines: [], size: 22)
            Text(stop.name).font(.headline).lineLimit(1)
            Spacer()
            closeButton
        }
        if departures.isEmpty {
            Text("Abfahrten werden geladen …").font(.caption).foregroundStyle(.secondary)
        } else {
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(departures.prefix(8)) { departure in
                        Button {
                            select(.vehicle(tripId: departure.tripId))
                        } label: {
                            HStack(spacing: 8) {
                                LineBadge(line: NearbyStop.Line(ref: departure.name, typ: LiveSegment.osmType(departure.mode, name: departure.name), farbe: nil))
                                Text(departure.headsign).lineLimit(1)
                                Spacer()
                                Text(Format.time(Date(timeIntervalSince1970: departure.time / 1000)))
                                    .monospacedDigit()
                                if departure.realTime, departure.delayMinutes > 0 {
                                    Text("+\(departure.delayMinutes)").font(.caption.weight(.bold)).foregroundStyle(.orange)
                                }
                            }
                            .font(.subheadline)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: 180)
        }
        if board == nil {
            Button {
                adopt(stop: stop)
            } label: {
                Label("Haltestelle übernehmen", systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
        }
    }

    private var closeButton: some View {
        Button {
            selection = nil
            trip = nil
        } label: {
            Image(systemName: "xmark")
                .font(.subheadline.weight(.bold))
                .frame(width: 32, height: 32)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("Auswahl aufheben")
    }

    /// Was übernommen wird, als Pillen wie im Verlauf: Fahrzeug, Strecke, Haltestellen. Es entsteht eine ÖPNV-Strecke
    /// mit genau diesen Ebenen; sie lassen sich später in der Strecke ändern.
    private var partsPicker: some View {
        PillPicker(items: Part.allCases, selection: $parts, title: \.title, symbol: \.symbol)
    }

    private func delayText(_ delay: Int?) -> String {
        guard let delay else { return "Echtzeit" }
        let minutes = Int((Double(delay) / 60).rounded())
        return minutes <= 0 ? "pünktlich (Echtzeit)" : "+\(minutes) Min. (Echtzeit)"
    }

    /// Übernimmt die gewählten Teile einer Fahrt als eine ÖPNV-Strecke.
    private func adopt(_ trip: TripDetail) {
        saveLine(trip)
        dismiss()
    }

    private func saveLine(_ trip: TripDetail) {
        let points = trip.stops.map(\.point)
        guard points.count >= 2 else { return }
        let names = trip.stops.map(\.name)
        let typ = LiveSegment.osmType(trip.mode, name: trip.name)
        let color = tripColor
        let ref = TransitRef(id: trip.tripId, ref: trip.name, typ: typ, richtung: trip.headsign, farbe: nil)
        let times = trip.stops.map { $0.dep ?? $0.arr }
        // Eine ÖPNV-Strecke mit den gewählten Ebenen; mit Fahrzeug fährt es nach echtem Fahrplan (Server führt nach).
        var line = MapObject(layerId: Layer.lageId, typ: .oepnvlinie, titel: "\(trip.name) → \(trip.headsign)", farbe: color, punkte: points, zeit: times.compactMap { $0 }.first)
        line.linie = ref
        line.haltNamen = names
        line.weg = trip.points.isEmpty ? nil : trip.points
        line.fahrt = TransitTrip(id: trip.tripId, zeiten: times, haltIds: trip.stops.map(\.stopId), echtzeit: trip.realTime, stand: (Date.now.timeIntervalSince1970 * 1000).rounded())
        line.ebenen = TransitLayerChoice(fahrzeug: parts.contains(.fahrzeug), strecke: parts.contains(.strecke), halte: parts.contains(.haltestellen))
        // Nur das Fahrzeug: verschwindet nach der Ankunft von selbst.
        if parts == [.fahrzeug], let end = times.compactMap({ $0 }).last { line.ablauf = end + 300_000 }
        lage.saveMapObject(line, id: LageStore.newId())
    }

    private func adopt(stop: LiveStop) {
        let pin = MapObject(layerId: Layer.lageId, typ: .haltestelle, titel: stop.name, farbe: "#0A84FF", punkte: [stop.point])
        lage.saveMapObject(pin, id: LageStore.newId())
        dismiss()
    }
}

/// Fahrzeug auf der ÖPNV-Karte: Liniennummer in Linienfarbe, ausgewählt größer.
private struct VehicleBadge: View {
    let segment: LiveSegment
    let selected: Bool

    var body: some View {
        LineBadge(line: segment.badge)
            .scaleEffect(selected ? 1.8 : 1.25)
            .shadow(color: .black.opacity(0.35), radius: selected ? 4 : 1.5)
            .overlay {
                if selected {
                    RoundedRectangle(cornerRadius: 4).stroke(.white, lineWidth: 2).scaleEffect(2.1)
                }
            }
            .animation(.snappy, value: selected)
            .accessibilityLabel("\(segment.name), \(segment.from.name) nach \(segment.to.name)")
            .accessibilityAddTraits(.isButton)
    }
}

private extension Double {
    func rounded(to places: Int) -> Double {
        let factor = pow(10, Double(places))
        return (self * factor).rounded() / factor
    }
}
