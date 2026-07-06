import XCTest
@testable import maohuoban

// PetAbnormalSeverityPresentationTests 异常程度展示测试
// 核心职责：
// - 锁定异常创建页的程度选择只展示等级本身
// - 防止程度选项重新加入替用户判断的说明文案
@MainActor
final class PetAbnormalSeverityPresentationTests: XCTestCase {
    func testSeverityOptionsDoNotCarryDecisionMakingSubtitles() {
        let subtitles = PetAbnormalSeverity.allCases.map(\.subtitle)

        XCTAssertTrue(
            subtitles.allSatisfy(\.isEmpty),
            "异常程度选择只应表达轻微/明显/严重本身，不应携带稳定、观察、处理等决断型说明文案"
        )
    }
}
