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

    @Test("采集策略会过滤低优先级事件并裁剪超长字段")
    func capturePolicyFiltersLowSeverityAndTruncatesOversizedFields() async throws {
        let root = try temporaryDirectory()
        let diagnostics = try await Diagnostics.install(
            .init(
                serviceName: "maohuoban",
                environment: "test",
                storageDirectory: root.appending(path: "segments"),
                capture: .init(
                    minimumSeverity: .warn,
                    maxMessageLength: 8,
                    maxMetadataValueLength: 6
                )
            )
        )

        await diagnostics.log(.info, "filtered")
        await diagnostics.record(
            DiagnosticEvent(kind: .error, severity: .error, message: "checkout request timeout")
                .metadata("detail", "database unavailable")
        )
        try await diagnostics.flush()

        let events = try await diagnostics.readEvents()
        #expect(events.count == 1)
        let event = try #require(events.first)
        #expect(event.message == "checkout...")
        #expect(event.metadata["detail"] == "databa...")
        #expect(event.metadata["service"] == "maohuo...")
        #expect(event.metadata["environment"] == "test")
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

    @Test("全局上下文会自动注入后续事件")
    func globalContextAppliesToEventsWithoutTempMetadataPlumbing() async throws {
        let root = try temporaryDirectory()
        let diagnostics = try await Diagnostics.install(
            .init(
                serviceName: "maohuoban",
                environment: "test",
                storageDirectory: root.appending(path: "segments")
            )
        )

        await diagnostics.setSessionID("session-a")
        await Diagnostics.setTraceID("trace-a")
        await Diagnostics.setContextMetadata("screen", "home")
        await diagnostics.log(.info, "context log")
        await diagnostics.network(.init(method: "GET", url: "https://api.example.com/feed"))
        await diagnostics.record(
            DiagnosticEvent(kind: .breadcrumb, severity: .info, message: "explicit context")
                .traceID("trace-event")
                .metadata("screen", "detail")
        )
        let span = diagnostics.beginSpan("context span")
        await span.end()

        var events = try await diagnostics.readEvents()
        let log = try #require(events.first { $0.message == "context log" })
        #expect(log.sessionID == "session-a")
        #expect(log.traceID == "trace-a")
        #expect(log.metadata["screen"] == "home")

        let network = try #require(events.first { $0.kind == .network })
        #expect(network.sessionID == "session-a")
        #expect(network.traceID == "trace-a")

        let explicit = try #require(events.first { $0.message == "explicit context" })
        #expect(explicit.sessionID == "session-a")
        #expect(explicit.traceID == "trace-event")
        #expect(explicit.metadata["screen"] == "detail")

        await diagnostics.clearTraceID()
        await diagnostics.log(.info, "trace cleared")

        events = try await diagnostics.readEvents()
        let cleared = try #require(events.first { $0.message == "trace cleared" })
        #expect(cleared.sessionID == "session-a")
        #expect(cleared.traceID == nil)
    }

    @Test("结构化错误 API 会记录 NSError domain、code 和 underlying chain")
    func capturesNSErrorChainAsStructuredMetadata() async throws {
        let root = try temporaryDirectory()
        let diagnostics = try await Diagnostics.install(
            .init(
                serviceName: "maohuoban",
                environment: "test",
                storageDirectory: root.appending(path: "segments")
            )
        )

        let underlying = NSError(
            domain: "Database",
            code: 100,
            userInfo: [NSLocalizedDescriptionKey: "database unavailable"]
        )
        let error = NSError(
            domain: "Checkout",
            code: 42,
            userInfo: [
                NSLocalizedDescriptionKey: "checkout failed",
                NSUnderlyingErrorKey: underlying
            ]
        )

        await Diagnostics.captureError(error, metadata: ["feature": "checkout"])

        let events = try await diagnostics.readEvents()
        let event = try #require(events.first { $0.kind == .error && $0.message == "checkout failed" })
        #expect(event.severity == .error)
        #expect(event.metadata["feature"] == "checkout")
        #expect(event.metadata["error_domain"] == "Checkout")
        #expect(event.metadata["error_code"] == "42")
        #expect(event.metadata["error_description"] == "checkout failed")
        #expect(event.metadata["underlying_errors"]?.contains("Database:100") == true)
        #expect(event.metadata["underlying_errors"]?.contains("database unavailable") == true)
    }

    @Test("运行时快照 API 会记录基础进程和系统信息")
    func capturesRuntimeSnapshotAsPerformanceEvent() async throws {
        let root = try temporaryDirectory()
        let diagnostics = try await Diagnostics.install(
            .init(
                serviceName: "maohuoban",
                environment: "test",
                storageDirectory: root.appending(path: "segments")
            )
        )

        await Diagnostics.captureRuntimeSnapshot(metadata: ["phase": "startup"])

        let events = try await diagnostics.readEvents()
        let event = try #require(events.first { $0.kind == .performance && $0.message == "runtime snapshot" })
        #expect(event.metadata["phase"] == "startup")
        #expect(event.metadata["process_id"] == "\(ProcessInfo.processInfo.processIdentifier)")
        #expect(event.metadata["process_name"] == ProcessInfo.processInfo.processName)
        #expect(event.metadata["os"]?.isEmpty == false)
        #expect(event.metadata["arch"]?.isEmpty == false)
        #expect(Int(event.metadata["uptime_ms"] ?? "") != nil)
    }

    @Test("作用域 trace 会在操作结束后恢复原 trace")
    func scopedTraceRestoresPreviousTraceAfterOperation() async throws {
        let root = try temporaryDirectory()
        let diagnostics = try await Diagnostics.install(
            .init(
                serviceName: "maohuoban",
                environment: "test",
                storageDirectory: root.appending(path: "segments")
            )
        )

        await diagnostics.setTraceID("outer")
        await #expect(throws: ScopedTraceTestError.self) {
            try await Diagnostics.withTraceID("inner") {
                await Diagnostics.log(.info, "inside trace")
                throw ScopedTraceTestError()
            }
        }
        await diagnostics.log(.info, "after trace")

        let events = try await diagnostics.readEvents()
        let inside = try #require(events.first { $0.message == "inside trace" })
        let after = try #require(events.first { $0.message == "after trace" })
        #expect(inside.traceID == "inner")
        #expect(after.traceID == "outer")
    }

    @Test("启动助手会一次安装并记录启动上下文")
    func bootstrapInstallsGlobalRuntimeAndCapturesStartupContext() async throws {
        let root = try temporaryDirectory()
        let diagnostics = try await Diagnostics.bootstrap(
            .init(
                serviceName: "maohuoban",
                environment: "test",
                storageDirectory: root.appending(path: "segments"),
                defaults: [
                    "app_version": "1.2.3",
                    "device_id": "simulator-a"
                ],
                sessionID: "session-bootstrap",
                traceID: "launch-trace",
                captureRuntimeSnapshot: true
            )
        )

        await Diagnostics.log(.info, "after bootstrap")
        try await diagnostics.flush()

        let current = await Diagnostics.current()
        #expect(current === diagnostics)

        let events = try await diagnostics.readEvents()
        let launchEvent = events.first { event in
            event.kind == .lifecycle && event.message == "diagnostics bootstrap completed"
        }
        let launch = try #require(launchEvent)
        #expect(launch.sessionID == "session-bootstrap")
        #expect(launch.traceID == "launch-trace")
        #expect(launch.metadata["app_version"] == "1.2.3")
        #expect(launch.metadata["device_id"] == "simulator-a")

        let runtimeEvent = events.first { event in
            event.kind == .performance && event.message == "runtime snapshot"
        }
        let runtime = try #require(runtimeEvent)
        #expect(runtime.metadata["phase"] == "bootstrap")
        #expect(runtime.metadata["app_version"] == "1.2.3")

        let afterEvent = events.first { event in
            event.message == "after bootstrap"
        }
        let after = try #require(afterEvent)
        #expect(after.sessionID == "session-bootstrap")
        #expect(after.metadata["device_id"] == "simulator-a")
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

private struct ScopedTraceTestError: Error {}
