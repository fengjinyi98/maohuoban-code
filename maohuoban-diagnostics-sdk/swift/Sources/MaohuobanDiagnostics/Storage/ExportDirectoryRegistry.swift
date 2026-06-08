import Foundation

// ExportDirectoryRegistry 导出目录注册表
// 核心职责：
// - 持久记录运行时创建的 Debug Bundle 目录
// - 按清理策略删除过期导出包
final class ExportDirectoryRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private let indexURL: URL
    private var directories: [URL] = []

    init(indexURL: URL) {
        self.indexURL = indexURL
        directories = loadIndex()
    }

    func register(_ directory: URL) throws {
        lock.lock()
        directories.append(directory.standardizedFileURL)
        let snapshot = uniqueDirectories(directories)
        lock.unlock()
        try saveIndex(snapshot)
    }

    func cleanup(policy: CleanupPolicy) throws -> CleanupReport {
        var report = CleanupReport()
        var remaining: [URL] = []
        lock.lock()
        let currentDirectories = uniqueDirectories(directories + loadIndex())
        directories.removeAll()
        lock.unlock()

        for directory in currentDirectories {
            guard FileManager.default.fileExists(atPath: directory.path) else {
                continue
            }
            let values = try directory.resourceValues(forKeys: [.contentModificationDateKey])
            let modified = values.contentModificationDate ?? .distantPast
            if Date().timeIntervalSince(modified) >= policy.maxExportAge {
                report.freedBytes += UInt64(directorySize(directory))
                try FileManager.default.removeItem(at: directory)
                report.removedExports += 1
            } else {
                remaining.append(directory)
            }
        }

        lock.lock()
        directories.append(contentsOf: remaining)
        let snapshot = uniqueDirectories(directories)
        lock.unlock()
        try saveIndex(snapshot)
        return report
    }

    private func loadIndex() -> [URL] {
        guard let lines = try? String(contentsOf: indexURL, encoding: .utf8) else {
            return []
        }
        return uniqueDirectories(
            lines
                .split(separator: "\n")
                .compactMap { URL(fileURLWithPath: String($0)).standardizedFileURL }
        )
    }

    private func saveIndex(_ directories: [URL]) throws {
        try FileManager.default.createDirectory(
            at: indexURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let body = directories.map(\.path).joined(separator: "\n")
        let data = Data((body.isEmpty ? "" : body + "\n").utf8)
        try data.write(to: indexURL, options: .atomic)
    }

    private func uniqueDirectories(_ directories: [URL]) -> [URL] {
        var seen = Set<String>()
        var output: [URL] = []
        for directory in directories {
            let standardized = directory.standardizedFileURL
            guard seen.insert(standardized.path).inserted else {
                continue
            }
            output.append(standardized)
        }
        return output
    }

    private func directorySize(_ directory: URL) -> Int {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else {
            return 0
        }
        var total = 0
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: [.fileSizeKey])
            total += values?.fileSize ?? 0
        }
        return total
    }
}
