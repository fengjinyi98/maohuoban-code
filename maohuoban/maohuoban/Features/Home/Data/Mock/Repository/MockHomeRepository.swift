import Foundation

// MockHomeRepository 首页 Mock 数据仓库
// 核心职责：
// - 为 UI 快速开发提供稳定首页快照
// - 保持与真实 HomeRepository 相同的调用边界
struct MockHomeRepository: HomeRepository {
    private let scenario: HomeMockScenario
    private let latency: Duration

    init(
        scenario: HomeMockScenario = .current(),
        latency: Duration = .milliseconds(180)
    ) {
        self.scenario = scenario
        self.latency = latency
    }

    func dashboard(
        currentUserID: String?,
        selectedPetID: String?
    ) async throws(MHBAPIError) -> MHBAPIResponse<HomeDashboardSnapshot> {
        do {
            try await Task.sleep(for: latency)
        } catch {
            throw MHBAPIError.transport("首页 Mock 请求已取消")
        }

        let snapshot = HomeMockDashboardFixtures.snapshot(
            scenario: scenario,
            selectedPetID: selectedPetID
        )

        return MHBAPIResponse(
            success: true,
            code: "mock.home.dashboard.loaded",
            message: "首页 Mock 数据已加载",
            data: snapshot
        )
    }
}
