import Foundation

// PrivacyPolicy 隐私脱敏策略
// 核心职责：
// - 定义需要脱敏的 metadata 字段
// - 在写入存储前统一处理敏感信息
public struct PrivacyPolicy: Sendable {
    public var redactedKeys: Set<String>
    public var redactedQueryItems: Set<String>
    public var redactedTextPatterns: [DiagnosticTextRedactionPattern]

    public init(
        redactedKeys: Set<String> = [],
        redactedQueryItems: Set<String> = [],
        redactedTextPatterns: [DiagnosticTextRedactionPattern] = []
    ) {
        self.redactedKeys = Self.defaultRedactedKeys
            .union(redactedKeys.map { $0.lowercased() })
        self.redactedQueryItems = Set(redactedQueryItems.map { $0.lowercased() })
        self.redactedTextPatterns = redactedTextPatterns
    }

    private static let defaultRedactedKeys: Set<String> = [
        "authorization",
        "password",
        "token",
        "access_token",
        "refresh_token",
        "cookie",
        "set-cookie"
    ]

    public func apply(to event: DiagnosticEvent) -> DiagnosticEvent {
        var metadata = event.metadata
        for key in metadata.keys {
            if redactedKeys.contains(key.lowercased()) {
                metadata[key] = "<redacted>"
            } else if let value = metadata[key] {
                metadata[key] = value.applyingToStrings { text in
                    let urlRedacted = redactURLQueryItems(in: text)
                    return redactText(in: urlRedacted)
                }
            }
        }
        return DiagnosticEvent(
            id: event.id,
            timestamp: event.timestamp,
            kind: event.kind,
            severity: event.severity,
            message: redactText(in: event.message),
            traceID: event.traceID,
            sessionID: event.sessionID,
            metadata: metadata
        )
    }

    private func redactURLQueryItems(in value: String) -> String {
        guard !redactedQueryItems.isEmpty,
              var components = URLComponents(string: value),
              let queryItems = components.queryItems else {
            return value
        }
        components.queryItems = queryItems.map { item in
            guard redactedQueryItems.contains(item.name.lowercased()) else {
                return item
            }
            return URLQueryItem(name: item.name, value: "<redacted>")
        }
        return (components.string ?? value)
            .replacingOccurrences(of: "%3Credacted%3E", with: "<redacted>")
    }

    private func redactText(in value: String) -> String {
        redactedTextPatterns.reduce(value) { output, pattern in
            pattern.apply(to: output)
        }
    }
}

// DiagnosticTextRedactionPattern 文本脱敏模式
// 核心职责：
// - 提供常见敏感文本的内置脱敏规则
// - 支持业务按正则扩展自定义脱敏边界
public enum DiagnosticTextRedactionPattern: Sendable, Equatable {
    case email
    case phoneNumber
    case custom(pattern: String, replacement: String)

    func apply(to value: String) -> String {
        switch self {
        case .email:
            replace(
                pattern: #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#,
                in: value,
                with: "<redacted:email>",
                options: [.caseInsensitive]
            )
        case .phoneNumber:
            replace(
                pattern: #"(?<!\d)1[3-9]\d{9}(?!\d)"#,
                in: value,
                with: "<redacted:phone>"
            )
        case let .custom(pattern, replacement):
            replace(pattern: pattern, in: value, with: replacement)
        }
    }

    private func replace(
        pattern: String,
        in value: String,
        with replacement: String,
        options: NSRegularExpression.Options = []
    ) -> String {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: options) else {
            return value
        }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return expression.stringByReplacingMatches(
            in: value,
            options: [],
            range: range,
            withTemplate: replacement
        )
    }
}

// DiagnosticsTrackingConsent 诊断采集授权状态
// 核心职责：
// - 表达用户或宿主 App 对诊断采集的授权边界
// - 让采集策略在统一入口阻断未授权事件写入
public enum DiagnosticsTrackingConsent: Sendable, Equatable {
    case granted
    case pending
    case denied
}

// CapturePolicy 采集控制策略
// 核心职责：
// - 控制进入存储层的最低事件级别
// - 裁剪超长 message 和 metadata 字符串，避免诊断数据失控
public struct CapturePolicy: Sendable {
    public var enabled: Bool
    public var consent: DiagnosticsTrackingConsent
    public var sampleRate: Double
    public var minimumSeverity: DiagnosticSeverity
    public var maxMessageLength: Int
    public var maxMetadataValueLength: Int

    public init(
        enabled: Bool = true,
        consent: DiagnosticsTrackingConsent = .granted,
        sampleRate: Double = 1,
        minimumSeverity: DiagnosticSeverity = .trace,
        maxMessageLength: Int = .max,
        maxMetadataValueLength: Int = .max
    ) {
        self.enabled = enabled
        self.consent = consent
        self.sampleRate = sampleRate
        self.minimumSeverity = minimumSeverity
        self.maxMessageLength = maxMessageLength
        self.maxMetadataValueLength = maxMetadataValueLength
    }

    public func apply(to event: DiagnosticEvent) -> DiagnosticEvent? {
        guard enabled, consent == .granted, shouldSample(event) else {
            return nil
        }
        guard event.severity.rank >= minimumSeverity.rank else {
            return nil
        }

        var metadata: DiagnosticProperties = [:]
        for (key, value) in event.metadata {
            metadata[key] = value.truncatingStrings(to: maxMetadataValueLength)
        }

        return DiagnosticEvent(
            id: event.id,
            timestamp: event.timestamp,
            kind: event.kind,
            severity: event.severity,
            message: truncate(event.message, limit: maxMessageLength),
            traceID: event.traceID,
            sessionID: event.sessionID,
            metadata: metadata
        )
    }

    private func truncate(_ value: String, limit: Int) -> String {
        guard limit >= 0, value.count > limit else {
            return value
        }
        return String(value.prefix(limit)) + "..."
    }

    private func shouldSample(_ event: DiagnosticEvent) -> Bool {
        if sampleRate >= 1 {
            return true
        }
        if sampleRate <= 0 {
            return false
        }
        let bucket = abs(event.id.uuidString.hashValue % 10_000)
        return Double(bucket) / 10_000 < sampleRate
    }
}

// CleanupPolicy 本地清理策略
// 核心职责：
// - 控制诊断段文件保留时间与磁盘上限
// - 控制导出包保留时间
public struct CleanupPolicy: Sendable {
    public var maxTotalBytes: UInt64
    public var maxSegmentAge: TimeInterval
    public var maxExportAge: TimeInterval

    public init(
        maxTotalBytes: UInt64 = 50 * 1_024 * 1_024,
        maxSegmentAge: TimeInterval = 7 * 24 * 60 * 60,
        maxExportAge: TimeInterval = 24 * 60 * 60
    ) {
        self.maxTotalBytes = maxTotalBytes
        self.maxSegmentAge = maxSegmentAge
        self.maxExportAge = maxExportAge
    }
}

// CleanupReport 清理执行结果
// 核心职责：
// - 记录被删除的段文件与导出包数量
// - 为调试清理策略提供可观测结果
public struct CleanupReport: Codable, Sendable {
    public var removedSegments: Int
    public var removedExports: Int
    public var freedBytes: UInt64

    public init(removedSegments: Int = 0, removedExports: Int = 0, freedBytes: UInt64 = 0) {
        self.removedSegments = removedSegments
        self.removedExports = removedExports
        self.freedBytes = freedBytes
    }
}
