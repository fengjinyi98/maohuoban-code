import Foundation
import SwiftUI

// MHBRemoteImageRequestFactory 远程图片请求工厂
// 核心职责：
// - 统一构造 AsyncImage 使用的 URLRequest
// - 将缓存策略和超时参数收敛到基础设施层
enum MHBRemoteImageRequestFactory {
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

// MHBRemoteImageSessionFactory 远程图片会话工厂
// 核心职责：
// - 为 AsyncImage 提供统一 URLSession
// - 收敛缓存容量、缓存策略和请求超时
enum MHBRemoteImageSessionFactory {
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

// MHBRemoteImage 远程图片组件
// 核心职责：
// - 使用 iOS 27 AsyncImage 请求缓存能力加载远程图片
// - 统一处理占位、失败兜底和图片缩放模式
struct MHBRemoteImage<Placeholder: View>: View {
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
                request: MHBRemoteImageRequestFactory.request(
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
            .asyncImageURLSession(MHBRemoteImageSessionFactory.shared)
        } else {
            placeholder()
        }
    }
}
