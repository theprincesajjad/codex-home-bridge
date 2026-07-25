import SwiftUI
import CodexHomeBridgeCore

struct BridgeView: View {
    @ObservedObject var coordinator: VoiceCoordinator
    @ObservedObject var phoneGate: PhonePresenceGate
    @State private var typedCommand = ""

    private var statusColor: Color {
        switch coordinator.state {
        case .error:
            return .orange
        case .phoneLocked:
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
                    Text("Codex Home Bridge")
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

            phoneGateCard

            VStack(alignment: .leading, spacing: 7) {
                Text("Say “Hey Codex” followed by a request.")
                    .font(.subheadline.weight(.medium))
                Text("The Mac microphone listens. Audio replies use your current Mac output, including a HomePod selected with AirPlay.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                TextField("Ask Codex…", text: $typedCommand)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(runTypedCommand)
                Button("Run", action: runTypedCommand)
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        typedCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || !phoneGate.isPhonePresent
                    )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Workspace")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField("~/Documents/Codex", text: $coordinator.workspace)
                    .textFieldStyle(.roundedBorder)

                Picker("Permission", selection: $coordinator.sandbox) {
                    ForEach(BridgeSandbox.allCases) { sandbox in
                        Text(sandbox.label).tag(sandbox)
                    }
                }
                .pickerStyle(.segmented)
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
        .frame(width: 430)
        .frame(maxHeight: 720)
    }

    private var phoneGateCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Label(
                    phoneGate.presenceLabel,
                    systemImage: phoneGate.isPhonePresent
                        ? "iphone.radiowaves.left.and.right"
                        : "lock.shield"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(phoneGate.isPhonePresent ? .green : .primary)

                Spacer()

                Circle()
                    .fill(phoneGate.isPhonePresent ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
            }

            Text(phoneGate.isPhonePresent
                ? "Your enrolled phone is sending a local heartbeat. Voice and typed tasks are unlocked."
                : "Open the local link on your iPhone, enter the code, and keep the page open. The listener stays off without the heartbeat.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("PAIRING CODE")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.1)
                        .foregroundStyle(.secondary)
                    Text(phoneGate.formattedCode)
                        .font(.system(size: 22, weight: .semibold, design: .monospaced))
                        .textSelection(.enabled)
                }

                Spacer()

                Picker("", selection: $phoneGate.cadence) {
                    ForEach(PairingCadence.allCases) { cadence in
                        Text(cadence.label).tag(cadence)
                    }
                }
                .labelsHidden()
                .frame(width: 135)
            }

            if let url = phoneGate.localURL {
                Text(url.absoluteString)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(1)
            }

            HStack {
                Button("Copy Phone Link") {
                    phoneGate.copyPairingLink()
                }
                Button("Rotate Code") {
                    phoneGate.rotatePairingCode()
                }
                Spacer()
                Text(phoneGate.credentialExpiresAt, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .controlSize(.small)

            if !phoneGate.serverError.isEmpty {
                Text(phoneGate.serverError)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
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
