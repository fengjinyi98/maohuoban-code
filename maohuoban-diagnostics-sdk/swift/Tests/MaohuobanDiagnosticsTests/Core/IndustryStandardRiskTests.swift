import Foundation
import Testing
@testable import MaohuobanDiagnostics

extension DiagnosticsPipelineTests {
    @Test("作用域 trace 不会泄漏给并发事件")
    func scopedTraceDoesNotLeakToConcurrentEvents() async throws {
        let root = try temporaryDirectory()
        let diagnostics = try await Diagnostics.install(
            .init(
                serviceName: "maohuoban",
                environment: "test",
                storageDirectory: root.appendingPathComponent("segments")
            )
        )
        let gate = AsyncTestGate()

        await diagnostics.setTraceID("outer")
        let scopedTask = Task {
            try await diagnostics.withTraceID("inner") {
                await diagnostics.log(.info, "inside scoped trace")
                await gate.wait()
                await diagnostics.log(.info, "inside scoped trace after wait")
            }
        }
        try await gate.waitUntilWaiting()

        await diagnostics.log(.info, "parallel event")
        await gate.open()
        try await scopedTask.value

        let events = try await diagnostics.readEvents()
        let parallel = try #require(events.first { $0.message == "parallel event" })
        let inside = try #require(events.first { $0.message == "inside scoped trace" })
        let insideAfterWait = try #require(events.first { $0.message == "inside scoped trace after wait" })

        #expect(parallel.traceID == "outer")
        #expect(inside.traceID == "inner")
        #expect(insideAfterWait.traceID == "inner")
    }

    @Test("默认安装保持网络采集低侵入")
    func installDoesNotRegisterGlobalNetworkCaptureByDefault() async throws {
        let root = try temporaryDirectory()
        let diagnostics = try await Diagnostics.install(
            .init(
                serviceName: "maohuoban",
                environment: "test",
                storageDirectory: root.appendingPathComponent("segments")
            )
        )

        #expect(diagnostics.configuration.networkCapture == .manual)
    }

    @Test("采集同意、启用开关和采样会控制事件写入")
    func captureConsentEnabledAndSamplingControlEventWrites() async throws {
        let root = try temporaryDirectory()
        let disabled = try await Diagnostics.install(
            .init(
                serviceName: "maohuoban",
                environment: "test",
                storageDirectory: root.appendingPathComponent("disabled"),
                capture: .init(enabled: false)
            )
        )
        await disabled.error("disabled event")
        #expect(try await disabled.readEvents().isEmpty)

        let pendingConsent = try await Diagnostics.install(
            .init(
                serviceName: "maohuoban",
                environment: "test",
                storageDirectory: root.appendingPathComponent("pending"),
                capture: .init(consent: .pending)
            )
        )
        await pendingConsent.error("pending event")
        #expect(try await pendingConsent.readEvents().isEmpty)

        let sampledOut = try await Diagnostics.install(
            .init(
                serviceName: "maohuoban",
                environment: "test",
                storageDirectory: root.appendingPathComponent("sampled-out"),
                capture: .init(sampleRate: 0)
            )
        )
        await sampledOut.error("sampled out event")
        #expect(try await sampledOut.readEvents().isEmpty)
    }

    @Test("运行时可以更新采集同意状态")
    func runtimeCanUpdateTrackingConsent() async throws {
        let root = try temporaryDirectory()
        let diagnostics = try await Diagnostics.install(
            .init(
                serviceName: "maohuoban",
                environment: "test",
                storageDirectory: root.appendingPathComponent("segments"),
                capture: .init(consent: .pending)
            )
        )

        await diagnostics.error("before consent")
        await diagnostics.setTrackingConsent(.granted)
        await diagnostics.error("after consent")

        let events = try await diagnostics.readEvents()
        #expect(!events.contains { $0.message == "before consent" })
        #expect(events.contains { $0.message == "after consent" })
    }

    @Test("隐私策略会脱敏 message、URL 和 error 文本")
    func privacyPolicyRedactsTextUrlAndErrorFields() async throws {
        let root = try temporaryDirectory()
        let diagnostics = try await Diagnostics.install(
            .init(
                serviceName: "maohuoban",
                environment: "test",
                storageDirectory: root.appendingPathComponent("segments"),
                privacy: .init(
                    redactedKeys: ["authorization"],
                    redactedQueryItems: ["token"],
                    redactedTextPatterns: [
                        .email,
                        .phoneNumber
                    ]
                )
            )
        )

        await diagnostics.log(.info, "contact 13800138000 at user@example.com")
        await diagnostics.network(
            .init(
                method: "GET",
                url: "https://api.example.com/profile?token=secret&safe=1",
                error: "failed for user@example.com"
            )
        )

        let events = try await diagnostics.readEvents()
        let log = try #require(events.first { $0.kind == .log })
        let network = try #require(events.first { $0.kind == .network })

        #expect(log.message == "contact <redacted:phone> at <redacted:email>")
        #expect(network.metadata["url"] == "https://api.example.com/profile?token=<redacted>&safe=1")
        #expect(network.metadata["error"] == "failed for <redacted:email>")
    }

    @Test("Swift Package 包含 Apple SDK 隐私清单")
    func packageContainsPrivacyManifestResource() throws {
        let packageRoot = try packageRootURL(from: URL(fileURLWithPath: #filePath))
        let manifest = try String(
            contentsOf: packageRoot.appendingPathComponent("Package.swift"),
            encoding: .utf8
        )
        let privacyManifestURL = packageRoot
            .appendingPathComponent("Sources/MaohuobanDiagnostics/Resources/PrivacyInfo.xcprivacy")

        #expect(manifest.contains(".process(\"Resources\")"))
        #expect(FileManager.default.fileExists(atPath: privacyManifestURL.path))
    }
}

private func packageRootURL(from fileURL: URL) throws -> URL {
    var current = fileURL.deletingLastPathComponent()
    while current.path != "/" {
        if FileManager.default.fileExists(atPath: current.appendingPathComponent("Package.swift").path) {
            return current
        }
        current.deleteLastPathComponent()
    }
    throw CocoaError(.fileNoSuchFile)
}

// AsyncTestGate 异步测试闸门
// 核心职责：
// - 让测试稳定制造一个挂起的异步作用域
// - 验证作用域上下文不会影响并发事件
private actor AsyncTestGate {
    private var waitContinuation: CheckedContinuation<Void, Never>?
    private var waiterReadyContinuation: CheckedContinuation<Void, Never>?
    private var isWaiting = false

    func wait() async {
        isWaiting = true
        waiterReadyContinuation?.resume()
        waiterReadyContinuation = nil
        await withCheckedContinuation { continuation in
            waitContinuation = continuation
        }
    }

    func waitUntilWaiting() async throws {
        if isWaiting {
            return
        }
        await withCheckedContinuation { continuation in
            waiterReadyContinuation = continuation
        }
    }

    func open() {
        waitContinuation?.resume()
        waitContinuation = nil
    }
}
