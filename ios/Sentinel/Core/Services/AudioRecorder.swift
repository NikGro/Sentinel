import AVFoundation
import Observation

/// Sprachnachrichten aufnehmen (AAC in M4A) und abspielen.
@MainActor
@Observable
final class AudioRecorder: NSObject, AVAudioPlayerDelegate {
    private(set) var isRecording = false
    private(set) var elapsed: TimeInterval = 0
    private(set) var playingId: String?
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
            recorder.record(forDuration: 300)
            self.recorder = recorder
            fileURL = url
            isRecording = true
            elapsed = 0
            timer = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(250))
                    guard let self, let recorder = self.recorder else { return }
                    self.elapsed = recorder.currentTime
                }
            }
        } catch {
            failure = "Aufnahme konnte nicht gestartet werden."
        }
    }

    /// Beendet die Aufnahme und liefert die Datei samt Dauer; `nil` bei Abbruch oder zu kurzer Aufnahme.
    func stop(cancel: Bool = false) -> (data: Data, duration: TimeInterval)? {
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
        return (data, duration)
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
        } catch {
            failure = "Sprachnachricht konnte nicht abgespielt werden."
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.playingId = nil }
    }
}
