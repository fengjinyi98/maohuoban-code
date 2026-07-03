import Foundation
import MaohuobanDesignSystem

// PetAlbumImageSourceResolver 相册图片源解析器
// 核心职责：
// - 将后端相对媒资路径解析为远端图片 URL
// - 为相册普通展示和大图预览提供一致的图片源语义
enum PetAlbumImageSourceResolver {
    static func remoteURL(
        from rawValue: String,
        baseURL: URL = MHBBackendEndpoint.localDevelopmentBaseURL
    ) -> URL? {
        let source = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isRemoteSource(source) else {
            return nil
        }

        if let url = URL(string: source),
           url.scheme != nil {
            return url
        }

        return URL(string: source, relativeTo: baseURL)?.absoluteURL
    }

    static func previewSourceKind(
        from rawValue: String,
        baseURL: URL = MHBBackendEndpoint.localDevelopmentBaseURL
    ) -> MHBImageSourceKind {
        if let url = remoteURL(from: rawValue, baseURL: baseURL) {
            return .remote(url.absoluteString)
        }

        let source = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard source.isEmpty == false else {
            return .empty
        }

        return .localAsset(source)
    }

    private static func isRemoteSource(_ source: String) -> Bool {
        source.hasPrefix("/") || source.hasPrefix("http://") || source.hasPrefix("https://")
    }
}
