import Foundation

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
        let promptURL = outputDirectory.appending(path: "prompt.md")
        let archiveURL = outputDirectory.appending(path: "archive.tar")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        var timeline = Data()
        for event in events {
            timeline.append(try encoder.encode(event))
            timeline.append(0x0A)
        }
        try timeline.write(to: timelineURL, options: .atomic)
        let prompt = LLMPromptExporter(title: "分析 Maohuoban 诊断包").export(events: events)
        try prompt.write(to: promptURL, atomically: true, encoding: .utf8)
        let manifest: [String: String] = [
            "schema": "maohuoban.diagnostics.bundle.v1",
            "sdkVersion": Diagnostics.sdkVersion,
            "eventCount": "\(events.count)",
            "createdAt": ISO8601DateFormatter().string(from: Date()),
            "timelineSHA256": try sha256Hex(for: timelineURL),
            "promptSHA256": try sha256Hex(for: promptURL),
            "archivePath": "archive.tar",
        ]
        try encoder.encode(manifest).write(to: manifestURL, options: .atomic)
        try writeTarArchive(
            to: archiveURL,
            files: [
                ("manifest.json", manifestURL),
                ("timeline.jsonl", timelineURL),
                ("prompt.md", promptURL),
            ]
        )

        return DebugBundle(
            directoryURL: outputDirectory,
            manifestURL: manifestURL,
            timelineURL: timelineURL,
            promptURL: promptURL,
            archiveURL: archiveURL
        )
    }
}
