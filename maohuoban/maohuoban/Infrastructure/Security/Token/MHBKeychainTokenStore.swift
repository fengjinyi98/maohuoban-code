import Foundation
import Security

// MHBKeychainTokenStore Keychain token 存储
// 核心职责：
// - 将 refresh token 等敏感凭证保存到 Keychain
// - 提供保存、读取、清除三类显式事件入口
struct MHBKeychainTokenStore: MHBTokenStore {
    private let service = "com.jinyi.maohuoban.auth"
    private let account = "current-session"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func loadTokens() throws -> MHBStoredTokens? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess, let data = item as? Data else {
            throw KeychainError.unhandled(status)
        }
        return try decoder.decode(MHBStoredTokens.self, from: data)
    }

    func saveTokens(_ tokens: MHBStoredTokens) throws {
        let data = try encoder.encode(tokens)
        var query = baseQuery()
        let attributes: [String: Any] = [kSecValueData as String: data]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecSuccess {
            return
        }
        if status == errSecItemNotFound {
            query[kSecValueData as String] = data
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unhandled(addStatus)
            }
            return
        }
        throw KeychainError.unhandled(status)
    }

    func clearTokens() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound {
            return
        }
        throw KeychainError.unhandled(status)
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

// KeychainError Keychain 操作错误
// 核心职责：
// - 保留系统状态码便于诊断
// - 将底层安全框架错误限制在基础设施层
private enum KeychainError: LocalizedError {
    case unhandled(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unhandled(let status):
            "Keychain 操作失败：\(status)"
        }
    }
}
