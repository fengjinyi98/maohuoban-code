import XCTest
@testable import maohuoban

// HomeGenderSymbolTests 首页性别符号展示策略测试
// 核心职责：
// - 固化首页头图宠物名称旁不展示性别符号
// - 固化我的宠物列表宠物名称旁不展示性别符号
final class HomeGenderSymbolTests: XCTestCase {
    @MainActor
    func testHomeIdentityHeaderUsesCurrentUserDisplayNameForPersonalIdentityKinds() {
        let header = HomeIdentityHeader(
            identity: HomeDashboardSnapshot.Identity(
                kind: .petOwner,
                displayName: "接口旧昵称",
                city: nil,
                verificationBadge: nil
            ),
            currentUserDisplayName: "小林"
        )

        XCTAssertEqual(header.displayNameText, "小林")
    }

    @MainActor
    func testHomeIdentityHeaderKeepsMerchantDisplayNameFromDashboardSnapshot() {
        let header = HomeIdentityHeader(
            identity: HomeDashboardSnapshot.Identity(
                kind: .certifiedMerchant,
                displayName: "梧桐猫舍",
                city: "成都",
                verificationBadge: "已认证"
            ),
            currentUserDisplayName: "小林"
        )

        XCTAssertEqual(header.displayNameText, "梧桐猫舍")
    }

    @MainActor
    func testHomeLoadedViewUsesCurrentUserDisplayNameForPetHeaderCompanionshipText() throws {
        let snapshot = HomeDashboardSnapshot.homeTestSnapshot(selectedPetID: "pet-1")
        let view = HomeDashboardLoadedView(
            snapshot: snapshot,
            currentUserDisplayName: "小林",
            onSelectPet: { _ in },
            onOpenRoute: { _ in }
        )

        let selectedPet = try XCTUnwrap(snapshot.selectedPet)
        let presentation = HomeImmersivePetHeaderPresentation.make(
            pet: selectedPet,
            displayName: view.petHeaderDisplayName,
            date: Date(timeIntervalSince1970: 1_766_361_600)
        )

        XCTAssertEqual(view.petHeaderDisplayName, "小林")
        XCTAssertEqual(presentation.companionshipText, "已陪伴 小林 365 天")
    }

    @MainActor
    func testHomeHeaderPresentationDoesNotExposeNameGenderSymbols() {
        let malePresentation = HomeImmersivePetHeaderPresentation.make(
            pet: makePet(sex: .male),
            displayName: "小林"
        )
        let femalePresentation = HomeImmersivePetHeaderPresentation.make(
            pet: makePet(sex: .female),
            displayName: "小林"
        )
        let unknownPresentation = HomeImmersivePetHeaderPresentation.make(
            pet: makePet(sex: .unknown),
            displayName: "小林"
        )

        XCTAssertNil(malePresentation.genderSymbolText)
        XCTAssertNil(femalePresentation.genderSymbolText)
        XCTAssertNil(unknownPresentation.genderSymbolText)
    }

    @MainActor
    func testPetManagementNameDoesNotExposeGenderSymbols() {
        XCTAssertNil(PetManagementPet.Sex.male.symbolText)
        XCTAssertNil(PetManagementPet.Sex.female.symbolText)
        XCTAssertNil(PetManagementPet.Sex.unknown.symbolText)
    }

    @MainActor
    func testHomePartnerAvatarUsesSquarePetAvatarSubject() {
        let partner = HomeDashboardSnapshot.PartnerRecommendation(
            petID: "partner-pet",
            petName: "糖豆",
            relationshipKind: .sameCity,
            title: "今日伙伴",
            subtitle: "同城活跃伙伴",
            distanceText: "1.2km",
            sex: .female
        )

        XCTAssertEqual(
            HomePartnerAvatarPresentation.avatarSubject(for: partner),
            .pet(
                MHBAvatarPet(
                    id: "partner-pet",
                    name: "糖豆",
                    source: .asset("HomePartnerAvatar"),
                    species: .other,
                    sex: .female
                )
            )
        )
        XCTAssertEqual(
            MHBAvatarShape.squircle.cornerRadius(for: 72),
            22.5,
            accuracy: 0.001
        )
    }

    @MainActor
    func testPetManagementAvatarUsesSquarePetAvatarSubject() {
        let pet = PetManagementPet.mockPets[0]

        XCTAssertEqual(
            PetManagementAvatarPresentation.avatarSubject(
                for: pet,
                source: .asset("HomePetHeroMock")
            ),
            .pet(
                MHBAvatarPet(
                    id: "pet-mochi",
                    name: "糯米",
                    source: .asset("HomePetHeroMock"),
                    species: .dog,
                    sex: .male
                )
            )
        )
        XCTAssertEqual(
            MHBAvatarShape.squircle.cornerRadius(for: 48),
            15,
            accuracy: 0.001
        )
    }

    @MainActor
    private func makePet(
        sex: HomeDashboardSnapshot.Sex
    ) -> HomeDashboardSnapshot.PetHeroSummary {
        HomeDashboardSnapshot.PetHeroSummary(
            id: "pet-1",
            name: "糯米",
            species: .dog,
            breed: "金毛",
            sex: sex,
            ageText: "2岁",
            statusText: "健康",
            updatedText: "刚刚更新",
            avatarURL: nil,
            heroImageAssetName: "HomePetHeroMock"
        )
    }
}
