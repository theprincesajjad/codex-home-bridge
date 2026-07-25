import Darwin
import Foundation
import Network
import SwiftUI
import CodexHomeBridgeCore

@MainActor
final class PhonePresenceGate: ObservableObject {
    @Published private(set) var isPhonePresent = false
    @Published private(set) var isServerReady = false
    @Published private(set) var pairingCode = "••••••"
    @Published private(set) var credentialExpiresAt = Date()
    @Published private(set) var pairedIPAddress = ""
    @Published private(set) var lastSeenAt: Date?
    @Published private(set) var serverError = ""
    @Published var cadence: PairingCadence {
        didSet {
            guard cadence != oldValue else { return }
            defaults.set(cadence.rawValue, forKey: Keys.cadence)
            rotatePairingCode()
        }
    }

    let port: UInt16 = 8765

    private enum Keys {
        static let cadence = "phoneGate.cadence"
        static let code = "phoneGate.code"
        static let expiresAt = "phoneGate.expiresAt"
        static let token = "phoneGate.token"
        static let pairedIP = "phoneGate.pairedIP"
    }

    private let defaults: UserDefaults
    private let policy = PhonePresencePolicy()
    private let networkQueue = DispatchQueue(label: "com.codexhomebridge.phone-gate")
    private var listener: NWListener?
    private var presenceTimer: Timer?
    private var enrolledToken = ""
    private var failedAttempts: [Date] = []
    private var blockedUntil: Date?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.cadence = PairingCadence(
            rawValue: defaults.string(forKey: Keys.cadence) ?? ""
        ) ?? .weekly

        let savedCode = defaults.string(forKey: Keys.code) ?? ""
        let savedExpiry = defaults.object(forKey: Keys.expiresAt) as? Date ?? .distantPast
        let savedToken = defaults.string(forKey: Keys.token) ?? ""

        if savedCode.count == 6, !savedToken.isEmpty, savedExpiry > Date() {
            pairingCode = savedCode
            credentialExpiresAt = savedExpiry
            enrolledToken = savedToken
            pairedIPAddress = defaults.string(forKey: Keys.pairedIP) ?? ""
        } else {
            createFreshCredential()
        }

        startServer()
        presenceTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) {
            [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshPresence()
            }
        }
    }

    deinit {
        listener?.cancel()
        presenceTimer?.invalidate()
    }

    var localURL: URL? {
        URL(string: "http://\(Self.localIPv4Address() ?? "codex-home-bridge.local"):\(port)")
    }

    var formattedCode: String {
        guard pairingCode.count == 6 else { return pairingCode }
        let splitIndex = pairingCode.index(pairingCode.startIndex, offsetBy: 3)
        return "\(pairingCode[..<splitIndex]) \(pairingCode[splitIndex...])"
    }

    var presenceLabel: String {
        if isPhonePresent {
            return pairedIPAddress.isEmpty ? "Phone present" : "Phone present at \(pairedIPAddress)"
        }
        if lastSeenAt != nil {
            return "Phone offline"
        }
        return "Waiting for your phone"
    }

    func rotatePairingCode() {
        createFreshCredential()
        refreshPresence()
    }

    func copyPairingLink() {
        guard let localURL else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(localURL.absoluteString, forType: .string)
    }

    private func createFreshCredential() {
        pairingCode = String(format: "%06d", Int.random(in: 0...999_999))
        credentialExpiresAt = Date().addingTimeInterval(cadence.validityInterval)
        enrolledToken = UUID().uuidString.replacingOccurrences(of: "-", with: "")
            + UUID().uuidString.replacingOccurrences(of: "-", with: "")
        pairedIPAddress = ""
        lastSeenAt = nil
        failedAttempts = []
        blockedUntil = nil

        defaults.set(pairingCode, forKey: Keys.code)
        defaults.set(credentialExpiresAt, forKey: Keys.expiresAt)
        defaults.set(enrolledToken, forKey: Keys.token)
        defaults.removeObject(forKey: Keys.pairedIP)
    }

    private func startServer() {
        do {
            let listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)
            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    switch state {
                    case .ready:
                        self.isServerReady = true
                        self.serverError = ""
                    case let .failed(error):
                        self.isServerReady = false
                        self.serverError = "Phone gate could not start: \(error.localizedDescription)"
                    case .cancelled:
                        self.isServerReady = false
                    default:
                        break
                    }
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                self?.receiveRequest(on: connection)
            }
            listener.start(queue: networkQueue)
            self.listener = listener
        } catch {
            serverError = "Phone gate could not start: \(error.localizedDescription)"
        }
    }

    nonisolated private func receiveRequest(on connection: NWConnection) {
        connection.start(queue: DispatchQueue.global(qos: .userInitiated))
        connection.receive(minimumIncompleteLength: 1, maximumLength: 32_768) {
            [weak self] data, _, _, _ in
            let request = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            let address = Self.remoteAddress(from: connection.endpoint)

            Task { @MainActor [weak self] in
                guard let self else {
                    connection.cancel()
                    return
                }
                let response = self.response(for: request, remoteAddress: address)
                connection.send(
                    content: response.data(using: .utf8),
                    completion: .contentProcessed { _ in
                        connection.cancel()
                    }
                )
            }
        }
    }

    private func response(for request: String, remoteAddress: String) -> String {
        if credentialExpiresAt <= Date() {
            createFreshCredential()
        }

        let parsed = HTTPRequest(raw: request)
        let suppliedToken = parsed.cookies["bridge_token"] ?? ""
        let hasValidToken = suppliedToken == enrolledToken && Date() < credentialExpiresAt

        if parsed.method == "GET",
           parsed.path == "/bridge-health",
           remoteAddress == "::1" || remoteAddress == "127.0.0.1" {
            return plainResponse(
                body: #"{"phonePresent":\#(isPhonePresent),"serverReady":\#(isServerReady)}"#,
                contentType: "application/json; charset=utf-8"
            )
        }

        if parsed.method == "POST", parsed.path == "/pair" {
            if let blockedUntil, blockedUntil > Date() {
                return htmlResponse(
                    status: "429 Too Many Requests",
                    body: pairingPage(message: "Too many attempts. Wait one minute and try again.")
                )
            }

            let suppliedCode = policy.normalizedPairingCode(parsed.form["code"] ?? "")
            if suppliedCode == pairingCode {
                failedAttempts = []
                blockedUntil = nil
                markHeartbeat(from: remoteAddress)
                let maxAge = Int(max(0, credentialExpiresAt.timeIntervalSinceNow))
                return htmlResponse(
                    body: pairedPage(),
                    headers: [
                        "Set-Cookie: bridge_token=\(enrolledToken); HttpOnly; SameSite=Strict; Path=/; Max-Age=\(maxAge)"
                    ]
                )
            }

            recordFailedAttempt()
            return htmlResponse(
                status: "401 Unauthorized",
                body: pairingPage(message: "That code did not match. Check the Mac and try again.")
            )
        }

        if parsed.method == "POST", parsed.path == "/heartbeat" {
            guard hasValidToken else {
                return plainResponse(status: "401 Unauthorized", body: "Pairing required")
            }
            markHeartbeat(from: remoteAddress)
            return plainResponse(status: "204 No Content", body: "")
        }

        if parsed.method == "GET", parsed.path == "/status" {
            guard hasValidToken else {
                return plainResponse(status: "401 Unauthorized", body: "Pairing required")
            }
            markHeartbeat(from: remoteAddress)
            return plainResponse(
                body: #"{"present":true,"expires":"\#(ISO8601DateFormatter().string(from: credentialExpiresAt))"}"#,
                contentType: "application/json; charset=utf-8"
            )
        }

        if hasValidToken {
            markHeartbeat(from: remoteAddress)
            return htmlResponse(body: pairedPage())
        }

        return htmlResponse(body: pairingPage(message: nil))
    }

    private func markHeartbeat(from address: String) {
        lastSeenAt = Date()
        if !address.isEmpty, address != "::1", address != "127.0.0.1" {
            pairedIPAddress = address
            defaults.set(address, forKey: Keys.pairedIP)
        }
        refreshPresence()
    }

    private func refreshPresence() {
        if credentialExpiresAt <= Date() {
            createFreshCredential()
        }
        isPhonePresent = policy.phoneIsPresent(
            lastHeartbeat: lastSeenAt,
            credentialExpiresAt: credentialExpiresAt
        )
    }

    private func recordFailedAttempt() {
        let cutoff = Date().addingTimeInterval(-60)
        failedAttempts = failedAttempts.filter { $0 > cutoff }
        failedAttempts.append(Date())
        if failedAttempts.count >= 5 {
            blockedUntil = Date().addingTimeInterval(60)
        }
    }

    private func pairingPage(message: String?) -> String {
        let notice = message.map {
            #"<p class="notice">\#(Self.htmlEscape($0))</p>"#
        } ?? ""

        return pageShell(
            title: "Pair your iPhone",
            body: """
            <div class="mark">C</div>
            <p class="eyebrow">CODEX HOME BRIDGE</p>
            <h1>Pair your iPhone</h1>
            <p class="lede">Enter the six-digit code shown on your Mac. Keep this page open while you want the bridge to listen.</p>
            \(notice)
            <form method="post" action="/pair">
              <label for="code">PAIRING CODE</label>
              <input id="code" name="code" inputmode="numeric" autocomplete="one-time-code" maxlength="7" placeholder="000 000" autofocus required>
              <button type="submit">Connect phone</button>
            </form>
            <p class="fine">The credential expires \(cadence == .weekly ? "every seven days" : "every thirty days"). Your voice listener turns off within 18 seconds of losing this heartbeat.</p>
            """
        )
    }

    private func pairedPage() -> String {
        let expiry = credentialExpiresAt.formatted(date: .abbreviated, time: .shortened)
        return pageShell(
            title: "Phone connected",
            body: """
            <div class="pulse"><span></span></div>
            <p class="eyebrow">CODEX HOME BRIDGE</p>
            <h1>Phone connected</h1>
            <p class="lede">This iPhone is keeping your Mac voice bridge unlocked.</p>
            <div class="status"><b>LIVE</b><span id="state">Heartbeat active</span></div>
            <p class="fine">Keep this page open. Pairing expires \(Self.htmlEscape(expiry)). The screen will stay awake when your browser permits it.</p>
            <script>
              let wakeLock;
              async function keepAwake() {
                try { wakeLock = await navigator.wakeLock.request('screen'); } catch (_) {}
              }
              async function beat() {
                try {
                  const response = await fetch('/heartbeat', {method: 'POST', cache: 'no-store'});
                  if (!response.ok) throw new Error();
                  document.getElementById('state').textContent = 'Heartbeat active';
                } catch (_) {
                  document.getElementById('state').textContent = 'Reconnecting…';
                }
              }
              keepAwake();
              beat();
              setInterval(beat, 5000);
              document.addEventListener('visibilitychange', () => {
                if (document.visibilityState === 'visible') { keepAwake(); beat(); }
              });
            </script>
            """
        )
    }

    private func pageShell(title: String, body: String) -> String {
        """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
          <title>\(Self.htmlEscape(title))</title>
          <style>
            :root{color-scheme:dark;font-family:-apple-system,BlinkMacSystemFont,"SF Pro Display",sans-serif}
            *{box-sizing:border-box}body{margin:0;min-height:100svh;display:grid;place-items:center;background:#090b0d;color:#f5f5f2;padding:28px}
            main{width:min(100%,420px);padding:30px;border:1px solid #292c31;border-radius:24px;background:linear-gradient(160deg,#181b20,#0e1013);box-shadow:0 30px 80px #0008}
            .mark{width:48px;height:48px;display:grid;place-items:center;border-radius:14px;background:#f2ff63;color:#111;font-weight:800;font-size:22px}
            .eyebrow{margin:26px 0 10px;color:#a7ffb2;font-size:11px;font-weight:700;letter-spacing:.16em}
            h1{font-size:38px;line-height:1.02;letter-spacing:-.04em;margin:0 0 14px}
            .lede{font-size:17px;line-height:1.5;color:#b5bac2;margin:0 0 24px}
            label{display:block;color:#9298a1;font-size:10px;font-weight:700;letter-spacing:.13em;margin-bottom:8px}
            input{width:100%;height:58px;border:1px solid #373c43;border-radius:13px;background:#090b0d;color:#fff;padding:0 16px;font:600 25px ui-monospace,SFMono-Regular,monospace;letter-spacing:.16em}
            input:focus{outline:2px solid #f2ff63;outline-offset:2px}
            button{width:100%;height:52px;border:0;border-radius:13px;background:#f2ff63;color:#101214;font-size:15px;font-weight:750;margin-top:12px}
            .fine{font-size:12px;line-height:1.5;color:#747a83;margin:20px 0 0}
            .notice{border:1px solid #70482e;background:#2b1a11;color:#ffbc87;padding:11px 13px;border-radius:10px;font-size:13px}
            .pulse{width:52px;height:52px;border-radius:50%;display:grid;place-items:center;background:#15351f}
            .pulse span{width:14px;height:14px;border-radius:50%;background:#71ff91;box-shadow:0 0 0 9px #71ff9120}
            .status{display:flex;align-items:center;gap:11px;border:1px solid #2e343b;border-radius:13px;padding:14px;margin-top:8px}
            .status b{color:#71ff91;font-size:10px;letter-spacing:.13em}.status span{color:#c8ccd2;font-size:14px}
          </style>
        </head>
        <body><main>\(body)</main></body>
        </html>
        """
    }

    private func htmlResponse(
        status: String = "200 OK",
        body: String,
        headers: [String] = []
    ) -> String {
        let data = body.data(using: .utf8) ?? Data()
        return """
        HTTP/1.1 \(status)\r
        Content-Type: text/html; charset=utf-8\r
        Content-Length: \(data.count)\r
        Cache-Control: no-store\r
        Connection: close\r
        \(headers.joined(separator: "\r\n"))\(headers.isEmpty ? "" : "\r\n")\r
        \(body)
        """
    }

    private func plainResponse(
        status: String = "200 OK",
        body: String,
        contentType: String = "text/plain; charset=utf-8"
    ) -> String {
        let data = body.data(using: .utf8) ?? Data()
        return """
        HTTP/1.1 \(status)\r
        Content-Type: \(contentType)\r
        Content-Length: \(data.count)\r
        Cache-Control: no-store\r
        Connection: close\r
        \r
        \(body)
        """
    }

    nonisolated private static func remoteAddress(from endpoint: NWEndpoint) -> String {
        guard case let .hostPort(host, _) = endpoint else { return "" }
        return String(describing: host)
            .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
    }

    private static func localIPv4Address() -> String? {
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0, let first = pointer else { return nil }
        defer { freeifaddrs(pointer) }

        for item in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let interface = item.pointee
            guard interface.ifa_addr.pointee.sa_family == UInt8(AF_INET),
                  String(cString: interface.ifa_name) == "en0" else {
                continue
            }

            var address = interface.ifa_addr.pointee
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(
                &address,
                socklen_t(interface.ifa_addr.pointee.sa_len),
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            )
            if result == 0 {
                return String(cString: hostname)
            }
        }
        return nil
    }

    private static func htmlEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

private struct HTTPRequest {
    let method: String
    let path: String
    let cookies: [String: String]
    let form: [String: String]

    init(raw: String) {
        let sections = raw.components(separatedBy: "\r\n\r\n")
        let head = sections.first ?? ""
        let body = sections.dropFirst().joined(separator: "\r\n\r\n")
        let lines = head.components(separatedBy: "\r\n")
        let requestLine = lines.first?.split(separator: " ") ?? []

        method = requestLine.first.map(String.init) ?? "GET"
        path = requestLine.dropFirst().first.map(String.init) ?? "/"

        var parsedCookies: [String: String] = [:]
        for line in lines.dropFirst() {
            guard line.lowercased().hasPrefix("cookie:") else { continue }
            let value = line.dropFirst("cookie:".count)
            for cookie in value.split(separator: ";") {
                let parts = cookie.split(separator: "=", maxSplits: 1)
                guard parts.count == 2 else { continue }
                parsedCookies[String(parts[0]).trimmingCharacters(in: .whitespaces)] =
                    String(parts[1]).trimmingCharacters(in: .whitespaces)
            }
        }
        cookies = parsedCookies

        var parsedForm: [String: String] = [:]
        for field in body.split(separator: "&") {
            let parts = field.split(separator: "=", maxSplits: 1)
            guard let key = parts.first else { continue }
            let rawValue = parts.count == 2 ? String(parts[1]) : ""
            parsedForm[String(key)] = rawValue
                .replacingOccurrences(of: "+", with: " ")
                .removingPercentEncoding ?? rawValue
        }
        form = parsedForm
    }
}
