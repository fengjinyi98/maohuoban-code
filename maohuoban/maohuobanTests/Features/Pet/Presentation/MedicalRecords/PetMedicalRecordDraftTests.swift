import XCTest
@testable import maohuoban

// PetMedicalRecordDraftTests 医院病历展示模型测试
// 核心职责：
// - 固化医院回流病历的前端展示派生规则
// - 避免测试继续依赖用户自建病历草稿入口
@MainActor
final class PetMedicalRecordDraftTests: XCTestCase {
    func testSubtitleCombinesHospitalAndDiagnosis() {
        let record = makeRecord(
            hospitalName: "毛伙伴验证闭环医院",
            diagnosis: "急性肠胃炎"
        )

        XCTAssertEqual(record.subtitle, "毛伙伴验证闭环医院 · 急性肠胃炎")
    }

    func testSubtitleOmitsBlankParts() {
        let record = makeRecord(
            hospitalName: "  ",
            diagnosis: "急性肠胃炎"
        )

        XCTAssertEqual(record.subtitle, "急性肠胃炎")
    }

    func testPublishedUpdatesPreserveHospitalReturnOrder() {
        let record = makeRecord(
            updates: [
                PetMedicalRecord.Update(
                    id: "latest-update",
                    title: "复诊建议",
                    occurredAtText: "2026年6月20日 20:10",
                    note: "继续观察食欲"
                ),
                PetMedicalRecord.Update(
                    id: "first-update",
                    title: "检查结果",
                    occurredAtText: "2026年6月19日 20:10",
                    note: "血常规无明显异常"
                )
            ]
        )

        XCTAssertEqual(record.updates.map(\.id), ["latest-update", "first-update"])
    }

    private func makeRecord(
        hospitalName: String = "毛伙伴验证闭环医院",
        diagnosis: String = "急性肠胃炎",
        updates: [PetMedicalRecord.Update] = []
    ) -> PetMedicalRecord {
        PetMedicalRecord(
            id: "medical-record-1",
            petID: "pet-1",
            title: diagnosis,
            hospitalName: hospitalName,
            doctorName: "林医生",
            occurredAtText: "2026年6月18日 15:30",
            reason: "呕吐",
            diagnosis: diagnosis,
            treatment: "止吐针",
            medication: "益生菌",
            costText: "328 元",
            note: "",
            attachmentTitles: [],
            updates: updates
        )
    }
}
