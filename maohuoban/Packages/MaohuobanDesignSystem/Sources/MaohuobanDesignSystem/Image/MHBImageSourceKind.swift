import Foundation

// MHBImageSourceKind 图片源类型
// 核心职责：
// - 在远端 URL、本地资源名、系统图标之间建立统一识别边界
// - 为远端图片组件和头像组件提供稳定的数据入口
public enum MHBImageSourceKind: Hashable, Sendable {
    case remote(String)
    case localAsset(String)
    case systemSymbol(String)
    case empty

    public static func remoteOrAsset(from rawValue: String?) -> Self {
        resolve(rawValue, localFallback: .asset)
    }

    public static func remoteOrSystemSymbol(from rawValue: String?) -> Self {
        resolve(rawValue, localFallback: .systemSymbol)
    }

    private enum LocalFallback {
        case asset
        case systemSymbol
    }

    private static func resolve(
        _ rawValue: String?,
        localFallback: LocalFallback
    ) -> Self {
        guard let rawValue else { return .empty }
        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedValue.isEmpty == false else { return .empty }

        if let scheme = URL(string: trimmedValue)?.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            return .remote(trimmedValue)
        }

        switch localFallback {
        case .asset:
            return .localAsset(trimmedValue)
        case .systemSymbol:
            return .systemSymbol(trimmedValue)
        }
    }
}
