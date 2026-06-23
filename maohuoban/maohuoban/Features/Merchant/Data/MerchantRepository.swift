import Foundation

// MerchantRepository 商家读写仓库协议
// 核心职责：
// - 定义商家工作台读写 API
// - 隔离 HTTP 客户端和展示层状态
protocol MerchantRepository {
    func listPets(
        merchantID: String,
        status: MerchantPetStatus,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<MerchantPetList>

    func createPet(
        merchantID: String,
        draft: MerchantPetDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<MerchantManagedPet>

    func loadLitterDetail(
        merchantID: String,
        litterID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<MerchantLitterDetail>

    func publishAvailableStatus(
        merchantID: String,
        petID: String,
        draft: MerchantAvailableStatusDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<MerchantAvailableStatusPublication>
}

// DefaultMerchantRepository 默认商家读写仓库
// 核心职责：
// - 使用 MHBHTTPClient 调用 Rust 商家接口
// - 在商家请求中传递当前用户上下文和业务筛选
struct DefaultMerchantRepository: MerchantRepository {
    private let client: MHBHTTPClient

    init(
        client: MHBHTTPClient = MHBHTTPClient.authenticated()
    ) {
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
            headers: try userHeaders(currentUserID: currentUserID)
        )
    }

    func createPet(
        merchantID: String,
        draft: MerchantPetDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<MerchantManagedPet> {
        try await client.post(
            path: "/api/v1/merchants/\(merchantID)/pets",
            body: draft,
            headers: try userHeaders(currentUserID: currentUserID)
        )
    }

    func loadLitterDetail(
        merchantID: String,
        litterID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<MerchantLitterDetail> {
        try await client.get(
            path: "/api/v1/merchants/\(merchantID)/litters/\(litterID)",
            headers: try userHeaders(currentUserID: currentUserID)
        )
    }

    func publishAvailableStatus(
        merchantID: String,
        petID: String,
        draft: MerchantAvailableStatusDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<MerchantAvailableStatusPublication> {
        try await client.post(
            path: "/api/v1/merchants/\(merchantID)/pets/\(petID)/available-status",
            body: draft,
            headers: try userHeaders(currentUserID: currentUserID)
        )
    }

    private func userHeaders(currentUserID: String) throws(MHBAPIError) -> [String: String] {
        guard !currentUserID.isEmpty else {
            throw .business(
                code: "auth.session_expired",
                message: "登录状态已过期，请重新登录",
                statusCode: 401
            )
        }
        return ["x-maohuoban-user-id": currentUserID]
    }
}
