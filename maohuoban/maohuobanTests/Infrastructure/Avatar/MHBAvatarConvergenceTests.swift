import XCTest
@testable import maohuoban

// MHBAvatarConvergenceTests 头像收敛测试
// 核心职责：
// - 固化非 Feed 展示头像统一输出 MHBAvatarSubject
// - 防止个人中心、宠物切换、AI、遛弯和商家页面重新散写头像语义
final class MHBAvatarConvergenceTests: XCTestCase {
    @MainActor
    func testProfileAccountAndCurrentUserStoreUseUserAvatarSubject() {
        XCTAssertEqual(
            ProfileAccountSummary.mock.avatarSubject,
            .user(
                MHBAvatarUser(
                    id: "profile-account",
                    displayName: "橘子午后",
                    source: .asset("HomeUserAvatarMock"),
                    sex: .unknown,
                    sexVisibility: .hidden
                )
            )
        )

        let currentUserStore = CurrentUserStore()
        currentUserStore.apply(
            profile: CurrentUserProfileSummary(
                maohuobanID: "8X29K4M7Q2",
                displayName: "橘子午后",
                avatar: nil,
                avatarPresentation: .hidden
            )
        )

        XCTAssertEqual(
            currentUserStore.avatarSubject,
            .user(
                MHBAvatarUser(
                    id: "current-user",
                    displayName: "橘子午后",
                    source: .asset("HomeUserAvatarMock"),
                    sex: .unknown,
                    sexVisibility: .hidden
                )
            )
        )
    }

    @MainActor
    func testProfileRelationshipItemsExposeAvatarSubjects() {
        let followedPet = ProfileFollowingItem.mockPet(
            id: "pet-nuomi",
            name: "糯米",
            breed: "金毛寻回犬"
        )
        let followedUser = ProfileFollowingItem.mockUser(
            id: "user-doctor",
            name: "Dr.张",
            bio: "宠物医生",
            badgeText: "认证医生"
        )
        let follower = ProfileFollowerItem.mockFollower(
            id: "follower-1",
            name: "夏天爱吃瓜",
            contextText: "关注了你",
            symbolName: "person.fill"
        )
        let reply = ProfileReplyItem.mockReply(
            id: "reply-1",
            scope: .received,
            actorName: "李大锤爱柯基",
            actorSymbolName: "pawprint.fill",
            timeText: "刚刚",
            replyText: "太可爱了",
            contextTitle: "我的动态",
            contextText: "日常记录",
            contextKind: .comment,
            primaryActionTitle: "回复",
            primaryActionSymbolName: "bubble.left",
            secondaryActionTitle: "赞",
            secondaryActionSymbolName: "heart"
        )

        XCTAssertEqual(
            followedPet.avatarSubject,
            .pet(
                MHBAvatarPet(
                    id: "pet-nuomi",
                    name: "糯米",
                    source: .systemSymbol("pawprint.fill"),
                    species: .other,
                    sex: .unknown
                )
            )
        )
        XCTAssertEqual(
            followedUser.avatarSubject,
            .user(
                MHBAvatarUser(
                    id: "user-doctor",
                    displayName: "Dr.张",
                    source: .systemSymbol("person.fill"),
                    sex: .unknown,
                    sexVisibility: .hidden
                )
            )
        )
        XCTAssertEqual(
            follower.avatarSubject,
            .user(
                MHBAvatarUser(
                    id: "follower-1",
                    displayName: "夏天爱吃瓜",
                    source: .systemSymbol("person.fill"),
                    sex: .unknown,
                    sexVisibility: .hidden
                )
            )
        )
        XCTAssertEqual(
            reply.avatarSubject,
            .user(
                MHBAvatarUser(
                    id: "reply-1",
                    displayName: "李大锤爱柯基",
                    source: .systemSymbol("pawprint.fill"),
                    sex: .unknown,
                    sexVisibility: .hidden
                )
            )
        )
    }

    @MainActor
    func testPetContextPagesExposePetAvatarSubjects() {
        let switcherItem = MHBPetSwitcherItem(
            id: "pet-switcher",
            name: "糯米",
            subtitle: "金毛 · 2岁",
            avatarURLString: nil,
            species: .dog,
            sex: .female,
            isSelected: true
        )
        let petFamilyItem = ProfileUserHomePet(
            id: "pet-family",
            name: "煤球",
            avatarAssetName: "HomePetAlbum4"
        )

        XCTAssertEqual(
            switcherItem.avatarSubject,
            .pet(
                MHBAvatarPet(
                    id: "pet-switcher",
                    name: "糯米",
                    source: .empty,
                    species: .dog,
                    sex: .female
                )
            )
        )
        XCTAssertEqual(
            petFamilyItem.avatarSubject,
            .pet(
                MHBAvatarPet(
                    id: "pet-family",
                    name: "煤球",
                    source: .asset("HomePetAlbum4"),
                    species: .other,
                    sex: .unknown
                )
            )
        )
    }

    @MainActor
    func testAssistantWalkAndMerchantExposePetAvatarSubjects() {
        let absoluteURL = URL(string: "https://example.com/pet.png")!
        let merchantPet = MerchantManagedPet(
            id: "merchant-pet",
            ownerUserID: nil,
            merchantID: "merchant-1",
            name: "小金",
            species: .cat,
            breed: nil,
            sex: .male,
            birthday: nil,
            managedStatus: .available,
            sourceKind: .merchantManaged,
            createdAt: "2026-06-01",
            updatedAt: "2026-06-23"
        )

        XCTAssertEqual(
            AIAssistantPetAvatarPresentation.avatarSubject(
                avatarURL: "https://example.com/pet.png",
                species: .cat
            ),
            .pet(
                MHBAvatarPet(
                    id: "ai-assistant-pet",
                    name: "当前宠物",
                    source: .remote(absoluteURL),
                    species: .cat,
                    sex: .unknown
                )
            )
        )
        XCTAssertEqual(
            PetWalkAvatarPresentation.avatarSubject(
                id: "walk-pet",
                name: "糯米",
                url: absoluteURL,
                sex: .female
            ),
            .pet(
                MHBAvatarPet(
                    id: "walk-pet",
                    name: "糯米",
                    source: .remote(absoluteURL),
                    species: .other,
                    sex: .female
                )
            )
        )
        XCTAssertEqual(
            merchantPet.avatarSubject,
            .pet(
                MHBAvatarPet(
                    id: "merchant-pet",
                    name: "小金",
                    source: .empty,
                    species: .cat,
                    sex: .male
                )
            )
        )
    }
}
