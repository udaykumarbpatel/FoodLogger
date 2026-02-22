import Foundation
import Observation
import Speech
import AVFoundation

// MARK: - Private delegate bridge (NSObject required for SFSpeechRecognizerDelegate)
// Kept separate because @Observable and NSObject are incompatible.
private final class SpeechRecognizerDelegate: NSObject, SFSpeechRecognizerDelegate {
    var onAvailabilityChange: ((Bool) -> Void)?

    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer,
                          availabilityDidChange available: Bool) {
        Task { @MainActor in
            self.onAvailabilityChange?(available)
        }
    }
}

// MARK: - SpeechService

@MainActor
@Observable
final class SpeechService {

    var transcript: String = ""
    var isRecording: Bool = false
    var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    var isAvailable: Bool = false

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let delegate = SpeechRecognizerDelegate()

    init() {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
        self.isAvailable = speechRecognizer?.isAvailable ?? false
        self.speechRecognizer?.delegate = delegate
        delegate.onAvailabilityChange = { [weak self] available in
            self?.isAvailable = available
        }
    }

    func requestAuthorization() async {
        let status = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        authorizationStatus = status
    }

    func startRecording() throws {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw SpeechError.recognizerUnavailable
        }

        // Cancel any in-flight task
        recognitionTask?.cancel()
        recognitionTask = nil

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // Create request
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        #if targetEnvironment(simulator)
        request.requiresOnDeviceRecognition = false
        #else
        request.requiresOnDeviceRecognition = true
        #endif
        recognitionRequest = request

        // Install microphone tap
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        // Start recognition task
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                }
                if error != nil || result?.isFinal == true {
                    self.stopAudioEngine()
                    self.isRecording = false
                }
            }
        }

        // Start engine
        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true
        transcript = ""
    }

    func stopRecording() {
        recognitionRequest?.endAudio()
        recognitionTask?.finish()
        stopAudioEngine()
        isRecording = false
    }

    private func stopAudioEngine() {
        guard audioEngine.isRunning else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    enum SpeechError: Error, LocalizedError {
        case recognizerUnavailable
        case requestCreationFailed

        var errorDescription: String? {
            switch self {
            case .recognizerUnavailable:  return "Speech recognizer is not available on this device."
            case .requestCreationFailed:  return "Could not create speech recognition request."
            }
        }
    }
}
