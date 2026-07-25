import AppKit
import AVFoundation
import Combine
import Foundation
import Speech
import SwiftUI
import CodexHomeBridgeCore

@MainActor
final class VoiceCoordinator: NSObject, ObservableObject {
    enum State: Equatable {
        case off
        case phoneLocked
        case requestingAccess
        case listening
        case processing
        case speaking
        case error(String)

        var label: String {
            switch self {
            case .off:
                return "Off"
            case .phoneLocked:
                return "Locked until your iPhone is present"
            case .requestingAccess:
                return "Requesting access"
            case .listening:
                return "Listening for “Hey Codex”"
            case .processing:
                return "Codex is working"
            case .speaking:
                return "Speaking"
            case let .error(message):
                return message
            }
        }

        var symbol: String {
            switch self {
            case .off:
                return "pause.circle"
            case .phoneLocked:
                return "iphone.slash"
            case .requestingAccess:
                return "lock.shield"
            case .listening:
                return "waveform.circle.fill"
            case .processing:
                return "sparkles"
            case .speaking:
                return "speaker.wave.2.fill"
            case .error:
                return "exclamationmark.triangle.fill"
            }
        }
    }

    @Published private(set) var state: State = .off
    @Published private(set) var lastHeard = ""
    @Published private(set) var lastResponse = ""
    @Published var workspace = "~/Documents/Codex"
    @Published var sandbox: BridgeSandbox = .readOnly

    let phoneGate: PhonePresenceGate

    private let parser = WakePhraseParser()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-CA"))
    private let audioEngine = AVAudioEngine()
    private let synthesizer = AVSpeechSynthesizer()

    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var commandDebounce: Task<Void, Never>?
    private var sessionReset: Task<Void, Never>?
    private var tapInstalled = false
    private var wantsListening = false
    private var lastSubmittedTranscript = ""
    private var presenceCancellable: AnyCancellable?

    init(phoneGate: PhonePresenceGate) {
        self.phoneGate = phoneGate
        super.init()
        synthesizer.delegate = self
        presenceCancellable = phoneGate.$isPhonePresent
            .removeDuplicates()
            .sink { [weak self] isPresent in
                Task { @MainActor [weak self] in
                    self?.phonePresenceChanged(isPresent)
                }
            }
    }

    var isListeningEnabled: Bool {
        wantsListening
    }

    func toggleListening() {
        wantsListening ? stopListening() : requestAccessAndStart()
    }

    func requestAccessAndStart() {
        wantsListening = true
        guard phoneGate.isPhonePresent else {
            stopRecognition()
            state = .phoneLocked
            return
        }
        state = .requestingAccess

        SFSpeechRecognizer.requestAuthorization { [weak self] speechStatus in
            AVCaptureDevice.requestAccess(for: .audio) { microphoneGranted in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    guard speechStatus == .authorized else {
                        self.wantsListening = false
                        self.state = .error("Speech recognition permission is required")
                        return
                    }
                    guard microphoneGranted else {
                        self.wantsListening = false
                        self.state = .error("Microphone permission is required")
                        return
                    }
                    self.startRecognition()
                }
            }
        }
    }

    func stopListening() {
        wantsListening = false
        stopRecognition()
        state = .off
    }

    func openSoundSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Sound-Settings.extension") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func copyLastResponse() {
        guard !lastResponse.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lastResponse, forType: .string)
    }

    func runTypedCommand(_ command: String) {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard phoneGate.isPhonePresent else {
            state = .phoneLocked
            return
        }
        submit(trimmed)
    }

    private func startRecognition() {
        guard wantsListening else { return }
        guard phoneGate.isPhonePresent else {
            stopRecognition()
            state = .phoneLocked
            return
        }
        guard state != .processing && state != .speaking else { return }
        guard let recognizer, recognizer.isAvailable else {
            state = .error("Speech recognition is not available")
            scheduleRestart(after: 2)
            return
        }

        stopRecognition()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else {
            state = .error("No microphone input is available")
            scheduleRestart(after: 2)
            return
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        tapInstalled = true

        do {
            audioEngine.prepare()
            try audioEngine.start()
            state = .listening
        } catch {
            state = .error("Could not start the microphone")
            scheduleRestart(after: 2)
            return
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }

                if let result {
                    let transcript = result.bestTranscription.formattedString
                    self.lastHeard = transcript
                    self.considerSubmitting(transcript, isFinal: result.isFinal)

                    if result.isFinal {
                        self.scheduleRestart(after: 0.4)
                    }
                } else if error != nil {
                    self.scheduleRestart(after: 0.8)
                }
            }
        }

        sessionReset?.cancel()
        sessionReset = Task { [weak self] in
            try? await Task.sleep(for: .seconds(50))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.restartRecognition()
            }
        }
    }

    private func considerSubmitting(_ transcript: String, isFinal: Bool) {
        guard transcript != lastSubmittedTranscript else { return }
        guard let command = parser.command(from: transcript) else { return }

        commandDebounce?.cancel()
        let delay = isFinal ? Duration.milliseconds(50) : Duration.milliseconds(950)
        commandDebounce = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, self.lastHeard == transcript else { return }
                self.lastSubmittedTranscript = transcript
                self.submit(command)
            }
        }
    }

    private func submit(_ command: String) {
        guard phoneGate.isPhonePresent else {
            state = .phoneLocked
            return
        }
        guard state != .processing && state != .speaking else { return }
        commandDebounce?.cancel()
        stopRecognition()
        lastHeard = command
        state = .processing

        let workspace = self.workspace
        let sandbox = self.sandbox

        Task { [weak self] in
            do {
                let response = try await CodexRunner.run(
                    spokenRequest: command,
                    workspace: workspace,
                    sandbox: sandbox
                )
                guard let self else { return }
                self.lastResponse = response
                self.speak(response)
            } catch {
                guard let self else { return }
                self.lastResponse = error.localizedDescription
                self.speak(error.localizedDescription)
            }
        }
    }

    private func speak(_ response: String) {
        state = .speaking
        let utterance = AVSpeechUtterance(string: response)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-CA")
        utterance.rate = 0.49
        synthesizer.speak(utterance)
    }

    private func restartRecognition() {
        guard wantsListening else { return }
        guard phoneGate.isPhonePresent else {
            stopRecognition()
            state = .phoneLocked
            return
        }
        guard state != .processing && state != .speaking else { return }
        startRecognition()
    }

    private func scheduleRestart(after seconds: Double) {
        guard wantsListening else { return }
        sessionReset?.cancel()
        sessionReset = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.restartRecognition()
            }
        }
    }

    private func stopRecognition() {
        commandDebounce?.cancel()
        sessionReset?.cancel()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        if audioEngine.isRunning {
            audioEngine.stop()
        }
        if tapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
    }

    private func phonePresenceChanged(_ isPresent: Bool) {
        if !isPresent {
            stopRecognition()
            if wantsListening {
                state = .phoneLocked
            }
            return
        }

        if wantsListening, state != .processing, state != .speaking {
            requestAccessAndStart()
        }
    }
}

extension VoiceCoordinator: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if self.wantsListening, self.phoneGate.isPhonePresent {
                self.startRecognition()
            } else if self.wantsListening {
                self.state = .phoneLocked
            } else {
                self.state = .off
            }
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.state = self.wantsListening && self.phoneGate.isPhonePresent
                ? .listening
                : (self.wantsListening ? .phoneLocked : .off)
            self.restartRecognition()
        }
    }
}
