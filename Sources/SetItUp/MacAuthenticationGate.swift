import AppKit
import Foundation
import LocalAuthentication
import SwiftUI

@MainActor
final class MacAuthenticationGate: ObservableObject {
    @Published private(set) var isUnlocked = false
    @Published private(set) var isAuthenticating = false
    @Published private(set) var statusMessage = "Mac authentication is required"
    @Published private(set) var lastUnlockedAt: Date?

    private var notificationObservers: [NSObjectProtocol] = []
    private var authenticationContext: LAContext?
    private var authenticationAttemptID: UUID?

    init() {
        let center = NSWorkspace.shared.notificationCenter

        for name in [
            NSWorkspace.sessionDidResignActiveNotification,
            NSWorkspace.screensDidSleepNotification,
        ] {
            notificationObservers.append(
                center.addObserver(forName: name, object: nil, queue: .main) {
                    [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.lock()
                    }
                }
            )
        }

        notificationObservers.append(
            center.addObserver(
                forName: NSWorkspace.sessionDidBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.lock()
                    self?.requestUnlock()
                }
            }
        )

        Task { @MainActor [weak self] in
            await Task.yield()
            self?.requestUnlock()
        }
    }

    deinit {
        let center = NSWorkspace.shared.notificationCenter
        for observer in notificationObservers {
            center.removeObserver(observer)
        }
    }

    var statusLabel: String {
        if isUnlocked {
            return "Owner verified"
        }
        if isAuthenticating {
            return "Waiting for authentication"
        }
        return "Assistant locked"
    }

    func requestUnlock() {
        guard !isUnlocked, !isAuthenticating else { return }

        let context = LAContext()
        context.localizedCancelTitle = "Keep Locked"

        var policyError: NSError?
        guard context.canEvaluatePolicy(
            .deviceOwnerAuthentication,
            error: &policyError
        ) else {
            statusMessage = policyError?.localizedDescription
                ?? "Mac owner authentication is not available"
            return
        }

        isAuthenticating = true
        let attemptID = UUID()
        authenticationContext = context
        authenticationAttemptID = attemptID
        statusMessage = "Use Touch ID or your Mac password to unlock Set It Up"

        context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: "Unlock Set It Up voice and typed requests"
        ) { [weak self] success, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard self.authenticationAttemptID == attemptID else { return }
                self.authenticationContext = nil
                self.authenticationAttemptID = nil
                self.isAuthenticating = false

                if success {
                    self.isUnlocked = true
                    self.lastUnlockedAt = Date()
                    self.statusMessage = "Voice and typed tasks are unlocked"
                } else {
                    self.isUnlocked = false
                    self.statusMessage = error?.localizedDescription
                        ?? "Mac authentication did not unlock Set It Up"
                }
            }
        }
    }

    func lock() {
        authenticationContext?.invalidate()
        authenticationContext = nil
        authenticationAttemptID = nil
        isUnlocked = false
        isAuthenticating = false
        statusMessage = "Mac authentication is required"
    }
}
