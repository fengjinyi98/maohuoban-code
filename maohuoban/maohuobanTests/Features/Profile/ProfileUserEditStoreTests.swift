import XCTest
@testable import maohuoban

// ProfileUserEditStoreTests 用户资料编辑状态测试
// 核心职责：
// - 固化资料编辑成功后写回 CurrentUserStore 的单向数据流
// - 验证后端 message 作为 Toast 文案向展示层暴露
@MainActor
final class ProfileUserEditStoreTests: XCTestCase {
    func testSaveProfilePublishesRemoteProfileIntoCurrentUserStore() async {
        let currentUserStore = CurrentUserStore()
        currentUserStore.apply(session: Self.authSession(displayName: "旧昵称"))
        let repository = CurrentUserProfileRepositoryStub(
            updateResponse: MHBAPIResponse(
                success: true,
                code: "profile.updated",
                message: "个人资料已更新",
                data: Self.remoteProfile(displayName: "橘子午后")
            )
        )
        let store = ProfileUserEditStore(
            repository: repository,
            currentUserStore: currentUserStore
        )

        let saved = await store.save(
            draft: CurrentUserProfileUpdateDraft(
                displayName: "橘子午后",
                bio: "记录两只毛孩子的日常。",
                gender: "female",
                isGenderVisible: false,
                birthday: "1999-12-31"
            )
        )

        XCTAssertTrue(saved)
        XCTAssertEqual(repository.lastUpdateDraft?.displayName, "橘子午后")
        XCTAssertEqual(store.toastMessage, "个人资料已更新")
        XCTAssertEqual(store.profile?.displayName, "橘子午后")
        XCTAssertEqual(currentUserStore.displayName, "橘子午后")
        XCTAssertEqual(currentUserStore.bio, "记录两只毛孩子的日常。")
        XCTAssertEqual(currentUserStore.gender, "female")
        XCTAssertFalse(currentUserStore.isGenderVisible)
        XCTAssertEqual(currentUserStore.birthday, "1999-12-31")
        XCTAssertEqual(currentUserStore.avatarPresentation.sex, .unknown)
        XCTAssertEqual(currentUserStore.avatarPresentation.sexVisibility, .hidden)
    }

    func testFieldCommandsSubmitPartialPatchDrafts() async {
        let currentUserStore = CurrentUserStore()
        currentUserStore.apply(session: Self.authSession(displayName: "旧昵称"))
        let repository = CurrentUserProfileRepositoryStub(
            updateResponse: MHBAPIResponse(
                success: true,
                code: "profile.updated",
                message: "个人资料已更新",
                data: nil
            )
        )
        let store = ProfileUserEditStore(
            repository: repository,
            currentUserStore: currentUserStore
        )

        _ = await store.updateDisplayName("橘子午后")
        _ = await store.updateBio("记录两只毛孩子的日常。")
        _ = await store.updateGender("female", isVisible: false)
        _ = await store.updateBirthday("1999-12-31")

        XCTAssertEqual(
            repository.updateDrafts,
            [
                CurrentUserProfileUpdateDraft(
                    displayName: "橘子午后",
                    bio: nil,
                    gender: nil,
                    isGenderVisible: nil,
                    birthday: nil
                ),
                CurrentUserProfileUpdateDraft(
                    displayName: nil,
                    bio: "记录两只毛孩子的日常。",
                    gender: nil,
                    isGenderVisible: nil,
                    birthday: nil
                ),
                CurrentUserProfileUpdateDraft(
                    displayName: nil,
                    bio: nil,
                    gender: "female",
                    isGenderVisible: false,
                    birthday: nil
                ),
                CurrentUserProfileUpdateDraft(
                    displayName: nil,
                    bio: nil,
                    gender: nil,
                    isGenderVisible: nil,
                    birthday: "1999-12-31"
                )
            ]
        )
    }

    func testUnchangedFieldCommandsSkipRemoteUpdateAndToast() async {
        let currentUserStore = CurrentUserStore()
        currentUserStore.apply(session: Self.authSession(displayName: "橘子午后"))
        currentUserStore.bio = "记录两只毛孩子的日常。"
        currentUserStore.gender = "female"
        currentUserStore.isGenderVisible = false
        currentUserStore.birthday = "1999-12-31"
        let repository = CurrentUserProfileRepositoryStub(
            updateResponse: MHBAPIResponse(
                success: true,
                code: "profile.updated",
                message: "个人资料已更新",
                data: Self.remoteProfile(displayName: "橘子午后")
            )
        )
        let store = ProfileUserEditStore(
            repository: repository,
            currentUserStore: currentUserStore
        )

        let nameSaved = await store.updateDisplayName(" 橘子午后 ")
        let bioSaved = await store.updateBio("记录两只毛孩子的日常。")
        let genderSaved = await store.updateGender("female", isVisible: false)
        let birthdaySaved = await store.updateBirthday("1999-12-31")

        XCTAssertTrue(nameSaved)
        XCTAssertTrue(bioSaved)
        XCTAssertTrue(genderSaved)
        XCTAssertTrue(birthdaySaved)
        XCTAssertTrue(repository.updateDrafts.isEmpty)
        XCTAssertNil(store.toastMessage)
    }

    func testUploadAvatarPublishesRemoteMediaIntoCurrentUserStore() async {
        let currentUserStore = CurrentUserStore()
        currentUserStore.apply(session: Self.authSession(displayName: "旧昵称"))
        let repository = CurrentUserProfileRepositoryStub(
            updateResponse: MHBAPIResponse(
                success: true,
                code: "profile.avatar_uploaded",
                message: "头像已保存",
                data: Self.remoteProfile(
                    displayName: "橘子午后",
                    avatar: Self.remoteMedia(url: "/api/v1/profile/media/avatar.png"),
                    cover: nil
                )
            )
        )
        let store = ProfileUserEditStore(
            repository: repository,
            currentUserStore: currentUserStore
        )

        let uploaded = await store.uploadAvatar(
            draft: CurrentUserProfileMediaUploadDraft(
                fileName: "avatar.png",
                mimeType: "image/png",
                content: Data([1, 2, 3]),
                sourceClient: "ios"
            )
        )

        XCTAssertTrue(uploaded)
        XCTAssertEqual(repository.uploadedAvatarDrafts.count, 1)
        XCTAssertEqual(repository.avatarProgressValues, [0.25, 1.0])
        XCTAssertEqual(store.mediaUploadProgress, 1.0)
        XCTAssertEqual(store.toastMessage, "头像已保存")
        XCTAssertEqual(store.profile?.avatar?.url, "/api/v1/profile/media/avatar.png")
        XCTAssertEqual(currentUserStore.avatarURLString, "/api/v1/profile/media/avatar.png")
    }

    func testUploadCoverPublishesRemoteMediaIntoCurrentUserStore() async {
        let currentUserStore = CurrentUserStore()
        currentUserStore.apply(session: Self.authSession(displayName: "旧昵称"))
        let repository = CurrentUserProfileRepositoryStub(
            updateResponse: MHBAPIResponse(
                success: true,
                code: "profile.cover_uploaded",
                message: "主页背景已保存",
                data: Self.remoteProfile(
                    displayName: "橘子午后",
                    avatar: nil,
                    cover: Self.remoteMedia(url: "/api/v1/profile/media/cover.png")
                )
            )
        )
        let store = ProfileUserEditStore(
            repository: repository,
            currentUserStore: currentUserStore
        )

        let uploaded = await store.uploadCover(
            draft: CurrentUserProfileMediaUploadDraft(
                fileName: "cover.png",
                mimeType: "image/png",
                content: Data([1, 2, 3]),
                sourceClient: "ios"
            )
        )

        XCTAssertTrue(uploaded)
        XCTAssertEqual(repository.uploadedCoverDrafts.count, 1)
        XCTAssertEqual(repository.coverProgressValues, [0.25, 1.0])
        XCTAssertEqual(store.mediaUploadProgress, 1.0)
        XCTAssertEqual(store.toastMessage, "主页背景已保存")
        XCTAssertEqual(store.profile?.cover?.url, "/api/v1/profile/media/cover.png")
        XCTAssertEqual(currentUserStore.coverURLString, "/api/v1/profile/media/cover.png")
    }

    func testEditPolicyTextComesFromRemoteProfile() async {
        let currentUserStore = CurrentUserStore()
        currentUserStore.apply(session: Self.authSession(displayName: "旧昵称"))
        let repository = CurrentUserProfileRepositoryStub(
            updateResponse: MHBAPIResponse(
                success: true,
                code: "profile.loaded",
                message: "个人资料已加载",
                data: Self.remoteProfileWithPolicies()
            )
        )
        let store = ProfileUserEditStore(
            repository: repository,
            currentUserStore: currentUserStore
        )

        _ = await store.load()

        XCTAssertEqual(store.displayNameEditPolicyText, "7月23日前还可以修改 4 次昵称。")
        XCTAssertEqual(store.bioEditPolicyText, "7月23日前还可以修改 2 次简介。")
    }

    func testLoadPublishesAvatarAndCoverURLIntoCurrentUserStore() async {
        let currentUserStore = CurrentUserStore()
        currentUserStore.apply(session: Self.authSession(displayName: "橘子午后"))
        let loadResponse = MHBAPIResponse(
            success: true,
            code: "profile.loaded",
            message: "个人资料已加载",
            data: Self.remoteProfile(
                displayName: "橘子午后",
                avatar: Self.remoteMedia(url: "/api/v1/media/assets/avatar-uuid/content"),
                cover: Self.remoteMedia(url: "/api/v1/media/assets/cover-uuid/content")
            )
        )
        let repository = CurrentUserProfileRepositoryStub(
            loadResponse: loadResponse,
            updateResponse: loadResponse
        )
        let store = ProfileUserEditStore(
            repository: repository,
            currentUserStore: currentUserStore
        )

        let loaded = await store.load()

        XCTAssertTrue(loaded)
        XCTAssertEqual(
            currentUserStore.avatarURLString,
            "/api/v1/media/assets/avatar-uuid/content"
        )
        XCTAssertEqual(
            currentUserStore.coverURLString,
            "/api/v1/media/assets/cover-uuid/content"
        )
    }

    private static func authSession(displayName: String) -> AuthSession {
        AuthSession(
            accessToken: "access-token",
            refreshToken: "refresh-token",
            tokenType: "Bearer",
            expiresInSeconds: 900,
            refreshExpiresInSeconds: 15_552_000,
            user: AuthUser(
                id: "user-1",
                phone: "13800138010",
                phoneMasked: "138****8010",
                hasPassword: false,
                profile: CurrentUserProfileSummary(
                    maohuobanID: "8X29K4M7Q2",
                    displayName: displayName,
                    avatar: nil,
                    avatarPresentation: CurrentUserAvatarPresentation(
                        sex: .female,
                        sexVisibility: .visible
                    )
                )
            )
        )
    }

    private static func remoteProfile(
        displayName: String,
        avatar: CurrentUserProfileMedia? = nil,
        cover: CurrentUserProfileMedia? = nil
    ) -> CurrentUserProfile {
        CurrentUserProfile(
            userID: "user-1",
            maohuobanID: "8X29K4M7Q2",
            displayName: displayName,
            defaultDisplayName: "毛伙伴用户7K29Q",
            bio: "记录两只毛孩子的日常。",
            gender: "female",
            isGenderVisible: false,
            birthday: "1999-12-31",
            birthdayDisplayText: "1999-12-31",
            avatar: avatar,
            cover: cover,
            avatarPresentation: CurrentUserAvatarPresentation(
                sex: .unknown,
                sexVisibility: .hidden
            )
        )
    }

    private static func remoteProfileWithPolicies() -> CurrentUserProfile {
        CurrentUserProfile(
            userID: "user-1",
            maohuobanID: "8X29K4M7Q2",
            displayName: "橘子午后",
            defaultDisplayName: "毛伙伴用户7K29Q",
            bio: "记录两只毛孩子的日常。",
            gender: "female",
            isGenderVisible: false,
            birthday: "1999-12-31",
            birthdayDisplayText: "1999-12-31",
            avatar: nil,
            cover: nil,
            avatarPresentation: CurrentUserAvatarPresentation(
                sex: .unknown,
                sexVisibility: .hidden
            ),
            displayNameEditPolicy: CurrentUserProfileEditPolicy(
                maxCount: 5,
                usedCount: 1,
                remainingCount: 4,
                windowDays: 30,
                windowEndsAt: "2026-07-23T00:00:00Z",
                displayText: "7月23日前还可以修改 4 次昵称。"
            ),
            bioEditPolicy: CurrentUserProfileEditPolicy(
                maxCount: 3,
                usedCount: 1,
                remainingCount: 2,
                windowDays: 30,
                windowEndsAt: "2026-07-23T00:00:00Z",
                displayText: "7月23日前还可以修改 2 次简介。"
            )
        )
    }

    private static func remoteMedia(url: String) -> CurrentUserProfileMedia {
        CurrentUserProfileMedia(
            assetID: "asset-1",
            url: url,
            width: 1,
            height: 1,
            mimeType: "image/png",
            updatedAt: "2026-06-23T19:48:26Z"
        )
    }
}

// CurrentUserProfileRepositoryStub 当前用户资料仓储测试桩
// 核心职责：
// - 用固定响应驱动 ProfileUserEditStore 分支
// - 记录最后一次更新草稿供测试断言
@MainActor
private final class CurrentUserProfileRepositoryStub: CurrentUserProfileRepository {
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
