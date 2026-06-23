import Foundation
import SwiftUI

// MHBRemoteMediaRequestFactory 远程媒体请求工厂
// 核心职责：
// - 统一构造 DesignSystem 远程图片和媒体下载请求
// - 将缓存策略和超时参数收敛到图片基础设施层
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
// - 为图片预览预加载提供统一下载入口
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
