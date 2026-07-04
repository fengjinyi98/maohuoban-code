import Foundation
import Observation

// PetRecordHistoryStore 宠物记录历史状态容器
// 核心职责：
// - 从宠物统一时间线接口加载完整记录列表
// - 将时间线条目映射为记录历史页展示状态
@MainActor
@Observable
final class PetRecordHistoryStore {
    var phase: PetRecordHistoryPhase = .idle

    private let repository: PetRepository
    private var requestSequence = 0
    private var activeLoadContext: PetRecordHistoryLoadContext?
    private var loadedContext: PetRecordHistoryLoadContext?
    private var failedContext: PetRecordHistoryLoadContext?

    init(repository: PetRepository = DefaultPetRepository()) {
        self.repository = repository
    }

    func load(
        petID: String?,
        currentUserID: String?,
        recordContext: PetRecordEntryContext,
        force: Bool = false
    ) async {
        guard let currentUserID, !currentUserID.isEmpty else {
            phase = .failed("请先登录")
            return
        }
        guard let petID, !petID.isEmpty else {
            phase = .failed("请先选择宠物")
            return
        }
        let context = PetRecordHistoryLoadContext(
            petID: petID,
            currentUserID: currentUserID
        )

        guard !shouldSkipLoad(context: context, force: force) else {
            return
        }

        let requestID = nextRequestID()
        activeLoadContext = context
        phase = .loading
        do {
            let response = try await repository.loadTimeline(
                petID: petID,
                currentUserID: currentUserID
            )
            guard isLatestRequest(requestID) else {
                return
            }
            let entries = response.data?.events ?? []
            activeLoadContext = nil
            loadedContext = context
            failedContext = nil
            phase = .loaded(entries.map { entry in
                PetRecordHistoryItemMapper.item(for: entry, context: recordContext)
            })
        } catch {
            guard isLatestRequest(requestID) else {
                return
            }
            activeLoadContext = nil
            loadedContext = nil
            failedContext = context
            phase = .failed(error.toastMessage)
        }
    }

    private func shouldSkipLoad(
        context: PetRecordHistoryLoadContext,
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

    private func nextRequestID() -> Int {
        requestSequence += 1
        return requestSequence
    }

    private func isLatestRequest(_ requestID: Int) -> Bool {
        requestID == requestSequence
    }
}

// PetRecordHistoryLoadContext 记录历史加载上下文
// 核心职责：
// - 标识一次记录历史请求对应的用户与宠物
// - 支持跳过 SwiftUI 生命周期触发的重复自动加载
private struct PetRecordHistoryLoadContext: Equatable {
    let petID: String?
    let currentUserID: String?

    init(
        petID: String?,
        currentUserID: String?
    ) {
        self.petID = Self.normalized(petID)
        self.currentUserID = Self.normalized(currentUserID)
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value, !value.isEmpty else {
            return nil
        }
        return value
    }
}
