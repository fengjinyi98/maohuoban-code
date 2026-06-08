import Testing
@testable import MaohuobanDiagnostics

extension DiagnosticsPipelineTests {
    @Test("便捷 API 会记录面包屑、错误和性能 span")
    func recordsBreadcrumbErrorAndSpan() async throws {
        let root = try temporaryDirectory()
        let diagnostics = try await Diagnostics.install(
            .init(
                serviceName: "maohuoban",
                environment: "test",
                storageDirectory: root.appendingPathComponent("segments")
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

    @Test("全局上下文会自动注入后续事件")
    func globalContextAppliesToEventsWithoutTempMetadataPlumbing() async throws {
        let root = try temporaryDirectory()
        let diagnostics = try await Diagnostics.install(
            .init(
                serviceName: "maohuoban",
                environment: "test",
                storageDirectory: root.appendingPathComponent("segments")
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

    @Test("作用域 trace 会在操作结束后恢复原 trace")
    func scopedTraceRestoresPreviousTraceAfterOperation() async throws {
        let root = try temporaryDirectory()
        let diagnostics = try await Diagnostics.install(
            .init(
                serviceName: "maohuoban",
                environment: "test",
                storageDirectory: root.appendingPathComponent("segments")
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

    @Test("全局 facade 会转发便捷 API 到当前 runtime")
    func globalFacadeForwardsConvenienceCapture() async throws {
        let root = try temporaryDirectory()
        let diagnostics = try await Diagnostics.install(
            .init(
                serviceName: "maohuoban",
                environment: "test",
                storageDirectory: root.appendingPathComponent("segments")
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
}
