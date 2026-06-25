import Foundation
import XCTest
@testable import maohuoban

// PetWriteDraftEncodingTests 宠物写入草稿编码测试
// 核心职责：
// - 验证宠物写入草稿编码前的文本规范化
// - 固化名称与品种空白移除行为
@MainActor
final class PetWriteDraftEncodingTests: PetRepositoryTestCase {
    func testPetWriteDraftsRemoveWhitespaceFromPetNameAndBreed() throws {
        let createJSON = try Self.encodedJSONObject(
            PetProfileDraft(
                name: " 奶 盖 宝 宝 兔 兔 ",
                species: .cat,
                breed: " 英 国 长 毛 猫 稀 有 毛 色 版 本 ",
                sex: .female,
                birthday: "2024-04-01"
            )
        )
        XCTAssertEqual(createJSON["name"] as? String, "奶盖宝宝兔兔")
        XCTAssertEqual(createJSON["breed"] as? String, "英国长毛猫稀有毛色版本")

        let updateJSON = try Self.encodedJSONObject(
            PetProfileUpdateDraft(
                name: " 奶 盖 宝 宝 兔 兔 ",
                species: .cat,
                breed: " 超 长 长 长 长 长 长 长 长 长 长 品 种 ",
                sex: .female,
                birthday: "2024-04-01",
                microchipNumber: "",
                arrivalDate: "",
                weightGrams: nil,
                neuterStatus: .unknown,
                personalityTags: [],
                note: ""
            )
        )
        XCTAssertEqual(updateJSON["name"] as? String, "奶盖宝宝兔兔")
        XCTAssertEqual(updateJSON["breed"] as? String, "超长长长长长长长长长长品种")

        let tradeJSON = try Self.encodedJSONObject(
            TradePetImportDraft(
                name: " 奶 盖 宝 宝 兔 兔 ",
                species: .cat,
                breed: " 布 偶 猫 长 毛 系 ",
                sex: .female,
                birthday: "2024-03-20",
                sellerName: "安心猫舍",
                tradeReference: "offline-contract-001",
                summary: "线下交易完成",
                occurredAt: "2026-06-13T10:00:00Z"
            )
        )
        XCTAssertEqual(tradeJSON["name"] as? String, "奶盖宝宝兔兔")
        XCTAssertEqual(tradeJSON["breed"] as? String, "布偶猫长毛系")
    }

    func testProfileDraftsSubmitMicrochipAsEditableProfileField() throws {
        let createJSON = try Self.encodedJSONObject(
            PetProfileDraft(
                name: "奶盖",
                species: .cat,
                breed: "布偶",
                sex: .female,
                birthday: "2024-04-01",
                microchipNumber: "156000000000101"
            )
        )
        XCTAssertEqual(createJSON["microchip_number"] as? String, "156000000000101")

        let updateJSON = try Self.encodedJSONObject(
            PetProfileUpdateDraft(
                name: "奶盖",
                species: .cat,
                breed: "布偶",
                sex: .female,
                birthday: "2024-04-01",
                microchipNumber: "156000000000101",
                arrivalDate: "",
                weightGrams: nil,
                neuterStatus: .unknown,
                personalityTags: [],
                note: ""
            )
        )
        XCTAssertEqual(updateJSON["microchip_number"] as? String, "156000000000101")
    }
}
