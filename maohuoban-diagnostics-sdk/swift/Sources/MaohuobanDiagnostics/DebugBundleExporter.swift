import Foundation
import CryptoKit

// DebugBundle 诊断包导出结果
// 核心职责：
// - 暴露导出目录、清单、时间线、Prompt 和归档文件路径
// - 为 Collector 后续压缩和发送给 LLM 提供稳定边界
public struct DebugBundle: Sendable {
    public let directoryURL: URL
    public let manifestURL: URL
    public let timelineURL: URL
    public let promptURL: URL
    public let archiveURL: URL
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

    private func sha256Hex(for url: URL) throws -> String {
        let digest = SHA256.hash(data: try Data(contentsOf: url))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func writeTarArchive(to outputURL: URL, files: [(String, URL)]) throws {
        var archive = Data()
        for (name, url) in files {
            let data = try Data(contentsOf: url)
            archive.append(tarHeader(name: name, size: UInt64(data.count)))
            archive.append(data)
            let padding = (512 - (data.count % 512)) % 512
            if padding > 0 {
                archive.append(Data(repeating: 0, count: padding))
            }
        }
        archive.append(Data(repeating: 0, count: 1_024))
        try archive.write(to: outputURL, options: .atomic)
    }

    private func tarHeader(name: String, size: UInt64) -> Data {
        var header = [UInt8](repeating: 0, count: 512)
        writeString(name, into: &header, offset: 0, length: 100)
        writeOctal(0o644, into: &header, offset: 100, length: 8)
        writeOctal(0, into: &header, offset: 108, length: 8)
        writeOctal(0, into: &header, offset: 116, length: 8)
        writeOctal(size, into: &header, offset: 124, length: 12)
        writeOctal(0, into: &header, offset: 136, length: 12)
        for index in 148..<156 {
            header[index] = UInt8(ascii: " ")
        }
        header[156] = UInt8(ascii: "0")
        writeString("ustar", into: &header, offset: 257, length: 6)
        writeString("00", into: &header, offset: 263, length: 2)
        let checksum = header.reduce(0) { $0 + UInt32($1) }
        writeChecksum(checksum, into: &header)
        return Data(header)
    }

    private func writeString(_ value: String, into header: inout [UInt8], offset: Int, length: Int) {
        let bytes = Array(value.utf8.prefix(length))
        header.replaceSubrange(offset..<(offset + bytes.count), with: bytes)
    }

    private func writeOctal(_ value: UInt64, into header: inout [UInt8], offset: Int, length: Int) {
        let text = String(value, radix: 8)
        let padded = String(repeating: "0", count: max(0, length - 1 - text.count)) + text
        let bytes = Array(padded.utf8.prefix(length - 1))
        header.replaceSubrange(offset..<(offset + bytes.count), with: bytes)
    }

    private func writeChecksum(_ value: UInt32, into header: inout [UInt8]) {
        let text = String(format: "%06o", value) + "\0 "
        let bytes = Array(text.utf8)
        header.replaceSubrange(148..<(148 + bytes.count), with: bytes)
    }
}

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
