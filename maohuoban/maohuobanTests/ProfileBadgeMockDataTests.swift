import XCTest
@testable import maohuoban

// ProfileBadgeMockDataTests 我的页勋章 Mock 数据测试
// 核心职责：
// - 固化 V1 冷启动勋章目录数量和关键文案
// - 确认第一只伙伴勋章保留猫狗资源差异的后端接入备注
final class ProfileBadgeMockDataTests: XCTestCase {
    @MainActor
    func testColdStartBadgesMatchV1Catalog() {
        let badges = ProfileBadge.mockBadges

        XCTAssertEqual(badges.count, 16)
        XCTAssertEqual(badges.filter { $0.isEarned }.count, 7)
        XCTAssertEqual(badges.first?.id, "genesis_partner")
        XCTAssertEqual(badges.first?.title, "创世伙伴")
        XCTAssertTrue(badges.allSatisfy { !$0.imageAssetName.isEmpty })
    }

    @MainActor
    func testFirstPartnerBadgeKeepsCatAndDogAssetVariants() {
        let badge = ProfileBadge.mockBadges.first { $0.id == "first_partner" }

        XCTAssertEqual(badge?.imageAssetName, "BadgeFirstPartnerCat")
        XCTAssertEqual(badge?.alternateImageAssetName, "BadgeFirstPartnerDog")
        XCTAssertEqual(
            badge?.backendSelectionNote,
            "第一只伙伴为互斥勋章，后端接入后根据用户创建的第一只宠物物种发放猫版或狗版其中一个。"
        )
    }

    @MainActor
    func testLockedBadgesExposeProgressForDetailSheet() {
        let monthlyCaregiver = ProfileBadge.mockBadges.first { $0.id == "monthly_caregiver" }

        XCTAssertEqual(monthlyCaregiver?.isEarned, false)
        XCTAssertEqual(monthlyCaregiver?.progressCurrent, 12)
        XCTAssertEqual(monthlyCaregiver?.progressTarget, 30)
        XCTAssertEqual(monthlyCaregiver?.progressText, "12/30")
    }
}
