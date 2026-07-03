import Foundation
@testable import maohuoban

// CurrentUserProfileRepositoryStub 当前用户资料仓储测试桩
// 核心职责：
// - 用固定响应驱动 ProfileUserEditStore 分支
// - 记录最后一次更新草稿供测试断言
@MainActor
final class CurrentUserProfileRepositoryStub: CurrentUserProfileRepository {
    var lastUpdateDraft: CurrentUserProfileUpdateDraft?
    var updateDrafts: [CurrentUserProfileUpdateDraft] = []
    var uploadedAvatarDrafts: [CurrentUserProfileMediaUploadDraft] = []
    var uploadedCoverDrafts: [CurrentUserProfileMediaUploadDraft] = []
    var avatarProgressValues: [Double] = []
    var coverProgressValues: [Double] = []
    private let loadResponse: MHBAPIResponse<CurrentUserProfile>
    private let updateResponse: MHBAPIResponse<CurrentUserProfile>

    init(
        loadResponse: MHBAPIResponse<CurrentUserProfile>? = nil,
        updateResponse: MHBAPIResponse<CurrentUserProfile>
    ) {
        self.loadResponse = loadResponse ?? updateResponse
        self.updateResponse = updateResponse
    }

    func loadCurrentProfile() async throws(MHBAPIError) -> MHBAPIResponse<CurrentUserProfile> {
        loadResponse
    }

    func updateCurrentProfile(
        draft: CurrentUserProfileUpdateDraft
    ) async throws(MHBAPIError) -> MHBAPIResponse<CurrentUserProfile> {
        lastUpdateDraft = draft
        updateDrafts.append(draft)
        return updateResponse
    }

    func uploadCurrentProfileAvatar(
        draft: CurrentUserProfileMediaUploadDraft,
        onUploadProgress: @escaping @MainActor @Sendable (Double) -> Void
    ) async throws(MHBAPIError) -> MHBAPIResponse<CurrentUserProfile> {
        uploadedAvatarDrafts.append(draft)
        onUploadProgress(0.25)
        avatarProgressValues.append(0.25)
        onUploadProgress(1.0)
        avatarProgressValues.append(1.0)
        return updateResponse
    }

    func uploadCurrentProfileCover(
        draft: CurrentUserProfileMediaUploadDraft,
        onUploadProgress: @escaping @MainActor @Sendable (Double) -> Void
    ) async throws(MHBAPIError) -> MHBAPIResponse<CurrentUserProfile> {
        uploadedCoverDrafts.append(draft)
        onUploadProgress(0.25)
        coverProgressValues.append(0.25)
        onUploadProgress(1.0)
        coverProgressValues.append(1.0)
        return updateResponse
    }
}
