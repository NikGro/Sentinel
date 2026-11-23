import MapKit
import Observation
import SwiftUI

/// Messfühler für Kameratests und die Fehlersuche auf dem Gerät. Eingeschaltet über das Startargument `-kameraprobe`
/// (automatischer Test) oder den Entwickler-Schalter „Kamera-Messdaten senden“ (dann gehen die Zeilen alle zehn
/// Sekunden an den eigenen Server, `diagnose/kamera-<Gerät>.jsonl`). Schreibt bei jeder
/// Kamerabewegung und jedem Gesten-Ereignis eine Zeile nach `Documents/kamera.jsonl` und zeigt den aktuellen Stand
/// als unsichtbares, für UI-Tests lesbares Element `kamera-probe`. So lässt sich Bild für Bild prüfen, ob die Kamera
/// angeheftet bleibt, zoomt, pumpt oder sich löst.
@MainActor
@Observable
final class CameraProbe {
    static let shared = CameraProbe()
    static let settingsKey = "entwickler.kameradiagnose"
    static var isTestRun: Bool { ProcessInfo.processInfo.arguments.contains("-kameraprobe") }
    static var sendsToServer: Bool { UserDefaults.standard.bool(forKey: settingsKey) }
    static var isEnabled: Bool { isTestRun || sendsToServer }

    /// Versand an den Server (setzt die Karte, solange sie offen ist).
    @ObservationIgnored var uploader: (([String]) async -> Void)?
    @ObservationIgnored private var outbox: [String] = []
    @ObservationIgnored private var lastUpload = Date.now

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

    /// `puck`: Abstand des Standortsymbols von der Bildmitte in Punkten (nur angeheftet).
    func record(_ camera: MapCamera, pin: CameraPin?, gesture: Bool, puck: CGPoint?, attached: Bool) {
        guard Self.isEnabled else { return }
        let mode = pin.map { $0 == .heading ? "heading" : "north" } ?? "none"
        let puckText = puck.map { String(format: " symbol=%.0f", hypot($0.x, $0.y)) } ?? ""
        summary = String(format: "pin=%@ d=%.0f p=%.0f h=%.0f geste=%d erkenner=%d lat=%.6f lon=%.6f", mode, camera.distance, camera.pitch, camera.heading,
                         gesture ? 1 : 0, attached ? 1 : 0, camera.centerCoordinate.latitude, camera.centerCoordinate.longitude) + puckText
        let t = Date.now.timeIntervalSince(start)
        let puckJSON = puck.map { String(format: #","sx":%.1f,"sy":%.1f"#, $0.x, $0.y) } ?? ""
        write(String(format: #"{"t":%.3f,"pin":"%@","d":%.1f,"p":%.1f,"h":%.1f,"lat":%.6f,"lon":%.6f,"geste":%d,"erkenner":%d"#,
                     t, mode, camera.distance, camera.pitch, camera.heading, camera.centerCoordinate.latitude, camera.centerCoordinate.longitude,
                     gesture ? 1 : 0, attached ? 1 : 0) + puckJSON + "}")
    }

    func event(_ name: String) {
        guard Self.isEnabled else { return }
        write(String(format: #"{"t":%.3f,"ereignis":"%@"}"#, Date.now.timeIntervalSince(start), name))
    }

    private func write(_ line: String) {
        if Self.sendsToServer {
            outbox.append(line)
            if outbox.count > 4000 { outbox.removeFirst(outbox.count - 4000) }
            if Date.now.timeIntervalSince(lastUpload) > 10, let uploader {
                lastUpload = .now
                let lines = outbox
                outbox.removeAll()
                Task { await uploader(lines) }
            }
        }
        guard Self.isTestRun else { return }
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

#if DEBUG
/// Bereich in der Bildmitte, auf den der Kamera-Test seine Gesten richtet (die Karte selbst meldet MapKit nicht immer
/// als Element). Lässt alle Berührungen zur Karte durch.
struct CameraGestureArea: View {
    var body: some View {
        if CameraProbe.isTestRun {
            GeometryReader { geometry in
                Color.clear
                    .frame(width: geometry.size.width * 0.4, height: geometry.size.height * 0.2)
                    .position(x: geometry.size.width * 0.45, y: geometry.size.height * 0.5)
                    .accessibilityElement()
                    .accessibilityLabel("Kartenmitte")
                    .accessibilityIdentifier("karte-gesten")
                    .allowsHitTesting(false)
            }
        }
    }
}

/// Element mit dem Stand des Messfühlers, für UI-Tests.
struct CameraProbeLabel: View {
    var body: some View {
        if CameraProbe.isTestRun {
            // Klein, aber sichtbar: Fast durchsichtige oder winzige Elemente blendet iOS für UI-Tests aus.
            Text(CameraProbe.shared.summary)
                .font(.system(size: 9, design: .monospaced))
                .padding(2)
                .background(.black.opacity(0.5))
                .foregroundStyle(.white)
                .allowsHitTesting(false)
                .accessibilityIdentifier("kamera-probe")
                .padding(.top, 60)
        }
    }
}
#endif
