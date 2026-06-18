import Foundation

// DebugBundleIndex 诊断包索引
// 核心职责：
// - 为 LLM 提供首读入口和文件读取顺序
// - 汇总事件数量、类型分布和严重级别分布
struct DebugBundleIndex: Encodable {
    let schema: String
    let sdkVersion: String
    let eventCount: Int
    let firstEventAt: String?
    let firstEventAtLocal: String?
    let latestEventAt: String?
    let latestEventAtLocal: String?
    let timeBasis: DebugBundleIndexTimeBasis
    let kindCounts: [String: Int]
    let severityCounts: [String: Int]
    let recommendedReadOrder: [String]
    let files: [DebugBundleIndexFile]
    let importantQueries: [DebugBundleIndexQuery]

    enum CodingKeys: String, CodingKey {
        case schema
        case sdkVersion = "sdk_version"
        case eventCount = "event_count"
        case firstEventAt = "first_event_at"
        case firstEventAtLocal = "first_event_at_local"
        case latestEventAt = "latest_event_at"
        case latestEventAtLocal = "latest_event_at_local"
        case timeBasis = "time_basis"
        case kindCounts = "kind_counts"
        case severityCounts = "severity_counts"
        case recommendedReadOrder = "recommended_read_order"
        case files
        case importantQueries = "important_queries"
    }

    static func make(events: [DiagnosticEvent]) -> DebugBundleIndex {
        let formatter = ISO8601DateFormatter()
        return DebugBundleIndex(
            schema: "maohuoban.diagnostics.index.v1",
            sdkVersion: Diagnostics.sdkVersion,
            eventCount: events.count,
            firstEventAt: events.first.map { formatter.string(from: $0.timestamp) },
            firstEventAtLocal: events.first.map { DebugBundleTimeBasis.localTimestampString(for: $0.timestamp) },
            latestEventAt: events.last.map { formatter.string(from: $0.timestamp) },
            latestEventAtLocal: events.last.map { DebugBundleTimeBasis.localTimestampString(for: $0.timestamp) },
            timeBasis: DebugBundleIndexTimeBasis(),
            kindCounts: Dictionary(grouping: events, by: { $0.kind.rawValue }).mapValues(\.count),
            severityCounts: Dictionary(grouping: events, by: { $0.severity.rawValue }).mapValues(\.count),
            recommendedReadOrder: [
                "index.json",
                "prompt.md",
                "timeline.jsonl",
                "manifest.json",
            ],
            files: [
                .init(path: "index.json", purpose: "诊断包索引和读取路由", readWhen: "始终先读，用于决定后续打开哪些报告文件。"),
                .init(path: "prompt.md", purpose: "面向 LLM 的压缩时间线摘要", readWhen: "需要快速判断问题现象、最近关键事件和用户问题时读取。"),
                .init(path: "timeline.jsonl", purpose: "完整事件时间线", readWhen: "需要按时间顺序定位具体 SDK 事件、日志、错误和 metadata 时读取。"),
                .init(path: "manifest.json", purpose: "诊断包清单和校验值", readWhen: "需要核对文件完整性、SDK 版本和导出时间时读取。"),
                .init(path: "archive.tar", purpose: "包含核心诊断文件的无压缩归档", readWhen: "需要把完整诊断包作为单文件传递给其他工具时使用。"),
            ],
            importantQueries: [
                .init(target: "timeline.jsonl", query: "\"severity\":\"error\"", purpose: "定位 error 级别事件"),
                .init(target: "timeline.jsonl", query: "\"severity\":\"fatal\"", purpose: "定位 fatal 级别事件"),
                .init(target: "timeline.jsonl", query: "\"kind\":\"network\"", purpose: "定位网络请求事件"),
                .init(target: "timeline.jsonl", query: "\"kind\":\"lifecycle\"", purpose: "定位启动、授权和生命周期事件"),
            ]
        )
    }
}

// DebugBundleIndexFile 诊断包文件索引项
// 核心职责：
// - 描述诊断包内单个文件的用途
// - 为 LLM 按需读取报告文件提供路由信息
struct DebugBundleIndexFile: Encodable {
    let path: String
    let purpose: String
    let readWhen: String

    enum CodingKeys: String, CodingKey {
        case path
        case purpose
        case readWhen = "read_when"
    }
}

// DebugBundleIndexQuery 诊断包查询提示
// 核心职责：
// - 描述常见问题定位时应搜索的目标文件和关键字
// - 降低 LLM 全量扫描时间线的概率
struct DebugBundleIndexQuery: Encodable {
    let target: String
    let query: String
    let purpose: String
}
