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
    private var activeLoadContext: HomeDashboardLoadContext?
    private var loadedContext: HomeDashboardLoadContext?
    private var failedContext: HomeDashboardLoadContext?

    init(repository: HomeRepository = HomeRepositoryFactory.makeDefault()) {
        self.repository = repository
    }

    // load 加载首页聚合快照
    // 核心职责：
    // - 为测试和旧调用点提供稳定的两参入口
    // - 复用带 force 参数的主加载流程
    func load(
        currentUserID: String? = nil,
        selectedPetID: String? = nil
    ) async {
        await load(
            currentUserID: currentUserID,
            selectedPetID: selectedPetID,
            force: false
        )
    }

    func load(
        currentUserID: String? = nil,
        selectedPetID: String? = nil,
        force: Bool = false
    ) async {
        let context = HomeDashboardLoadContext(
            currentUserID: currentUserID,
            selectedPetID: selectedPetID
        )

        guard !shouldSkipLoad(context: context, force: force) else {
            return
        }

        let requestID = nextDashboardRequestID()
        activeLoadContext = context
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
                activeLoadContext = nil
                failedContext = context
                phase = .failed("首页数据为空")
                return
            }
            activeLoadContext = nil
            loadedContext = context
            failedContext = nil
            phase = .loaded(snapshot.resolvingClientOwnedQuickActions())
        } catch {
            guard isLatestDashboardRequest(requestID) else {
                return
            }
            activeLoadContext = nil
            loadedContext = nil
            failedContext = context
            phase = .failed(error.toastMessage)
        }
    }

    func selectPet(currentUserID: String? = nil, petID: String) async {
        guard case .loaded(let currentSnapshot) = phase else {
            await load(currentUserID: currentUserID, selectedPetID: petID, force: true)
            return
        }

        guard currentSnapshot.selectedPet?.id != petID else {
            return
        }

        let context = HomeDashboardLoadContext(
            currentUserID: currentUserID,
            selectedPetID: petID
        )
        let requestID = nextDashboardRequestID()
        activeLoadContext = context

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
                activeLoadContext = nil
                return
            }
            activeLoadContext = nil
            loadedContext = context
            failedContext = nil
            phase = .loaded(snapshot.resolvingClientOwnedQuickActions())
        } catch {
            guard isLatestDashboardRequest(requestID) else {
                return
            }
            activeLoadContext = nil
        }
    }

    private func shouldSkipLoad(
        context: HomeDashboardLoadContext,
        force: Bool
    ) -> Bool {
        if activeLoadContext == context {
            return true
        }

        guard !force else {
            return false
        }

        switch phase {
        case .idle:
            return false
        case .loading:
            return false
        case .loaded:
            return loadedContext == context
        case .failed:
            return failedContext == context
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

// HomeDashboardLoadContext 首页加载上下文
// 核心职责：
// - 标识一次首页聚合请求对应的用户与选中宠物
// - 支持 Store 跳过 SwiftUI 生命周期触发的重复自动加载
private struct HomeDashboardLoadContext: Equatable {
    let currentUserID: String?
    let selectedPetID: String?

    init(
        currentUserID: String?,
        selectedPetID: String?
    ) {
        self.currentUserID = Self.normalized(currentUserID)
        self.selectedPetID = Self.normalized(selectedPetID)
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value, !value.isEmpty else {
            return nil
        }
        return value
    }
}
