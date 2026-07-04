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

    init(repository: PetRepository = DefaultPetRepository()) {
        self.repository = repository
    }

    func load(petID: String?, currentUserID: String?) async {
        guard let currentUserID, !currentUserID.isEmpty else {
            phase = .failed("请先登录")
            return
        }
        guard let petID, !petID.isEmpty else {
            phase = .failed("请先选择宠物")
            return
        }
        guard phase != .loading else { return }

        phase = .loading
        do {
            let response = try await repository.loadTimeline(
                petID: petID,
                currentUserID: currentUserID
            )
            let entries = response.data?.events ?? []
            phase = .loaded(entries.map(PetRecordHistoryItemMapper.item))
        } catch {
            phase = .failed(error.toastMessage)
        }
    }
}
