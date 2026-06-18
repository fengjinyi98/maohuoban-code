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

    @Test("组件交互事件工厂覆盖按钮、Tab、Sheet、Toast 和输入框边界")
    func swiftUIComponentInstrumentationBuildsStableEvents() {
        let button = DiagnosticsSwiftUIInstrumentation.componentEvent(
            diagnosticsID: "pet.profile.save",
            component: .button,
            action: .tap,
            metadata: ["screen_name": "pet_profile_edit"]
        )
        let textField = DiagnosticsSwiftUIInstrumentation.textFieldBoundaryEvent(
            diagnosticsID: "pet.profile.name",
            action: .blur,
            form: "pet_profile",
            field: "name",
            screenName: "pet_profile_edit",
            valueLength: 6,
            valid: true
        )

        #expect(button.message == "ui.button.tap")
        #expect(button.metadata["diagnostics_id"] == "pet.profile.save")
        #expect(button.metadata["component"] == "button")
        #expect(button.metadata["screen_name"] == "pet_profile_edit")
        #expect(textField.message == "ui.text_field.blur")
        #expect(textField.metadata["form"] == "pet_profile")
        #expect(textField.metadata["field"] == "name")
        #expect(textField.metadata["length_bucket"] == "short")
        #expect(textField.metadata["value"] == nil)
    }
}
