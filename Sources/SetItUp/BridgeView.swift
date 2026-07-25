import SwiftUI
import SetItUpCore

struct BridgeView: View {
    @ObservedObject var coordinator: VoiceCoordinator
    @ObservedObject var authenticationGate: MacAuthenticationGate
    @State private var typedCommand = ""

    private var statusColor: Color {
        switch coordinator.state {
        case .error:
            return .orange
        case .authenticationLocked:
            return .orange
        case .listening:
            return .green
        case .processing, .speaking:
            return .blue
        default:
            return .secondary
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: coordinator.state.symbol)
                    .font(.system(size: 25, weight: .medium))
                    .foregroundStyle(statusColor)
                    .symbolEffect(.pulse, isActive: coordinator.state == .processing)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Set It Up")
                        .font(.headline)
                    Text(coordinator.state.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle(
                    "",
                    isOn: Binding(
                        get: { coordinator.isListeningEnabled },
                        set: { _ in coordinator.toggleListening() }
                    )
                )
                .toggleStyle(.switch)
                .labelsHidden()
            }

            Divider()

            authenticationCard
            assistantCard

            VStack(alignment: .leading, spacing: 7) {
                Text("Say “Set It Up” followed by a request.")
                    .font(.subheadline.weight(.medium))
                Text("The Mac microphone listens. Replies use your current audio output, including a HomePod selected with AirPlay.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                TextField("Ask Set It Up…", text: $typedCommand)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(runTypedCommand)
                Button("Run", action: runTypedCommand)
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        typedCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || !authenticationGate.isUnlocked
                    )
            }

            if !coordinator.lastHeard.isEmpty {
                transcriptBlock(
                    title: "Last request",
                    text: coordinator.lastHeard
                )
            }

            if !coordinator.lastResponse.isEmpty {
                transcriptBlock(
                    title: "Last response",
                    text: coordinator.lastResponse
                )
            }

            HStack {
                Button("Sound Output") {
                    coordinator.openSoundSettings()
                }
                Button("Copy Response") {
                    coordinator.copyLastResponse()
                }
                .disabled(coordinator.lastResponse.isEmpty)

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .controlSize(.small)
            }
            .padding(18)
        }
        .frame(width: 450)
        .frame(maxHeight: 780)
    }

    private var authenticationCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Label(
                    authenticationGate.statusLabel,
                    systemImage: authenticationGate.isUnlocked
                        ? "checkmark.shield"
                        : "lock.shield"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(authenticationGate.isUnlocked ? .green : .primary)

                Spacer()

                Circle()
                    .fill(authenticationGate.isUnlocked ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
            }

            Text(authenticationGate.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                if authenticationGate.isUnlocked {
                    Button("Lock Assistant") {
                        authenticationGate.lock()
                    }
                } else {
                    Button(authenticationGate.isAuthenticating
                        ? "Waiting for Mac…"
                        : "Unlock on this Mac") {
                        authenticationGate.requestUnlock()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(authenticationGate.isAuthenticating)
                }

                Spacer()

                if let lastUnlockedAt = authenticationGate.lastUnlockedAt,
                   authenticationGate.isUnlocked {
                    Text("Verified \(lastUnlockedAt, style: .time)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .controlSize(.small)
        }
        .padding(12)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
    }

    private var assistantCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text("Assistant")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(coordinator.provider.supportsWorkspaceActions ? "CAN ACT" : "CHAT")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(coordinator.provider.supportsWorkspaceActions ? .orange : .green)
            }

            Picker("Assistant", selection: $coordinator.provider) {
                ForEach(AssistantProvider.allCases) { provider in
                    Text(provider.label).tag(provider)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)

            Text(coordinator.provider.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            switch coordinator.provider {
            case .localAI:
                TextField("Ollama model, for example llama3.2", text: $coordinator.localModel)
                    .textFieldStyle(.roundedBorder)
                TextField("Local endpoint", text: $coordinator.localEndpoint)
                    .textFieldStyle(.roundedBorder)

            case .openAI:
                TextField("OpenAI API model", text: $coordinator.openAIModel)
                    .textFieldStyle(.roundedBorder)
                SecureField(
                    coordinator.hasSavedOpenAIKey
                        ? "Replace saved API key"
                        : "OpenAI API key",
                    text: $coordinator.openAIKeyDraft
                )
                .textFieldStyle(.roundedBorder)

                HStack {
                    Button("Save to Keychain") {
                        coordinator.saveOpenAIKey()
                    }
                    .disabled(
                        coordinator.openAIKeyDraft
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            .isEmpty
                    )

                    if coordinator.hasSavedOpenAIKey {
                        Button("Remove Key") {
                            coordinator.removeOpenAIKey()
                        }
                    }
                }
                .controlSize(.small)

            case .codex:
                TextField("~/Documents/Codex", text: $coordinator.workspace)
                    .textFieldStyle(.roundedBorder)

                Picker("Permission", selection: $coordinator.sandbox) {
                    ForEach(BridgeSandbox.allCases) { sandbox in
                        Text(sandbox.label).tag(sandbox)
                    }
                }
                .pickerStyle(.segmented)
            }

            HStack {
                Button(
                    coordinator.isCheckingProvider
                        ? "Checking…"
                        : "Check \(coordinator.provider.label)"
                ) {
                    coordinator.checkSelectedProvider()
                }
                .disabled(coordinator.isCheckingProvider)

                Spacer()

                if !coordinator.providerStatus.isEmpty {
                    Text(coordinator.providerStatus)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }
            .controlSize(.small)
        }
        .padding(12)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func transcriptBlock(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.caption)
                .lineLimit(4)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
    }

    private func runTypedCommand() {
        let command = typedCommand
        typedCommand = ""
        coordinator.runTypedCommand(command)
    }
}
