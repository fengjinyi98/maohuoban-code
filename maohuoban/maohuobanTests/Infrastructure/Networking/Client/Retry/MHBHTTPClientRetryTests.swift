import XCTest
@testable import maohuoban

@MainActor
extension MHBHTTPClientRequestInfrastructureTests {
    func testRetryPolicyRetriesRetryableStatusAndKeepsSameIdempotencyKey() async throws {
        let requestStore = MHBRecordedRequestStore()
        let client = makeClient(retryPolicy: .immediate(maxAttempts: 2)) { request in
            requestStore.record(request)
            if requestStore.requests.count == 1 {
                return Self.retryableResponse()
            }
            return Self.successResponse()
        }

        let response: MHBAPIResponse<MHBEmptyResponse> = try await client.post(
            path: "/api/v1/pets",
            body: MHBHTTPClientEmptyTestRequest()
        )

        XCTAssertTrue(response.success)
        XCTAssertEqual(requestStore.requests.count, 2)
        XCTAssertEqual(
            requestStore.requests.first?.value(forHTTPHeaderField: MHBHTTPHeader.idempotencyKey),
            requestStore.requests.last?.value(forHTTPHeaderField: MHBHTTPHeader.idempotencyKey)
        )
    }
}
