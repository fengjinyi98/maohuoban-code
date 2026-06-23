import Foundation

// MHBHTTPHeader 后端请求头约定
// 核心职责：
// - 固化前后端链路追踪和鉴权 header 名称
// - 避免业务代码散写大小写不一致的字符串
enum MHBHTTPHeader {
    static let authorization = "Authorization"
    static let idempotencyKey = "Idempotency-Key"
    static let requestID = "x-request-id"
    static let traceparent = "traceparent"
}

// MHBHTTPClientSessionFactory API 请求会话工厂
// 核心职责：
// - 为业务 API 提供独立 URLSession 配置
// - 统一 timeout、缓存、蜂窝和网络连通策略
enum MHBHTTPClientSessionFactory {
    static let shared: URLSession = URLSession(configuration: configuration())

    static func configuration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.waitsForConnectivity = true
        configuration.allowsCellularAccess = true
        configuration.allowsConstrainedNetworkAccess = true
        configuration.allowsExpensiveNetworkAccess = true
        return configuration
    }
}

// MHBHTTPAuthorizationProvider HTTP 鉴权头提供协议
// 核心职责：
// - 让 HTTP client 在发送边界统一补齐认证头
// - 保留测试和不同 token 来源的注入能力
protocol MHBHTTPAuthorizationProvider {
    func authorizationHeaders() throws(MHBAPIError) -> [String: String]
}

// MHBHTTPTokenRefreshHandler HTTP token 刷新处理协议
// 核心职责：
// - 在 access token 失效后统一刷新并生成新的认证头
// - 让 HTTP client 可重放原请求而不泄露 refresh 细节
protocol MHBHTTPTokenRefreshHandler {
    func refreshAuthorizationHeaders() async throws(MHBAPIError) -> [String: String]
}

extension MHBAuthorizationHeaderProvider: MHBHTTPAuthorizationProvider, MHBHTTPTokenRefreshHandler {
    func authorizationHeaders() throws(MHBAPIError) -> [String: String] { try headers() }
}

// MHBHTTPRetryPolicy HTTP 重试策略
// 核心职责：
// - 判断传输错误和短暂服务端错误是否允许重试
// - 为写请求配合幂等键提供安全重试边界
struct MHBHTTPRetryPolicy {
    let maxAttempts: Int
    let baseDelay: TimeInterval
    let retryableStatusCodes: Set<Int>
    let retryableURLErrorCodes: Set<URLError.Code>

    static let disabled = MHBHTTPRetryPolicy(
        maxAttempts: 1,
        baseDelay: 0,
        retryableStatusCodes: [],
        retryableURLErrorCodes: []
    )

    static let `default` = MHBHTTPRetryPolicy(
        maxAttempts: 3,
        baseDelay: 0.35,
        retryableStatusCodes: [408, 429, 500, 502, 503, 504],
        retryableURLErrorCodes: [
            .timedOut,
            .cannotConnectToHost,
            .cannotFindHost,
            .dnsLookupFailed,
            .networkConnectionLost
        ]
    )

    static func immediate(maxAttempts: Int) -> MHBHTTPRetryPolicy {
        MHBHTTPRetryPolicy(
            maxAttempts: max(maxAttempts, 1),
            baseDelay: 0,
            retryableStatusCodes: Self.default.retryableStatusCodes,
            retryableURLErrorCodes: Self.default.retryableURLErrorCodes
        )
    }

    func shouldRetry(response: HTTPURLResponse, request: URLRequest) -> Bool {
        retryableStatusCodes.contains(response.statusCode) && request.isRetrySafe
    }

    func shouldRetry(error: Error, request: URLRequest) -> Bool {
        guard let urlError = error as? URLError else {
            return false
        }
        return retryableURLErrorCodes.contains(urlError.code) && request.isRetrySafe
    }

    func delayBeforeRetry(afterAttempt attempt: Int) -> TimeInterval {
        guard baseDelay > 0 else {
            return 0
        }
        return baseDelay * pow(2, Double(max(attempt - 1, 0)))
    }
}

private extension URLRequest {
    var isRetrySafe: Bool {
        let method = httpMethod?.uppercased() ?? "GET"
        if ["GET", "HEAD", "OPTIONS"].contains(method) {
            return true
        }
        return value(forHTTPHeaderField: MHBHTTPHeader.idempotencyKey)?.isEmpty == false
    }
}

// MHBHTTPNetworkSummaryBuilder 网络诊断摘要构造器
// 核心职责：
// - 对诊断 URL 做敏感 query 脱敏
// - 合并请求和响应中的 request id 便于前后端日志串联
enum MHBHTTPNetworkSummaryBuilder {
    private static let sensitiveQueryKeys: Set<String> = [
        "access_token",
        "authorization",
        "code",
        "id_token",
        "lat",
        "latitude",
        "lng",
        "location",
        "longitude",
        "password",
        "phone",
        "refresh_token",
        "token"
    ]

    static func redactedURLString(from url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              !queryItems.isEmpty else {
            return url.absoluteString
        }
        components.queryItems = queryItems.map { item in
            guard sensitiveQueryKeys.contains(item.name.lowercased()) else {
                return item
            }
            return URLQueryItem(name: item.name, value: "[REDACTED]")
        }
        return components.string ?? url.absoluteString
    }

    static func metadata(
        request: URLRequest,
        response: URLResponse?,
        responseData: Data?,
        requestBodyBytes: Int?
    ) -> [String: String] {
        var metadata: [String: String] = [:]
        metadata["network_capture_source"] = "http_client"
        if let requestID = request.value(forHTTPHeaderField: MHBHTTPHeader.requestID) {
            metadata["request_id"] = requestID
        }
        if let responseRequestID = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: MHBHTTPHeader.requestID) {
            metadata["response_request_id"] = responseRequestID
        }
        if let requestBodyBytes = requestBodyBytes ?? request.httpBody?.count {
            metadata["request_body_bytes"] = String(requestBodyBytes)
        }
        if let responseBodyBytes = responseData?.count {
            metadata["response_body_bytes"] = String(responseBodyBytes)
        }
        if let mimeType = response?.mimeType, !mimeType.isEmpty {
            metadata["response_mime_type"] = mimeType
        }
        let requestHeaderKeys = (request.allHTTPHeaderFields ?? [:]).keys.sorted()
        if !requestHeaderKeys.isEmpty {
            metadata["request_header_keys"] = requestHeaderKeys.joined(separator: ",")
        }
        if let httpResponse = response as? HTTPURLResponse {
            let responseHeaderKeys = httpResponse.allHeaderFields.keys
                .compactMap { $0 as? String }
                .sorted()
            if !responseHeaderKeys.isEmpty {
                metadata["response_header_keys"] = responseHeaderKeys.joined(separator: ",")
            }
        }
        return metadata
    }
}

// MHBTokenRefreshService token 刷新服务协议
// 核心职责：
// - 抽象 refresh token 换取新会话的网络能力
// - 让刷新单飞协调器与具体认证仓库解耦
protocol MHBTokenRefreshService {
    func refresh(currentTokens: MHBStoredTokens) async throws(MHBAPIError) -> MHBStoredTokens
}

// MHBDefaultTokenRefreshService 默认 token 刷新服务
// 核心职责：
// - 调用后端 refresh 接口换取新的 access token
// - 将认证领域响应转换为基础设施 token 模型
struct MHBDefaultTokenRefreshService: MHBTokenRefreshService {
    private let client: MHBHTTPClient
    private let deviceIDStore: MHBDeviceIDStore

    init(
        baseURL: URL = MHBBackendEndpoint.localDevelopmentBaseURL,
        session: URLSession = MHBHTTPClientSessionFactory.shared,
        deviceIDStore: MHBDeviceIDStore = MHBDeviceIDStore(),
        retryPolicy: MHBHTTPRetryPolicy = .default
    ) {
        self.client = MHBHTTPClient(
            baseURL: baseURL,
            session: session,
            retryPolicy: retryPolicy
        )
        self.deviceIDStore = deviceIDStore
    }

    func refresh(currentTokens: MHBStoredTokens) async throws(MHBAPIError) -> MHBStoredTokens {
        let response: MHBAPIResponse<MHBTokenRefreshPayload> = try await client.post(
            path: "/api/v1/auth/refresh",
            body: MHBRefreshTokenPayload(
                refreshToken: currentTokens.refreshToken,
                deviceID: deviceIDStore.currentDeviceID()
            )
        )
        guard let payload = response.data else {
            throw .invalidResponse
        }
        return payload.storedTokens
    }
}

// MHBRefreshTokenPayload refresh 请求载荷
// 核心职责：
// - 提交 refresh token
// - 携带当前设备 id 绑定后端设备会话
private struct MHBRefreshTokenPayload: Encodable {
    let refreshToken: String
    let deviceID: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
        case deviceID = "device_id"
    }
}

// MHBTokenRefreshPayload refresh 响应载荷
// 核心职责：
// - 解码后端返回的新 token 字段
// - 忽略用户资料等刷新链路不需要的额外字段
private struct MHBTokenRefreshPayload: Decodable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresInSeconds: Int
    let refreshExpiresInSeconds: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresInSeconds = "expires_in_seconds"
        case refreshExpiresInSeconds = "refresh_expires_in_seconds"
    }

    var storedTokens: MHBStoredTokens {
        MHBStoredTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
            tokenType: tokenType,
            expiresInSeconds: expiresInSeconds,
            refreshExpiresInSeconds: refreshExpiresInSeconds
        )
    }
}

// MHBTokenRefreshCoordinator token 刷新单飞协调器
// 核心职责：
// - 合并并发 401 触发的 token refresh 请求
// - 刷新成功后统一写回 token store
@MainActor
final class MHBTokenRefreshCoordinator {
    private var inFlight: Task<MHBStoredTokens, Error>?

    func refresh(
        currentTokens: MHBStoredTokens,
        tokenStore: MHBTokenStore,
        service: MHBTokenRefreshService
    ) async throws(MHBAPIError) -> MHBStoredTokens {
        if let inFlight {
            return try await resolve(inFlight)
        }

        let task = Task { @MainActor in
            let refreshedTokens = try await service.refresh(currentTokens: currentTokens)
            try tokenStore.saveTokens(refreshedTokens)
            return refreshedTokens
        }
        inFlight = task
        do {
            let tokens = try await resolve(task)
            inFlight = nil
            return tokens
        } catch {
            inFlight = nil
            throw error
        }
    }

    private func resolve(_ task: Task<MHBStoredTokens, Error>) async throws(MHBAPIError) -> MHBStoredTokens {
        do {
            return try await task.value
        } catch let error as MHBAPIError {
            throw error
        } catch {
            throw .transport(error.localizedDescription)
        }
    }
}
