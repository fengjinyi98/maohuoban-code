import XCTest
@testable import maohuoban

// SearchHotKeywordProviderTests 搜索热搜数据测试
// 核心职责：
// - 固化同城入口展示同城热搜
// - 固化宠物世界入口展示宠物世界热搜
@MainActor
final class SearchHotKeywordProviderTests: XCTestCase {
    func testSameCityContextUsesCityHotKeywords() {
        let context = SearchEntryContext.sameCity(city: "上海")

        let keywords = SearchHotKeywordProvider.hotKeywords(for: context)

        XCTAssertEqual(context.hotSectionTitle, "上海同城热搜")
        XCTAssertEqual(context.searchPrompt, "搜索上海同城 柯基 拼单")
        XCTAssertEqual(keywords.first?.title, "金渐层 跨品种拼单")
        XCTAssertTrue(keywords.contains { $0.badge == .cobuy })
    }

    func testPetWorldContextUsesPetWorldHotKeywords() {
        let context = SearchEntryContext.petWorld

        let keywords = SearchHotKeywordProvider.hotKeywords(for: context)

        XCTAssertEqual(context.hotSectionTitle, "宠物世界热搜")
        XCTAssertEqual(context.searchPrompt, "搜索宠物经验、话题和动态")
        XCTAssertEqual(keywords.first?.title, "猫藓怎么治")
        XCTAssertFalse(keywords.contains { $0.title == "金渐层 跨品种拼单" })
    }
}
