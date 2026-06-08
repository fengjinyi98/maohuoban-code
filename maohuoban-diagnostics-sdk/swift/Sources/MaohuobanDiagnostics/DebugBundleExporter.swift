import Foundation

// DebugBundle 诊断包导出结果
// 核心职责：
// - 暴露导出目录、清单和时间线文件路径
// - 为 Collector 后续压缩和发送给 LLM 提供稳定边界
public struct DebugBundle: Sendable {
    public let directoryURL: URL
    public let manifestURL: URL
    public let timelineURL: URL
}

// DebugBundleExporter 诊断包导出器
// 核心职责：
// - 将事件存储导出成可读时间线与机器可读清单
// - 生成适合 LLM 分析的本地 Debug Bundle
struct DebugBundleExporter {
    let outputDirectory: URL

    func export(events: [DiagnosticEvent]) throws -> DebugBundle {
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let manifestURL = outputDirectory.appending(path: "manifest.json")
        let timelineURL = outputDirectory.appending(path: "timeline.jsonl")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let manifest: [String: String] = [
            "schema": "maohuoban.diagnostics.bundle.v1",
            "sdkVersion": Diagnostics.sdkVersion,
            "eventCount": "\(events.count)",
            "createdAt": ISO8601DateFormatter().string(from: Date()),
        ]
        try encoder.encode(manifest).write(to: manifestURL, options: .atomic)

        var timeline = Data()
        for event in events {
            timeline.append(try encoder.encode(event))
            timeline.append(0x0A)
        }
        try timeline.write(to: timelineURL, options: .atomic)

        return DebugBundle(
            directoryURL: outputDirectory,
            manifestURL: manifestURL,
            timelineURL: timelineURL
        )
    }
}
