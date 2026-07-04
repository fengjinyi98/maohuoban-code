import Foundation
import Observation

// PetPreventiveCareStore 疫苗驱虫记录状态模型
// 核心职责：
// - 从宠物时间线读取真实疫苗驱虫事件
// - 编排新增、更新和删除命令后刷新单一记录列表
@MainActor
@Observable
final class PetPreventiveCareStore {
    var phase: PetPreventiveCarePhase = .idle
    private(set) var isMutating = false

    private let repository: PetRepository

    init(repository: PetRepository = DefaultPetRepository()) {
        self.repository = repository
    }

    var records: [PetPreventiveCareRecord] {
        guard case .loaded(let records) = phase else { return [] }
        return records
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

        phase = .loading
        do {
            let response = try await repository.loadTimeline(
                petID: petID,
                currentUserID: currentUserID
            )
            let entries = response.data?.events ?? []
            phase = .loaded(PetPreventiveCareRecordMapper.records(from: entries))
        } catch {
            phase = .failed(error.toastMessage)
        }
    }

    func create(
        petID: String?,
        currentUserID: String?,
        draft: PetPreventiveCareDraft
    ) async -> Bool {
        guard let currentUserID, !currentUserID.isEmpty else {
            phase = .failed("请先登录")
            return false
        }
        guard let petID, !petID.isEmpty else {
            phase = .failed("请先选择宠物")
            return false
        }
        guard !isMutating else { return false }

        isMutating = true
        defer { isMutating = false }

        do {
            _ = try await repository.createEvent(
                petID: petID,
                draft: draft.eventDraft,
                currentUserID: currentUserID
            )
            await load(petID: petID, currentUserID: currentUserID)
            return true
        } catch {
            phase = .failed(error.toastMessage)
            return false
        }
    }

    func update(
        eventID: String,
        petID: String?,
        currentUserID: String?,
        draft: PetPreventiveCareDraft
    ) async -> Bool {
        guard let currentUserID, !currentUserID.isEmpty else {
            phase = .failed("请先登录")
            return false
        }
        guard !eventID.isEmpty else {
            phase = .failed("记录信息为空")
            return false
        }
        guard !isMutating else { return false }

        isMutating = true
        defer { isMutating = false }

        do {
            _ = try await repository.updateEvent(
                eventID: eventID,
                draft: draft.eventDraft,
                currentUserID: currentUserID
            )
            await load(petID: petID, currentUserID: currentUserID)
            return true
        } catch {
            phase = .failed(error.toastMessage)
            return false
        }
    }

    func delete(eventID: String, currentUserID: String?) async -> Bool {
        guard let currentUserID, !currentUserID.isEmpty else {
            phase = .failed("请先登录")
            return false
        }
        guard !eventID.isEmpty else {
            phase = .failed("记录信息为空")
            return false
        }
        guard !isMutating else { return false }

        isMutating = true
        defer { isMutating = false }

        do {
            let response = try await repository.deleteEvent(
                eventID: eventID,
                currentUserID: currentUserID
            )
            return response.data?.deleted == true
        } catch {
            phase = .failed(error.toastMessage)
            return false
        }
    }

    func removeRecord(id recordID: String) {
        guard case .loaded(let records) = phase else { return }
        phase = .loaded(records.filter { $0.id != recordID })
    }
}
