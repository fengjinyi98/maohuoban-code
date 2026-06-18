import XCTest
@testable import maohuoban

// MaohuobanDiagnosticsLaunchModeTests 诊断启动模式测试
// 核心职责：
// - 固化诊断清理启动参数契约
// - 避免真机报告清理入口被普通启动路径误触发
final class MaohuobanDiagnosticsLaunchModeTests: XCTestCase {
    @MainActor
    func testPurgeArgumentEnablesDiagnosticsPurgeMode() {
        let mode = MaohuobanDiagnosticsLaunchMode(arguments: [
            "maohuoban",
            "--maohuoban-diagnostics-purge"
        ])

        XCTAssertEqual(mode, .purgeReports)
    }

    @MainActor
    func testPurgeEnvironmentEnablesDiagnosticsPurgeMode() {
        let mode = MaohuobanDiagnosticsLaunchMode(
            arguments: ["maohuoban"],
            environment: ["MAOHUOBAN_DIAGNOSTICS_PURGE": "1"]
        )

        XCTAssertEqual(mode, .purgeReports)
    }

    @MainActor
    func testDefaultArgumentsUseNormalMode() {
        let mode = MaohuobanDiagnosticsLaunchMode(arguments: ["maohuoban"])

        XCTAssertEqual(mode, .normal)
    }

    @MainActor
    func testDiagnosticsSegmentsEnvironmentOverridesStorageDirectory() {
        let url = MaohuobanDiagnosticsStorageDirectory.resolve(
            environment: [
                MaohuobanDiagnosticsStorageDirectory.segmentsEnvironmentKey: "/tmp/maohuoban-segments"
            ],
            sourceFilePath: "/tmp/repo/maohuoban/maohuoban/App/MaohuobanApp.swift"
        )

        XCTAssertEqual(url.path, "/tmp/maohuoban-segments")
    }

    @MainActor
    func testWorkspaceStorageDirectoryUsesRepositoryDiagnosticsSegments() {
        let url = MaohuobanDiagnosticsStorageDirectory.workspaceSegmentsDirectory(
            sourceFilePath: "/tmp/repo/maohuoban/maohuoban/App/MaohuobanApp.swift"
        )

        XCTAssertEqual(url.path, "/tmp/repo/.maohuoban-diagnostics/segments")
    }

    @MainActor
    func testRemoteMirrorDefaultUsesBackendDiagnosticsIngestForDevice() {
        let configuration = MaohuobanDiagnosticsRemoteMirror.resolve(
            environment: [:],
            isSimulator: false
        )

        XCTAssertEqual(configuration?.endpoint.path, "/internal/diagnostics/ingest")
        XCTAssertEqual(
            configuration?.headers["X-Maohuoban-Diagnostics-Token"],
            "maohuoban-local-diagnostics"
        )
        XCTAssertEqual(
            configuration?.headers["X-Maohuoban-Diagnostics-Source"],
            "ios-device-debug"
        )
    }
}
