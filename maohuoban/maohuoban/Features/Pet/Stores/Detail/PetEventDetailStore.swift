import Foundation
import Observation

// PetEventDetailStore 宠物事件详情状态模型
// 核心职责：
// - 管理宠物事件详情加载状态
// - 承接当前用户和事件 ID 校验及 Repository 调用
@MainActor
@Observable
final class PetEventDetailStore {
    var phase: PetEventDetailPhase = .idle
    private(set) var isMutating = false

    var isLoading: Bool {
        phase == .loading
    }

    private let repository: PetRepository

    init(repository: PetRepository = DefaultPetRepository()) {
        self.repository = repository
    }

    func load(eventID: String, currentUserID: String?) async {
        guard let currentUserID, !currentUserID.isEmpty else {
            phase = .failed("请先登录")
            return
        }
        guard !eventID.isEmpty else {
            phase = .failed("事件信息为空")
            return
        }
        guard phase != .loading else { return }

        phase = .loading
        do {
            let response = try await repository.loadEventDetail(
                eventID: eventID,
                currentUserID: currentUserID
            )
            guard let event = response.data else {
                phase = .failed("事件详情为空")
                return
            }
            phase = .loaded(event)
        } catch {
            phase = .failed(error.toastMessage)
        }
    }

    // delete 删除当前宠物事件
    // 核心职责：
    // - 通过通用宠物事件删除接口移除当前记录
    // - 将删除结果写回 phase 供详情页单向渲染
    func delete(eventID: String, currentUserID: String?) async -> Bool {
        guard let currentUserID, !currentUserID.isEmpty else {
            phase = .failed("请先登录")
            return false
        }
        guard !eventID.isEmpty else {
            phase = .failed("事件信息为空")
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
            guard response.data?.deleted == true else { return false }
            phase = .deleted(eventID)
            return true
        } catch {
            phase = .failed(error.toastMessage)
            return false
        }
    }
}

// PetEventDetailPhase 宠物事件详情加载阶段
// 核心职责：
// - 表达空闲、加载、成功和失败状态
// - 支持详情页基于单一状态渲染反馈
enum PetEventDetailPhase: Equatable {
    case idle
    case loading
    case loaded(PetEventDetail)
    case deleted(String)
    case failed(String)
}
