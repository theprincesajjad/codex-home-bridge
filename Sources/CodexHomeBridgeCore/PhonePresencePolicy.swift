import Foundation

public enum PairingCadence: String, CaseIterable, Codable, Identifiable, Sendable {
    case weekly
    case monthly

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .weekly:
            return "Every week"
        case .monthly:
            return "Every month"
        }
    }

    public var validityInterval: TimeInterval {
        switch self {
        case .weekly:
            return 7 * 24 * 60 * 60
        case .monthly:
            return 30 * 24 * 60 * 60
        }
    }
}

public struct PhonePresencePolicy: Sendable {
    public let heartbeatGraceInterval: TimeInterval

    public init(heartbeatGraceInterval: TimeInterval = 18) {
        self.heartbeatGraceInterval = heartbeatGraceInterval
    }

    public func credentialIsValid(expiresAt: Date, now: Date = Date()) -> Bool {
        now < expiresAt
    }

    public func phoneIsPresent(
        lastHeartbeat: Date?,
        credentialExpiresAt: Date,
        now: Date = Date()
    ) -> Bool {
        guard credentialIsValid(expiresAt: credentialExpiresAt, now: now),
              let lastHeartbeat else {
            return false
        }

        return now.timeIntervalSince(lastHeartbeat) <= heartbeatGraceInterval
    }

    public func normalizedPairingCode(_ value: String) -> String {
        String(value.filter(\.isNumber).prefix(6))
    }
}
