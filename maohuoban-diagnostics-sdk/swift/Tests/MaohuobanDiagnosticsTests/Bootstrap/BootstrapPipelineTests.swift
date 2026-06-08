import Foundation
import Testing
@testable import MaohuobanDiagnostics

extension DiagnosticsPipelineTests {
    @Test("启动助手会一次安装并记录启动上下文")
    func bootstrapInstallsGlobalRuntimeAndCapturesStartupContext() async throws {
        let root = try temporaryDirectory()
        let diagnostics = try await Diagnostics.bootstrap(
            .init(
                serviceName: "maohuoban",
                environment: "test",
                storageDirectory: root.appendingPathComponent("segments"),
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

    @Test("启动助手会在记录启动事件前执行清理策略")
    func bootstrapRunsCleanupBeforeRecordingStartupEvents() async throws {
        let root = try temporaryDirectory()
        let storage = root.appendingPathComponent("segments")
        try FileManager.default.createDirectory(at: storage, withIntermediateDirectories: true)
        let staleEvent = DiagnosticEvent(kind: .log, severity: .info, message: "stale before bootstrap")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var staleData = try encoder.encode(staleEvent)
        staleData.append(0x0A)
        try staleData.write(to: storage.appendingPathComponent("stale.jsonl"))

        let diagnostics = try await Diagnostics.bootstrap(
            .init(
                serviceName: "maohuoban",
                environment: "test",
                storageDirectory: storage,
                cleanup: .init(maxTotalBytes: 1_024 * 1_024, maxSegmentAge: 0, maxExportAge: 0),
                captureRuntimeSnapshot: false,
                cleanupOnBootstrap: true
            )
        )
        try await diagnostics.flush()

        let events = try await diagnostics.readEvents()
        #expect(!events.contains { $0.message == "stale before bootstrap" })
        #expect(events.contains { event in
            event.kind == .lifecycle && event.message == "diagnostics bootstrap completed"
        })
    }
}
