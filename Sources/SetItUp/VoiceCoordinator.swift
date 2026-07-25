import AppKit
import AVFoundation
import Combine
import Foundation
import Speech
import SwiftUI
import SetItUpCore

@MainActor
final class VoiceCoordinator: NSObject, ObservableObject {
    enum State: Equatable {
        case off
        case authenticationLocked
        case requestingAccess
        case listening
        case processing
        case speaking
        case error(String)

        var label: String {
            switch self {
            case .off:
                return "Off"
            case .authenticationLocked:
                return "Locked — Touch ID required"
            case .requestingAccess:
                return "Requesting access"
            case .listening:
                return "Listening for “Set It Up”"
            case .processing:
                return "Assistant is working"
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
            case .authenticationLocked:
                return "touchid"
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
    @Published var provider: AssistantProvider = .localAI {
        didSet {
            UserDefaults.standard.set(provider.rawValue, forKey: "assistantProvider")
            providerStatus = ""
        }
    }
    @Published var localEndpoint = "http://127.0.0.1:11434" {
        didSet {
            UserDefaults.standard.set(localEndpoint, forKey: "localAIEndpoint")
            providerStatus = ""
        }
    }
    @Published var localModel = "" {
        didSet {
            UserDefaults.standard.set(localModel, forKey: "localAIModel")
            providerStatus = ""
        }
    }
    @Published var openAIModel = "" {
        didSet {
            UserDefaults.standard.set(openAIModel, forKey: "openAIModel")
            providerStatus = ""
        }
    }
    @Published var openAIKeyDraft = ""
    @Published private(set) var providerStatus = ""
    @Published private(set) var isCheckingProvider = false
    @Published private(set) var hasSavedOpenAIKey = KeychainStore.hasOpenAIKey

    let authenticationGate: MacAuthenticationGate

    private let parser = WakePhraseParser()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-CA"))
    private let audioEngine = AVAudioEngine()
    private let synthesizer = AVSpeechSynthesizer()

    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var commandDebounce: Task<Void, Never>?
    private var commandTask: Task<Void, Never>?
    private var sessionReset: Task<Void, Never>?
    private var tapInstalled = false
    private var wantsListening = true
    private var lastSubmittedTranscript = ""
    private var authenticationCancellable: AnyCancellable?
    private var providerCheckTask: Task<Void, Never>?

    init(authenticationGate: MacAuthenticationGate) {
        self.authenticationGate = authenticationGate
        let defaults = UserDefaults.standard
        if let savedProvider = defaults.string(forKey: "assistantProvider"),
           let provider = AssistantProvider(rawValue: savedProvider) {
            self.provider = provider
        }
        if let savedEndpoint = defaults.string(forKey: "localAIEndpoint") {
            self.localEndpoint = savedEndpoint
        }
        if let savedModel = defaults.string(forKey: "localAIModel") {
            self.localModel = savedModel
        }
        if let savedModel = defaults.string(forKey: "openAIModel") {
            self.openAIModel = savedModel
        }
        super.init()
        synthesizer.delegate = self
        authenticationCancellable = authenticationGate.$isUnlocked
            .removeDuplicates()
            .sink { [weak self] isUnlocked in
                Task { @MainActor [weak self] in
                    self?.authenticationChanged(isUnlocked)
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
        guard authenticationGate.isUnlocked else {
            stopRecognition()
            state = .authenticationLocked
            authenticationGate.requestUnlock()
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

    func saveOpenAIKey() {
        do {
            try KeychainStore.saveOpenAIKey(openAIKeyDraft)
            openAIKeyDraft = ""
            hasSavedOpenAIKey = KeychainStore.hasOpenAIKey
            providerStatus = hasSavedOpenAIKey
                ? "API key saved in this Mac’s Keychain"
                : "API key removed"
        } catch {
            providerStatus = error.localizedDescription
        }
    }

    func removeOpenAIKey() {
        do {
            try KeychainStore.deleteOpenAIKey()
            openAIKeyDraft = ""
            hasSavedOpenAIKey = false
            providerStatus = "API key removed"
        } catch {
            providerStatus = error.localizedDescription
        }
    }

    func checkSelectedProvider() {
        providerCheckTask?.cancel()
        isCheckingProvider = true
        providerStatus = "Checking \(provider.label)…"
        let selectedProvider = provider
        let endpoint = localEndpoint

        providerCheckTask = Task { [weak self] in
            let status: String
            switch selectedProvider {
            case .localAI:
                let available = await LocalAIRunner.check(endpoint: endpoint)
                status = available
                    ? "Ollama is responding on this Mac"
                    : "Ollama is not running on this Mac yet"
            case .openAI:
                status = KeychainStore.hasOpenAIKey
                    ? "API key is saved; the first request will verify access"
                    : "Save an OpenAI API key first"
            case .codex:
                status = CodexRunner.executableURL() == nil
                    ? "Codex is not installed on this Mac"
                    : "Codex is installed; sign-in is checked on the first request"
            }

            guard !Task.isCancelled else { return }
            self?.providerStatus = status
            self?.isCheckingProvider = false
        }
    }

    func runTypedCommand(_ command: String) {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard authenticationGate.isUnlocked else {
            state = .authenticationLocked
            authenticationGate.requestUnlock()
            return
        }
        submit(trimmed)
    }

    private func startRecognition() {
        guard wantsListening else { return }
        guard authenticationGate.isUnlocked else {
            stopRecognition()
            state = .authenticationLocked
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
        guard authenticationGate.isUnlocked else {
            state = .authenticationLocked
            authenticationGate.requestUnlock()
            return
        }
        guard state != .processing && state != .speaking else { return }
        commandDebounce?.cancel()
        stopRecognition()
        lastHeard = command
        state = .processing

        let workspace = self.workspace
        let sandbox = self.sandbox
        let provider = self.provider
        let localEndpoint = self.localEndpoint
        let localModel = self.localModel
        let openAIModel = self.openAIModel

        commandTask?.cancel()
        commandTask = Task { [weak self] in
            do {
                let response = try await AssistantRunner.run(
                    request: command,
                    provider: provider,
                    localEndpoint: localEndpoint,
                    localModel: localModel,
                    openAIModel: openAIModel,
                    workspace: workspace,
                    sandbox: sandbox
                )
                guard let self,
                      !Task.isCancelled,
                      self.authenticationGate.isUnlocked else {
                    return
                }
                self.lastResponse = response
                self.speak(response)
            } catch {
                guard let self,
                      !Task.isCancelled,
                      self.authenticationGate.isUnlocked else {
                    return
                }
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
        guard authenticationGate.isUnlocked else {
            stopRecognition()
            state = .authenticationLocked
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

    private func authenticationChanged(_ isUnlocked: Bool) {
        if !isUnlocked {
            stopRecognition()
            commandTask?.cancel()
            synthesizer.stopSpeaking(at: .immediate)
            if wantsListening {
                state = .authenticationLocked
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
            if self.wantsListening, self.authenticationGate.isUnlocked {
                self.startRecognition()
            } else if self.wantsListening {
                self.state = .authenticationLocked
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
            self.state = self.wantsListening && self.authenticationGate.isUnlocked
                ? .listening
                : (self.wantsListening ? .authenticationLocked : .off)
            self.restartRecognition()
        }
    }
}
