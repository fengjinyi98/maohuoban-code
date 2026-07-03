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

    func testPetOwnerMockDoesNotExposeCareSummary() {
        let snapshot = HomeMockDashboardFixtures.snapshot(
            scenario: .petOwner,
            selectedPetID: nil
        )

        XCTAssertFalse(
            Mirror(reflecting: snapshot).children.contains { $0.label == "careSummary" }
        )
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
                heroImageURL: "/api/v1/media/assets/background/content",
                heroImageWidth: 1200,
                heroImageHeight: 900,
                heroThemeColorHex: "#AABBCC",
                heroImageAssetName: nil,
                profileNumber: "MHB-REAL-001",
                microchipNumber: "CHIP-REAL-001",
                birthday: "2024-01-02",
                arrivalDate: "2024-03-04",
                weightGrams: 5200,
                neuterStatus: .neutered,
                personalityTags: ["真实标签"],
                note: "真实备注",
                companionshipDays: 88
            ),
            petSwitcher: [
                HomeDashboardSnapshot.PetSwitchItem(
                    id: "real-pet",
                    name: "测试宠物 1",
                    species: .dog,
                    avatarURL: "/api/v1/media/assets/avatar/content",
                    avatarWidth: 320,
                    avatarHeight: 320,
                    profileNumber: "MHB-REAL-001",
                    microchipNumber: "CHIP-REAL-001",
                    birthday: "2024-01-02",
                    arrivalDate: "2024-03-04",
                    weightGrams: 5200,
                    neuterStatus: .neutered,
                    personalityTags: ["真实标签"],
                    note: "真实备注",
                    isSelected: true
                )
            ],
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
        XCTAssertEqual(supplemented.selectedPet?.avatarURL, "/api/v1/media/assets/avatar/content")
        XCTAssertEqual(supplemented.selectedPet?.heroImageURL, "/api/v1/media/assets/background/content")
        XCTAssertEqual(supplemented.selectedPet?.heroImageWidth, 1200)
        XCTAssertEqual(supplemented.selectedPet?.heroImageHeight, 900)
        XCTAssertEqual(supplemented.selectedPet?.heroThemeColorHex, "#AABBCC")
        XCTAssertEqual(supplemented.selectedPet?.profileNumber, "MHB-REAL-001")
        XCTAssertEqual(supplemented.selectedPet?.microchipNumber, "CHIP-REAL-001")
        XCTAssertEqual(supplemented.selectedPet?.birthday, "2024-01-02")
        XCTAssertEqual(supplemented.selectedPet?.arrivalDate, "2024-03-04")
        XCTAssertEqual(supplemented.selectedPet?.weightGrams, 5200)
        XCTAssertEqual(supplemented.selectedPet?.neuterStatus, .neutered)
        XCTAssertEqual(supplemented.selectedPet?.personalityTags, ["真实标签"])
        XCTAssertEqual(supplemented.selectedPet?.note, "真实备注")
        XCTAssertEqual(supplemented.selectedPet?.companionshipDays, 88)
        XCTAssertEqual(supplemented.petSwitcher.map(\.id), ["real-pet"])
        XCTAssertEqual(supplemented.petSwitcher.first?.avatarURL, "/api/v1/media/assets/avatar/content")
        XCTAssertEqual(supplemented.petSwitcher.first?.avatarWidth, 320)
        XCTAssertEqual(supplemented.petSwitcher.first?.avatarHeight, 320)
        XCTAssertEqual(supplemented.petSwitcher.first?.profileNumber, "MHB-REAL-001")
        XCTAssertEqual(supplemented.petSwitcher.first?.microchipNumber, "CHIP-REAL-001")
        XCTAssertEqual(supplemented.petSwitcher.first?.birthday, "2024-01-02")
        XCTAssertEqual(supplemented.petSwitcher.first?.arrivalDate, "2024-03-04")
        XCTAssertEqual(supplemented.petSwitcher.first?.weightGrams, 5200)
        XCTAssertEqual(supplemented.petSwitcher.first?.neuterStatus, .neutered)
        XCTAssertEqual(supplemented.petSwitcher.first?.personalityTags, ["真实标签"])
        XCTAssertEqual(supplemented.petSwitcher.first?.note, "真实备注")
        XCTAssertNotNil(supplemented.partnerRecommendation)
        XCTAssertTrue(supplemented.recentTimeline.isEmpty)
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
        XCTAssertTrue(supplementedNewUser.recentTimeline.isEmpty)
        XCTAssertFalse(supplementedNewUser.reminders.isEmpty)
        XCTAssertFalse(supplementedNewUser.quickActions.isEmpty)
    }

    func testPetOwnerQuickActionsUseClientOwnedBaseEntries() {
        let backendSnapshot = HomeDashboardSnapshot(
            identity: HomeDashboardSnapshot.Identity(
                kind: .petOwner,
                displayName: "真实用户",
                city: nil,
                verificationBadge: nil
            ),
            selectedPet: nil,
            petSwitcher: [],
            reminders: [],
            quickActions: [
                HomeDashboardSnapshot.Action(
                    kind: .dailyRecord,
                    title: "记录日常",
                    subtitle: nil
                ),
                HomeDashboardSnapshot.Action(
                    kind: .healthRecord,
                    title: "健康记录",
                    subtitle: nil
                ),
                HomeDashboardSnapshot.Action(
                    kind: .bookHospital,
                    title: "预约医院",
                    subtitle: nil
                )
            ],
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

        XCTAssertEqual(
            supplemented.quickActions.map(\.kind),
            [.dailyRecord, .walk, .healthRecord, .bookHospital]
        )
        XCTAssertFalse(supplemented.quickActions.map(\.kind).contains(.importTradePet))
    }

    func testSupplementingMissingSectionsKeepsBackendPantryItems() {
        let backendSnapshot = HomeDashboardSnapshot(
            identity: HomeDashboardSnapshot.Identity(
                kind: .petOwner,
                displayName: "真实用户",
                city: nil,
                verificationBadge: nil
            ),
            selectedPet: nil,
            petSwitcher: [],
            reminders: [],
            quickActions: [],
            partnerRecommendation: nil,
            recentTimeline: [],
            merchantDashboard: nil,
            emptyState: nil,
            recommendedContent: [],
            pantryItems: [
                HomeDashboardSnapshot.PantryPreviewItem(
                    id: "food-real",
                    title: "后端真实主粮",
                    subtitle: "主粮",
                    coverImageAssetName: "home-pantry-main-food"
                )
            ]
        )
        let mockSnapshot = HomeMockDashboardFixtures.snapshot(
            scenario: .petOwner,
            selectedPetID: nil
        )

        let supplemented = backendSnapshot.supplementingMissingSections(from: mockSnapshot)

        XCTAssertEqual(supplemented.pantryItems?.map(\.id), ["food-real"])
        XCTAssertEqual(supplemented.pantryItems?.first?.title, "后端真实主粮")
    }

    func testSupplementingMissingSectionsKeepsGalleryAlbumsEmptyForBackendSnapshot() {
        let backendSnapshot = HomeDashboardSnapshot(
            identity: HomeDashboardSnapshot.Identity(
                kind: .petOwner,
                displayName: "真实用户",
                city: nil,
                verificationBadge: nil
            ),
            selectedPet: nil,
            petSwitcher: [],
            reminders: [],
            quickActions: [],
            partnerRecommendation: nil,
            recentTimeline: [],
            galleryAlbums: [],
            merchantDashboard: nil,
            emptyState: nil,
            recommendedContent: []
        )
        let mockSnapshot = HomeMockDashboardFixtures.snapshot(
            scenario: .petOwner,
            selectedPetID: nil
        )

        let supplemented = backendSnapshot.supplementingMissingSections(from: mockSnapshot)

        XCTAssertTrue(supplemented.galleryAlbums.isEmpty)
    }
}
