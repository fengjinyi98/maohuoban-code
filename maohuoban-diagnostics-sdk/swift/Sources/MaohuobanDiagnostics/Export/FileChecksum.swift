import CryptoKit
import Foundation

// sha256Hex 计算文件 SHA256
// 核心职责：
// - 为导出清单提供文件内容校验值
// - 隔离 CryptoKit 依赖和十六进制编码细节
func sha256Hex(for url: URL) throws -> String {
    let digest = SHA256.hash(data: try Data(contentsOf: url))
    return digest.map { String(format: "%02x", $0) }.joined()
}
