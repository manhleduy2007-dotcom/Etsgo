import AVFoundation
import Foundation
import Speech

/// Nhận giọng nói thành văn bản để người dùng xem và sửa trước khi gửi (AI-01).
@MainActor
final class SpeechRecognizer: ObservableObject {
    @Published var isRecording = false
    @Published var transcript = ""
    @Published var errorText: String?

    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    func toggle() {
        if isRecording {
            stop()
        } else {
            Task { await start() }
        }
    }

    private func start() async {
        errorText = nil
        let speechAllowed = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
        }
        let micAllowed = await AVAudioApplication.requestRecordPermission()
        guard speechAllowed, micAllowed else {
            errorText = L(
                "Chưa có quyền dùng micro hoặc nhận dạng giọng nói.",
                "Microphone or speech recognition permission is missing."
            )
            return
        }
        guard let recognizer = SFSpeechRecognizer(locale: AppLanguage.current.speechLocale), recognizer.isAvailable else {
            errorText = L("Nhận dạng giọng nói hiện không dùng được.", "Speech recognition is unavailable right now.")
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            self.request = request

            let input = engine.inputNode
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { buffer, _ in
                request.append(buffer)
            }
            engine.prepare()
            try engine.start()

            transcript = ""
            isRecording = true
            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                let text = result?.bestTranscription.formattedString
                let finished = error != nil || (result?.isFinal ?? false)
                Task { @MainActor in
                    if let text { self?.transcript = text }
                    if finished { self?.stop() }
                }
            }
        } catch {
            errorText = L("Không bật được micro.", "Could not start the microphone.")
            stop()
        }
    }

    func stop() {
        guard isRecording || request != nil else { return }
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        request = nil
        task = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
