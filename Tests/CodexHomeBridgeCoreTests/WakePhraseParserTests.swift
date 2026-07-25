import XCTest
@testable import CodexHomeBridgeCore

final class WakePhraseParserTests: XCTestCase {
    private let parser = WakePhraseParser()

    func testParsesPrimaryWakePhrase() {
        XCTAssertEqual(
            parser.command(from: "Hey Codex, summarize this folder"),
            "summarize this folder"
        )
    }

    func testParsesShortWakePhrase() {
        XCTAssertEqual(
            parser.command(from: "Codex check the weather"),
            "check the weather"
        )
    }

    func testRequiresWakePhraseAtStart() {
        XCTAssertNil(
            parser.command(from: "Please ask Codex to check the weather")
        )
    }

    func testWaitsForCommandAfterWakePhrase() {
        XCTAssertNil(parser.command(from: "Hey Codex"))
    }

    func testIsCaseInsensitive() {
        XCTAssertEqual(
            parser.command(from: "HEY CODEX open Sound settings"),
            "open Sound settings"
        )
    }
}

final class PhonePresencePolicyTests: XCTestCase {
    private let policy = PhonePresencePolicy(heartbeatGraceInterval: 18)
    private let now = Date(timeIntervalSince1970: 1_000_000)

    func testWeeklyAndMonthlyCadencesUseExpectedWindows() {
        XCTAssertEqual(PairingCadence.weekly.validityInterval, 604_800)
        XCTAssertEqual(PairingCadence.monthly.validityInterval, 2_592_000)
    }

    func testPhoneRequiresFreshHeartbeatAndValidCredential() {
        XCTAssertTrue(
            policy.phoneIsPresent(
                lastHeartbeat: now.addingTimeInterval(-10),
                credentialExpiresAt: now.addingTimeInterval(100),
                now: now
            )
        )
        XCTAssertFalse(
            policy.phoneIsPresent(
                lastHeartbeat: now.addingTimeInterval(-19),
                credentialExpiresAt: now.addingTimeInterval(100),
                now: now
            )
        )
        XCTAssertFalse(
            policy.phoneIsPresent(
                lastHeartbeat: now,
                credentialExpiresAt: now,
                now: now
            )
        )
    }

    func testCodeNormalizationKeepsOnlySixDigits() {
        XCTAssertEqual(policy.normalizedPairingCode("123 456"), "123456")
        XCTAssertEqual(policy.normalizedPairingCode("12-34-56-78"), "123456")
    }
}
