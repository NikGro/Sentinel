import Foundation
import Observation

/// Die laufende Lage, wie sie der Server verteilt: alle gemeinsamen Objekte, Einsatzzustand und Live-Positionen.
/// Einzige Quelle der Wahrheit für die Oberfläche. Schreibzugriffe gehen immer über den Server und kommen als Ereignis zurück.
@MainActor
@Observable
final class LageStore {
    private(set) var connection: ConnectionState = .getrennt
    private(set) var hasSnapshot = false
    private(set) var selfId: String?
    private(set) var routingAvailable = false

    private(set) var members: [String: Versioned<Member>] = [:]
    private(set) var vehicles: [String: Versioned<Vehicle>] = [:]
    private(set) var mapObjects: [String: Versioned<MapObject>] = [:]
    private(set) var targets: [String: Versioned<Target>] = [:]
    private(set) var trackers: [String: Versioned<Tracker>] = [:]
    private(set) var layers: [String: Versioned<Layer>] = [:]
    private(set) var messages: [Versioned<ChatMessage>] = []

    private(set) var operation = OperationState()
    private(set) var positions: [String: Position] = [:]
    private(set) var trackerPositions: [String: Position] = [:]
    private(set) var online: Set<String> = []

    /// Wird hochgezählt, wenn die Bestreifung neu geladen werden muss.
    private(set) var coverageGeneration = 0
    /// Letzte Fehlermeldung des Servers, zur Anzeige.
    var lastError: String?

    private(set) var undoStack = UndoStack()

    private let realtime = RealtimeClient()
    private var onUnauthorized: () -> Void = {}
    /// Empfänger für Positionsmeldungen, z. B. die Bestreifungsanzeige.
    var onMemberPosition: (String, Position) -> Void = { _, _ in }

    init() {
        realtime.onMessage = { [weak self] data in self?.receive(data) }
        realtime.onStateChange = { [weak self] state in self?.connection = state }
        realtime.onUnauthorized = { [weak self] in self?.onUnauthorized() }
    }

    // MARK: Verbindung

    func connect(credentials: Credentials, onUnauthorized: @escaping () -> Void) {
        self.onUnauthorized = onUnauthorized
        selfId = credentials.deviceId
        realtime.start(credentials: credentials)
    }

    func disconnect() {
        realtime.stop()
        hasSnapshot = false
        members = [:]
        vehicles = [:]
        mapObjects = [:]
        targets = [:]
        trackers = [:]
        layers = [:]
        messages = []
        positions = [:]
        trackerPositions = [:]
        online = []
        operation = OperationState()
        undoStack.clear()
    }

    // MARK: Abgeleitete Sichten

    var me: Versioned<Member>? { selfId.flatMap { members[$0] } }
    var myPosition: Position? { selfId.flatMap { positions[$0] } }
    var holdsA: Bool { operation.a?.memberId == selfId && selfId != nil }
    var aHolder: Versioned<Member>? { operation.a.flatMap { members[$0.memberId] } }
    var aPosition: Position? { operation.a.flatMap { positions[$0.memberId] } }

    var sortedMembers: [Versioned<Member>] {
        members.values.sorted { $0.data.funkrufname.localizedStandardCompare($1.data.funkrufname) == .orderedAscending }
    }

    var sortedTargets: [Versioned<Target>] {
        targets.values.sorted { $0.data.displayName.localizedStandardCompare($1.data.displayName) == .orderedAscending }
    }

    var sortedVehicles: [Versioned<Vehicle>] {
        vehicles.values.sorted { $0.data.bezeichnung.localizedStandardCompare($1.data.bezeichnung) == .orderedAscending }
    }

    var sortedLayers: [Versioned<Layer>] {
        layers.values.sorted { lhs, rhs in
            let order = ["lage": 0, "dauerhaft": 1, "paket": 2, "argus": 3]
            let l = order[lhs.data.art] ?? 9
            let r = order[rhs.data.art] ?? 9
            return l == r ? lhs.data.name < rhs.data.name : l < r
        }
    }

    func isOnline(_ memberId: String) -> Bool { online.contains(memberId) }

    func occupants(of vehicleId: String) -> [Versioned<Member>] {
        sortedMembers.filter { $0.data.fahrzeugId == vehicleId }
    }

    /// Aktueller Standort eines Fahrzeugs: frischer Tracker vor Insassen vor Abstellort.
    func position(ofVehicle vehicle: Versioned<Vehicle>) -> (point: GeoPoint, date: Date, source: String)? {
        let occupantPosition = occupants(of: vehicle.id).compactMap { positions[$0.id] }.max { $0.ts < $1.ts }
        let trackerPosition = vehicle.data.trackerId.flatMap { trackerPositions[$0] }
        if let trackerPosition, trackerPosition.ts >= (occupantPosition?.ts ?? 0) - 120_000 {
            return (trackerPosition.point, trackerPosition.date, "Tracker")
        }
        if let occupantPosition { return (occupantPosition.point, occupantPosition.date, "Besatzung") }
        if let trackerPosition { return (trackerPosition.point, trackerPosition.date, "Tracker") }
        if let parked = vehicle.data.abgestellt {
            return (GeoPoint(lat: parked.lat, lon: parked.lon), Date(timeIntervalSince1970: parked.ts / 1000), "Abgestellt")
        }
        return nil
    }

    func position(ofTarget target: Versioned<Target>) -> Position? {
        target.data.trackerId.flatMap { trackerPositions[$0] }
    }

    func name(of actorId: String) -> String {
        if actorId == "zentrale" { return "Zentrale" }
        if actorId == "system" { return "System" }
        return members[actorId]?.data.funkrufname ?? "Unbekannt"
    }

    // MARK: Schreiben

    private func nextRef() -> String { UUID().uuidString }

    static func newId() -> String {
        UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    }

    @discardableResult
    func put<T: LageEntity>(_ data: T, id: String) -> Bool {
        report(realtime.send(WireCodec.put(id: id, data: data, ref: nextRef())))
    }

    @discardableResult
    func delete<T: LageEntity>(_ type: T.Type, id: String) -> Bool {
        report(realtime.send(WireCodec.delete(kind: T.kind, id: id, ref: nextRef())))
    }

    @discardableResult
    func command(_ name: String) -> Bool {
        report(realtime.send(WireCodec.command(name, ref: nextRef())))
    }

    @discardableResult
    func command<A: Encodable>(_ name: String, args: A) -> Bool {
        report(realtime.send(WireCodec.command(name, args: args, ref: nextRef())))
    }

    func sendPosition(_ position: Position) {
        realtime.send(WireCodec.position(position))
    }

    private func report(_ sent: Bool) -> Bool {
        if !sent { lastError = "Keine Verbindung zum Server. Die Änderung wurde nicht übernommen." }
        return sent
    }

    // MARK: Einsatz-Kommandos

    func setMode(_ modus: Modus) { command("modus.setzen", args: ["modus": modus.rawValue]) }
    func claimA() { command("a.uebernehmen") }
    func releaseA() { command("a.freigeben") }
    func setChannel(_ channel: String?) { command("funkkanal.setzen", args: ["kanal": channel]) }
    func setSituation(title: String, notes: String) { command("lage.setzen", args: ["titel": title, "hinweise": notes]) }
    func clearLastKnownPosition() { command("lkp.loeschen") }
    func board(vehicleId: String) { command("fahrzeug.einsteigen", args: ["fahrzeugId": vehicleId]) }
    func leaveVehicle() { command("fahrzeug.aussteigen") }
    func resetCoverage() { command("bestreifung.zuruecksetzen") }

    private struct LastKnownArgs: Encodable {
        let lat: Double
        let lon: Double
        let ts: Double
        let targetId: String?
    }

    func setLastKnownPosition(_ point: GeoPoint, at date: Date = .now, targetId: String? = nil) {
        let ts = (date.timeIntervalSince1970 * 1000).rounded()
        command("lkp.setzen", args: LastKnownArgs(lat: point.lat, lon: point.lon, ts: ts, targetId: targetId))
    }

    func sendMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        put(ChatMessage(text: String(trimmed.prefix(1000))), id: Self.newId())
    }

    // MARK: Markierungen mit Rückgängig/Wiederholen

    /// Legt eine Markierung an oder ändert sie und merkt den Schritt für Rückgängig.
    func saveMapObject(_ object: MapObject, id: String) {
        let before = mapObjects[id]?.data
        if put(object, id: id) { undoStack.record(MapEdit(id: id, before: before, after: object)) }
    }

    func deleteMapObject(id: String) {
        guard let before = mapObjects[id]?.data else { return }
        if delete(MapObject.self, id: id) { undoStack.record(MapEdit(id: id, before: before, after: nil)) }
    }

    func undo() {
        guard let step = undoStack.undo() else { return }
        apply(step)
    }

    func redo() {
        guard let step = undoStack.redo() else { return }
        apply(step)
    }

    private func apply(_ step: (id: String, restore: MapObject?)) {
        if let restore = step.restore {
            put(restore, id: step.id)
        } else {
            delete(MapObject.self, id: step.id)
        }
    }

    // MARK: Empfang

    private func receive(_ data: Data) {
        guard let message = try? WireCodec.decode(data) else { return }
        switch message {
        case .snapshot(let snapshot):
            selfId = snapshot.me.id
            routingAvailable = snapshot.server.routing
            members = index(snapshot.members)
            vehicles = index(snapshot.vehicles)
            mapObjects = index(snapshot.annotations)
            targets = index(snapshot.targets)
            trackers = index(snapshot.trackers)
            layers = index(snapshot.layers)
            messages = snapshot.messages
            operation = snapshot.operation
            positions = Dictionary(snapshot.positions.map { ($0.id, $0.p) }, uniquingKeysWith: { _, new in new })
            trackerPositions = Dictionary(snapshot.trackerPositions.map { ($0.id, $0.p) }, uniquingKeysWith: { _, new in new })
            online = Set(snapshot.online)
            hasSnapshot = true
            coverageGeneration += 1
        case .putMember(let entity): members[entity.id] = entity
        case .putVehicle(let entity): vehicles[entity.id] = entity
        case .putMapObject(let entity): mapObjects[entity.id] = entity
        case .putTarget(let entity): targets[entity.id] = entity
        case .putTracker(let entity): trackers[entity.id] = entity
        case .putLayer(let entity): layers[entity.id] = entity
        case .putMessage(let entity):
            if !messages.contains(where: { $0.id == entity.id }) { messages.append(entity) }
        case .delete(let kind, let id):
            remove(kind: kind, id: id)
        case .operation(let next):
            if next.modus != operation.modus || next.bestreifungSeit != operation.bestreifungSeit { coverageGeneration += 1 }
            operation = next
        case .position(let id, let position):
            positions[id] = position
            onMemberPosition(id, position)
        case .trackerPosition(let id, let position):
            trackerPositions[id] = position
        case .online(let ids):
            online = Set(ids)
        case .coverageReset:
            coverageGeneration += 1
        case .error(_, let message):
            lastError = message
        case .ack, .pong, .unknown:
            break
        }
    }

    private func remove(kind: String, id: String) {
        switch kind {
        case Member.kind:
            members[id] = nil
            positions[id] = nil
        case Vehicle.kind: vehicles[id] = nil
        case MapObject.kind: mapObjects[id] = nil
        case Target.kind: targets[id] = nil
        case Tracker.kind:
            trackers[id] = nil
            trackerPositions[id] = nil
        case Layer.kind: layers[id] = nil
        case ChatMessage.kind: messages.removeAll { $0.id == id }
        default: break
        }
    }

    private func index<T: Codable & Equatable & Sendable>(_ list: [Versioned<T>]) -> [String: Versioned<T>] {
        Dictionary(list.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
    }
}
