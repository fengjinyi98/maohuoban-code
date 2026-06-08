import Foundation
import Testing
@testable import MaohuobanDiagnostics

extension DiagnosticsPipelineTests {
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

    @Test("运行时快照会暴露存储写入失败计数")
    func runtimeSnapshotReportsDroppedEventsAfterStorageWriteFailure() async throws {
        let root = try temporaryDirectory()
        let storage = root.appending(path: "segments")
        let diagnostics = try await Diagnostics.install(
            .init(
                serviceName: "maohuoban",
                environment: "test",
                storageDirectory: storage
            )
        )

        try FileManager.default.removeItem(at: storage)
        try Data("blocked".utf8).write(to: storage)
        await diagnostics.log(.error, "cannot be stored")

        try FileManager.default.removeItem(at: storage)
        try FileManager.default.createDirectory(at: storage, withIntermediateDirectories: true)
        await diagnostics.captureRuntimeSnapshot(metadata: ["phase": "after-storage-error"])

        let events = try await diagnostics.readEvents()
        let event = try #require(events.first { $0.message == "runtime snapshot" })
        #expect(event.metadata["phase"] == "after-storage-error")
        #expect(event.metadata["dropped_event_count"] == "1")
        #expect(event.metadata["last_storage_error"]?.isEmpty == false)
    }
}
