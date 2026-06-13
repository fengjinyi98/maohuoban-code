import Foundation

// HomeRepository 首页数据仓库协议
// 核心职责：
// - 定义首页 Store 所需 API
// - 隔离 HTTP 客户端和展示层状态
protocol HomeRepository {
    func dashboard() async throws(MHBAPIError) -> MHBAPIResponse<HomeDashboardSnapshot>
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

    func dashboard() async throws(MHBAPIError) -> MHBAPIResponse<HomeDashboardSnapshot> {
        try await client.get(path: "/api/v1/home/dashboard")
    }
}

