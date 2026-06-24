import XCTest
@testable import maohuoban

@MainActor
extension MHBHTTPClientRequestInfrastructureTests {
    func testAuthorizationMiddlewareAddsBearerHeaderWhenRepositoryDoesNotPassHeaders() async throws {
        let requestStore = MHBRecordedRequestStore()
        let client = makeClient(
            authorizationProvider: MHBTestAuthorizationProvider(token: "middleware-token")
        ) { request in
            requestStore.record(request)
            return Self.successResponse()
        }

        let response: MHBAPIResponse<MHBEmptyResponse> = try await client.get(path: "/api/v1/profile/me")

        XCTAssertTrue(response.success)
        XCTAssertEqual(
            requestStore.requests.first?.value(forHTTPHeaderField: MHBHTTPHeader.authorization),
            "Bearer middleware-token"
        )
    }
}
