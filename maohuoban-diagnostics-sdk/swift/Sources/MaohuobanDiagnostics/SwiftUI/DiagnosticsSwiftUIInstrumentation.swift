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

// DiagnosticsSwiftUIInstrumentation SwiftUI 埋点事件工厂
// 核心职责：
// - 构造页面和点击埋点事件
// - 让 View modifier 与测试复用同一事件协议
public enum DiagnosticsSwiftUIInstrumentation {
    public static func screenEvent(
        name: String,
        lifecycle: DiagnosticsSwiftUIScreenLifecycle,
        metadata: [String: String]
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
        metadata: [String: String]
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
}

// DiagnosticsScreenModifier SwiftUI 页面埋点修饰器
// 核心职责：
// - 在页面出现和离开事件边界记录诊断事件
// - 避免在 SwiftUI 同步渲染路径执行写入副作用
public struct DiagnosticsScreenModifier: ViewModifier {
    private let name: String
    private let metadata: [String: String]
    private let trackDisappear: Bool

    public init(name: String, metadata: [String: String], trackDisappear: Bool) {
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
    private let metadata: [String: String]

    public init(name: String, metadata: [String: String]) {
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
        metadata: [String: String] = [:],
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
        metadata: [String: String] = [:]
    ) -> some View {
        modifier(DiagnosticsTapModifier(name: name, metadata: metadata))
    }
}
#endif
