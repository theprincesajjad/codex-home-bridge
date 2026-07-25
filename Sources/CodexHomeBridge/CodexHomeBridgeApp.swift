import SwiftUI

@main
struct CodexHomeBridgeApp: App {
    @StateObject private var phoneGate: PhonePresenceGate
    @StateObject private var coordinator: VoiceCoordinator

    init() {
        let phoneGate = PhonePresenceGate()
        _phoneGate = StateObject(wrappedValue: phoneGate)
        _coordinator = StateObject(wrappedValue: VoiceCoordinator(phoneGate: phoneGate))
    }

    var body: some Scene {
        Window("Codex Home Bridge", id: "setup") {
            BridgeView(coordinator: coordinator, phoneGate: phoneGate)
        }
        .windowResizability(.contentSize)

        MenuBarExtra {
            BridgeView(coordinator: coordinator, phoneGate: phoneGate)
        } label: {
            Image(systemName: coordinator.isListeningEnabled
                ? "waveform.circle.fill"
                : "waveform.circle")
        }
        .menuBarExtraStyle(.window)
    }
}
