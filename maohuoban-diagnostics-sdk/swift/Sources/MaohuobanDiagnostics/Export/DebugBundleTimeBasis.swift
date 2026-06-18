import Foundation

// DebugBundleTimeBasis 诊断包时间基准
// 核心职责：
// - 声明事件时间使用 UTC RFC3339 作为统一排序基准
// - 提供导出机器本地时区预览，辅助人工和 LLM 阅读报告
enum DebugBundleTimeBasis {
    static func localTimestampString(for date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = .current
        return formatter.string(from: date)
    }

    static var localTimezoneName: String {
        TimeZone.current.abbreviation() ?? TimeZone.current.identifier
    }

    static var localUTCOffsetSeconds: Int {
        TimeZone.current.secondsFromGMT()
    }
}

// DebugBundleManifestTimeBasis manifest 时间基准说明
// 核心职责：
// - 使用 Swift manifest 的 camelCase 字段风格
// - 暴露本地时区名称和 UTC 偏移秒数
struct DebugBundleManifestTimeBasis: Encodable {
    let eventTimestamps = "utc_rfc3339"
    let localPreviews = "export_machine_local_time"
    let localTimezone = DebugBundleTimeBasis.localTimezoneName
    let localUTCOffsetSeconds = DebugBundleTimeBasis.localUTCOffsetSeconds
}

// DebugBundleIndexTimeBasis index 时间基准说明
// 核心职责：
// - 使用 index 的 snake_case 字段风格
// - 与 Rust/Collector 报告保持读取语义一致
struct DebugBundleIndexTimeBasis: Encodable {
    let eventTimestamps = "utc_rfc3339"
    let localPreviews = "export_machine_local_time"
    let localTimezone = DebugBundleTimeBasis.localTimezoneName
    let localUTCOffsetSeconds = DebugBundleTimeBasis.localUTCOffsetSeconds

    enum CodingKeys: String, CodingKey {
        case eventTimestamps = "event_timestamps"
        case localPreviews = "local_previews"
        case localTimezone = "local_timezone"
        case localUTCOffsetSeconds = "local_utc_offset_seconds"
    }
}
