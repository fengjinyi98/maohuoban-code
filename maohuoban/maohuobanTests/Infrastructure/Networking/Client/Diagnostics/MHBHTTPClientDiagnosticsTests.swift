import XCTest
@testable import maohuoban

@MainActor
extension MHBHTTPClientRequestInfrastructureTests {
    func testDiagnosticsSummaryRedactsSensitiveQueryValues() {
        let url = URL(
            string: "https://api.maohuoban.test/api/v1/search?phone=13800138000&city=hangzhou&token=secret&password=pw&code=123456&page=2"
        )!

        let redacted = MHBHTTPNetworkSummaryBuilder.redactedURLString(from: url)

        XCTAssertEqual(
            redacted,
            "https://api.maohuoban.test/api/v1/search?phone=%5BREDACTED%5D&city=hangzhou&token=%5BREDACTED%5D&password=%5BREDACTED%5D&code=%5BREDACTED%5D&page=2"
        )
    }
}
