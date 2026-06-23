import Foundation
import SwiftUI

// MHBRemoteMediaRequestFactory 远程媒体请求工厂
// 核心职责：
// - 统一构造远程图片和媒体下载请求
// - 将缓存策略和超时参数收敛到 App 与 Widget 共享层
enum MHBRemoteMediaRequestFactory {
    static func request(
        url: URL,
        cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
        timeoutInterval: TimeInterval = 30
    ) -> URLRequest {
        URLRequest(
            url: url,
            cachePolicy: cachePolicy,
            timeoutInterval: timeoutInterval
        )
    }
}

// MHBRemoteMediaSessionFactory 远程媒体会话工厂
// 核心职责：
// - 为 AsyncImage 和底层媒体下载提供统一 URLSession
// - 收敛缓存容量、缓存策略和请求超时
enum MHBRemoteMediaSessionFactory {
    static let shared: URLSession = URLSession(configuration: configuration())

    static func configuration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .useProtocolCachePolicy
        configuration.timeoutIntervalForRequest = 30
        configuration.urlCache = URLCache(
            memoryCapacity: 24 * 1024 * 1024,
            diskCapacity: 256 * 1024 * 1024
        )
        return configuration
    }
}

// MHBRemoteMediaDataLoader 远程媒体数据下载器
// 核心职责：
// - 为 UIKit 和文件型媒体加载提供统一下载入口
// - 保持请求策略、session 和 HTTP 响应校验一致
enum MHBRemoteMediaDataLoader {
    static func data(
        from url: URL,
        cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
        timeoutInterval: TimeInterval = 30,
        session: URLSession = MHBRemoteMediaSessionFactory.shared
    ) async throws -> Data {
        let request = MHBRemoteMediaRequestFactory.request(
            url: url,
            cachePolicy: cachePolicy,
            timeoutInterval: timeoutInterval
        )
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            return data
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}

// MHBRemoteMediaImage 远程媒体图片视图
// 核心职责：
// - 使用 iOS 27 AsyncImage 请求缓存能力加载远程图片
// - 为 App 和 Widget 提供扩展安全的统一图片展示组件
struct MHBRemoteMediaImage<Placeholder: View>: View {
    let url: URL?
    let scale: CGFloat
    let cachePolicy: URLRequest.CachePolicy
    let timeoutInterval: TimeInterval
    let contentMode: ContentMode
    let transaction: Transaction
    let placeholder: () -> Placeholder

    init(
        url: URL?,
        scale: CGFloat = 1,
        cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
        timeoutInterval: TimeInterval = 30,
        contentMode: ContentMode = .fill,
        transaction: Transaction = Transaction(animation: .easeInOut(duration: 0.18)),
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.scale = scale
        self.cachePolicy = cachePolicy
        self.timeoutInterval = timeoutInterval
        self.contentMode = contentMode
        self.transaction = transaction
        self.placeholder = placeholder
    }

    var body: some View {
        if let url {
            AsyncImage(
                request: MHBRemoteMediaRequestFactory.request(
                    url: url,
                    cachePolicy: cachePolicy,
                    timeoutInterval: timeoutInterval
                ),
                scale: scale,
                transaction: transaction
            ) { phase in
                switch phase {
                case let .success(image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                case .empty, .failure:
                    placeholder()
                @unknown default:
                    placeholder()
                }
            }
            .asyncImageURLSession(MHBRemoteMediaSessionFactory.shared)
        } else {
            placeholder()
        }
    }
}
