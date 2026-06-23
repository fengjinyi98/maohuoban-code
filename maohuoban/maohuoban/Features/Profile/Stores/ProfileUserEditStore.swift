import Foundation
import Observation

// ProfileUserEditPhase 用户资料编辑请求阶段
// 核心职责：
// - 表达编辑页读取和保存中的互斥请求状态
// - 为 UI 禁用态和加载态提供稳定输入
enum ProfileUserEditPhase: Equatable {
    case idle
    case loading
    case saving
}

// ProfileUserEditStore 用户资料编辑状态源
// 核心职责：
// - 管理当前用户资料读取、保存和 Toast 文案
// - 将后端 profile 响应写回 CurrentUserStore 单一数据源
@MainActor
@Observable
final class ProfileUserEditStore {
    private(set) var profile: CurrentUserProfile?
    private(set) var phase: ProfileUserEditPhase = .idle
    var toastMessage: String?

    @ObservationIgnored private let repository: any CurrentUserProfileRepository
    @ObservationIgnored private let currentUserStore: CurrentUserStore

    var isBusy: Bool {
        phase != .idle
    }

    var displayNameEditPolicyText: String? {
        profile?.displayNameEditPolicy?.displayText
    }

    var bioEditPolicyText: String? {
        profile?.bioEditPolicy?.displayText
    }

    init(
        repository: any CurrentUserProfileRepository = DefaultCurrentUserProfileRepository(),
        currentUserStore: CurrentUserStore
    ) {
        self.repository = repository
        self.currentUserStore = currentUserStore
    }

    func load() async -> Bool {
        guard phase == .idle else { return false }
        phase = .loading
        defer { phase = .idle }

        do {
            let response = try await repository.loadCurrentProfile()
            if let profile = response.data {
                publish(profile: profile)
            }
            return true
        } catch {
            toastMessage = error.toastMessage
            return false
        }
    }

    func save(draft: CurrentUserProfileUpdateDraft) async -> Bool {
        guard phase == .idle else { return false }
        phase = .saving
        toastMessage = nil
        defer { phase = .idle }

        do {
            let response = try await repository.updateCurrentProfile(draft: draft)
            toastMessage = response.message
            if let profile = response.data {
                publish(profile: profile)
            }
            return true
        } catch {
            toastMessage = error.toastMessage
            return false
        }
    }

    func updateDisplayName(_ displayName: String) async -> Bool {
        let normalizedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedDisplayName != currentUserStore.displayName else {
            toastMessage = nil
            return true
        }

        return await save(
            draft: CurrentUserProfileUpdateDraft(
                displayName: normalizedDisplayName,
                bio: nil,
                gender: nil,
                isGenderVisible: nil,
                birthday: nil
            )
        )
    }

    func updateBio(_ bio: String) async -> Bool {
        let normalizedBio = bio.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedBio != currentUserStore.bio.trimmingCharacters(in: .whitespacesAndNewlines) else {
            toastMessage = nil
            return true
        }

        return await save(
            draft: CurrentUserProfileUpdateDraft(
                displayName: nil,
                bio: normalizedBio,
                gender: nil,
                isGenderVisible: nil,
                birthday: nil
            )
        )
    }

    func updateGender(_ gender: String, isVisible: Bool) async -> Bool {
        guard gender != currentUserStore.gender || isVisible != currentUserStore.isGenderVisible else {
            toastMessage = nil
            return true
        }

        return await save(
            draft: CurrentUserProfileUpdateDraft(
                displayName: nil,
                bio: nil,
                gender: gender,
                isGenderVisible: isVisible,
                birthday: nil
            )
        )
    }

    func updateBirthday(_ birthday: String) async -> Bool {
        guard birthday != currentUserStore.birthday else {
            toastMessage = nil
            return true
        }

        return await save(
            draft: CurrentUserProfileUpdateDraft(
                displayName: nil,
                bio: nil,
                gender: nil,
                isGenderVisible: nil,
                birthday: birthday
            )
        )
    }

    func uploadAvatar(draft: CurrentUserProfileMediaUploadDraft) async -> Bool {
        await uploadMedia(kind: .avatar, draft: draft)
    }

    func uploadCover(draft: CurrentUserProfileMediaUploadDraft) async -> Bool {
        await uploadMedia(kind: .cover, draft: draft)
    }

    private func publish(profile: CurrentUserProfile) {
        self.profile = profile
        currentUserStore.apply(profile: profile)
    }

    private func uploadMedia(
        kind: ProfileUserEditMediaUploadKind,
        draft: CurrentUserProfileMediaUploadDraft
    ) async -> Bool {
        guard phase == .idle else { return false }
        phase = .saving
        toastMessage = nil
        defer { phase = .idle }

        do {
            let response: MHBAPIResponse<CurrentUserProfile>
            switch kind {
            case .avatar:
                response = try await repository.uploadCurrentProfileAvatar(draft: draft)
            case .cover:
                response = try await repository.uploadCurrentProfileCover(draft: draft)
            }
            toastMessage = response.message
            if let profile = response.data {
                publish(profile: profile)
            }
            return true
        } catch {
            toastMessage = error.toastMessage
            return false
        }
    }
}

private enum ProfileUserEditMediaUploadKind {
    case avatar
    case cover
}
