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
