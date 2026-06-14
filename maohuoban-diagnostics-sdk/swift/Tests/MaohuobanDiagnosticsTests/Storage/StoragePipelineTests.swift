import Foundation
import Testing
@testable import MaohuobanDiagnostics

extension DiagnosticsPipelineTests {
    @Test("安装后记录事件会脱敏并导出诊断包")
    func recordsRedactsAndExportsBundle() async throws {
        let root = try temporaryDirectory()
        let diagnostics = try await Diagnostics.install(
            .init(
                serviceName: "maohuoban",
                environment: "test",
                storageDirectory: root.appendingPathComponent("segments"),
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

        let bundle = try await diagnostics.exportDebugBundle(to: root.appendingPathComponent("bundle"))
        let timeline = try String(contentsOf: bundle.timelineURL, encoding: .utf8)

        #expect(timeline.contains("request completed"))
        #expect(timeline.contains("\"authorization\":\"<redacted>\""))
        #expect(timeline.contains("\"password\":\"<redacted>\""))
        #expect(!timeline.contains("Bearer token"))
        #expect(!timeline.contains("secret"))
    }

    @Test("采集策略会过滤低优先级事件并裁剪超长字段")
    func capturePolicyFiltersLowSeverityAndTruncatesOversizedFields() async throws {
        let root = try temporaryDirectory()
        let diagnostics = try await Diagnostics.install(
            .init(
                serviceName: "maohuoban",
                environment: "test",
                storageDirectory: root.appendingPathComponent("segments"),
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

    @Test("读取段文件会跳过损坏行并保留告警事件")
    func readEventsSkipsCorruptedSegmentLinesAndReportsWarning() async throws {
        let root = try temporaryDirectory()
        let storage = root.appendingPathComponent("segments")
        let diagnostics = try await Diagnostics.install(
            .init(
                serviceName: "maohuoban",
                environment: "test",
                storageDirectory: storage
            )
        )
        let validEvent = DiagnosticEvent(
            timestamp: Date(timeIntervalSince1970: 1),
            kind: .log,
            severity: .info,
            message: "valid after corrupt line"
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let validData = try encoder.encode(validEvent)
        let segment = storage.appendingPathComponent("corrupted.jsonl")
        try Data("not json\n".utf8).write(to: segment)
        let handle = try FileHandle(forWritingTo: segment)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: validData)
        try handle.write(contentsOf: Data("\n".utf8))

        let events = try await diagnostics.readEvents()
        let valid = try #require(events.first { $0.message == "valid after corrupt line" })
        let warning = try #require(events.first { $0.message == "storage segment decode failed" })

        #expect(valid.kind == .log)
        #expect(warning.kind == .error)
        #expect(warning.severity == .warn)
        #expect(warning.metadata["source"] == "file_segment_store")
        #expect(warning.metadata["line"] == "1")
        #expect(warning.metadata["segment"]?.hasSuffix("corrupted.jsonl") == true)
    }

    @Test("清理策略会删除过期段文件")
    func cleanupRemovesExpiredSegments() async throws {
        let root = try temporaryDirectory()
        let diagnostics = try await Diagnostics.install(
            .init(
                serviceName: "maohuoban",
                environment: "test",
                storageDirectory: root.appendingPathComponent("segments"),
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

    @Test("运行时可使用一次性策略清理全部段文件")
    func runtimeCleanupAcceptsOneShotPolicy() async throws {
        let root = try temporaryDirectory()
        let diagnostics = try await Diagnostics.install(
            .init(
                serviceName: "maohuoban",
                environment: "test",
                storageDirectory: root.appendingPathComponent("segments"),
                cleanup: .init(maxTotalBytes: 1_024 * 1_024, maxSegmentAge: 7 * 24 * 60 * 60, maxExportAge: 24 * 60 * 60)
            )
        )

        await diagnostics.error("device report to purge")
        try await diagnostics.flush()
        #expect(try await !diagnostics.readEvents().isEmpty)

        let report = try await diagnostics.cleanup(
            policy: .init(maxTotalBytes: 0, maxSegmentAge: 0, maxExportAge: 0)
        )

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
                storageDirectory: root.appendingPathComponent("segments"),
                cleanup: .init(maxTotalBytes: 1_024 * 1_024, maxSegmentAge: 7 * 24 * 60 * 60, maxExportAge: 0)
            )
        )

        await diagnostics.error("export cleanup input")
        let bundle = try await diagnostics.exportDebugBundle(to: root.appendingPathComponent("bundle"))
        #expect(FileManager.default.fileExists(atPath: bundle.directoryURL.path))

        let report = try await diagnostics.cleanup()
        #expect(report.removedExports == 1)
        #expect(!FileManager.default.fileExists(atPath: bundle.directoryURL.path))
    }

    @Test("清理策略会删除上次运行遗留的过期诊断包")
    func cleanupRemovesExpiredDebugBundlesAcrossRuntimeRestart() async throws {
        let root = try temporaryDirectory()
        let storage = root.appendingPathComponent("segments")
        let bundleURL = root.appendingPathComponent("bundle")
        let firstRuntime = try await Diagnostics.install(
            .init(
                serviceName: "maohuoban",
                environment: "test",
                storageDirectory: storage,
                cleanup: .init(maxTotalBytes: 1_024 * 1_024, maxSegmentAge: 7 * 24 * 60 * 60, maxExportAge: 0)
            )
        )

        await firstRuntime.error("previous export cleanup input")
        let bundle = try await firstRuntime.exportDebugBundle(to: bundleURL)
        #expect(FileManager.default.fileExists(atPath: bundle.directoryURL.path))

        let nextRuntime = try await Diagnostics.install(
            .init(
                serviceName: "maohuoban",
                environment: "test",
                storageDirectory: storage,
                cleanup: .init(maxTotalBytes: 1_024 * 1_024, maxSegmentAge: 7 * 24 * 60 * 60, maxExportAge: 0)
            )
        )
        let report = try await nextRuntime.cleanup()

        #expect(report.removedExports == 1)
        #expect(!FileManager.default.fileExists(atPath: bundle.directoryURL.path))
    }
}
