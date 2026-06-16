import Foundation
import Observation

// HomeDashboardStore 首页聚合状态模型
// 核心职责：
// - 管理首页快照加载状态
// - 通过 Repository 获取后端聚合读模型
@MainActor
@Observable
final class HomeDashboardStore {
    var phase: HomeDashboardPhase = .idle

    private let repository: HomeRepository
    private var dashboardRequestSequence = 0

    init(repository: HomeRepository = HomeRepositoryFactory.makeDefault()) {
        self.repository = repository
    }

    func load(currentUserID: String? = nil, selectedPetID: String? = nil) async {
        guard phase != .loading else {
            return
        }

        let requestID = nextDashboardRequestID()
        phase = .loading
        do {
            let response = try await repository.dashboard(
                currentUserID: currentUserID,
                selectedPetID: selectedPetID
            )
            guard isLatestDashboardRequest(requestID) else {
                return
            }
            guard let snapshot = response.data else {
                phase = .failed("首页数据为空")
                return
            }
            phase = .loaded(snapshot)
        } catch {
            guard isLatestDashboardRequest(requestID) else {
                return
            }
            phase = .failed(error.toastMessage)
        }
    }

    func selectPet(currentUserID: String? = nil, petID: String) async {
        guard case .loaded(let currentSnapshot) = phase else {
            await load(currentUserID: currentUserID, selectedPetID: petID)
            return
        }

        guard currentSnapshot.selectedPet?.id != petID else {
            return
        }

        let requestID = nextDashboardRequestID()

        if let optimisticSnapshot = currentSnapshot.optimisticallySelectingPet(id: petID) {
            phase = .loaded(optimisticSnapshot)
        }

        do {
            let response = try await repository.dashboard(
                currentUserID: currentUserID,
                selectedPetID: petID
            )
            guard isLatestDashboardRequest(requestID) else {
                return
            }
            guard let snapshot = response.data else {
                return
            }
            phase = .loaded(snapshot)
        } catch {
            guard isLatestDashboardRequest(requestID) else {
                return
            }
        }
    }

    private func nextDashboardRequestID() -> Int {
        dashboardRequestSequence += 1
        return dashboardRequestSequence
    }

    private func isLatestDashboardRequest(_ requestID: Int) -> Bool {
        requestID == dashboardRequestSequence
    }
}

// HomeDashboardPhase 首页加载阶段
// 核心职责：
// - 表达首页加载、成功和失败状态
// - 让 View 通过单一状态渲染
enum HomeDashboardPhase: Equatable {
    case idle
    case loading
    case loaded(HomeDashboardSnapshot)
    case failed(String)
}
