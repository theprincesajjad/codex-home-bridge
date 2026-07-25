import XCTest
@testable import SetItUpCore

final class AssistantProviderTests: XCTestCase {
    func testOnlyCodexSupportsWorkspaceActions() {
        XCTAssertFalse(AssistantProvider.localAI.supportsWorkspaceActions)
        XCTAssertFalse(AssistantProvider.openAI.supportsWorkspaceActions)
        XCTAssertTrue(AssistantProvider.codex.supportsWorkspaceActions)
    }

    func testLocalEndpointAllowsOnlyLoopbackHosts() {
        XCTAssertTrue(
            AssistantConfiguration.localEndpointIsAllowed("http://127.0.0.1:11434")
        )
        XCTAssertTrue(
            AssistantConfiguration.localEndpointIsAllowed("http://localhost:11434")
        )
        XCTAssertFalse(
            AssistantConfiguration.localEndpointIsAllowed("https://example.com")
        )
        XCTAssertFalse(
            AssistantConfiguration.localEndpointIsAllowed("not-a-url")
        )
    }

    func testNormalizesTrailingSlash() {
        XCTAssertEqual(
            AssistantConfiguration.normalizedLocalEndpoint("http://127.0.0.1:11434/"),
            "http://127.0.0.1:11434"
        )
    }
}
