import XCTest
@testable import maohuoban

// HomeQuickActionPresentationTests 首页快捷动作展示语义测试
// 核心职责：
// - 固化快捷动作副标题优先使用接口文案
// - 固化缺省副标题回落到本地说明映射
final class HomeQuickActionPresentationTests: XCTestCase {
    func testSubtitleUsesBackendValueWhenProvided() {
        let action = HomeDashboardSnapshot.Action(
            kind: .createPet,
            title: "添加宠物",
            subtitle: "从犬猫档案开始"
        )

        XCTAssertEqual(
            HomeQuickActionPresentation.subtitle(for: action),
            "从犬猫档案开始"
        )
    }

    func testSubtitleFallsBackToLocalCopyWhenBackendValueMissing() {
        let action = HomeDashboardSnapshot.Action(
            kind: .publishAvailableStatus,
            title: "发布可售状态",
            subtitle: nil
        )

        XCTAssertEqual(
            HomeQuickActionPresentation.subtitle(for: action),
            "同步在售宠物与档期状态"
        )
    }
}
