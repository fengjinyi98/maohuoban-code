import Testing
import Foundation
@testable import MaohuobanDiagnostics

@Suite("Diagnostics pipeline", .serialized)
struct DiagnosticsPipelineTests {
    @Test("远端镜像配置会生成标准 ingest 请求")
    func remoteMirrorConfigurationBuildsIngestRequest() throws {
        let endpoint = try #require(URL(string: "http://127.0.0.1:8080/internal/diagnostics/ingest"))
        let configuration = DiagnosticsRemoteMirrorConfiguration(
            endpoint: endpoint,
            headers: ["X-Diagnostics-Source": "ios-device"],
            timeoutSeconds: 3
        )
        let event = DiagnosticEvent(
            kind: .lifecycle,
            severity: .info,
            message: "device event",
            metadata: ["client": .string("ios")]
        )

        let request = try DiagnosticsRemoteEventSink.makeRequest(
            for: event,
            configuration: configuration
        )

        #expect(request.url == endpoint)
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.value(forHTTPHeaderField: "X-Diagnostics-Source") == "ios-device")
        let body = try #require(request.httpBody)
        let decoded = try JSONDecoder.maohuobanDiagnostics.decode(DiagnosticEvent.self, from: body)
        #expect(decoded.message == "device event")
        #expect(decoded.metadata["client"] == "ios")
    }

    @Test("远端镜像批量请求会编码事件数组")
    func remoteMirrorConfigurationBuildsBatchIngestRequest() throws {
        let endpoint = try #require(URL(string: "http://127.0.0.1:8080/internal/diagnostics/ingest"))
        let configuration = DiagnosticsRemoteMirrorConfiguration(
            endpoint: endpoint,
            headers: ["X-Maohuoban-Diagnostics-Token": "local-token"],
            timeoutSeconds: 1
        )
        let events = [
            DiagnosticEvent(kind: .lifecycle, severity: .info, message: "first"),
            DiagnosticEvent(kind: .network, severity: .info, message: "second")
        ]

        let request = try DiagnosticsRemoteEventSink.makeBatchRequest(
            for: events,
            configuration: configuration
        )

        #expect(request.url == endpoint)
        #expect(request.timeoutInterval == 1)
        #expect(request.value(forHTTPHeaderField: "X-Maohuoban-Diagnostics-Token") == "local-token")
        let body = try #require(request.httpBody)
        let decoded = try JSONDecoder.maohuobanDiagnostics.decode([DiagnosticEvent].self, from: body)
        #expect(decoded.map(\.message) == ["first", "second"])
    }

    @Test("远端镜像批量请求会按字节上限拆包")
    func remoteMirrorSplitsBatchRequestsByByteLimit() throws {
        let endpoint = try #require(URL(string: "http://127.0.0.1:8080/internal/diagnostics/ingest"))
        let configuration = DiagnosticsRemoteMirrorConfiguration(
            endpoint: endpoint,
            headers: ["X-Maohuoban-Diagnostics-Token": "local-token"],
            timeoutSeconds: 1,
            maxBatchEvents: 10,
            maxBatchBytes: 1_200
        )
        let events = (0..<4).map { index in
            DiagnosticEvent(
                kind: .lifecycle,
                severity: .info,
                message: "event-\(index)",
                metadata: ["payload": .string(String(repeating: "x", count: 500))]
            )
        }

        let requests = try DiagnosticsRemoteEventSink.makeBatchRequests(
            for: events,
            configuration: configuration
        )

        #expect(requests.count > 1)
        for request in requests {
            let body = try #require(request.httpBody)
            #expect(body.count <= configuration.maxBatchBytes)
            let decoded = try JSONDecoder.maohuobanDiagnostics.decode([DiagnosticEvent].self, from: body)
            #expect(decoded.count < events.count)
        }
    }
}
