import XCTest
@testable import SetItUpCore

final class WakePhraseParserTests: XCTestCase {
    private let parser = WakePhraseParser()

    func testParsesPrimaryWakePhrase() {
        XCTAssertEqual(
            parser.command(from: "Set It Up, summarize this folder"),
            "summarize this folder"
        )
    }

    func testParsesShortWakePhrase() {
        XCTAssertEqual(
            parser.command(from: "Hey Set It Up check the weather"),
            "check the weather"
        )
    }

    func testRequiresWakePhraseAtStart() {
        XCTAssertNil(
            parser.command(from: "Please ask Set It Up to check the weather")
        )
    }

    func testWaitsForCommandAfterWakePhrase() {
        XCTAssertNil(parser.command(from: "Set It Up"))
    }

    func testIsCaseInsensitive() {
        XCTAssertEqual(
            parser.command(from: "SET IT UP open Sound settings"),
            "open Sound settings"
        )
    }

    func testKeepsLegacyHeyCodexCompatibility() {
        XCTAssertEqual(
            parser.command(from: "Hey Codex check the build"),
            "check the build"
        )
    }
}
