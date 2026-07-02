import Foundation
import XCTest
@testable import maohuoban

// PetIdentityContextDecodingTests Agent 身份上下文解码测试
// 核心职责：
// - 验证 PetIdentityContext 聚合 JSON 解码
// - 验证 GuardianSummary 多关系场景
@MainActor
final class PetIdentityContextDecodingTests: XCTestCase {

    func testDecodeFullIdentityContext() throws {
        let json = """
        {
          "identity": {
            "pet_id": "pet-1",
            "profile_number": "0000000000000001",
            "name": "旺财",
            "species": "dog",
            "breed": "金毛",
            "sex": "male",
            "life_status": "alive"
          },
          "origin": {
            "origin_kind": "user_created",
            "created_at": "2026-01-01T00:00:00Z"
          },
          "current_guardians": [
            {
              "guardian_id": "g-1",
              "guardian_type": "user",
              "guardian_user_id": "user-1",
              "role": "owner",
              "status": "active"
            }
          ],
          "external_identifiers": [
            {
              "identifier_type": "microchip",
              "identifier_value": "900000000000001",
              "verified_status": "self_reported",
              "status": "active"
            }
          ],
          "lifecycle": [
            {
              "id": "le-1",
              "event_kind": "created",
              "occurred_at": "2026-01-01T00:00:00Z"
            }
          ]
        }
        """
        let data = Data(json.utf8)
        let context = try JSONDecoder().decode(PetIdentityContext.self, from: data)

        XCTAssertEqual(context.identity.petID, "pet-1")
        XCTAssertEqual(context.identity.name, "旺财")
        XCTAssertEqual(context.identity.lifeStatus, "alive")
        XCTAssertEqual(context.origin.originKind, "user_created")
        XCTAssertEqual(context.currentGuardians.count, 1)
        XCTAssertEqual(context.externalIdentifiers.count, 1)
        XCTAssertEqual(context.lifecycle.count, 1)
    }

    func testGuardianSummaryActiveOwner() throws {
        let json = """
        {
          "guardian_id": "g-1",
          "guardian_type": "user",
          "guardian_user_id": "user-1",
          "role": "owner",
          "status": "active"
        }
        """
        let data = Data(json.utf8)
        let guardian = try JSONDecoder().decode(GuardianSummary.self, from: data)
        XCTAssertTrue(guardian.isActiveOwner)
        XCTAssertFalse(guardian.isCoCaretaker)
    }

    func testGuardianSummaryCoCaretaker() throws {
        let json = """
        {
          "guardian_id": "g-2",
          "guardian_type": "user",
          "guardian_user_id": "user-2",
          "role": "co_caretaker",
          "status": "active"
        }
        """
        let data = Data(json.utf8)
        let guardian = try JSONDecoder().decode(GuardianSummary.self, from: data)
        XCTAssertFalse(guardian.isActiveOwner)
        XCTAssertTrue(guardian.isCoCaretaker)
    }

    func testGuardianSummaryIdentifiable() throws {
        let json = """
        {
          "guardian_id": "g-3",
          "guardian_type": "user",
          "role": "owner",
          "status": "active"
        }
        """
        let data = Data(json.utf8)
        let guardian = try JSONDecoder().decode(GuardianSummary.self, from: data)
        // Identifiable conformance：id 应返回 guardianID
        XCTAssertEqual(guardian.id, "g-3")
        XCTAssertEqual(guardian.guardianID, "g-3")
    }

    func testIdentityContextMultipleGuardians() throws {
        let json = """
        {
          "identity": {
            "pet_id": "pet-1",
            "profile_number": "0000000000000001",
            "name": "多主人宠物",
            "species": "cat",
            "sex": "female",
            "life_status": "alive"
          },
          "origin": {
            "origin_kind": "adopted",
            "created_at": "2026-03-01T00:00:00Z"
          },
          "current_guardians": [
            { "guardian_id": "g-1", "guardian_type": "user", "guardian_user_id": "user-1", "role": "owner", "status": "active" },
            { "guardian_id": "g-2", "guardian_type": "user", "guardian_user_id": "user-2", "role": "co_caretaker", "status": "active" }
          ],
          "external_identifiers": [],
          "lifecycle": [
            { "id": "le-1", "event_kind": "created", "occurred_at": "2026-03-01T00:00:00Z" }
          ]
        }
        """
        let data = Data(json.utf8)
        let context = try JSONDecoder().decode(PetIdentityContext.self, from: data)

        XCTAssertEqual(context.currentGuardians.count, 2)
        XCTAssertEqual(context.currentGuardians.filter { $0.isActiveOwner }.count, 1)
        XCTAssertEqual(context.currentGuardians.filter { $0.isCoCaretaker }.count, 1)
    }
}
