import XCTest
@testable import maohuoban

// PetProfileEditScreenTests 宠物编辑页行为测试
// 核心职责：
// - 固化编辑页字段到更新 DTO 的映射
// - 覆盖前端本地编辑态和后端写入契约的衔接
@MainActor
final class PetProfileEditScreenTests: XCTestCase {
    func testAvatarBorderSexStyleNormalizesSexText() {
        XCTAssertEqual(PetProfileEditAvatarBorderSex(sexText: "公"), .male)
        XCTAssertEqual(PetProfileEditAvatarBorderSex(sexText: "男"), .male)
        XCTAssertEqual(PetProfileEditAvatarBorderSex(sexText: "母"), .female)
        XCTAssertEqual(PetProfileEditAvatarBorderSex(sexText: "女"), .female)
        XCTAssertEqual(PetProfileEditAvatarBorderSex(sexText: "未知"), .unknown)
    }

    func testBreedEditSubmissionRemovesWhitespaceBeforeSave() {
        let submission = PetProfileBreedEditSubmission(rawValue: " 金 毛 寻 回 犬 ")

        XCTAssertEqual(submission.value, "金毛寻回犬")
    }

    func testUpdateDraftUsesSubmittedBreed() throws {
        let profile = PetProfileEditProfile(
            id: "pet-1",
            name: "糯米",
            species: .dog,
            breed: "",
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

        let draft = screen.updateDraft(for: profile, breed: "金毛寻回犬")
        let json = try Self.encodedJSONObject(draft)

        XCTAssertEqual(json["breed"] as? String, "金毛寻回犬")
    }

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

    func testCurrentUpdateDraftUsesStoredValuesInsteadOfDisplayPlaceholders() throws {
        let profile = PetProfileEditProfile(
            id: "pet-1",
            name: "糯米",
            species: .cat,
            breed: "",
            avatarURL: nil,
            heroMedia: .image(assetName: "HomePetHeroMock"),
            heroThemeColorHex: nil,
            heroContentColorScheme: nil,
            profileCode: "0000000000000001",
            chipNumber: "",
            sexText: "未知",
            birthDateText: "",
            arrivalDateText: "",
            weightText: "",
            neuterStatusText: "未绝育",
            personalityTags: [],
            note: "",
            nameEditPolicy: nil
        )
        let screen = PetProfileEditScreen(
            context: PetProfileEditContext(selectedProfile: profile, profiles: [profile])
        )

        let draft = screen.currentUpdateDraft(for: profile)
        let json = try Self.encodedJSONObject(draft)

        XCTAssertTrue(json["breed"] is NSNull)
        XCTAssertTrue(json["birthday"] is NSNull)
        XCTAssertTrue(json["arrival_date"] is NSNull)
        XCTAssertNil(json["weight_grams"])
        XCTAssertTrue(json["note"] is NSNull)
    }

    func testSubmittedDraftMatchingCurrentProfileIsNoop() {
        let profile = PetProfileEditProfile(
            id: "pet-1",
            name: "糯米",
            species: .cat,
            breed: "布偶",
            avatarURL: nil,
            heroMedia: .image(assetName: "HomePetHeroMock"),
            heroThemeColorHex: nil,
            heroContentColorScheme: nil,
            profileCode: "0000000000000001",
            chipNumber: "901156260000001",
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

        XCTAssertTrue(screen.isNoopUpdateDraft(draft, for: profile))
    }

    func testProfileDisplaysDisputedMicrochipStatusFromExternalIdentifierSummary() {
        let profile = PetProfileEditProfile(
            id: "pet-1",
            name: "糯米",
            species: .cat,
            breed: "布偶",
            avatarURL: nil,
            heroMedia: .image(assetName: "HomePetHeroMock"),
            heroThemeColorHex: nil,
            heroContentColorScheme: nil,
            profileCode: "0000000000000001",
            chipNumber: "901156260000001",
            chipIdentifier: PetExternalIdentifierSummary(
                id: "identifier-1",
                petID: "pet-1",
                identifierType: "microchip",
                identifierValue: "901156260000001",
                issuer: nil,
                issuedAt: nil,
                verifiedStatus: "self_reported",
                status: "disputed"
            ),
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

        XCTAssertEqual(screen.displayChipStatusLabel(for: profile), "争议中")
    }

    private static func encodedJSONObject<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
