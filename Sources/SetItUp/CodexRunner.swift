import Foundation
import SetItUpCore

enum CodexRunnerError: LocalizedError {
    case executableNotFound
    case failed(exitCode: Int32, details: String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .executableNotFound:
            return "Codex was not found. Install the Codex app or CLI, then sign in."
        case let .failed(exitCode, details):
            return "Codex stopped with code \(exitCode). \(details)"
        case .emptyResponse:
            return "Codex finished without a response."
        }
    }
}

struct CodexRunner {
    private static let candidates = [
        "/Applications/Codex.app/Contents/Resources/codex",
        "/opt/homebrew/bin/codex",
        "/usr/local/bin/codex"
    ]

    static func executableURL(fileManager: FileManager = .default) -> URL? {
        candidates
            .map(URL.init(fileURLWithPath:))
            .first { fileManager.isExecutableFile(atPath: $0.path) }
    }

    static func run(
        spokenRequest: String,
        workspace: String,
        sandbox: BridgeSandbox
    ) async throws -> String {
        guard let executableURL = executableURL() else {
            throw CodexRunnerError.executableNotFound
        }

        let resolvedWorkspace = NSString(string: workspace).expandingTildeInPath
        let workingDirectory = FileManager.default.fileExists(atPath: resolvedWorkspace)
            ? resolvedWorkspace
            : FileManager.default.homeDirectoryForCurrentUser.path

        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("set-it-up-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let responseURL = tempDirectory.appendingPathComponent("response.txt")
        let logURL = tempDirectory.appendingPathComponent("codex.log")
        FileManager.default.createFile(atPath: logURL.path, contents: nil)

        let prompt = """
        You are the reasoning and action engine for a local voice assistant on this Mac.
        Respond to the spoken request below.
        Your final response will be read aloud, so keep it concise, direct, and conversational.
        Do not use markdown tables. Avoid long lists.
        If the request needs an action the current sandbox cannot take, explain the single next step.

        Spoken request:
        \(spokenRequest)
        """

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let process = Process()
                    process.executableURL = executableURL
                    process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
                    process.arguments = [
                        "exec",
                        "--skip-git-repo-check",
                        "--ephemeral",
                        "--sandbox", sandbox.rawValue,
                        "--cd", workingDirectory,
                        "--output-last-message", responseURL.path,
                        prompt
                    ]

                    let logHandle = try FileHandle(forWritingTo: logURL)
                    process.standardOutput = logHandle
                    process.standardError = logHandle
                    try process.run()
                    process.waitUntilExit()
                    try logHandle.close()

                    guard process.terminationStatus == 0 else {
                        let log = (try? String(contentsOf: logURL, encoding: .utf8)) ?? ""
                        let details = log
                            .split(separator: "\n")
                            .suffix(4)
                            .joined(separator: " ")
                        throw CodexRunnerError.failed(
                            exitCode: process.terminationStatus,
                            details: details
                        )
                    }

                    let response = try String(contentsOf: responseURL, encoding: .utf8)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !response.isEmpty else {
                        throw CodexRunnerError.emptyResponse
                    }
                    continuation.resume(returning: response)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
