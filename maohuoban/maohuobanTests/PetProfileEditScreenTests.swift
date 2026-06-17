import XCTest
@testable import maohuoban

// PetProfileEditScreenTests 宠物编辑页行为测试
// 核心职责：
// - 固化编辑页字段到更新 DTO 的映射
// - 覆盖前端本地编辑态和后端写入契约的衔接
@MainActor
final class PetProfileEditScreenTests: XCTestCase {
    func testUpdateDraftUsesEditedSpeciesText() throws {
        let profile = PetProfileEditProfile(
            id: "pet-1",
            name: "糯米",
            species: .dog,
            breed: "比熊犬",
            avatarURL: nil,
            heroMedia: .image(assetName: "HomePetHeroMock"),
            heroThemeColorHex: nil,
            heroContentColorScheme: nil,
            profileCode: "0000000000000001",
            chipNumber: "",
            sexText: "母",
            birthDateText: "2024-01-01",
            arrivalDateText: "2024-05-01",
            weightText: "4.2 kg",
            neuterStatusText: "已绝育",
            personalityTags: ["亲人"],
            note: "喜欢晒太阳",
            nameEditPolicy: nil
        )
        let screen = PetProfileEditScreen(
            context: PetProfileEditContext(selectedProfile: profile, profiles: [profile])
        )

        let draft = screen.updateDraft(for: profile, speciesText: "猫咪")
        let json = try Self.encodedJSONObject(draft)

        XCTAssertEqual(json["species"] as? String, "cat")
    }

    private static func encodedJSONObject<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
