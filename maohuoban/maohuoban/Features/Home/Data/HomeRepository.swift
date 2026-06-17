import Foundation

// HomeRepository 首页数据仓库协议
// 核心职责：
// - 定义首页 Store 所需 API
// - 隔离 HTTP 客户端和展示层状态
protocol HomeRepository {
    func dashboard(
        currentUserID: String?,
        selectedPetID: String?
    ) async throws(MHBAPIError) -> MHBAPIResponse<HomeDashboardSnapshot>
}

// DefaultHomeRepository 默认首页数据仓库
// 核心职责：
// - 使用 MHBHTTPClient 调用 Rust 后端首页接口
// - 返回后端聚合好的首页快照
struct DefaultHomeRepository: HomeRepository {
    private let client: MHBHTTPClient

    init(client: MHBHTTPClient = MHBHTTPClient()) {
        self.client = client
    }

    func dashboard(
        currentUserID: String?,
        selectedPetID: String?
    ) async throws(MHBAPIError) -> MHBAPIResponse<HomeDashboardSnapshot> {
        var headers: [String: String] = [:]
        if let currentUserID {
            headers["x-maohuoban-user-id"] = currentUserID
        }
        let queryItems = selectedPetID
            .flatMap { $0.isEmpty ? nil : URLQueryItem(name: "selected_pet_id", value: $0) }
            .map { [$0] } ?? []
        return try await client.get(
            path: "/api/v1/home/dashboard",
            queryItems: queryItems,
            headers: headers
        )
    }
}

// SupplementedHomeRepository 首页开发态补全仓库
// 核心职责：
// - 优先返回后端真实首页快照
// - 用 Mock 快照补齐后端尚未接入的展示 section
struct SupplementedHomeRepository: HomeRepository {
    private let primary: HomeRepository
    private let fallback: HomeRepository

    init(
        primary: HomeRepository,
        fallback: HomeRepository
    ) {
        self.primary = primary
        self.fallback = fallback
    }

    func dashboard(
        currentUserID: String?,
        selectedPetID: String?
    ) async throws(MHBAPIError) -> MHBAPIResponse<HomeDashboardSnapshot> {
        let primaryResponse = try await primary.dashboard(
            currentUserID: currentUserID,
            selectedPetID: selectedPetID
        )
        guard let primarySnapshot = primaryResponse.data else {
            return primaryResponse
        }

        let fallbackResponse = try? await fallback.dashboard(
            currentUserID: currentUserID,
            selectedPetID: selectedPetID
        )
        let fallbackSnapshot = fallbackResponse?.data

        guard let fallbackSnapshot else {
            return primaryResponse
        }

        let supplementedSnapshot = primarySnapshot.supplementingMissingSections(from: fallbackSnapshot)
        return MHBAPIResponse(
            success: primaryResponse.success,
            code: primaryResponse.code,
            message: primaryResponse.message,
            data: supplementedSnapshot
        )
    }
}
