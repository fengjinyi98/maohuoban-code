//
//  maohuobanApp.swift
//  maohuoban
//
//  Created by fengjinyi on 2026/6/8.
//

import SwiftUI
import MaohuobanDiagnostics

@main
struct maohuobanApp: App {
    init() {
        Task {
            let diagnostics = try await Diagnostics.install(
                DiagnosticsConfiguration(
                    serviceName: "maohuoban-ios",
                    environment: "local",
                    privacy: PrivacyPolicy(redactedKeys: ["authorization", "password", "token"])
                )
            )
            await diagnostics.record(
                DiagnosticEvent(kind: .lifecycle, severity: .info, message: "maohuoban app launched")
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
