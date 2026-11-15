import Foundation

enum ConnectionState: Equatable, Sendable {
    case getrennt
    case verbindet
    case verbunden

    var title: String {
        switch self {
        case .getrennt: "Getrennt"
        case .verbindet: "Verbindet"
        case .verbunden: "Verbunden"
        }
    }
}

/// Dauerhafte WebSocket-Verbindung zum Server mit automatischem Wiederaufbau.
@MainActor
final class RealtimeClient {
    var onMessage: (Data) -> Void = { _ in }
    var onStateChange: (ConnectionState) -> Void = { _ in }
    /// Der Server hat diesem Gerät den Zugang entzogen.
    var onUnauthorized: () -> Void = {}

    private var runner: Task<Void, Never>?
    private var pinger: Task<Void, Never>?
    private var socket: URLSessionWebSocketTask?
    private var state: ConnectionState = .getrennt {
        didSet { if state != oldValue { onStateChange(state) } }
    }

    private static let unauthorizedCloseCode = 4401

    func start(credentials: Credentials) {
        stop()
        guard var components = URLComponents(url: credentials.serverURL.appending(path: "api/v1/ws"), resolvingAgainstBaseURL: false) else { return }
        components.scheme = "wss"
        guard let url = components.url else { return }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(credentials.token)", forHTTPHeaderField: "Authorization")

        runner = Task { [weak self] in
            var backoff: Duration = .seconds(1)
            while !Task.isCancelled {
                guard let self else { return }
                self.state = .verbindet
                let socket = APIClient.session.webSocketTask(with: request)
                socket.maximumMessageSize = 16 * 1024 * 1024
                self.socket = socket
                socket.resume()
                do {
                    while true {
                        let message = try await socket.receive()
                        if self.state != .verbunden {
                            self.state = .verbunden
                            backoff = .seconds(1)
                        }
                        switch message {
                        case .string(let text): self.onMessage(Data(text.utf8))
                        case .data(let data): self.onMessage(data)
                        @unknown default: break
                        }
                    }
                } catch {
                    // Verbindung beendet: unten wird neu aufgebaut.
                }
                let closeCode = socket.closeCode.rawValue
                self.socket = nil
                self.state = .getrennt
                if closeCode == Self.unauthorizedCloseCode {
                    self.onUnauthorized()
                    return
                }
                try? await Task.sleep(for: backoff)
                backoff = min(backoff * 2, .seconds(15))
            }
        }

        pinger = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(25))
                self?.send(WireCodec.ping)
            }
        }
    }

    func stop() {
        runner?.cancel()
        pinger?.cancel()
        runner = nil
        pinger = nil
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        state = .getrennt
    }

    /// Sendet, wenn verbunden. Liefert `false`, wenn die Nachricht nicht abgeschickt werden konnte.
    @discardableResult
    func send(_ data: Data?) -> Bool {
        guard let data, let socket, state == .verbunden, let text = String(data: data, encoding: .utf8) else { return false }
        socket.send(.string(text)) { _ in }
        return true
    }
}
