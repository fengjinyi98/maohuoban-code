import Foundation

// MHBStoredTokens 本地登录凭证
// 核心职责：
// - 保存 access token 与 refresh token
// - 为冷启动恢复和退出登录提供统一数据模型
struct MHBStoredTokens: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresInSeconds: Int
    let refreshExpiresInSeconds: Int
}

// MHBTokenStore token 存储协议
// 核心职责：
// - 隔离 Keychain 读写细节
// - 支持测试或预览替换持久化实现
protocol MHBTokenStore {
    func loadTokens() throws -> MHBStoredTokens?
    func saveTokens(_ tokens: MHBStoredTokens) throws
    func clearTokens() throws
}
