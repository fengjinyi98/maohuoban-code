import Foundation
import XCTest
@testable import maohuoban

// PetProfileSummaryDecodingTests 宠物摘要解码测试
// 核心职责：
// - 验证 ownerUserID Optional 解码（不再空字符串兜底）
// - 验证 lifeStatus / originKind 字段解码
// - 验证向后兼容（旧 JSON 无新字段仍可解码）
@MainActor
final class PetProfileSummaryDecodingTests: XCTestCase {

    // ── ownerUserID Optional 兜底移除 ──

    func testOwnerUserIDIsNilWhenMissing() throws {
        let json = """
        {
          "id": "pet-1",
          "name": "测试",
          "species": "dog",
          "sex": "male"
        }
        """
        let data = Data(json.utf8)
        let profile = try JSONDecoder().decode(PetProfileSummary.self, from: data)
        XCTAssertNil(profile.ownerUserID, "ownerUserID 缺失时应为 nil，不应兜底空字符串")
    }

    func testOwnerUserIDDecodesWhenPresent() throws {
        let json = """
        {
          "id": "pet-1",
          "owner_user_id": "user-1",
          "name": "测试",
          "species": "dog",
          "sex": "male"
        }
        """
        let data = Data(json.utf8)
        let profile = try JSONDecoder().decode(PetProfileSummary.self, from: data)
        XCTAssertEqual(profile.ownerUserID, "user-1")
    }

    // ── lifeStatus / originKind 新字段解码 ──

    func testLifeStatusAndOriginKindDecodeFromJSON() throws {
        let json = """
        {
          "id": "pet-1",
          "owner_user_id": "user-1",
          "name": "旺财",
          "species": "dog",
          "sex": "male",
          "life_status": "alive",
          "origin_kind": "user_created"
        }
        """
        let data = Data(json.utf8)
        let profile = try JSONDecoder().decode(PetProfileSummary.self, from: data)
        XCTAssertEqual(profile.lifeStatus, "alive")
        XCTAssertEqual(profile.originKind, "user_created")
    }

    func testLifeStatusDeceasedDecodesCorrectly() throws {
        let json = """
        {
          "id": "pet-1",
          "owner_user_id": "user-1",
          "name": "已故宠物",
          "species": "cat",
          "sex": "female",
          "life_status": "deceased",
          "origin_kind": "adopted"
        }
        """
        let data = Data(json.utf8)
        let profile = try JSONDecoder().decode(PetProfileSummary.self, from: data)
        XCTAssertEqual(profile.lifeStatus, "deceased")
        XCTAssertEqual(profile.originKind, "adopted")
    }

    // ── 向后兼容：旧 JSON 无新字段 ──

    func testDecodeLegacyJSONWithoutNewFields() throws {
        let json = """
        {
          "id": "pet-1",
          "owner_user_id": "user-1",
          "name": "旧版本宠物",
          "species": "dog",
          "sex": "male",
          "profile_number": "0000000000000001",
          "microchip_number": "156000000000001"
        }
        """
        let data = Data(json.utf8)
        let profile = try JSONDecoder().decode(PetProfileSummary.self, from: data)
        XCTAssertEqual(profile.name, "旧版本宠物")
        XCTAssertNil(profile.lifeStatus, "旧 JSON 无 life_status 时应为 nil")
        XCTAssertNil(profile.originKind, "旧 JSON 无 origin_kind 时应为 nil")
        XCTAssertEqual(profile.microchipNumber, "156000000000001")
    }

    // ── lifeStatus 展示保护逻辑 ──

    func testAliveAllowsWrite() throws {
        let status = PetLifeStatus.alive
        XCTAssertTrue(status.allowsWriteOperations)
        XCTAssertTrue(status.allowsViewHistory)
        XCTAssertEqual(status.displayLabel, "健在")
        XCTAssertFalse(status.isTerminal)
    }

    func testDeceasedBlocksWrite() throws {
        let status = PetLifeStatus.deceased
        XCTAssertFalse(status.allowsWriteOperations, "去世宠物禁止写入")
        XCTAssertTrue(status.allowsViewHistory, "去世宠物仍可查看历史")
        XCTAssertEqual(status.displayLabel, "已离世")
        XCTAssertTrue(status.isTerminal)
    }

    func testLostAllowsWrite() throws {
        let status = PetLifeStatus.lost
        XCTAssertTrue(status.allowsWriteOperations, "走失宠物允许记录线索")
        XCTAssertTrue(status.allowsViewHistory)
        XCTAssertEqual(status.displayLabel, "走失中")
        XCTAssertFalse(status.isTerminal)
    }

    func testArchivedBlocksWrite() throws {
        let status = PetLifeStatus.archived
        XCTAssertFalse(status.allowsWriteOperations)
        XCTAssertTrue(status.allowsViewHistory)
        XCTAssertEqual(status.displayLabel, "已归档")
        XCTAssertTrue(status.isTerminal)
    }

    func testLifeStatusDecodingFromRawValue() throws {
        XCTAssertEqual(PetLifeStatus(rawValue: "alive"), .alive)
        XCTAssertEqual(PetLifeStatus(rawValue: "deceased"), .deceased)
        XCTAssertEqual(PetLifeStatus(rawValue: "lost"), .lost)
        XCTAssertEqual(PetLifeStatus(rawValue: "archived"), .archived)
        XCTAssertNil(PetLifeStatus(rawValue: "unknown"))
    }
}
