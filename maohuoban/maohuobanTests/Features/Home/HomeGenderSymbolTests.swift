import XCTest
@testable import maohuoban

// HomeGenderSymbolTests 首页性别符号测试
// 核心职责：
// - 固化首页头图性别符号使用文本渲染字段
// - 固化我的宠物列表性别符号不再依赖 SF Symbols 名称
final class HomeGenderSymbolTests: XCTestCase {
    @MainActor
    func testHomeHeaderPresentationUsesTextGenderSymbols() {
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

        XCTAssertEqual(malePresentation.genderSymbolText, "♂")
        XCTAssertEqual(femalePresentation.genderSymbolText, "♀")
        XCTAssertNil(unknownPresentation.genderSymbolText)
    }

    @MainActor
    func testPetManagementSexUsesTextGenderSymbols() {
        XCTAssertEqual(PetManagementPet.Sex.male.symbolText, "♂")
        XCTAssertEqual(PetManagementPet.Sex.female.symbolText, "♀")
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
