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
    private(set) var rooms: [String: Versioned<ChatRoom>] = [:]
    private(set) var messages: [Versioned<ChatMessage>] = []

    private(set) var operation = OperationState()
    private(set) var positions: [String: Position] = [:]
    private(set) var trackerPositions: [String: Position] = [:]
    private(set) var online: Set<String> = []

    /// Wird hochgezählt, wenn die Bestreifung neu geladen werden muss.
    private(set) var coverageGeneration = 0
    /// Letzte Fehlermeldung des Servers, zur Anzeige.
    var lastError: String?

    private let realtime = RealtimeClient()
    private var onUnauthorized: () -> Void = {}
    /// Empfänger für Positionsmeldungen, z. B. die Bestreifungsanzeige.
    var onMemberPosition: (String, Position) -> Void = { _, _ in }
    /// Meldet bemerkenswerte Änderungen (A, Notruf, Nachrichten) für Hinweise und Vibration.
    var onEvent: (LageEvent) -> Void = { _ in }

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
        rooms = [:]
        messages = []
        positions = [:]
        trackerPositions = [:]
        online = []
        operation = OperationState()
    }

    // MARK: Abgeleitete Sichten

    var me: Versioned<Member>? { selfId.flatMap { members[$0] } }
    var myPosition: Position? { selfId.flatMap { positions[$0] } }
    var holdsA: Bool { operation.a?.memberId == selfId && selfId != nil }
    var aHolder: Versioned<Member>? { operation.a.flatMap { members[$0.memberId] } }
    var aPosition: Position? { operation.a.flatMap { positions[$0.memberId] } }
    /// Fährt die A gerade im ÖPNV mit bekannter Linie? Dann ist überschlagendes Anfahren möglich.
    var aRidesTransit: Bool { aHolder?.data.fortbewegung == .oepnv && aHolder?.data.oepnv != nil }
    var joinedLeapfrog: Bool { selfId.map { operation.ueberschlagen.teilnehmer.contains($0) } ?? false }
    var myLeapfrogStop: LeapfrogStop? { selfId.flatMap { operation.ueberschlagen.zuweisungen[$0] } }

    var sortedMembers: [Versioned<Member>] {
        members.values.sorted { lhs, rhs in
            if lhs.data.aktiv != rhs.data.aktiv { return lhs.data.aktiv }
            return lhs.data.spitzname.localizedStandardCompare(rhs.data.spitzname) == .orderedAscending
        }
    }

    var activeMembers: [Versioned<Member>] { sortedMembers.filter(\.data.aktiv) }

    var sortedTargets: [Versioned<Target>] {
        targets.values.sorted { $0.data.displayName.localizedStandardCompare($1.data.displayName) == .orderedAscending }
    }

    var sortedVehicles: [Versioned<Vehicle>] {
        vehicles.values.sorted { lhs, rhs in
            if lhs.data.aktiv != rhs.data.aktiv { return lhs.data.aktiv }
            return lhs.data.funkrufname.localizedStandardCompare(rhs.data.funkrufname) == .orderedAscending
        }
    }

    var activeVehicles: [Versioned<Vehicle>] { sortedVehicles.filter(\.data.aktiv) }

    var sortedLayers: [Versioned<Layer>] {
        layers.values.sorted { lhs, rhs in
            let order = ["lage": 0, "dauerhaft": 1, "paket": 2, "argus": 3]
            let l = order[lhs.data.art] ?? 9
            let r = order[rhs.data.art] ?? 9
            return l == r ? lhs.data.name < rhs.data.name : l < r
        }
    }

    var sortedRooms: [Versioned<ChatRoom>] {
        rooms.values.sorted { lhs, rhs in
            if lhs.id == ChatRoom.generalId { return true }
            if rhs.id == ChatRoom.generalId { return false }
            return lhs.data.name.localizedStandardCompare(rhs.data.name) == .orderedAscending
        }
    }

    func messages(in roomId: String) -> [Versioned<ChatMessage>] {
        messages.filter { $0.data.roomId == roomId }
    }

    func isOnline(_ memberId: String) -> Bool { online.contains(memberId) }

    func vehicle(of member: Member) -> Versioned<Vehicle>? {
        guard member.fortbewegung == .fahrzeug, let id = member.fahrzeugId else { return nil }
        return vehicles[id]
    }

    /// Bezeichnung auf der Karte: zu Fuß der Spitzname, im Fahrzeug dessen Funkrufname, im ÖPNV mit Linie.
    func label(of member: Member) -> String {
        if let vehicle = vehicle(of: member) { return vehicle.data.funkrufname }
        if member.fortbewegung == .oepnv, let line = member.oepnv { return "\(member.spitzname) (\(line.linie))" }
        return member.spitzname
    }

    /// Kurzbeschreibung der Fortbewegung, z. B. "Fahrzeug P 35/24" oder "U3 Richtung Barmbek".
    func mobilityDescription(of member: Member) -> String {
        switch member.fortbewegung {
        case .fuss: return Fortbewegung.fuss.title
        case .fahrzeug: return vehicle(of: member).map { "Fahrzeug \($0.data.funkrufname)" } ?? Fortbewegung.fahrzeug.title
        case .oepnv: return member.oepnv.map { "\($0.linie) Richtung \($0.richtung)" } ?? Fortbewegung.oepnv.title
        }
    }

    func occupants(of vehicleId: String) -> [Versioned<Member>] {
        activeMembers.filter { $0.data.fortbewegung == .fahrzeug && $0.data.fahrzeugId == vehicleId }
    }

    /// Aktueller Standort eines Fahrzeugs: Sitzt jemand drin, ist dessen Telefon die Quelle. Der Tracker zählt nur,
    /// wenn niemand drinsitzt oder seine Meldung deutlich frischer ist; sonst gilt der Abstellort.
    func position(ofVehicle vehicle: Versioned<Vehicle>) -> (point: GeoPoint, date: Date, source: String)? {
        let occupantPosition = occupants(of: vehicle.id).compactMap { positions[$0.id] }.max { $0.ts < $1.ts }
        let trackerPosition = vehicle.data.trackerId.flatMap { trackerPositions[$0] }
        if let trackerPosition, let occupantPosition, trackerPosition.ts > occupantPosition.ts + 120_000 {
            return (trackerPosition.point, trackerPosition.date, "Tracker")
        }
        if let occupantPosition { return (occupantPosition.point, occupantPosition.date, "Besatzung") }
        if let trackerPosition { return (trackerPosition.point, trackerPosition.date, "Tracker") }
        if let parked = vehicle.data.abgestellt { return (parked.point, parked.date, "Abgestellt") }
        return nil
    }

    /// Standort eines Ziels: Tracker vor von Hand gesetztem Standort.
    func position(ofTarget target: Versioned<Target>) -> (point: GeoPoint, date: Date, fromTracker: Bool)? {
        if let tracker = target.data.trackerId.flatMap({ trackerPositions[$0] }) { return (tracker.point, tracker.date, true) }
        if let standort = target.data.standort { return (standort.point, standort.date, false) }
        return nil
    }

    /// Standort einer Markierung: bei verbundenem Tracker dessen Position, sonst der gesetzte Punkt.
    func position(ofObject object: MapObject) -> GeoPoint {
        object.trackerId.flatMap { trackerPositions[$0]?.point } ?? object.anchor
    }

    func name(of actorId: String) -> String {
        if actorId == "zentrale" { return "Zentrale" }
        if actorId == "system" { return "System" }
        return members[actorId]?.data.spitzname ?? "Unbekannt"
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

    func claimA() { command("a.uebernehmen") }
    func triggerSOS() { command("sos.ausloesen") }
    func endSOS() { command("sos.beenden") }

    /// Notruf eines anderen läuft gerade.
    var foreignSOS: Versioned<Member>? {
        guard let sos = operation.sos, sos.memberId != selfId else { return nil }
        return members[sos.memberId]
    }

    var ownSOS: Bool { operation.sos?.memberId == selfId && selfId != nil }

    private func announce(from old: OperationState, to new: OperationState) {
        guard hasSnapshot else { return }
        if old.sos?.memberId != new.sos?.memberId {
            if let sos = new.sos {
                onEvent(.sosStarted(memberId: sos.memberId, mine: sos.memberId == selfId))
            } else if let ended = old.sos {
                onEvent(.sosEnded(memberId: ended.memberId))
            }
        }
        if old.a?.memberId != new.a?.memberId {
            if let a = new.a {
                onEvent(.aTaken(memberId: a.memberId, mine: a.memberId == selfId))
            } else if let previous = old.a {
                onEvent(.aReleased(previousMemberId: previous.memberId))
            }
        }
    }
    func releaseA() { command("a.freigeben") }
    func setChannel(_ channel: String?) { command("funkkanal.setzen", args: ["kanal": channel]) }
    func setSituation(title: String, notes: String) { command("lage.setzen", args: ["titel": title, "hinweise": notes]) }
    func resetCoverage() { command("bestreifung.zuruecksetzen") }
    func joinLeapfrog() { command("ueberschlagen.beitreten") }
    func leaveLeapfrog() { command("ueberschlagen.verlassen") }
    func resetSituation(includingTargets: Bool) { command("lage.zuruecksetzen", args: ["ziele": includingTargets]) }

    func setActive(_ active: Bool) { command("aktiv.setzen", args: ["aktiv": active]) }

    private struct MobilityArgs: Encodable {
        let art: Fortbewegung
        let fahrzeugId: String?
        let oepnv: OepnvFahrt?
    }

    func setMobility(_ art: Fortbewegung, vehicleId: String? = nil, transit: OepnvFahrt? = nil) {
        command("fortbewegung.setzen", args: MobilityArgs(art: art, fahrzeugId: vehicleId, oepnv: transit))
    }

    private struct IntervalArgs: Encodable {
        let trackerId: String
        let sekunden: Int
    }

    func setTrackerInterval(_ trackerId: String, seconds: Int) {
        command("tracker.intervall", args: IntervalArgs(trackerId: trackerId, sekunden: seconds))
    }

    func sendMessage(_ text: String, in roomId: String, attachment: ChatAttachment? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || attachment != nil else { return }
        put(ChatMessage(roomId: roomId, text: String(trimmed.prefix(1000)), anhang: attachment), id: Self.newId())
    }

    func saveMapObject(_ object: MapObject, id: String) {
        put(object, id: id)
    }

    func deleteMapObject(id: String) {
        delete(MapObject.self, id: id)
    }

    // MARK: Empfang

    private func receive(_ data: Data) {
        guard let message = try? WireCodec.decode(data) else { return }
        apply(message)
    }

    private func apply(_ message: ServerMessage) {
        switch message {
        case .snapshot(let snapshot):
            let previousSOS = operation.sos?.memberId
            defer {
                // Läuft beim Verbinden bereits ein Notruf, gilt er als neu (nicht erneut nach einem Wiederverbinden).
                if let sos = snapshot.operation.sos, sos.memberId != previousSOS {
                    onEvent(.sosStarted(memberId: sos.memberId, mine: sos.memberId == snapshot.me.id))
                }
            }
            selfId = snapshot.me.id
            routingAvailable = snapshot.server.routing
            members = index(snapshot.members)
            vehicles = index(snapshot.vehicles)
            mapObjects = index(snapshot.annotations)
            targets = index(snapshot.targets)
            trackers = index(snapshot.trackers)
            layers = index(snapshot.layers)
            rooms = index(snapshot.rooms)
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
        case .putRoom(let entity): rooms[entity.id] = entity
        case .putMessage(let entity) where !messages.contains(where: { $0.id == entity.id }) && entity.updatedBy != selfId && hasSnapshot:
            messages.append(entity)
            onEvent(.message(entity))
        case .putMessage(let entity):
            if !messages.contains(where: { $0.id == entity.id }) { messages.append(entity) }
        case .delete(let kind, let id):
            remove(kind: kind, id: id)
        case .operation(let next):
            announce(from: operation, to: next)
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
        case ChatRoom.kind:
            rooms[id] = nil
            messages.removeAll { $0.data.roomId == id }
        case ChatMessage.kind: messages.removeAll { $0.id == id }
        default: break
        }
    }

    private func index<T: Codable & Equatable & Sendable>(_ list: [Versioned<T>]) -> [String: Versioned<T>] {
        Dictionary(list.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
    }

    #if DEBUG
    /// Lädt eine Beispiel-Lage ohne Serververbindung (Oberflächentests).
    func loadDemo(_ snapshot: Data) {
        receive(snapshot)
        connection = .verbunden
    }
    #endif
}

/// Bemerkenswerte Änderung der Lage, aus der ein Hinweis wird.
enum LageEvent {
    case aTaken(memberId: String, mine: Bool)
    case aReleased(previousMemberId: String)
    case sosStarted(memberId: String, mine: Bool)
    case sosEnded(memberId: String)
    case message(Versioned<ChatMessage>)
}
