import Foundation
import Observation

// PetAbnormalDetailStore 异常详情状态模型
// 核心职责：
// - 管理异常事件详情加载状态
// - 解析 event_payload 中的 episode_id、症状和严重程度
// - 提供追加观察和标记恢复的命令式入口
@MainActor
@Observable
final class PetAbnormalDetailStore {
    var phase: PetAbnormalDetailPhase = .idle
    var actionPhase: PetAbnormalDetailActionPhase = .idle
    private(set) var isMutating = false

    var isLoading: Bool { phase == .loading }
    var isSubmitting: Bool { actionPhase == .submitting }

    private let repository: PetRepository

    init(repository: PetRepository = DefaultPetRepository()) {
        self.repository = repository
    }

    // load 加载异常事件详情
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

    // addObservation 追加观察记录
    // 核心职责：
    // - 创建 symptom_followup 事件，自动关联到当前 episode
    func addObservation(
        petID: String,
        note: String,
        currentUserID: String?,
        lifeStatus: String?
    ) async {
        guard let currentUserID, !currentUserID.isEmpty else {
            actionPhase = .failed("请先登录")
            return
        }
        guard !petID.isEmpty else {
            actionPhase = .failed("请先选择宠物")
            return
        }
        guard actionPhase != .submitting else { return }

        actionPhase = .submitting
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        var payload: [String: PetEventPayloadValue] = [:]
        if !trimmedNote.isEmpty {
            payload["note"] = .string(trimmedNote)
        }
        if let episodeID = currentEpisodeID {
            payload["episode_id"] = .string(episodeID)
        }

        let draft = PetEventDraft(
            kind: .health,
            subkind: "symptom_followup",
            title: "追加观察",
            summary: trimmedNote.isEmpty ? "追加了一条观察记录" : trimmedNote,
            visibility: .private,
            occurredAt: PetWriteFormatters.occurredAtString(from: Date()),
            eventPayload: payload
        )

        do {
            let response = try await repository.createEvent(
                petID: petID,
                draft: draft,
                currentUserID: currentUserID
            )
            guard response.data != nil else {
                actionPhase = .failed("观察记录提交失败")
                return
            }
            actionPhase = .succeeded("观察记录已追加")
        } catch {
            actionPhase = .failed(error.toastMessage)
        }
    }

    // markRecovered 标记异常恢复
    // 核心职责：
    // - 创建 abnormal_recovery 事件，后端自动将 episode 标记为 recovered
    // - 后端自动将关联 attention_hint 标记为 resolved
    func markRecovered(
        petID: String,
        note: String,
        currentUserID: String?,
        lifeStatus: String?
    ) async {
        guard let currentUserID, !currentUserID.isEmpty else {
            actionPhase = .failed("请先登录")
            return
        }
        guard !petID.isEmpty else {
            actionPhase = .failed("请先选择宠物")
            return
        }
        guard actionPhase != .submitting else { return }

        actionPhase = .submitting
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        var payload: [String: PetEventPayloadValue] = [:]
        if !trimmedNote.isEmpty {
            payload["note"] = .string(trimmedNote)
        }
        if let episodeID = currentEpisodeID {
            payload["episode_id"] = .string(episodeID)
        }

        let draft = PetEventDraft(
            kind: .health,
            subkind: "abnormal_recovery",
            title: "标记恢复",
            summary: trimmedNote.isEmpty ? "异常已标记为恢复" : "已恢复：\(trimmedNote)",
            visibility: .private,
            occurredAt: PetWriteFormatters.occurredAtString(from: Date()),
            eventPayload: payload
        )

        do {
            let response = try await repository.createEvent(
                petID: petID,
                draft: draft,
                currentUserID: currentUserID
            )
            guard response.data != nil else {
                actionPhase = .failed("恢复标记提交失败")
                return
            }
            actionPhase = .succeeded("异常已标记为恢复")
        } catch {
            actionPhase = .failed(error.toastMessage)
        }
    }

    // delete 删除当前异常事件
    // 核心职责：
    // - 通过通用宠物事件删除接口移除异常记录
    // - 让详情页基于 phase 完成删除后的关闭或反馈
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

    private var currentEpisodeID: String? {
        guard case .loaded(let event) = phase else { return nil }
        return event.eventPayload?.episodeID
    }
}

// PetAbnormalDetailPhase 异常详情加载阶段
enum PetAbnormalDetailPhase: Equatable {
    case idle
    case loading
    case loaded(PetEventDetail)
    case deleted(String)
    case failed(String)
}

// PetAbnormalDetailActionPhase 异常动作提交阶段
enum PetAbnormalDetailActionPhase: Equatable {
    case idle
    case submitting
    case succeeded(String)
    case failed(String)
}
