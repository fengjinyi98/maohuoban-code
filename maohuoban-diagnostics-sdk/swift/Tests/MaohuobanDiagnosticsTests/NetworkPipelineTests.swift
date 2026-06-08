import Foundation
import Testing
@testable import MaohuobanDiagnostics

extension DiagnosticsPipelineTests {
    @Test("全局入口能生成已注入网络采集的 URLSessionConfiguration")
    func installsNetworkCaptureConfiguration() async throws {
        let root = try temporaryDirectory()
        let diagnostics = try await Diagnostics.install(
            .init(
                serviceName: "maohuoban",
                environment: "test",
                storageDirectory: root.appendingPathComponent("segments")
            )
        )

        let configuration = diagnostics.instrumentedURLSessionConfiguration(.ephemeral)
        #expect(configuration.protocolClasses?.first == DiagnosticsURLProtocol.self)
    }

    @Test("URLProtocol 采集摘要会记录载荷和响应类型")
    func urlProtocolSummaryCapturesPayloadMetadata() throws {
        let url = try #require(URL(string: "https://api.example.com/upload"))
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = Data(repeating: 1, count: 16)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer token", forHTTPHeaderField: "Authorization")

        let response = try #require(
            HTTPURLResponse(
                url: url,
                statusCode: 201,
                httpVersion: nil,
                headerFields: [
                    "Content-Type": "application/json",
                    "X-Request-ID": "request-1"
                ]
            )
        )

        let summary = DiagnosticsURLProtocol.networkSummary(
            request: request,
            response: response,
            data: Data(repeating: 2, count: 32),
            error: nil,
            durationMs: 42
        )
        let event = summary.event()

        #expect(event.metadata["method"] == "POST")
        #expect(event.metadata["status_code"] == "201")
        #expect(event.metadata["request_body_bytes"] == "16")
        #expect(event.metadata["response_body_bytes"] == "32")
        #expect(event.metadata["response_mime_type"] == "application/json")
        #expect(event.metadata["request_header_keys"] == "Authorization,Content-Type")
        #expect(event.metadata["response_header_keys"] == "Content-Type,X-Request-ID")
    }

    @Test("URLProtocol 取消摘要会记录取消状态")
    func urlProtocolSummaryCapturesCancellation() throws {
        let url = try #require(URL(string: "https://api.example.com/stream"))
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let summary = DiagnosticsURLProtocol.cancelledNetworkSummary(
            request: request,
            durationMs: 17
        )
        let event = summary.event()

        #expect(event.kind == .network)
        #expect(event.severity == .warn)
        #expect(event.message == "network request cancelled")
        #expect(event.metadata["method"] == "GET")
        #expect(event.metadata["url"] == "https://api.example.com/stream")
        #expect(event.metadata["duration_ms"] == "17")
        #expect(event.metadata["cancelled"] == "true")
    }

    @Test("URLProtocol 取消错误会归一为取消摘要")
    func urlProtocolSummaryNormalizesCancelledError() throws {
        let url = try #require(URL(string: "https://api.example.com/stream"))
        let request = URLRequest(url: url)

        let summary = DiagnosticsURLProtocol.networkSummary(
            request: request,
            response: nil,
            data: nil,
            error: URLError(.cancelled),
            durationMs: 23
        )
        let event = summary.event()

        #expect(event.severity == .warn)
        #expect(event.message == "network request cancelled")
        #expect(event.metadata["cancelled"] == "true")
        #expect(event.metadata["error"] == nil)
    }

    @Test("URLProtocol 停止加载只记录一次取消事件")
    func urlProtocolStopLoadingRecordsCancellationOnce() async throws {
        let root = try temporaryDirectory()
        let diagnostics = try await Diagnostics.install(
            .init(
                serviceName: "maohuoban",
                environment: "test",
                storageDirectory: root.appendingPathComponent("segments")
            )
        )
        DiagnosticsURLProtocol.runtime = diagnostics
        defer {
            DiagnosticsURLProtocol.runtime = nil
        }
        let url = try #require(URL(string: "https://api.example.com/stream"))
        let request = URLRequest(url: url)
        let protocolInstance = DiagnosticsURLProtocol(
            request: request,
            cachedResponse: nil,
            client: nil
        )

        protocolInstance.stopLoading()
        protocolInstance.stopLoading()
        try await Task.sleep(nanoseconds: 50_000_000)

        let events = try await diagnostics.readEvents()
        let cancellations = events.filter { event in
            event.kind == .network && event.message == "network request cancelled"
        }

        #expect(cancellations.count == 1)
    }

    @Test("网络摘要 API 会记录成功和失败请求")
    func recordsNetworkSummaryWithoutTempLogs() async throws {
        let root = try temporaryDirectory()
        let diagnostics = try await Diagnostics.install(
            .init(
                serviceName: "maohuoban",
                environment: "test",
                storageDirectory: root.appendingPathComponent("segments")
            )
        )

        await diagnostics.network(
            .init(
                method: "GET",
                url: "https://api.example.com/feed",
                statusCode: 200,
                durationMs: 42,
                metadata: ["feature": "feed"]
            )
        )
        await Diagnostics.network(
            .init(
                method: "POST",
                url: "https://api.example.com/login",
                durationMs: 1_200,
                error: "request timed out"
            )
        )
        await diagnostics.network(
            .init(
                method: "GET",
                url: "https://api.example.com/profile",
                statusCode: 500,
                durationMs: 80
            )
        )

        let events = try await diagnostics.readEvents()
        #expect(events.contains {
            $0.kind == .network
                && $0.severity == .info
                && $0.metadata["status_code"] == "200"
                && $0.metadata["feature"] == "feed"
        })
        #expect(events.contains {
            $0.kind == .network
                && $0.severity == .error
                && $0.metadata["error"] == "request timed out"
                && $0.metadata["duration_ms"] == "1200"
        })
        #expect(events.contains {
            $0.kind == .network
                && $0.severity == .error
                && $0.metadata["status_code"] == "500"
                && $0.message == "network request failed"
        })
    }
}
