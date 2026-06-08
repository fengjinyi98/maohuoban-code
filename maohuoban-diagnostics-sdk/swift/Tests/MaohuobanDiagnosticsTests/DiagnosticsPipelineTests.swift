import Foundation
import Testing
@testable import MaohuobanDiagnostics

@Suite("Diagnostics pipeline")
struct DiagnosticsPipelineTests {
    @Test("安装后记录事件会脱敏并导出诊断包")
    func recordsRedactsAndExportsBundle() async throws {
        let root = try temporaryDirectory()
        let diagnostics = try await Diagnostics.install(
            .init(
                serviceName: "maohuoban",
                environment: "test",
                storageDirectory: root.appending(path: "segments"),
                privacy: .init(redactedKeys: ["authorization", "password"]),
                cleanup: .init()
            )
        )

        await diagnostics.record(
            .network("request completed")
                .metadata("url", "https://example.com/login")
                .metadata("authorization", "Bearer token")
                .metadata("password", "secret")
        )
        try await diagnostics.flush()

        let bundle = try await diagnostics.exportDebugBundle(to: root.appending(path: "bundle"))
        let timeline = try String(contentsOf: bundle.timelineURL, encoding: .utf8)

        #expect(timeline.contains("request completed"))
        #expect(timeline.contains("\"authorization\":\"<redacted>\""))
        #expect(timeline.contains("\"password\":\"<redacted>\""))
        #expect(!timeline.contains("Bearer token"))
        #expect(!timeline.contains("secret"))
    }

    @Test("清理策略会删除过期段文件")
    func cleanupRemovesExpiredSegments() async throws {
        let root = try temporaryDirectory()
        let diagnostics = try await Diagnostics.install(
            .init(
                serviceName: "maohuoban",
                environment: "test",
                storageDirectory: root.appending(path: "segments"),
                privacy: .init(),
                cleanup: .init(maxTotalBytes: 1_024 * 1_024, maxSegmentAge: 0, maxExportAge: 0)
            )
        )

        await diagnostics.log(.info, "will be cleaned")
        try await diagnostics.flush()

        let report = try await diagnostics.cleanup()
        #expect(report.removedSegments >= 1)
        #expect(try await diagnostics.readEvents().isEmpty)
    }

    @Test("全局入口能生成已注入网络采集的 URLSessionConfiguration")
    func installsNetworkCaptureConfiguration() async throws {
        let root = try temporaryDirectory()
        let diagnostics = try await Diagnostics.install(
            .init(
                serviceName: "maohuoban",
                environment: "test",
                storageDirectory: root.appending(path: "segments")
            )
        )

        let configuration = diagnostics.instrumentedURLSessionConfiguration(.ephemeral)
        #expect(configuration.protocolClasses?.first == DiagnosticsURLProtocol.self)
    }
}

private func temporaryDirectory() throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "maohuoban-diagnostics-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}
