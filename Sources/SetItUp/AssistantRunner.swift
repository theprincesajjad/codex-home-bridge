import Foundation
import SetItUpCore

enum AssistantRunnerError: LocalizedError {
    case invalidLocalEndpoint
    case localModelRequired
    case localAIUnavailable
    case openAIKeyRequired
    case openAIModelRequired
    case invalidResponse
    case requestFailed(status: Int, details: String)

    var errorDescription: String? {
        switch self {
        case .invalidLocalEndpoint:
            return "Local AI must use localhost or 127.0.0.1."
        case .localModelRequired:
            return "Choose an installed Ollama model first."
        case .localAIUnavailable:
            return "Ollama is not responding on this Mac. Install or start Ollama, then try again."
        case .openAIKeyRequired:
            return "Save an OpenAI API key in the Mac Keychain first."
        case .openAIModelRequired:
            return "Enter an OpenAI API model available to your account."
        case .invalidResponse:
            return "The assistant returned a response Set It Up could not read."
        case let .requestFailed(status, details):
            return "The assistant request failed (\(status)). \(details)"
        }
    }
}

struct AssistantRunner {
    static func run(
        request: String,
        provider: AssistantProvider,
        localEndpoint: String,
        localModel: String,
        openAIModel: String,
        workspace: String,
        sandbox: BridgeSandbox
    ) async throws -> String {
        switch provider {
        case .localAI:
            return try await LocalAIRunner.run(
                request: request,
                endpoint: localEndpoint,
                model: localModel
            )
        case .openAI:
            guard let apiKey = try KeychainStore.readOpenAIKey(),
                  !apiKey.isEmpty else {
                throw AssistantRunnerError.openAIKeyRequired
            }
            return try await OpenAIRunner.run(
                request: request,
                model: openAIModel,
                apiKey: apiKey
            )
        case .codex:
            return try await CodexRunner.run(
                spokenRequest: request,
                workspace: workspace,
                sandbox: sandbox
            )
        }
    }
}

struct LocalAIRunner {
    static func check(endpoint: String) async -> Bool {
        guard let base = AssistantConfiguration.normalizedLocalEndpoint(endpoint),
              let url = URL(string: "\(base)/api/tags") else {
            return false
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 3

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    static func run(request: String, endpoint: String, model: String) async throws -> String {
        guard let base = AssistantConfiguration.normalizedLocalEndpoint(endpoint),
              let url = URL(string: "\(base)/api/chat") else {
            throw AssistantRunnerError.invalidLocalEndpoint
        }

        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedModel.isEmpty else {
            throw AssistantRunnerError.localModelRequired
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 120
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": trimmedModel,
            "stream": false,
            "messages": [
                [
                    "role": "system",
                    "content": spokenResponseInstruction,
                ],
                [
                    "role": "user",
                    "content": request,
                ],
            ],
        ])

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: urlRequest)
        } catch {
            throw AssistantRunnerError.localAIUnavailable
        }

        try validate(response: response, data: data)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = object["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AssistantRunnerError.invalidResponse
        }
        return try nonEmpty(content)
    }
}

struct OpenAIRunner {
    static func run(request: String, model: String, apiKey: String) async throws -> String {
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedModel.isEmpty else {
            throw AssistantRunnerError.openAIModelRequired
        }

        var urlRequest = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 120
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": trimmedModel,
            "instructions": spokenResponseInstruction,
            "input": request,
        ])

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        try validate(response: response, data: data)

        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AssistantRunnerError.invalidResponse
        }

        if let outputText = object["output_text"] as? String, !outputText.isEmpty {
            return outputText.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let output = object["output"] as? [[String: Any]] {
            let text = output
                .compactMap { $0["content"] as? [[String: Any]] }
                .flatMap { $0 }
                .compactMap { $0["text"] as? String }
                .joined(separator: "\n")
            return try nonEmpty(text)
        }

        throw AssistantRunnerError.invalidResponse
    }
}

private let spokenResponseInstruction = """
You are the conversational engine for Set It Up, a local Mac voice assistant.
Answer the user directly. The response will be read aloud, so keep it concise,
plain-language, and conversational. Avoid markdown tables and long lists.
"""

private func validate(response: URLResponse, data: Data) throws {
    guard let http = response as? HTTPURLResponse else {
        throw AssistantRunnerError.invalidResponse
    }
    guard (200..<300).contains(http.statusCode) else {
        let raw = String(data: data, encoding: .utf8) ?? ""
        let details = String(raw.prefix(280))
        throw AssistantRunnerError.requestFailed(status: http.statusCode, details: details)
    }
}

private func nonEmpty(_ value: String) throws -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
        throw AssistantRunnerError.invalidResponse
    }
    return trimmed
}
