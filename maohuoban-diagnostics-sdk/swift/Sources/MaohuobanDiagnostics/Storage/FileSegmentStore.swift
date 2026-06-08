import Foundation

// FileSegmentStore JSONL 分段文件存储
// 核心职责：
// - 将诊断事件以 JSONL 格式分段落盘
// - 执行基于时间与大小的段文件清理和损坏行恢复
actor FileSegmentStore {
    private let directory: URL
    private let maxSegmentBytes: UInt64
    private var currentURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(directory: URL, maxSegmentBytes: UInt64) throws {
        self.directory = directory
        self.maxSegmentBytes = maxSegmentBytes
        currentURL = directory.appendingPathComponent("\(UUID().uuidString).jsonl")
        encoder = JSONEncoder()
        decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func append(_ event: DiagnosticEvent) throws {
        try rotateIfNeeded()
        var data = try encoder.encode(event)
        data.append(0x0A)
        if FileManager.default.fileExists(atPath: currentURL.path) {
            let handle = try FileHandle(forWritingTo: currentURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } else {
            try data.write(to: currentURL, options: .atomic)
        }
    }

    func flush() throws {}

    func readAll() throws -> [DiagnosticEvent] {
        var events: [DiagnosticEvent] = []
        for url in try segmentURLs() {
            guard let lines = String(data: try Data(contentsOf: url), encoding: .utf8) else {
                continue
            }
            for (index, line) in lines.split(separator: "\n").enumerated() {
                let data = Data(line.utf8)
                do {
                    events.append(try decoder.decode(DiagnosticEvent.self, from: data))
                } catch {
                    events.append(corruptedSegmentEvent(url: url, line: index + 1, error: error))
                }
            }
        }
        return events.sorted { $0.timestamp < $1.timestamp }
    }

    func cleanup(_ policy: CleanupPolicy) throws -> CleanupReport {
        var report = CleanupReport()
        let now = Date()
        for url in try segmentURLs() {
            let values = try url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
            let modified = values.contentModificationDate ?? .distantPast
            if now.timeIntervalSince(modified) >= policy.maxSegmentAge {
                let size = UInt64(values.fileSize ?? 0)
                try FileManager.default.removeItem(at: url)
                report.removedSegments += 1
                report.freedBytes += size
            }
        }

        var urlsWithSize = try segmentURLs().map { url in
            let size = UInt64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            return (url, size)
        }
        urlsWithSize.sort { $0.0.path < $1.0.path }
        var total = urlsWithSize.reduce(UInt64(0)) { $0 + $1.1 }
        for (url, size) in urlsWithSize where total > policy.maxTotalBytes {
            try FileManager.default.removeItem(at: url)
            total -= min(total, size)
            report.removedSegments += 1
            report.freedBytes += size
        }

        return report
    }

    private func rotateIfNeeded() throws {
        guard FileManager.default.fileExists(atPath: currentURL.path) else {
            return
        }
        let values = try currentURL.resourceValues(forKeys: [.fileSizeKey])
        if UInt64(values.fileSize ?? 0) >= maxSegmentBytes {
            currentURL = directory.appendingPathComponent("\(UUID().uuidString).jsonl")
        }
    }

    private func segmentURLs() throws -> [URL] {
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return []
        }
        return try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]
        )
        .filter { $0.pathExtension == "jsonl" }
        .sorted { $0.path < $1.path }
    }

    // corruptedSegmentEvent 构造损坏段文件告警事件
    // 核心职责：
    // - 保留段文件读取损坏的可观测信号
    // - 允许合法诊断事件继续导出给分析流程
    private func corruptedSegmentEvent(url: URL, line: Int, error: Error) -> DiagnosticEvent {
        DiagnosticEvent(
            kind: .error,
            severity: .warn,
            message: "storage segment decode failed",
            metadata: [
                "source": .string("file_segment_store"),
                "segment": .string(url.lastPathComponent),
                "line": .string("\(line)"),
                "error": .string(String(describing: error))
            ]
        )
    }
}
