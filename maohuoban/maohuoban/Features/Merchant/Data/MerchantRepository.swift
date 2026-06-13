import Foundation

// MerchantRepository 商家读取仓库协议
// 核心职责：
// - 定义商家工作台读取 API
// - 隔离 HTTP 客户端和展示层状态
protocol MerchantRepository {
    func listPets(
        merchantID: String,
        status: MerchantPetStatus,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<MerchantPetList>
}

// DefaultMerchantRepository 默认商家读取仓库
// 核心职责：
// - 使用 MHBHTTPClient 调用 Rust 商家接口
// - 在读取请求中传递当前用户上下文和状态筛选
struct DefaultMerchantRepository: MerchantRepository {
    private let client: MHBHTTPClient

    init(client: MHBHTTPClient = MHBHTTPClient()) {
        self.client = client
    }

    func listPets(
        merchantID: String,
        status: MerchantPetStatus,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<MerchantPetList> {
        try await client.get(
            path: "/api/v1/merchants/\(merchantID)/pets",
            queryItems: [
                URLQueryItem(name: "status", value: status.rawValue)
            ],
            headers: userHeaders(currentUserID: currentUserID)
        )
    }

    private func userHeaders(currentUserID: String) -> [String: String] {
        ["x-maohuoban-user-id": currentUserID]
    }
}
