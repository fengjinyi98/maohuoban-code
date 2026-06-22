import XCTest
@testable import maohuoban

// MHBPetSwitcherItemTests 宠物切换展示模型测试
// 核心职责：
// - 固化通用宠物切换列表的选中态重建
// - 防止业务页面各自散写不一致的切换逻辑
final class MHBPetSwitcherItemTests: XCTestCase {
    @MainActor
    func testPetSwitcherItemKeepsCapsuleDisplayFields() {
        let item = MHBPetSwitcherItem(
            id: "pet-1",
            name: "糯米",
            subtitle: "比熊 · 2岁",
            avatarURLString: nil,
            species: .dog,
            sex: .female,
            isSelected: true
        )

        XCTAssertEqual(item.name, "糯米")
        XCTAssertEqual(item.species, .dog)
        XCTAssertEqual(item.sex, .female)
        XCTAssertTrue(item.isSelected)
    }
}
