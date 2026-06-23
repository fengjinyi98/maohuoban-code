import Foundation
import Testing
@testable import MaohuobanDesignSystem

// MHBRemoteImageLoadingTests 远程图片加载测试
// 核心职责：
// - 固化 DesignSystem 远程图片请求与缓存策略
// - 保证图片预览预加载和远程图片组件复用统一下载入口
@Suite("MHBRemoteImage 远程加载")
struct MHBRemoteImageLoadingTests {
    @Test("默认请求使用协议缓存策略和统一超时")
    func requestUsesProtocolCachePolicyByDefault() throws {
        let url = try #require(URL(string: "https://img.maohuoban.test/pet.png"))

        let request = MHBRemoteMediaRequestFactory.request(url: url)

        #expect(request.url == url)
        #expect(request.cachePolicy == .useProtocolCachePolicy)
        #expect(request.timeoutInterval == 30)
    }

    @Test("共享 session 使用图片缓存容量")
    func sessionUsesSharedCacheConfiguration() {
        let configuration = MHBRemoteMediaSessionFactory.configuration()

        #expect(configuration.requestCachePolicy == .useProtocolCachePolicy)
        #expect(configuration.timeoutIntervalForRequest == 30)
        #expect(configuration.urlCache?.memoryCapacity == 24 * 1024 * 1024)
        #expect(configuration.urlCache?.diskCapacity == 256 * 1024 * 1024)
    }

    @Test("下载器使用传入 session 和请求策略")
    func dataLoaderUsesUnifiedRequestAndSession() async throws {
        let url = try #require(URL(string: "https://img.maohuoban.test/avatar.png"))
        let expectedData = Data("image-data".utf8)
        let requestBox = MHBRemoteMediaRequestBox()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MHBRemoteMediaURLProtocol.self]
        let session = URLSession(configuration: configuration)
        MHBRemoteMediaURLProtocol.handler = { request in
            requestBox.request = request
            return (
                HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "image/png"]
                )!,
                expectedData
            )
        }

        let data = try await MHBRemoteMediaDataLoader.data(
            from: url,
            cachePolicy: .returnCacheDataElseLoad,
            timeoutInterval: 12,
            session: session
        )

        #expect(data == expectedData)
        let request = try #require(requestBox.request)
        #expect(request.url == url)
        #expect(request.cachePolicy == .returnCacheDataElseLoad)
        #expect(request.timeoutInterval == 12)
        MHBRemoteMediaURLProtocol.handler = nil
    }
}

private final class MHBRemoteMediaRequestBox {
    var request: URLRequest?
}

private final class MHBRemoteMediaURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
