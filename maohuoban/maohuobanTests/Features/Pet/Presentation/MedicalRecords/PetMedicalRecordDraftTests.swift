import XCTest
@testable import maohuoban

// PetMedicalRecordDraftTests 病历记录草稿测试
// 核心职责：
// - 固化新增病历草稿到前端病历模型的映射
// - 验证追加病历条目的生成规则
@MainActor
final class PetMedicalRecordDraftTests: XCTestCase {
    func testCreateDraftBuildsMedicalRecord() {
        var draft = PetMedicalRecordDraft()
        draft.reason = "呕吐"
        draft.hospitalName = "瑞派宠物医院"
        draft.doctorName = "林医生"
        draft.diagnosis = "急性肠胃炎"
        draft.treatment = "止吐针"
        draft.medication = "益生菌"
        draft.costText = "328 元"
        draft.note = "少量多餐"

        let record = draft.makeRecord(petID: "pet-1")

        XCTAssertEqual(record.petID, "pet-1")
        XCTAssertEqual(record.title, "急性肠胃炎")
        XCTAssertEqual(record.reason, "呕吐")
        XCTAssertEqual(record.hospitalName, "瑞派宠物医院")
        XCTAssertEqual(record.doctorName, "林医生")
        XCTAssertEqual(record.treatment, "止吐针")
        XCTAssertEqual(record.medication, "益生菌")
        XCTAssertEqual(record.costText, "328 元")
        XCTAssertEqual(record.note, "少量多餐")
    }

    func testAppendDraftBuildsUpdate() {
        var draft = PetMedicalRecordDraft()
        draft.treatment = "复查血常规"
        draft.medication = "继续益生菌"
        draft.note = "食欲恢复"

        let update = draft.makeUpdate()

        XCTAssertEqual(update.title, "处置更新")
        XCTAssertEqual(update.note, "复查血常规\n继续益生菌\n食欲恢复")
    }

    func testAppendUpdateInsertsAtFrontOfRecord() {
        var record = PetMedicalRecord(
            id: "medical-record-1",
            petID: "pet-1",
            title: "复诊",
            hospitalName: "瑞派宠物医院",
            doctorName: "林医生",
            occurredAtText: "2026年6月18日 15:30",
            reason: "呕吐",
            diagnosis: "急性肠胃炎",
            treatment: "止吐针",
            medication: "益生菌",
            costText: "328 元",
            note: "",
            attachmentTitles: [],
            updates: [
                PetMedicalRecord.Update(
                    id: "old-update",
                    title: "旧追加",
                    occurredAtText: "2026年6月19日 20:10",
                    note: "旧记录"
                )
            ]
        )

        record.appendUpdate(
            PetMedicalRecord.Update(
                id: "new-update",
                title: "新追加",
                occurredAtText: "2026年6月20日 20:10",
                note: "新记录"
            )
        )

        XCTAssertEqual(record.updates.map(\.id), ["new-update", "old-update"])
    }
}
