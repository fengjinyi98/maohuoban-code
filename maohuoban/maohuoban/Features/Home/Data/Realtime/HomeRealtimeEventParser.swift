import Foundation

// HomeRealtimeEventParser 首页 SSE 行解析器
// 核心职责：
// - 将 URLSession bytes.lines 输出的 SSE 行合并为事件
// - 在空行、新事件开始或流结束时提交待处理事件
struct HomeRealtimeEventParser {
    private var currentEventName: String?
    private var currentDataLines: [String] = []
    private let decoder: JSONDecoder

    init(decoder: JSONDecoder = JSONDecoder()) {
        self.decoder = decoder
    }

    mutating func consumeLine(_ line: String) -> [HomeRealtimeParsedEvent] {
        if isEventBoundary(line) {
            return flushCurrentEvent()
        }

        if line.hasPrefix("event:") {
            let flushedEvents = flushCurrentEvent()
            currentEventName = sseFieldValue(from: line, prefix: "event:")
            currentDataLines = []
            return flushedEvents
        }

        if line.hasPrefix("data:") {
            currentDataLines.append(sseFieldValue(from: line, prefix: "data:"))
        }

        return []
    }

    mutating func finish() -> [HomeRealtimeParsedEvent] {
        flushCurrentEvent()
    }

    private func isEventBoundary(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func sseFieldValue(from line: String, prefix: String) -> String {
        var value = String(line.dropFirst(prefix.count))
        if value.first == " " {
            value.removeFirst()
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private mutating func flushCurrentEvent() -> [HomeRealtimeParsedEvent] {
        guard let currentEventName,
              currentDataLines.isEmpty == false else {
            currentEventName = nil
            currentDataLines = []
            return []
        }

        let data = currentDataLines.joined(separator: "\n")
        let event: HomeRealtimeEvent?
        if let eventData = data.data(using: .utf8) {
            event = try? decoder.decode(HomeRealtimeEvent.self, from: eventData)
        } else {
            event = nil
        }
        self.currentEventName = nil
        currentDataLines = []
        return [
            HomeRealtimeParsedEvent(
                eventName: currentEventName,
                data: data,
                event: event
            ),
        ]
    }
}
