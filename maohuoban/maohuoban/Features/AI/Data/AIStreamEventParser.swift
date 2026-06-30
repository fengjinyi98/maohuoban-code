import Foundation

// AIStreamParsedEvent AI SSE 解析结果
// 核心职责：
// - 保留原始 SSE event 名称用于诊断
// - 承载前端已识别的稳定流式事件
struct AIStreamParsedEvent {
    let eventName: String
    let data: String
    let event: AIStreamEventDTO?
}

// AIStreamEventParser AI SSE 行解析器
// 核心职责：
// - 将 URLSession bytes.lines 输出的 SSE 行合并为事件
// - 在空行、新事件开始或流结束时提交待处理事件
struct AIStreamEventParser {
    private var currentEventName: String?
    private var currentDataLines: [String] = []

    mutating func consumeLine(_ line: String) -> [AIStreamParsedEvent] {
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

    mutating func finish() -> [AIStreamParsedEvent] {
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

    private mutating func flushCurrentEvent() -> [AIStreamParsedEvent] {
        guard let currentEventName,
              currentDataLines.isEmpty == false else {
            currentEventName = nil
            currentDataLines = []
            return []
        }

        let data = currentDataLines.joined(separator: "\n")
        let event = AIStreamEventDecoder.decode(event: currentEventName, data: data)
        self.currentEventName = nil
        currentDataLines = []
        return [
            AIStreamParsedEvent(
                eventName: currentEventName,
                data: data,
                event: event
            ),
        ]
    }
}
