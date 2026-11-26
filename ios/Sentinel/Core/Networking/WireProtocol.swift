import Foundation

// Nachrichten des Echtzeit-Protokolls (WebSocket, JSON). Gegenstück: server/src/hub.ts.

struct ActorInfo: Codable, Equatable, Sendable {
    var id: String
    var role: String
}

struct ServerInfo: Codable, Equatable, Sendable {
    var version: String
    var routing: Bool
}

struct PositionEntry: Codable, Equatable, Sendable {
    var id: String
    var p: Position
}

/// Vollständiger Zustand beim Verbindungsaufbau.
struct Snapshot: Decodable, Sendable {
    var me: ActorInfo
    var server: ServerInfo
    var online: [String]
    var members: [Versioned<Member>]
    var vehicles: [Versioned<Vehicle>]
    var annotations: [Versioned<MapObject>]
    var targets: [Versioned<Target>]
    var relations: [Versioned<Relation>]
    var targetGroups: [Versioned<TargetGroup>]
    var trackers: [Versioned<Tracker>]
    var layers: [Versioned<Layer>]
    var rooms: [Versioned<ChatRoom>]
    var messages: [Versioned<ChatMessage>]
    var operation: OperationState
    var positions: [PositionEntry]
    var trackerPositions: [PositionEntry]
    /// Geöffnete Instanz und alle Instanzen des Servers (ab 0.13).
    var instanz: String
    var instances: [Versioned<Instance>]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        me = try c.decode(ActorInfo.self, forKey: .me)
        server = try c.decode(ServerInfo.self, forKey: .server)
        online = try c.decode([String].self, forKey: .online)
        members = try c.lossy(Versioned<Member>.self, forKey: .members)
        vehicles = try c.lossy(Versioned<Vehicle>.self, forKey: .vehicles)
        annotations = try c.lossy(Versioned<MapObject>.self, forKey: .annotations)
        targets = try c.lossy(Versioned<Target>.self, forKey: .targets)
        relations = (try? c.lossy(Versioned<Relation>.self, forKey: .relations)) ?? []
        targetGroups = (try? c.lossy(Versioned<TargetGroup>.self, forKey: .targetGroups)) ?? []
        trackers = try c.lossy(Versioned<Tracker>.self, forKey: .trackers)
        layers = try c.lossy(Versioned<Layer>.self, forKey: .layers)
        rooms = (try? c.lossy(Versioned<ChatRoom>.self, forKey: .rooms)) ?? []
        messages = try c.lossy(Versioned<ChatMessage>.self, forKey: .messages)
        operation = try c.decode(OperationState.self, forKey: .operation)
        positions = try c.lossy(PositionEntry.self, forKey: .positions)
        trackerPositions = try c.lossy(PositionEntry.self, forKey: .trackerPositions)
        instanz = try c.decodeIfPresent(String.self, forKey: .instanz) ?? Instance.mainId
        instances = (try? c.lossy(Versioned<Instance>.self, forKey: .instances)) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case me = "self"
        case server, online, members, vehicles, annotations, targets, relations, targetGroups, trackers, layers, rooms, messages, operation, positions, trackerPositions, instanz, instances
    }
}

/// A-Position oder Notruf in einer anderen Instanz, in der man Mitglied ist.
struct InstanceNotice: Decodable, Equatable, Sendable {
    let instanz: String
    let name: String
    let art: String
    let memberId: String
    let spitzname: String
}

/// Geofence-Alarm vom Server: ein überwachtes Ziel hat den Bereich verlassen oder betreten.
struct GeofenceAlarm: Decodable, Equatable, Sendable {
    let annotationId: String
    let titel: String
    let zielId: String
    let zielName: String
    let art: String
    let lat: Double
    let lon: Double
}

enum ServerMessage: Sendable {
    case snapshot(Snapshot)
    case putMember(Versioned<Member>)
    case putVehicle(Versioned<Vehicle>)
    case putMapObject(Versioned<MapObject>)
    case putTarget(Versioned<Target>)
    case putRelation(Versioned<Relation>)
    case putTargetGroup(Versioned<TargetGroup>)
    case putTracker(Versioned<Tracker>)
    case putLayer(Versioned<Layer>)
    case putRoom(Versioned<ChatRoom>)
    case putMessage(Versioned<ChatMessage>)
    case putInstance(Versioned<Instance>)
    case notice(InstanceNotice)
    case geofence(GeofenceAlarm)
    case delete(kind: String, id: String)
    case operation(OperationState)
    case position(id: String, Position)
    case trackerPosition(id: String, Position)
    case online([String])
    case coverageReset
    case ack(ref: String)
    case error(ref: String?, message: String)
    case pong
    case unknown
}

enum WireCodec {
    private static let decoder = JSONDecoder()
    private static let encoder = JSONEncoder()

    private struct Head: Decodable {
        let t: String
        let kind: String?
    }

    private struct Put<T: LageEntity>: Decodable {
        let entity: Versioned<T>
    }

    private struct Del: Decodable {
        let kind: String
        let id: String
    }

    private struct OperationBody: Decodable {
        let operation: OperationState
    }

    private struct Online: Decodable {
        let ids: [String]
    }

    private struct Ack: Decodable {
        let ref: String
    }

    private struct Failure: Decodable {
        let ref: String?
        let message: String
    }

    static func decode(_ data: Data) throws -> ServerMessage {
        let head = try decoder.decode(Head.self, from: data)
        switch head.t {
        case "snapshot":
            return .snapshot(try decoder.decode(Snapshot.self, from: data))
        case "put":
            switch head.kind {
            case Member.kind: return .putMember(try decoder.decode(Put<Member>.self, from: data).entity)
            case Vehicle.kind: return .putVehicle(try decoder.decode(Put<Vehicle>.self, from: data).entity)
            case MapObject.kind: return .putMapObject(try decoder.decode(Put<MapObject>.self, from: data).entity)
            case Target.kind: return .putTarget(try decoder.decode(Put<Target>.self, from: data).entity)
            case TargetGroup.kind: return .putTargetGroup(try decoder.decode(Put<TargetGroup>.self, from: data).entity)
            case Relation.kind: return .putRelation(try decoder.decode(Put<Relation>.self, from: data).entity)
            case Tracker.kind: return .putTracker(try decoder.decode(Put<Tracker>.self, from: data).entity)
            case Layer.kind: return .putLayer(try decoder.decode(Put<Layer>.self, from: data).entity)
            case ChatRoom.kind: return .putRoom(try decoder.decode(Put<ChatRoom>.self, from: data).entity)
            case ChatMessage.kind: return .putMessage(try decoder.decode(Put<ChatMessage>.self, from: data).entity)
            case Instance.kind: return .putInstance(try decoder.decode(Put<Instance>.self, from: data).entity)
            default: return .unknown
            }
        case "del":
            let body = try decoder.decode(Del.self, from: data)
            return .delete(kind: body.kind, id: body.id)
        case "operation":
            return .operation(try decoder.decode(OperationBody.self, from: data).operation)
        case "pos":
            let body = try decoder.decode(PositionEntry.self, from: data)
            return .position(id: body.id, body.p)
        case "tpos":
            let body = try decoder.decode(PositionEntry.self, from: data)
            return .trackerPosition(id: body.id, body.p)
        case "online":
            return .online(try decoder.decode(Online.self, from: data).ids)
        case "hinweis":
            return .notice(try decoder.decode(InstanceNotice.self, from: data))
        case "geofence":
            return .geofence(try decoder.decode(GeofenceAlarm.self, from: data))
        case "bestreifungReset":
            return .coverageReset
        case "ack":
            return .ack(ref: try decoder.decode(Ack.self, from: data).ref)
        case "err":
            let body = try decoder.decode(Failure.self, from: data)
            return .error(ref: body.ref, message: body.message)
        case "pong":
            return .pong
        default:
            return .unknown
        }
    }

    // MARK: Ausgehend

    private struct PutOut<T: Encodable>: Encodable {
        let t = "put"
        let kind: String
        let id: String
        let data: T
        let ref: String
    }

    private struct DelOut: Encodable {
        let t = "del"
        let kind: String
        let id: String
        let ref: String
    }

    private struct PosOut: Encodable {
        let t = "pos"
        let p: Position
    }

    private struct CmdOut<A: Encodable>: Encodable {
        let t = "cmd"
        let name: String
        let args: A
        let ref: String
    }

    private struct NoArgs: Encodable {}

    static func put<T: LageEntity>(id: String, data: T, ref: String) -> Data? {
        try? encoder.encode(PutOut(kind: T.kind, id: id, data: data, ref: ref))
    }

    static func delete(kind: String, id: String, ref: String) -> Data? {
        try? encoder.encode(DelOut(kind: kind, id: id, ref: ref))
    }

    static func position(_ position: Position) -> Data? {
        try? encoder.encode(PosOut(p: position))
    }

    static func command<A: Encodable>(_ name: String, args: A, ref: String) -> Data? {
        try? encoder.encode(CmdOut(name: name, args: args, ref: ref))
    }

    static func command(_ name: String, ref: String) -> Data? {
        command(name, args: NoArgs(), ref: ref)
    }

    static let ping = Data(#"{"t":"ping"}"#.utf8)
}

/// Einzelnes fehlerhaftes oder unbekanntes Element (z. B. eine neue Markierungsart eines neueren Servers)
/// darf nicht den ganzen Lagestand unbrauchbar machen: Es wird übersprungen.
private struct Lossy<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws { value = try? T(from: decoder) }
}

extension KeyedDecodingContainer {
    func lossy<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> [T] {
        try decode([Lossy<T>].self, forKey: key).compactMap(\.value)
    }
}
