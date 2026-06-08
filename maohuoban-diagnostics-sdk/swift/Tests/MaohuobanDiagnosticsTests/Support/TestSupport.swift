import Foundation
import Testing

// temporaryDirectory 创建测试用临时目录
// 核心职责：
// - 为每个测试提供独立文件根目录
// - 避免诊断段文件、导出包和日志文件相互污染
func temporaryDirectory() throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("maohuoban-diagnostics-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

// tarEntries 解析测试用无压缩 tar 条目
// 核心职责：
// - 验证 Debug Bundle 归档可以按 tar 格式读取
// - 对比归档内文件内容和导出目录原文件
func tarEntries(from archive: Data) throws -> [String: Data] {
    var entries: [String: Data] = [:]
    var offset = 0
    while offset + 512 <= archive.count {
        let header = archive.subdata(in: offset..<(offset + 512))
        if header.allSatisfy({ $0 == 0 }) {
            break
        }
        let nameBytes = header.prefix(100).prefix { $0 != 0 }
        let name = try #require(String(data: Data(nameBytes), encoding: .utf8))
        let sizeBytes = header.subdata(in: 124..<136)
            .filter { $0 != 0 && $0 != UInt8(ascii: " ") }
        let sizeText = try #require(String(data: Data(sizeBytes), encoding: .utf8))
        let size = try #require(Int(sizeText, radix: 8))
        let dataStart = offset + 512
        let dataEnd = dataStart + size
        guard dataEnd <= archive.count else {
            Issue.record("tar entry exceeds archive size")
            break
        }
        entries[name] = archive.subdata(in: dataStart..<dataEnd)
        offset = dataStart + ((size + 511) / 512) * 512
    }
    return entries
}

// ScopedTraceTestError 标记作用域 trace 测试错误
// 核心职责：
// - 触发 `withTraceID` 的失败路径
// - 验证失败后 trace 上下文可以恢复
struct ScopedTraceTestError: Error {}
