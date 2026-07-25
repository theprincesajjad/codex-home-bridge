import Foundation

public enum AssistantProvider: String, CaseIterable, Identifiable, Sendable {
    case localAI = "local-ai"
    case openAI = "openai-api"
    case codex

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .localAI:
            return "Local AI"
        case .openAI:
            return "OpenAI"
        case .codex:
            return "Codex"
        }
    }

    public var detail: String {
        switch self {
        case .localAI:
            return "Private chat through Ollama on this Mac. No cloud account required."
        case .openAI:
            return "Cloud chat using the customer’s own OpenAI API key."
        case .codex:
            return "Reasoning and computer tasks through the signed-in Codex app."
        }
    }

    public var supportsWorkspaceActions: Bool {
        self == .codex
    }
}

public enum AssistantConfiguration {
    public static func localEndpointIsAllowed(_ value: String) -> Bool {
        guard let url = URL(string: value),
              let host = url.host?.lowercased(),
              ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
            return false
        }

        return host == "localhost" || host == "127.0.0.1" || host == "::1"
    }

    public static func normalizedLocalEndpoint(_ value: String) -> String? {
        guard localEndpointIsAllowed(value) else { return nil }
        return value.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}
