import Foundation

// DiagnosticSeverity 诊断事件严重级别
// 核心职责：
// - 描述事件对调试分析的重要程度
// - 为导出包筛选、排序和摘要提供稳定枚举
public enum DiagnosticSeverity: String, Codable, Sendable {
    case trace
    case debug
    case info
    case warn
    case error
    case fatal
}

// DiagnosticEventKind 诊断事件类型
// 核心职责：
// - 统一日志、网络、性能、错误、面包屑和生命周期事件分类
// - 作为 Swift 与 Rust 共享协议的顶层分类字段
public enum DiagnosticEventKind: String, Codable, Sendable {
    case log
    case network
    case performance
    case error
    case breadcrumb
    case lifecycle
}

// DiagnosticEvent 标准诊断事件
// 核心职责：
// - 承载跨语言统一事件协议
// - 保存可脱敏 metadata 与可串联的 trace/session 标识
public struct DiagnosticEvent: Codable, Sendable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let kind: DiagnosticEventKind
    public let severity: DiagnosticSeverity
    public let message: String
    public let traceID: String?
    public let sessionID: String?
    public let metadata: [String: String]

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        kind: DiagnosticEventKind,
        severity: DiagnosticSeverity,
        message: String,
        traceID: String? = nil,
        sessionID: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.kind = kind
        self.severity = severity
        self.message = message
        self.traceID = traceID
        self.sessionID = sessionID
        self.metadata = metadata
    }

    public static func log(_ severity: DiagnosticSeverity, _ message: String) -> DiagnosticEvent {
        DiagnosticEvent(kind: .log, severity: severity, message: message)
    }

    public static func network(_ message: String) -> DiagnosticEvent {
        DiagnosticEvent(kind: .network, severity: .info, message: message)
    }

    public static func performance(_ message: String) -> DiagnosticEvent {
        DiagnosticEvent(kind: .performance, severity: .info, message: message)
    }

    public static func error(_ message: String) -> DiagnosticEvent {
        DiagnosticEvent(kind: .error, severity: .error, message: message)
    }

    public func metadata(_ key: String, _ value: String) -> DiagnosticEvent {
        var metadata = self.metadata
        metadata[key] = value
        return DiagnosticEvent(
            id: id,
            timestamp: timestamp,
            kind: kind,
            severity: severity,
            message: message,
            traceID: traceID,
            sessionID: sessionID,
            metadata: metadata
        )
    }

    public func traceID(_ traceID: String) -> DiagnosticEvent {
        DiagnosticEvent(
            id: id,
            timestamp: timestamp,
            kind: kind,
            severity: severity,
            message: message,
            traceID: traceID,
            sessionID: sessionID,
            metadata: metadata
        )
    }

    public func sessionID(_ sessionID: String) -> DiagnosticEvent {
        DiagnosticEvent(
            id: id,
            timestamp: timestamp,
            kind: kind,
            severity: severity,
            message: message,
            traceID: traceID,
            sessionID: sessionID,
            metadata: metadata
        )
    }
}
