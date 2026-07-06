import Foundation
@testable import maohuoban

// ScriptedHomeDashboardRepository 脚本化首页测试仓库
// 核心职责：
// - 按顺序返回预设首页请求结果
// - 记录首页 Store 实际发起的请求次数
@MainActor
final class ScriptedHomeDashboardRepository: HomeRepository {
    private var results: [Result<MHBAPIResponse<HomeDashboardSnapshot>, MHBAPIError>]
    private(set) var requestCount = 0

    init(results: [Result<MHBAPIResponse<HomeDashboardSnapshot>, MHBAPIError>]) {
        self.results = results
    }

    func dashboard(
        currentUserID: String?,
        selectedPetID: String?
    ) async throws(MHBAPIError) -> MHBAPIResponse<HomeDashboardSnapshot> {
        requestCount += 1
        let result = results.isEmpty
            ? Result<MHBAPIResponse<HomeDashboardSnapshot>, MHBAPIError>.failure(.transport("首页测试结果为空"))
            : results.removeFirst()
        switch result {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }
}
