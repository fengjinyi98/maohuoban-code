import Foundation
import Testing
@testable import MaohuobanDiagnostics

@Suite("Diagnostics pipeline", .serialized)
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

    @Test("诊断包会写入可直接给 LLM 分析的 prompt 文件")
    func debugBundleIncludesLLMPromptFile() async throws {
        let root = try temporaryDirectory()
        let diagnostics = try await Diagnostics.install(
            .init(
                serviceName: "maohuoban",
                environment: "test",
                storageDirectory: root.appending(path: "segments")
            )
        )

        await diagnostics.error("checkout request failed")
        let bundle = try await diagnostics.exportDebugBundle(to: root.appending(path: "bundle"))
        let prompt = try String(contentsOf: bundle.promptURL, encoding: .utf8)

        #expect(prompt.contains("maohuoban.diagnostics.prompt.v1"))
        #expect(prompt.contains("checkout request failed"))
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

    @Test("清理策略会删除过期诊断包")
    func cleanupRemovesExpiredDebugBundles() async throws {
        let root = try temporaryDirectory()
        let diagnostics = try await Diagnostics.install(
            .init(
                serviceName: "maohuoban",
                environment: "test",
                storageDirectory: root.appending(path: "segments"),
                cleanup: .init(maxTotalBytes: 1_024 * 1_024, maxSegmentAge: 7 * 24 * 60 * 60, maxExportAge: 0)
            )
        )

        await diagnostics.error("export cleanup input")
        let bundle = try await diagnostics.exportDebugBundle(to: root.appending(path: "bundle"))
        #expect(FileManager.default.fileExists(atPath: bundle.directoryURL.path))

        let report = try await diagnostics.cleanup()
        #expect(report.removedExports == 1)
        #expect(!FileManager.default.fileExists(atPath: bundle.directoryURL.path))
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

    @Test("便捷 API 会记录面包屑、错误和性能 span")
    func recordsBreadcrumbErrorAndSpan() async throws {
        let root = try temporaryDirectory()
        let diagnostics = try await Diagnostics.install(
            .init(
                serviceName: "maohuoban",
                environment: "test",
                storageDirectory: root.appending(path: "segments")
            )
        )

        await diagnostics.breadcrumb("open detail", metadata: ["screen": "detail"])
        await diagnostics.error("load failed", metadata: ["reason": "timeout"])
        let span = diagnostics.beginSpan("load detail")
        await span.end(metadata: ["result": "failed"])

        let events = try await diagnostics.readEvents()
        #expect(events.contains { $0.kind == .breadcrumb && $0.message == "open detail" })
        #expect(events.contains { $0.kind == .error && $0.message == "load failed" })
        #expect(events.contains { $0.kind == .performance && $0.message == "load detail" })
    }

    @Test("网络摘要 API 会记录成功和失败请求")
    func recordsNetworkSummaryWithoutTempLogs() async throws {
        let root = try temporaryDirectory()
        let diagnostics = try await Diagnostics.install(
            .init(
                serviceName: "maohuoban",
                environment: "test",
                storageDirectory: root.appending(path: "segments")
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
    }

    @Test("全局 facade 会转发便捷 API 到当前 runtime")
    func globalFacadeForwardsConvenienceCapture() async throws {
        let root = try temporaryDirectory()
        let diagnostics = try await Diagnostics.install(
            .init(
                serviceName: "maohuoban",
                environment: "test",
                storageDirectory: root.appending(path: "segments")
            )
        )

        await Diagnostics.breadcrumb("global open", metadata: ["screen": "home"])
        await Diagnostics.error("global error", metadata: ["reason": "timeout"])
        let span = await Diagnostics.beginSpan("global load")
        await span?.end(metadata: ["result": "ok"])
        try await Diagnostics.flush()

        let events = try await diagnostics.readEvents()
        #expect(events.contains { $0.kind == .breadcrumb && $0.message == "global open" })
        #expect(events.contains { $0.kind == .error && $0.message == "global error" })
        #expect(events.contains { $0.kind == .performance && $0.message == "global load" })
    }

    @Test("LLM Prompt 导出会包含 schema 和时间线摘要")
    func exportsLLMPrompt() async throws {
        let root = try temporaryDirectory()
        let diagnostics = try await Diagnostics.install(
            .init(
                serviceName: "maohuoban",
                environment: "test",
                storageDirectory: root.appending(path: "segments")
            )
        )

        await diagnostics.error("request timeout")
        let prompt = try await diagnostics.exportLLMPrompt(title: "分析这个 bug")

        #expect(prompt.contains("maohuoban.diagnostics.prompt.v1"))
        #expect(prompt.contains("分析这个 bug"))
        #expect(prompt.contains("request timeout"))
    }
}

private func temporaryDirectory() throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "maohuoban-diagnostics-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}
