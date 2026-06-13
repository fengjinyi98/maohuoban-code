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

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--reset-auth-state") {
            try? MHBKeychainTokenStore().clearTokens()
        }
        _isLaunchCompleted = State(initialValue: arguments.contains("--skip-launch-screen"))

        Task {
            do {
                let diagnostics = try await Diagnostics.bootstrap(
                    DiagnosticsBootstrapConfiguration(
                        serviceName: "maohuoban-ios",
                        environment: "local",
                        privacy: PrivacyPolicy(
                            redactedKeys: ["authorization", "password", "token"],
                            redactedQueryItems: ["token", "access_token", "refresh_token"],
                            redactedTextPatterns: [.email, .phoneNumber]
                        ),
                        capture: CapturePolicy(consent: .granted, minimumSeverity: .info),
                        defaults: [
                            "client": "ios",
                            "app": "maohuoban"
                        ]
                    )
                )
                await diagnostics.record(
                    DiagnosticEvent(kind: .lifecycle, severity: .info, message: "maohuoban app launched")
                )
            } catch {
                assertionFailure("Diagnostics bootstrap failed: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if isLaunchCompleted {
                    AuthRootView(viewModel: authViewModel)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                } else {
                    LaunchScreenView(isCompleted: $isLaunchCompleted)
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.45), value: isLaunchCompleted)
        }
    }
}
