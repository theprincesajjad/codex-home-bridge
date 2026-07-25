import SwiftUI

@main
struct SetItUpApp: App {
    @StateObject private var authenticationGate: MacAuthenticationGate
    @StateObject private var coordinator: VoiceCoordinator

    init() {
        let authenticationGate = MacAuthenticationGate()
        _authenticationGate = StateObject(wrappedValue: authenticationGate)
        _coordinator = StateObject(
            wrappedValue: VoiceCoordinator(authenticationGate: authenticationGate)
        )
    }

    var body: some Scene {
        Window("Set It Up", id: "setup") {
            BridgeView(
                coordinator: coordinator,
                authenticationGate: authenticationGate
            )
        }
        .windowResizability(.contentSize)

        MenuBarExtra {
            BridgeView(
                coordinator: coordinator,
                authenticationGate: authenticationGate
            )
        } label: {
            Image(systemName: coordinator.isListeningEnabled
                ? "waveform.circle.fill"
                : "waveform.circle")
        }
        .menuBarExtraStyle(.window)
    }
}
