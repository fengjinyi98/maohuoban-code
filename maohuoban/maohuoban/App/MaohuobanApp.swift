//
//  MaohuobanApp.swift
//  maohuoban
//
//  Created by fengjinyi on 2026/6/8.
//

import SwiftUI
import MaohuobanDiagnostics

// MaohuobanApp 应用入口
// 核心职责：
// - 初始化诊断基础设施
// - 挂载 SwiftUI 根场景
@main
struct MaohuobanApp: App {
    @State private var isLaunchCompleted: Bool
    @State private var authViewModel = AuthViewModel()
    @State private var router = MHBAppRouter()

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--reset-auth-state") {
            try? MHBKeychainTokenStore().clearTokens()
        }
        _isLaunchCompleted = State(initialValue: arguments.contains("--skip-launch-screen"))
        let diagnosticsLaunchMode = MaohuobanDiagnosticsLaunchMode(arguments: arguments)

        Task {
            await Self.prepareDiagnostics(mode: diagnosticsLaunchMode)
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if isLaunchCompleted {
                    AuthRootView(viewModel: authViewModel, router: router)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                } else {
                    LaunchScreenView(isCompleted: $isLaunchCompleted)
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.45), value: isLaunchCompleted)
        }
    }

    // prepareDiagnostics 准备诊断运行时
    // 核心职责：
    // - 普通启动时初始化诊断采集
    // - 维护启动时清理 SDK 已生成报告
    private static func prepareDiagnostics(mode: MaohuobanDiagnosticsLaunchMode) async {
        do {
            switch mode {
            case .normal:
                try await bootstrapDiagnostics()
            case .purgeReports:
                try await purgeDiagnosticsReports()
            }
        } catch {
            assertionFailure("Diagnostics bootstrap failed: \(error)")
        }
    }

    // bootstrapDiagnostics 初始化诊断采集
    // 核心职责：
    // - 安装标准诊断运行时
    // - 记录 app 启动事件
    private static func bootstrapDiagnostics() async throws {
        let diagnostics = try await Diagnostics.bootstrap(
            DiagnosticsBootstrapConfiguration(
                serviceName: "maohuoban-ios",
                environment: "local",
                storageDirectory: MaohuobanDiagnosticsStorageDirectory.resolve(),
                privacy: diagnosticsPrivacyPolicy(),
                capture: CapturePolicy(consent: .granted, minimumSeverity: .info),
                defaults: diagnosticsDefaults()
            )
        )
        await diagnostics.record(
            DiagnosticEvent(kind: .lifecycle, severity: .info, message: "maohuoban app launched")
        )
    }

    // purgeDiagnosticsReports 清理诊断报告
    // 核心职责：
    // - 为真机沙盒报告提供启动参数清理入口
    // - 清理后卸载运行时避免本次维护启动继续写入报告
    private static func purgeDiagnosticsReports() async throws {
        let policy = CleanupPolicy(maxTotalBytes: 0, maxSegmentAge: 0, maxExportAge: 0)
        let diagnostics = try await Diagnostics.install(
            DiagnosticsConfiguration(
                serviceName: "maohuoban-ios",
                environment: "local",
                storageDirectory: MaohuobanDiagnosticsStorageDirectory.resolve(),
                privacy: diagnosticsPrivacyPolicy(),
                capture: CapturePolicy(consent: .granted, minimumSeverity: .info),
                cleanup: policy
            )
        )
        _ = try await diagnostics.cleanup(policy: policy)
        await Diagnostics.uninstall()
    }

    private static func diagnosticsPrivacyPolicy() -> PrivacyPolicy {
        PrivacyPolicy(
            redactedKeys: ["authorization", "password", "token"],
            redactedQueryItems: ["token", "access_token", "refresh_token"],
            redactedTextPatterns: [.email, .phoneNumber]
        )
    }

    private static func diagnosticsDefaults() -> DiagnosticProperties {
        [
            "client": "ios",
            "app": "maohuoban"
        ]
    }
}
