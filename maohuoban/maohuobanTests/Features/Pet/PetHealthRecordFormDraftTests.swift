import XCTest
@testable import maohuoban

// PetHealthRecordFormDraftTests 健康记录表单草稿测试
// 核心职责：
// - 固化健康记录细分类型到事件字段的映射
// - 验证健康表单详情会合并为当前事件接口摘要
@MainActor
final class PetHealthRecordFormDraftTests: XCTestCase {
    func testVaccineDraftBuildsEventTitleSubkindAndSummary() {
        let draft = PetHealthRecordFormDraft(
            type: .vaccine,
            weightText: "5.2",
            vaccineBrand: "妙三多",
            vaccineDose: "第 3 针",
            visitReason: "",
            note: "精神稳定，食欲正常",
            reminderEnabled: true,
            reminderDateText: "2027-06-22"
        )

        XCTAssertEqual(draft.eventTitle, "疫苗记录")
        XCTAssertEqual(draft.eventSubkind, "vaccine")
        XCTAssertEqual(
            draft.eventSummary,
            "类型：疫苗\n体重：5.2kg\n疫苗品牌：妙三多\n打针针次：第 3 针\n下次提醒：2027-06-22\n备注：精神稳定，食欲正常"
        )
    }
}
