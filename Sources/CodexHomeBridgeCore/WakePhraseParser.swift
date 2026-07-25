import Foundation

public struct WakePhraseParser: Sendable {
    public let wakePhrases: [String]

    public init(wakePhrases: [String] = ["hey codex", "okay codex", "codex"]) {
        self.wakePhrases = wakePhrases
    }

    public func command(from transcript: String) -> String? {
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

        for phrase in wakePhrases.sorted(by: { $0.count > $1.count }) {
            guard let range = transcript.range(of: phrase, options: options) else {
                continue
            }

            let before = transcript[..<range.lowerBound]
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard before.isEmpty else {
                continue
            }

            let remainder = transcript[range.upperBound...]
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))

            return remainder.isEmpty ? nil : remainder
        }

        return nil
    }

    public func containsWakePhrase(_ transcript: String) -> Bool {
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        return wakePhrases.contains { transcript.range(of: $0, options: options) != nil }
    }
}

public enum BridgeSandbox: String, CaseIterable, Identifiable, Sendable {
    case readOnly = "read-only"
    case workspaceWrite = "workspace-write"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .readOnly:
            return "Read only"
        case .workspaceWrite:
            return "Workspace write"
        }
    }
}
