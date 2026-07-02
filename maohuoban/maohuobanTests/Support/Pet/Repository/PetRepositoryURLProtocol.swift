import Foundation
@testable import maohuoban

// PetRepositoryURLProtocol 宠物仓库测试协议桩
// 核心职责：
// - 拦截 URLSession 请求
// - 将请求交给测试断言并返回固定响应
final class PetRepositoryURLProtocol: URLProtocol {
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

// PetRepositoryTestTokenStore 宠物仓库测试 token 存储
// 核心职责：
// - 为仓库契约测试提供固定 Authorization 请求头
// - 避免测试读取真实 Keychain 登录状态
struct PetRepositoryTestTokenStore: MHBTokenStore {
    func loadTokens() throws -> MHBStoredTokens? {
        MHBStoredTokens(
            accessToken: "test-access-token",
            refreshToken: "test-refresh-token",
            tokenType: "Bearer",
            expiresInSeconds: 3600,
            refreshExpiresInSeconds: 86_400
        )
    }

    func saveTokens(_ tokens: MHBStoredTokens) throws {}

    func clearTokens() throws {}
}

extension URLRequest {
    func bodyDataForPetRepositoryTest() -> Data? {
        if let httpBody {
            return httpBody
        }
        guard let httpBodyStream else {
            return nil
        }

        httpBodyStream.open()
        defer { httpBodyStream.close() }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while httpBodyStream.hasBytesAvailable {
            let readCount = httpBodyStream.read(&buffer, maxLength: buffer.count)
            if readCount < 0 {
                return nil
            }
            if readCount == 0 {
                break
            }
            data.append(buffer, count: readCount)
        }
        return data
    }
}
