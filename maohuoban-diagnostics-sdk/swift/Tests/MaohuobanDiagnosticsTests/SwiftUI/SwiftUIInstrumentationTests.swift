import SwiftUI
import Testing
@testable import MaohuobanDiagnostics

extension DiagnosticsPipelineTests {
    @Test("SwiftUI 便捷埋点 API 会构造稳定页面事件")
    func swiftUIScreenInstrumentationBuildsStableEvents() {
        let appeared = DiagnosticsSwiftUIInstrumentation.screenEvent(
            name: "home",
            lifecycle: .appear,
            metadata: ["tab": "main"]
        )
        let disappeared = DiagnosticsSwiftUIInstrumentation.screenEvent(
            name: "home",
            lifecycle: .disappear,
            metadata: [:]
        )

        #expect(appeared.kind == .breadcrumb)
        #expect(appeared.message == "screen appeared")
        #expect(appeared.metadata["screen"] == "home")
        #expect(appeared.metadata["screen_lifecycle"] == "appear")
        #expect(appeared.metadata["tab"] == "main")
        #expect(disappeared.message == "screen disappeared")
        #expect(disappeared.metadata["screen_lifecycle"] == "disappear")
    }

    @Test("SwiftUI View 可以一行添加页面和点击埋点")
    @MainActor
    func swiftUIViewCanAttachDiagnosticsModifiers() {
        let view = Text("Home")
            .diagnosticsScreen("home", metadata: ["tab": "main"])
            .diagnosticsTap("home.refresh", metadata: ["source": "toolbar"])

        _ = view
    }
}
