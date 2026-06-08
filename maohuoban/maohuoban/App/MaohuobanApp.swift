//
//  MaohuobanApp.swift
//  maohuoban
//
//  Created by fengjinyi on 2026/6/8.
//

import SwiftUI
import MaohuobanDiagnostics

@main
struct MaohuobanApp: App {
    init() {
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
            ContentView()
        }
    }
}
