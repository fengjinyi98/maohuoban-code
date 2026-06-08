import Foundation

// LLMPromptExporter LLM 分析输入导出器
// 核心职责：
// - 将诊断时间线压缩成适合 LLM 读取的文本
// - 保留 schema、用户问题和关键事件摘要
struct LLMPromptExporter {
    let title: String
    var maxEvents = 200

    func export(events: [DiagnosticEvent]) -> String {
        let suffix = events.suffix(maxEvents)
        var output = """
        # Maohuoban Diagnostics Prompt

        schema: maohuoban.diagnostics.prompt.v1
        title: \(title)
        sdkVersion: \(Diagnostics.sdkVersion)
        eventCount: \(events.count)

        ## Timeline

        """
        for event in suffix {
            output += "- [\(event.timestamp.ISO8601Format())] \(event.kind.rawValue)/\(event.severity.rawValue): \(event.message) metadata=\(event.metadata)\n"
        }
        return output
    }
}
