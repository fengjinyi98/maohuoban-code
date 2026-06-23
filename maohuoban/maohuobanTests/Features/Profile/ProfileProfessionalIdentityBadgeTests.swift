import XCTest
@testable import maohuoban

// ProfileProfessionalIdentityBadgeTests 专业身份角标测试
// 核心职责：
// - 固化猫舍、犬舍和宠物店三类认证身份的资源映射
// - 约束未认证用户在个人主页头像处不携带角标状态
final class ProfileProfessionalIdentityBadgeTests: XCTestCase {
    func testProfessionalIdentityBadgesExposeStableAssetsAndLabels() {
        XCTAssertEqual(ProfileProfessionalIdentityBadge.cattery.assetName, "ProfileProfessionalCatteryBadge")
        XCTAssertEqual(ProfileProfessionalIdentityBadge.cattery.accessibilityLabel, "猫舍认证")

        XCTAssertEqual(ProfileProfessionalIdentityBadge.kennel.assetName, "ProfileProfessionalKennelBadge")
        XCTAssertEqual(ProfileProfessionalIdentityBadge.kennel.accessibilityLabel, "犬舍认证")

        XCTAssertEqual(ProfileProfessionalIdentityBadge.petStore.assetName, "ProfileProfessionalPetStoreBadge")
        XCTAssertEqual(ProfileProfessionalIdentityBadge.petStore.accessibilityLabel, "宠物店认证")
    }

    @MainActor
    func testUnauthenticatedProfileCarriesNoProfessionalBadge() {
        let profile = ProfileUserHome(
            displayName: "普通用户",
            petID: "10086",
            bio: "还没有认证身份",
            coverAssetName: "HomePetHeroMock",
            avatarAssetName: "MockUserAvatar",
            genderSystemImage: "person.fill",
            professionalBadge: nil,
            stats: [],
            pets: [],
            tabContents: []
        )

        XCTAssertNil(profile.professionalBadge)
    }
}
