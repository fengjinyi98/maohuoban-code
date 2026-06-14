import Foundation

// DebugBundle 诊断包导出结果
// 核心职责：
// - 暴露导出目录、索引、清单、时间线、Prompt 和归档文件路径
// - 为 Collector 后续压缩和发送给 LLM 提供稳定边界
public struct DebugBundle: Sendable {
    public let directoryURL: URL
    public let indexURL: URL
    public let manifestURL: URL
    public let timelineURL: URL
    public let promptURL: URL
    public let archiveURL: URL
}
