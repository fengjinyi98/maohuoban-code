import Foundation

#if canImport(SwiftUI)
import SwiftUI

// DiagnosticsSwiftUIScreenLifecycle SwiftUI 页面生命周期
// 核心职责：
// - 表达页面曝光与离开两类埋点事件
// - 为 SwiftUI modifier 构造稳定 metadata
public enum DiagnosticsSwiftUIScreenLifecycle: String, Sendable {
    case appear
    case disappear
}

// DiagnosticsSwiftUIComponent 通用 SwiftUI 组件类型
// 核心职责：
// - 统一 DesignSystem 和业务组件的交互分类
// - 为点击、切换、展示和输入边界事件提供稳定枚举
public enum DiagnosticsSwiftUIComponent: String, Sendable {
    case button
    case tab
    case sheet
    case toast
    case textField = "text_field"
    case picker
    case menu
}

// DiagnosticsSwiftUIComponentAction 通用 SwiftUI 组件动作
// 核心职责：
// - 描述组件交互阶段
// - 避免业务层散写事件后缀
public enum DiagnosticsSwiftUIComponentAction: String, Sendable {
    case tap
    case disabledTap = "disabled_tap"
    case switchTab = "switch"
    case presented
    case dismissed
    case shown
    case actionTapped = "action_tapped"
    case focus
    case blur
    case validationFailed = "validation_failed"
    case selected
}

// DiagnosticsSwiftUIInstrumentation SwiftUI 埋点事件工厂
// 核心职责：
// - 构造页面和点击埋点事件
// - 让 View modifier 与测试复用同一事件协议
public enum DiagnosticsSwiftUIInstrumentation {
    public static func screenEvent(
        name: String,
        lifecycle: DiagnosticsSwiftUIScreenLifecycle,
        metadata: DiagnosticProperties
    ) -> DiagnosticEvent {
        var event = DiagnosticEvent(
            kind: .breadcrumb,
            severity: .info,
            message: lifecycle == .appear ? "screen appeared" : "screen disappeared"
        )
        .metadata("screen", name)
        .metadata("screen_lifecycle", lifecycle.rawValue)
        for (key, value) in metadata {
            event = event.metadata(key, value)
        }
        return event
    }

    public static func tapEvent(
        name: String,
        metadata: DiagnosticProperties
    ) -> DiagnosticEvent {
        var event = DiagnosticEvent(
            kind: .breadcrumb,
            severity: .info,
            message: "ui tapped"
        )
        .metadata("action", name)
        .metadata("interaction", "tap")
        for (key, value) in metadata {
            event = event.metadata(key, value)
        }
        return event
    }

    public static func componentEvent(
        diagnosticsID: String,
        component: DiagnosticsSwiftUIComponent,
        action: DiagnosticsSwiftUIComponentAction,
        metadata: DiagnosticProperties = [:]
    ) -> DiagnosticEvent {
        var event = DiagnosticEvent(
            kind: .breadcrumb,
            severity: .info,
            message: "ui.\(component.rawValue).\(action.rawValue)"
        )
        .metadata("diagnostics_id", diagnosticsID)
        .metadata("component", component.rawValue)
        .metadata("interaction", action.rawValue)
        for (key, value) in metadata {
            event = event.metadata(key, value)
        }
        return event
    }

    public static func textFieldBoundaryEvent(
        diagnosticsID: String,
        action: DiagnosticsSwiftUIComponentAction,
        form: String,
        field: String,
        screenName: String,
        valueLength: Int,
        valid: Bool? = nil,
        metadata: DiagnosticProperties = [:]
    ) -> DiagnosticEvent {
        var properties = metadata
        properties["form"] = .string(form)
        properties["field"] = .string(field)
        properties["screen_name"] = .string(screenName)
        properties["empty"] = .bool(valueLength == 0)
        properties["length_bucket"] = .string(componentLengthBucket(for: valueLength))
        if let valid {
            properties["valid"] = .bool(valid)
        }
        return componentEvent(
            diagnosticsID: diagnosticsID,
            component: .textField,
            action: action,
            metadata: properties
        )
    }
}

// DiagnosticsScreenModifier SwiftUI 页面埋点修饰器
// 核心职责：
// - 在页面出现和离开事件边界记录诊断事件
// - 避免在 SwiftUI 同步渲染路径执行写入副作用
public struct DiagnosticsScreenModifier: ViewModifier {
    private let name: String
    private let metadata: DiagnosticProperties
    private let trackDisappear: Bool

    public init(name: String, metadata: DiagnosticProperties, trackDisappear: Bool) {
        self.name = name
        self.metadata = metadata
        self.trackDisappear = trackDisappear
    }

    public func body(content: Content) -> some View {
        content
            .onAppear {
                let event = DiagnosticsSwiftUIInstrumentation.screenEvent(
                    name: name,
                    lifecycle: .appear,
                    metadata: metadata
                )
                Task {
                    await Diagnostics.record(event)
                }
            }
            .onDisappear {
                guard trackDisappear else {
                    return
                }
                let event = DiagnosticsSwiftUIInstrumentation.screenEvent(
                    name: name,
                    lifecycle: .disappear,
                    metadata: metadata
                )
                Task {
                    await Diagnostics.record(event)
                }
            }
    }
}

// DiagnosticsTapModifier SwiftUI 点击埋点修饰器
// 核心职责：
// - 在用户点击事件边界记录诊断事件
// - 为现有 View 提供低侵入交互埋点入口
public struct DiagnosticsTapModifier: ViewModifier {
    private let name: String
    private let metadata: DiagnosticProperties

    public init(name: String, metadata: DiagnosticProperties) {
        self.name = name
        self.metadata = metadata
    }

    public func body(content: Content) -> some View {
        content.simultaneousGesture(
            TapGesture().onEnded {
                let event = DiagnosticsSwiftUIInstrumentation.tapEvent(
                    name: name,
                    metadata: metadata
                )
                Task {
                    await Diagnostics.record(event)
                }
            }
        )
    }
}

public extension View {
    func diagnosticsScreen(
        _ name: String,
        metadata: DiagnosticProperties = [:],
        trackDisappear: Bool = false
    ) -> some View {
        modifier(
            DiagnosticsScreenModifier(
                name: name,
                metadata: metadata,
                trackDisappear: trackDisappear
            )
        )
    }

    func diagnosticsTap(
        _ name: String,
        metadata: DiagnosticProperties = [:]
    ) -> some View {
        modifier(DiagnosticsTapModifier(name: name, metadata: metadata))
    }

    func diagnosticsComponent(
        _ diagnosticsID: String,
        component: DiagnosticsSwiftUIComponent,
        action: DiagnosticsSwiftUIComponentAction,
        metadata: DiagnosticProperties = [:]
    ) -> some View {
        simultaneousGesture(
            TapGesture().onEnded {
                let event = DiagnosticsSwiftUIInstrumentation.componentEvent(
                    diagnosticsID: diagnosticsID,
                    component: component,
                    action: action,
                    metadata: metadata
                )
                Task {
                    await Diagnostics.record(event)
                }
            }
        )
    }
}

private func componentLengthBucket(for valueLength: Int) -> String {
    switch valueLength {
    case 0:
        "empty"
    case 1...8:
        "short"
    case 9...32:
        "medium"
    case 33...128:
        "long"
    default:
        "very_long"
    }
}
#endif
