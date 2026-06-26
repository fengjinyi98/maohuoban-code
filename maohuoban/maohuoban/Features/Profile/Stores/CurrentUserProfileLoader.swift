import Foundation
import Observation

// CurrentUserProfileLoader 当前用户完整资料加载器
// 核心职责：
// - 通过仓储加载 GET /api/v1/profile/me 完整资料
// - 将后端响应写回 CurrentUserStore 单一数据源
// - 补全登录摘要中缺失的 cover 和其他完整字段
@MainActor
@Observable
final class CurrentUserProfileLoader {
    @ObservationIgnored private let repository: any CurrentUserProfileRepository
    @ObservationIgnored private let currentUserStore: CurrentUserStore

    init(
        repository: any CurrentUserProfileRepository = DefaultCurrentUserProfileRepository(),
        currentUserStore: CurrentUserStore
    ) {
        self.repository = repository
        self.currentUserStore = currentUserStore
    }

    func loadProfile() async {
        do {
            let response = try await repository.loadCurrentProfile()
            if let profile = response.data {
                currentUserStore.apply(profile: profile)
            }
        } catch {
            // 静默失败，不阻塞首屏展示
        }
    }
}
