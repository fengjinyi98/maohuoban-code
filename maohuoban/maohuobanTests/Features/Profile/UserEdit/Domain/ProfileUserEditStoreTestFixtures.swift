import Foundation
@testable import maohuoban

extension ProfileUserEditStoreTests {
    static func authSession(displayName: String) -> AuthSession {
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

    static func remoteProfile(
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

    static func remoteProfileWithPolicies() -> CurrentUserProfile {
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

    static func remoteMedia(url: String) -> CurrentUserProfileMedia {
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
