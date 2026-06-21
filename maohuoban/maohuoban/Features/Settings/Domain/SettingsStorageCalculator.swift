import Foundation

// SettingsStorageCalculator 存储空间计算工具
// 核心职责：
// - 统计设备容量与 App 沙盒目录占用
// - 为设置页和存储空间页提供真实展示数据
enum SettingsStorageCalculator {
    struct StorageSnapshot: Sendable, Equatable {
        let deviceTotal: Int64
        let deviceAvailable: Int64
        let appCaches: Int64
        let appDocuments: Int64
        let appTemporary: Int64

        var deviceUsed: Int64 { max(0, deviceTotal - deviceAvailable) }
        var appTotal: Int64 { appCaches + appDocuments + appTemporary }

        var appPercentageText: String {
            guard deviceTotal > 0 else { return "0%" }
            let percent = Double(appTotal) / Double(deviceTotal) * 100
            return percent < 1 ? "不足 1%" : "\(Int(percent))%"
        }
    }

    nonisolated static func calculate() async -> StorageSnapshot {
        await Task.detached(priority: .utility) {
            let capacity = deviceCapacity()
            return StorageSnapshot(
                deviceTotal: capacity.total,
                deviceAvailable: capacity.available,
                appCaches: directorySize(.cachesDirectory),
                appDocuments: directorySize(.documentDirectory),
                appTemporary: sizeOfDirectory(at: URL(fileURLWithPath: NSTemporaryDirectory()))
            )
        }.value
    }

    nonisolated static func clearCaches() async -> StorageSnapshot {
        await Task.detached(priority: .utility) {
            let manager = FileManager.default
            guard let cachesURL = manager.urls(for: .cachesDirectory, in: .userDomainMask).first,
                  let contents = try? manager.contentsOfDirectory(at: cachesURL, includingPropertiesForKeys: nil) else {
                return
            }
            contents.forEach { try? manager.removeItem(at: $0) }
        }.value
        return await calculate()
    }

    private nonisolated static func deviceCapacity() -> (total: Int64, available: Int64) {
        let homePath = NSHomeDirectory()
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: homePath) else {
            return (0, 0)
        }

        let total = attrs[.systemSize] as? Int64 ?? 0
        let homeURL = URL(fileURLWithPath: homePath)
        if let values = try? homeURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
           let available = values.volumeAvailableCapacityForImportantUsage {
            return (total, available)
        }

        return (total, attrs[.systemFreeSize] as? Int64 ?? 0)
    }

    private nonisolated static func directorySize(_ directory: FileManager.SearchPathDirectory) -> Int64 {
        guard let url = FileManager.default.urls(for: directory, in: .userDomainMask).first else {
            return 0
        }
        return sizeOfDirectory(at: url)
    }

    private nonisolated static func sizeOfDirectory(at url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  values.isRegularFile == true,
                  let size = values.fileSize else {
                continue
            }
            total += Int64(size)
        }
        return total
    }
}

// Int64StorageFormatting 存储字节格式化能力
// 核心职责：
// - 统一设置模块的字节大小展示
// - 避免页面重复实现单位转换
extension Int64 {
    var settingsStorageFormatted: String {
        if self <= 0 { return "0 KB" }
        return formatted(.byteCount(style: .file))
    }
}
