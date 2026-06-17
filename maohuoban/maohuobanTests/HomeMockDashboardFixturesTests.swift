import XCTest
@testable import maohuoban

// HomeMockDashboardFixturesTests 首页 Mock 数据测试
// 核心职责：
// - 固化宠物 owner 开发态只保留一只宠物
// - 防止已下线的第二只宠物 mock 回流
@MainActor
final class HomeMockDashboardFixturesTests: XCTestCase {
    func testPetOwnerMockKeepsSingleMochiPet() {
        let snapshot = HomeMockDashboardFixtures.snapshot(
            scenario: .petOwner,
            selectedPetID: "pet-tangyuan"
        )

        XCTAssertEqual(snapshot.petSwitcher.map(\.id), ["pet-mochi"])
        XCTAssertEqual(snapshot.selectedPet?.id, "pet-mochi")
        XCTAssertEqual(snapshot.selectedPet?.heroImageAssetName, "HomePetHeroMock")
        XCTAssertNil(snapshot.selectedPet?.heroVideoResourceName)
    }

    func testPetOwnerMockCareWeightUsesSinglePetValue() throws {
        let snapshot = HomeMockDashboardFixtures.snapshot(
            scenario: .petOwner,
            selectedPetID: nil
        )

        let careSummary = try XCTUnwrap(snapshot.careSummary)
        let weightMetric = try XCTUnwrap(
            careSummary.metrics.first { $0.kind == .weight }
        )
        XCTAssertEqual(weightMetric.valueText, "4.8kg")
    }

    func testBackendPetSnapshotCanUseMockSectionsWithoutReplacingPetData() throws {
        let backendSnapshot = HomeDashboardSnapshot(
            identity: HomeDashboardSnapshot.Identity(
                kind: .petOwner,
                displayName: "真实用户",
                city: nil,
                verificationBadge: nil
            ),
            selectedPet: HomeDashboardSnapshot.PetHeroSummary(
                id: "real-pet",
                name: "测试宠物 1",
                species: .dog,
                breed: "未填写品种",
                sex: .unknown,
                ageText: "未知年龄",
                statusText: "记录正在形成可信档案",
                updatedText: "档案已同步",
                avatarURL: "/api/v1/media/assets/avatar/content",
                heroImageAssetName: nil
            ),
            petSwitcher: [
                HomeDashboardSnapshot.PetSwitchItem(
                    id: "real-pet",
                    name: "测试宠物 1",
                    species: .dog,
                    avatarURL: "/api/v1/media/assets/avatar/content",
                    isSelected: true
                )
            ],
            careSummary: nil,
            reminders: [],
            quickActions: [],
            partnerRecommendation: nil,
            recentTimeline: [],
            merchantDashboard: nil,
            emptyState: nil,
            recommendedContent: []
        )
        let mockSnapshot = HomeMockDashboardFixtures.snapshot(
            scenario: .petOwner,
            selectedPetID: nil
        )

        let supplemented = backendSnapshot.supplementingMissingSections(from: mockSnapshot)

        XCTAssertEqual(supplemented.selectedPet?.id, "real-pet")
        XCTAssertEqual(supplemented.selectedPet?.name, "测试宠物 1")
        XCTAssertEqual(supplemented.petSwitcher.map(\.id), ["real-pet"])
        XCTAssertNotNil(supplemented.partnerRecommendation)
        XCTAssertFalse(supplemented.recentTimeline.isEmpty)
        XCTAssertFalse(supplemented.reminders.isEmpty)
        XCTAssertFalse(supplemented.quickActions.isEmpty)

        let newUserBackendSnapshot = HomeDashboardSnapshot(
            identity: HomeDashboardSnapshot.Identity(
                kind: .newUser,
                displayName: "真实新用户",
                city: "成都",
                verificationBadge: nil
            ),
            selectedPet: nil,
            petSwitcher: [],
            careSummary: nil,
            reminders: [],
            quickActions: [],
            partnerRecommendation: nil,
            recentTimeline: [],
            merchantDashboard: nil,
            emptyState: HomeDashboardSnapshot.EmptyState(
                kind: .createFirstPet,
                title: "创建第一只宠物",
                subtitle: "开始建立档案",
                primaryAction: HomeDashboardSnapshot.Action(
                    kind: .createPet,
                    title: "创建宠物",
                    subtitle: nil
                )
            ),
            recommendedContent: []
        )

        let supplementedNewUser = newUserBackendSnapshot.supplementingMissingSections(from: mockSnapshot)

        XCTAssertEqual(supplementedNewUser.identity.kind, .newUser)
        XCTAssertNil(supplementedNewUser.selectedPet)
        XCTAssertTrue(supplementedNewUser.petSwitcher.isEmpty)
        XCTAssertEqual(supplementedNewUser.emptyState?.title, "创建第一只宠物")
        XCTAssertNotNil(supplementedNewUser.partnerRecommendation)
        XCTAssertFalse(supplementedNewUser.recentTimeline.isEmpty)
        XCTAssertFalse(supplementedNewUser.reminders.isEmpty)
        XCTAssertFalse(supplementedNewUser.quickActions.isEmpty)
        XCTAssertFalse(supplementedNewUser.petAlbums?.isEmpty ?? true)
        XCTAssertFalse(supplementedNewUser.galleryAlbums?.isEmpty ?? true)
    }
}
