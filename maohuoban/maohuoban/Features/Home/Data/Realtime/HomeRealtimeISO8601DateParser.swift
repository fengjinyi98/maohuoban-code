import Foundation

// HomeRealtimeISO8601DateParser 首页实时事件时间解析器
// 核心职责：
// - 解析后端 SSE 事件中的 ISO8601 UTC 时间
// - 支持带毫秒和不带毫秒两种 timestamptz 输出
enum HomeRealtimeISO8601DateParser {
    static func date(from value: String) throws -> Date {
        for formatter in formatters {
            if let date = formatter.date(from: value) {
                return date
            }
        }
        throw DecodingError.dataCorrupted(.init(
            codingPath: [],
            debugDescription: "Invalid ISO8601 date: \(value)"
        ))
    }

    private static let formatters: [ISO8601DateFormatter] = [
        {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter
        }(),
        {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            return formatter
        }()
    ]
}
