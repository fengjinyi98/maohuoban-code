import Foundation

// PrivacyPolicy 隐私脱敏策略
// 核心职责：
// - 定义需要脱敏的 metadata 字段
// - 在写入存储前统一处理敏感信息
public struct PrivacyPolicy: Sendable {
    public var redactedKeys: Set<String>

    public init(redactedKeys: Set<String> = []) {
        self.redactedKeys = Set(redactedKeys.map { $0.lowercased() })
    }

    public func apply(to event: DiagnosticEvent) -> DiagnosticEvent {
        var metadata = event.metadata
        for key in metadata.keys {
            if redactedKeys.contains(key.lowercased()) {
                metadata[key] = "<redacted>"
            }
        }
        return DiagnosticEvent(
            id: event.id,
            timestamp: event.timestamp,
            kind: event.kind,
            severity: event.severity,
            message: event.message,
            traceID: event.traceID,
            sessionID: event.sessionID,
            metadata: metadata
        )
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
