import Foundation
import XCTest
@testable import maohuoban

// PetExternalIdentifierSummaryTests 外部标识摘要测试
// 核心职责：
// - 验证芯片号外部标识解码
// - 验证验证状态和争议状态逻辑
@MainActor
final class PetExternalIdentifierSummaryTests: XCTestCase {

    func testDecodeMicrochipIdentifier() throws {
        let json = """
        {
          "id": "ext-1",
          "pet_id": "pet-1",
          "identifier_type": "microchip",
          "identifier_value": "900000000000001",
          "verified_status": "self_reported",
          "status": "active"
        }
        """
        let data = Data(json.utf8)
        let ident = try JSONDecoder().decode(PetExternalIdentifierSummary.self, from: data)
        XCTAssertEqual(ident.identifierType, "microchip")
        XCTAssertEqual(ident.identifierValue, "900000000000001")
        XCTAssertEqual(ident.verifiedStatus, "self_reported")
        XCTAssertEqual(ident.status, "active")
    }

    func testIsVerifiedFlag() {
        let ident = PetExternalIdentifierSummary(
            id: "1", petID: "p1",
            identifierType: "microchip", identifierValue: "900000000000001",
            issuer: nil, issuedAt: nil,
            verifiedStatus: "verified", status: "active"
        )
        XCTAssertTrue(ident.isVerified)
        XCTAssertFalse(ident.isDisputed)
    }

    func testIsNotVerifiedForSelfReported() {
        let ident = PetExternalIdentifierSummary(
            id: "1", petID: "p1",
            identifierType: "microchip", identifierValue: "900000000000001",
            issuer: nil, issuedAt: nil,
            verifiedStatus: "self_reported", status: "active"
        )
        XCTAssertFalse(ident.isVerified)
    }

    func testIsDisputedFlag() {
        let ident = PetExternalIdentifierSummary(
            id: "1", petID: "p1",
            identifierType: "microchip", identifierValue: "900000000000001",
            issuer: nil, issuedAt: nil,
            verifiedStatus: "self_reported", status: "disputed"
        )
        XCTAssertTrue(ident.isDisputed)
    }

    func testVerificationLabels() {
        let verified = PetExternalIdentifierSummary(
            id: "1", petID: "p1",
            identifierType: "microchip", identifierValue: "1",
            issuer: nil, issuedAt: nil,
            verifiedStatus: "verified", status: "active"
        )
        XCTAssertEqual(verified.verificationLabel, "已验证")

        let selfReported = PetExternalIdentifierSummary(
            id: "2", petID: "p1",
            identifierType: "microchip", identifierValue: "2",
            issuer: nil, issuedAt: nil,
            verifiedStatus: "self_reported", status: "active"
        )
        XCTAssertEqual(selfReported.verificationLabel, "用户自报")

        let rejected = PetExternalIdentifierSummary(
            id: "3", petID: "p1",
            identifierType: "microchip", identifierValue: "3",
            issuer: nil, issuedAt: nil,
            verifiedStatus: "rejected", status: "active"
        )
        XCTAssertEqual(rejected.verificationLabel, "已驳回")

        let unverified = PetExternalIdentifierSummary(
            id: "4", petID: "p1",
            identifierType: "microchip", identifierValue: "4",
            issuer: nil, issuedAt: nil,
            verifiedStatus: "unverified", status: "active"
        )
        XCTAssertEqual(unverified.verificationLabel, "未验证")
    }
}
