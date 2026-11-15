import AVFoundation
import Observation

/// Sprachnachrichten aufnehmen (AAC in M4A) und abspielen.
@MainActor
@Observable
final class AudioRecorder: NSObject, AVAudioPlayerDelegate {
    private(set) var isRecording = false
    private(set) var elapsed: TimeInterval = 0
    private(set) var playingId: String?
    /// Lautstärke während der Aufnahme (0 bis 1), für die Live-Wellenform.
    private(set) var levels: [Double] = []
    /// Wiedergabefortschritt der laufenden Sprachnachricht (0 bis 1).
    private(set) var playbackProgress: Double = 0
    var failure: String?

    @ObservationIgnored private var recorder: AVAudioRecorder?
    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var timer: Task<Void, Never>?
    @ObservationIgnored private var fileURL: URL?

    func start() async {
        guard !isRecording else { return }
        guard await AVAudioApplication.requestRecordPermission() else {
            failure = "Kein Zugriff auf das Mikrofon. Bitte in den Einstellungen erlauben."
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker])
            try session.setActive(true)
            let url = FileManager.default.temporaryDirectory.appending(path: "sprachnachricht-\(UUID().uuidString).m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 22_050,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
            ]
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.isMeteringEnabled = true
            recorder.record(forDuration: 300)
            levels = []
            self.recorder = recorder
            fileURL = url
            isRecording = true
            elapsed = 0
            timer = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(100))
                    guard let self, let recorder = self.recorder else { return }
                    self.elapsed = recorder.currentTime
                    recorder.updateMeters()
                    self.levels.append(Self.normalized(recorder.averagePower(forChannel: 0)))
                }
            }
        } catch {
            failure = "Aufnahme konnte nicht gestartet werden."
        }
    }

    /// Dezibel (-50 bis 0) auf 0 bis 1, leise Stellen bleiben als kleiner Strich sichtbar.
    nonisolated static func normalized(_ decibels: Float) -> Double {
        let clamped = min(max(Double(decibels), -50), 0)
        return pow((clamped + 50) / 50, 1.6)
    }

    /// Verdichtet den Lautstärkeverlauf auf eine feste Anzahl Balken.
    nonisolated static func waveform(_ levels: [Double], bars: Int = 48) -> [Double] {
        guard !levels.isEmpty else { return [] }
        return (0..<bars).map { bar in
            let start = bar * levels.count / bars
            let end = max(start + 1, (bar + 1) * levels.count / bars)
            let slice = levels[min(start, levels.count - 1)..<min(end, levels.count)]
            return ((slice.max() ?? 0) * 100).rounded() / 100
        }
    }

    /// Beendet die Aufnahme und liefert die Datei samt Dauer und Wellenform; `nil` bei Abbruch oder zu kurzer Aufnahme.
    func stop(cancel: Bool = false) -> (data: Data, duration: TimeInterval, waveform: [Double])? {
        timer?.cancel()
        let duration = recorder?.currentTime ?? 0
        recorder?.stop()
        recorder = nil
        isRecording = false
        defer {
            if let fileURL { try? FileManager.default.removeItem(at: fileURL) }
            fileURL = nil
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
        guard !cancel, duration >= 0.8, let fileURL, let data = try? Data(contentsOf: fileURL) else { return nil }
        return (data, duration, Self.waveform(levels))
    }

    func play(_ data: Data, id: String) {
        if playingId == id {
            player?.stop()
            playingId = nil
            return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
            let player = try AVAudioPlayer(data: data)
            player.delegate = self
            player.play()
            self.player = player
            playingId = id
            playbackProgress = 0
            timer?.cancel()
            timer = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(100))
                    guard let self, let player = self.player, self.playingId == id, player.duration > 0 else { return }
                    self.playbackProgress = player.currentTime / player.duration
                }
            }
        } catch {
            failure = "Sprachnachricht konnte nicht abgespielt werden."
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.playingId = nil
            self.playbackProgress = 0
        }
    }
}
