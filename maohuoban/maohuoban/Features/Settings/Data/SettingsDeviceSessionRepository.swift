import Foundation

// DefaultSettingsDeviceSessionRepository 默认登录设备仓储
// 核心职责：
// - 使用 MHBHTTPClient 调用 Rust 账号设备接口
// - 统一附加 Authorization Bearer 请求头
struct DefaultSettingsDeviceSessionRepository: SettingsDeviceSessionRepository {
    let client: MHBHTTPClient
    let authorizationHeaderProvider: MHBAuthorizationHeaderProvider

    init(
        client: MHBHTTPClient = MHBHTTPClient(),
        authorizationHeaderProvider: MHBAuthorizationHeaderProvider = MHBAuthorizationHeaderProvider()
    ) {
        self.client = client
        self.authorizationHeaderProvider = authorizationHeaderProvider
    }

    func fetchDevices() async throws(MHBAPIError) -> MHBAPIResponse<SettingsDeviceSessionList> {
        try await client.get(
            path: "/api/v1/account/devices",
            headers: try authorizationHeaderProvider.headers()
        )
    }

    func fetchDeviceDetails(
        sessionID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<SettingsDeviceSessionDetails> {
        try await client.get(
            path: "/api/v1/account/devices/\(sessionID)",
            headers: try authorizationHeaderProvider.headers()
        )
    }

    func removeDevice(sessionID: String) async throws(MHBAPIError) -> MHBAPIResponse<MHBEmptyResponse> {
        try await client.delete(
            path: "/api/v1/account/devices/\(sessionID)",
            body: SettingsDeviceSessionEmptyRequest(),
            headers: try authorizationHeaderProvider.headers()
        )
    }
}

// SettingsDeviceSessionEmptyRequest 空请求体
// 核心职责：
// - 复用 JSON DELETE 发送路径
// - 承接只依赖路径和授权头的设备移除命令
private struct SettingsDeviceSessionEmptyRequest: Encodable {}
