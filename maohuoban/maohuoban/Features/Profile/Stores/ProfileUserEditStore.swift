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
    private(set) var mediaUploadProgress: Double?
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
        let targetDraft = updateDraft(displayName: normalizedDisplayName)
        guard !isNoopUpdateDraft(targetDraft) else {
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
        let targetDraft = updateDraft(bio: normalizedBio)
        guard !isNoopUpdateDraft(targetDraft) else {
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
        let targetDraft = updateDraft(gender: gender, isGenderVisible: isVisible)
        guard !isNoopUpdateDraft(targetDraft) else {
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
        let normalizedBirthday = birthday.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetDraft = updateDraft(birthday: normalizedBirthday)
        guard !isNoopUpdateDraft(targetDraft) else {
            toastMessage = nil
            return true
        }

        return await save(
            draft: CurrentUserProfileUpdateDraft(
                displayName: nil,
                bio: nil,
                gender: nil,
                isGenderVisible: nil,
                birthday: normalizedBirthday
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

    private func updateDraft(
        displayName: String? = nil,
        bio: String? = nil,
        gender: String? = nil,
        isGenderVisible: Bool? = nil,
        birthday: String? = nil
    ) -> ProfileUserEditComparableDraft {
        let currentDraft = currentUpdateDraft()
        return ProfileUserEditComparableDraft(
            displayName: displayName ?? currentDraft.displayName,
            bio: bio ?? currentDraft.bio,
            gender: gender ?? currentDraft.gender,
            isGenderVisible: isGenderVisible ?? currentDraft.isGenderVisible,
            birthday: birthday ?? currentDraft.birthday
        )
    }

    private func currentUpdateDraft() -> ProfileUserEditComparableDraft {
        ProfileUserEditComparableDraft(
            displayName: currentUserStore.displayName,
            bio: currentUserStore.bio,
            gender: currentUserStore.gender,
            isGenderVisible: currentUserStore.isGenderVisible,
            birthday: currentUserStore.birthday
        )
    }

    private func isNoopUpdateDraft(_ draft: ProfileUserEditComparableDraft) -> Bool {
        draft.isSemanticallyEquivalent(to: currentUpdateDraft())
    }

    private func uploadMedia(
        kind: ProfileUserEditMediaUploadKind,
        draft: CurrentUserProfileMediaUploadDraft
    ) async -> Bool {
        guard phase == .idle else {
            print("[DEBUG:ProfileMediaUpload] store upload rejected kind=\(kind.debugName) phase=\(phase)")
            return false
        }
        print("[DEBUG:ProfileMediaUpload] store upload started kind=\(kind.debugName) fileName=\(draft.fileName) mime=\(draft.mimeType) byteSize=\(draft.content.count)")
        phase = .saving
        mediaUploadProgress = 0
        toastMessage = nil
        defer { phase = .idle }

        do {
            let response: MHBAPIResponse<CurrentUserProfile>
            switch kind {
            case .avatar:
                response = try await repository.uploadCurrentProfileAvatar(
                    draft: draft,
                    onUploadProgress: { progress in
                        print("[DEBUG:ProfileMediaUpload] store upload progress kind=avatar progress=\(progress)")
                        self.mediaUploadProgress = progress
                    }
                )
            case .cover:
                response = try await repository.uploadCurrentProfileCover(
                    draft: draft,
                    onUploadProgress: { progress in
                        print("[DEBUG:ProfileMediaUpload] store upload progress kind=cover progress=\(progress)")
                        self.mediaUploadProgress = progress
                    }
                )
            }
            mediaUploadProgress = 1
            toastMessage = response.message
            print("[DEBUG:ProfileMediaUpload] store upload success kind=\(kind.debugName) code=\(response.code) message=\(response.message) hasData=\(response.data != nil)")
            if let profile = response.data {
                publish(profile: profile)
            }
            return true
        } catch {
            mediaUploadProgress = nil
            toastMessage = error.toastMessage
            print("[DEBUG:ProfileMediaUpload] store upload failed kind=\(kind.debugName) error=\(error.debugSummary) toast=\(error.toastMessage)")
            return false
        }
    }
}

private enum ProfileUserEditMediaUploadKind {
    case avatar
    case cover

    var debugName: String {
        switch self {
        case .avatar:
            "avatar"
        case .cover:
            "cover"
        }
    }
}

private extension MHBAPIError {
    var debugSummary: String {
        switch self {
        case .business(let code, let message, let statusCode):
            "business code=\(code) status=\(statusCode) message=\(message)"
        case .invalidResponse:
            "invalidResponse"
        case .transport(let message):
            "transport message=\(message)"
        case .decoding(let message):
            "decoding message=\(message)"
        }
    }
}

// ProfileUserEditComparableDraft 用户资料编辑语义草稿
// 核心职责：
// - 对齐宠物编辑页的当前草稿与目标草稿比较模式
// - 在请求前识别无变化保存，避免空 PATCH 与无意义 Toast
private struct ProfileUserEditComparableDraft: Equatable {
    let displayName: String
    let bio: String
    let gender: String
    let isGenderVisible: Bool
    let birthday: String?

    func isSemanticallyEquivalent(to other: ProfileUserEditComparableDraft) -> Bool {
        comparableValue == other.comparableValue
    }

    private var comparableValue: ComparableValue {
        ComparableValue(
            displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            bio: bio.trimmingCharacters(in: .whitespacesAndNewlines),
            gender: gender,
            isGenderVisible: isGenderVisible,
            birthday: normalizedOptionalText(birthday)
        )
    }

    private func normalizedOptionalText(_ value: String?) -> String? {
        guard let value else {
            return nil
        }
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    private struct ComparableValue: Equatable {
        let displayName: String
        let bio: String
        let gender: String
        let isGenderVisible: Bool
        let birthday: String?
    }
}
