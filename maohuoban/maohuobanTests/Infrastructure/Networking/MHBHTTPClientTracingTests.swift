import XCTest
@testable import maohuoban

@MainActor
extension MHBHTTPClientRequestInfrastructureTests {
    func testSendInjectsTraceparentRequestIDAndIdempotencyKeyForWriteRequest() async throws {
        let requestStore = MHBRecordedRequestStore()
        let client = makeClient { request in
            requestStore.record(request)
            return Self.successResponse()
        }

        let response: MHBAPIResponse<MHBEmptyResponse> = try await client.post(
            path: "/api/v1/pets",
            body: MHBHTTPClientEmptyTestRequest()
        )

        XCTAssertTrue(response.success)
        let request = try XCTUnwrap(requestStore.requests.first)
        XCTAssertNotNil(
            request.value(forHTTPHeaderField: MHBHTTPHeader.requestID)
                .flatMap(UUID.init(uuidString:))
        )
        XCTAssertNotNil(
            request.value(forHTTPHeaderField: MHBHTTPHeader.idempotencyKey)
                .flatMap(UUID.init(uuidString:))
        )
        XCTAssertTrue(
            request.value(forHTTPHeaderField: MHBHTTPHeader.traceparent)?
                .range(
                    of: #"^00-[0-9a-f]{32}-[0-9a-f]{16}-01$"#,
                    options: .regularExpression
                ) != nil
        )
    }

    func testBackendCorrelationHeadersKeepExistingValuesAndExposeResponseRequestID() async throws {
        let requestStore = MHBRecordedRequestStore()
        let client = makeClient { request in
            requestStore.record(request)
            return Self.successResponse(headers: [
                MHBHTTPHeader.requestID: "backend-request-9"
            ])
        }

        var request = URLRequest(url: URL(string: "http://127.0.0.1:18080/api/v1/profile/me")!)
        request.httpMethod = "GET"
        request.setValue("client-request-1", forHTTPHeaderField: MHBHTTPHeader.requestID)
        request.setValue("00-1234567890abcdef1234567890abcdef-1234567890abcdef-01", forHTTPHeaderField: MHBHTTPHeader.traceparent)

        let response: MHBAPIResponse<MHBEmptyResponse> = try await client.send(request)

        XCTAssertTrue(response.success)
        let sentRequest = try XCTUnwrap(requestStore.requests.first)
        XCTAssertEqual(sentRequest.value(forHTTPHeaderField: MHBHTTPHeader.requestID), "client-request-1")
        XCTAssertEqual(
            sentRequest.value(forHTTPHeaderField: MHBHTTPHeader.traceparent),
            "00-1234567890abcdef1234567890abcdef-1234567890abcdef-01"
        )

        let metadata = MHBHTTPNetworkSummaryBuilder.metadata(
            request: sentRequest,
            response: HTTPURLResponse(
                url: sentRequest.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: [MHBHTTPHeader.requestID: "backend-request-9"]
            ),
            responseData: Data(),
            requestBodyBytes: nil
        )
        XCTAssertEqual(metadata["request_id"], "client-request-1")
        XCTAssertEqual(metadata["response_request_id"], "backend-request-9")
    }
}
