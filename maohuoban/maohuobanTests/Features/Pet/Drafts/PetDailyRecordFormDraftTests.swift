import XCTest
@testable import maohuoban

// PetDailyRecordFormDraftTests 日常记录草稿测试
// 核心职责：
// - 固化日常打卡输入到事件摘要的合成规则
// - 验证发布前记录与仅保存记录使用同一事件草稿
@MainActor
final class PetDailyRecordFormDraftTests: XCTestCase {
    func testDailyDraftBuildsEventTitleAndSummary() {
        let draft = PetDailyRecordFormDraft(
            energy: .steady,
            didFeed: true,
            foodText: "渴望六种鱼",
            didCleanPoop: true,
            poopStatus: .healthy,
            didAddWater: true,
            didBath: true,
            note: "晚上食欲稳定"
        )

        XCTAssertEqual(draft.eventTitle, "日常记录")
        XCTAssertEqual(
            draft.eventSummary,
            "精神与活力：正常平稳\n完成喂食：渴望六种鱼\n清理粪便：健康成型\n补充水分\n洗澡清洁\n备注：晚上食欲稳定"
        )
    }
}
