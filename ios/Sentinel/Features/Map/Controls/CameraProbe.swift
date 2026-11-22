import MapKit
import Observation
import SwiftUI

#if DEBUG
/// Messfühler für automatische Kameratests (nur Testbuilds, Startargument `-kameraprobe`): schreibt bei jeder
/// Kamerabewegung und jedem Gesten-Ereignis eine Zeile nach `Documents/kamera.jsonl` und zeigt den aktuellen Stand
/// als unsichtbares, für UI-Tests lesbares Element `kamera-probe`. So lässt sich Bild für Bild prüfen, ob die Kamera
/// angeheftet bleibt, zoomt, pumpt oder sich löst.
@MainActor
@Observable
final class CameraProbe {
    static let shared = CameraProbe()
    static var isEnabled: Bool { ProcessInfo.processInfo.arguments.contains("-kameraprobe") }

    /// Aktueller Stand, z. B. „pin=heading d=550 p=40 h=12 geste=0“.
    private(set) var summary = "pin=none"
    @ObservationIgnored private var buffer: [String] = []
    @ObservationIgnored private var lastFlush = Date.now
    @ObservationIgnored private let start = Date.now

    private var file: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("kamera.jsonl")
    }

    init() {
        if let file { try? FileManager.default.removeItem(at: file) }
    }

    func record(_ camera: MapCamera, pin: CameraPin?, gesture: Bool, settling: Bool, attached: Bool) {
        guard Self.isEnabled else { return }
        let mode = pin.map { $0 == .heading ? "heading" : "north" } ?? "none"
        summary = String(format: "pin=%@ d=%.0f p=%.0f h=%.0f geste=%d erkenner=%d", mode, camera.distance, camera.pitch, camera.heading, gesture ? 1 : 0, attached ? 1 : 0)
        let t = Date.now.timeIntervalSince(start)
        write(String(format: #"{"t":%.3f,"pin":"%@","d":%.1f,"p":%.1f,"h":%.1f,"lat":%.6f,"lon":%.6f,"geste":%d,"settle":%d,"erkenner":%d}"#,
                     t, mode, camera.distance, camera.pitch, camera.heading, camera.centerCoordinate.latitude, camera.centerCoordinate.longitude,
                     gesture ? 1 : 0, settling ? 1 : 0, attached ? 1 : 0))
    }

    func event(_ name: String) {
        guard Self.isEnabled else { return }
        write(String(format: #"{"t":%.3f,"ereignis":"%@"}"#, Date.now.timeIntervalSince(start), name))
    }

    private func write(_ line: String) {
        buffer.append(line)
        guard Date.now.timeIntervalSince(lastFlush) > 0.5 || buffer.count > 200, let file else { return }
        lastFlush = .now
        let data = Data((buffer.joined(separator: "\n") + "\n").utf8)
        buffer.removeAll()
        if let handle = try? FileHandle(forWritingTo: file) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: file)
        }
    }
}

/// Unsichtbares Element mit dem Stand des Messfühlers, für UI-Tests.
struct CameraProbeLabel: View {
    var body: some View {
        if CameraProbe.isEnabled {
            Text(CameraProbe.shared.summary)
                .font(.system(size: 1))
                .opacity(0.02)
                .frame(width: 2, height: 2)
                .allowsHitTesting(false)
                .accessibilityIdentifier("kamera-probe")
        }
    }
}
#endif
