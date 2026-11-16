import AVFoundation
import Observation
import Speech

/// Spracheingabe für das Navigationsziel. Erkennung möglichst auf dem Gerät, nichts verlässt es dann.
@MainActor
@Observable
final class SpeechInput {
    private(set) var transcript = ""
    private(set) var isListening = false
    private(set) var failure: String?

    @ObservationIgnored private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "de-DE"))
    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?
    @ObservationIgnored private var onFinish: ((String) -> Void)?

    func start(onFinish: @escaping (String) -> Void) {
        self.onFinish = onFinish
        failure = nil
        SFSpeechRecognizer.requestAuthorization { status in
            Task { @MainActor in
                guard status == .authorized else {
                    self.failure = "Spracherkennung ist nicht erlaubt (Einstellungen)."
                    return
                }
                self.begin()
            }
        }
    }

    private func begin() {
        guard let recognizer, recognizer.isAvailable else {
            failure = "Spracherkennung ist gerade nicht verfügbar."
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            if recognizer.supportsOnDeviceRecognition { request.requiresOnDeviceRecognition = true }
            self.request = request
            let input = engine.inputNode
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { buffer, _ in
                request.append(buffer)
            }
            engine.prepare()
            try engine.start()
            transcript = ""
            isListening = true
            task = recognizer.recognitionTask(with: request) { result, error in
                let text = result?.bestTranscription.formattedString
                let final = result?.isFinal ?? false
                Task { @MainActor in
                    if let text { self.transcript = text }
                    if final || error != nil { self.stop() }
                }
            }
        } catch {
            failure = error.localizedDescription
            stop()
        }
    }

    /// Beendet die Aufnahme und liefert den erkannten Text.
    func stop() {
        guard isListening || task != nil else { return }
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        isListening = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        let text = transcript.trimmingCharacters(in: .whitespaces)
        if !text.isEmpty { onFinish?(text) }
        onFinish = nil
    }

    /// Füllwörter wie „navigiere zur“ oder „bring mich zu“ entfernen, damit nur das Ziel übrig bleibt.
    nonisolated static func destination(from text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespaces)
        let prefixes = [
            "navigiere mich zu", "navigiere mich zur", "navigiere mich zum", "navigiere zu", "navigiere zur", "navigiere zum",
            "navigation zu", "navigation zur", "navigation zum", "bring mich zu", "bring mich zur", "bring mich zum",
            "fahre zu", "fahre zur", "fahre zum", "fahr zu", "fahr zur", "fahr zum", "führe mich zu", "führe mich zur", "führe mich zum",
            "zu", "zur", "zum", "nach",
        ]
        for prefix in prefixes where result.lowercased().hasPrefix(prefix + " ") {
            result = String(result.dropFirst(prefix.count + 1))
            break
        }
        return result.trimmingCharacters(in: CharacterSet(charactersIn: " .!?"))
    }
}
