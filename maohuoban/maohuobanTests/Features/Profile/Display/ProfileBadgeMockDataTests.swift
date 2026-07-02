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

    @MainActor
    func testDetailPresentationFeedbackOnlyTargetsEarnedBadges() throws {
        let earnedBadge = try XCTUnwrap(ProfileBadge.mockBadges.first { $0.isEarned })
        let lockedBadge = try XCTUnwrap(ProfileBadge.mockBadges.first { !$0.isEarned })

        XCTAssertTrue(ProfileBadgeDetailFeedbackPolicy.shouldTriggerPresentationFeedback(for: earnedBadge))
        XCTAssertFalse(ProfileBadgeDetailFeedbackPolicy.shouldTriggerPresentationFeedback(for: lockedBadge))
    }

    @MainActor
    func testDetailPresentationFeedbackUsesNoticeableImpactIntensity() {
        XCTAssertEqual(ProfileBadgeDetailFeedbackPolicy.presentationFeedbackIntensity, 1.0)
    }

    func testDetailSheetDoesNotPersistFeedbackStateAcrossBadgePresentations() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot().appendingPathComponent(
                "maohuoban/maohuoban/Features/Profile/Presentation/Components/ProfileBadgeDetailSheet.swift"
            ),
            encoding: .utf8
        )

        XCTAssertFalse(
            source.contains("didTriggerPresentationFeedback"),
            "Badge detail sheet must evaluate presentation feedback per appearance instead of persisting a cross-badge trigger flag."
        )
    }

    private static func repositoryRoot() throws -> URL {
        var url = URL(fileURLWithPath: #filePath)
        while url.pathComponents.isEmpty == false {
            let candidate = url.appendingPathComponent("maohuoban/maohuoban.xcodeproj")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return url
            }
            url.deleteLastPathComponent()
        }
        throw NSError(
            domain: "ProfileBadgeMockDataTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Unable to locate repository root."]
        )
    }
}
