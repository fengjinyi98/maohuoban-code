import XCTest
@testable import maohuoban

// PetPantryEmptyStatePresentationTests 储物柜空态展示测试
// 核心职责：
// - 固定空储物柜的页面级空态文案
// - 防止空态回退到宠物饮食配置语义
final class PetPantryEmptyStatePresentationTests: XCTestCase {
    func testDefaultPresentationUsesSpaceLevelPantryCopy() {
        let presentation = PetPantryEmptyStatePresentation.default

        XCTAssertEqual(presentation.title, "还没有常备物品")
        XCTAssertEqual(presentation.message, "添加猫粮、零食、营养品或清洁用品后，家庭储物柜会按分类整理它们。")
        XCTAssertEqual(presentation.buttonTitle, "添加第一个物品")
    }
}
