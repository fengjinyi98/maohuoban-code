import Testing
import Foundation
@testable import MaohuobanDiagnostics

@Suite("Diagnostics pipeline", .serialized)
struct DiagnosticsPipelineTests {
    @Test("远端镜像配置会生成标准 ingest 请求")
    func remoteMirrorConfigurationBuildsIngestRequest() throws {
        let endpoint = try #require(URL(string: "http://127.0.0.1:18081/ingest"))
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
}
