import XCTest
@testable import maohuoban

// SearchHistoryStateTests 搜索历史状态测试
// 核心职责：
// - 固化搜索历史清空行为
// - 保证搜索页历史区域使用可变本地 Mock 状态
@MainActor
final class SearchHistoryStateTests: XCTestCase {
    func testClearRemovesAllHistoryKeywords() {
        var state = SearchHistoryState(keywords: ["金渐层 拼单", "猫藓怎么治"])

        state.clear()

        XCTAssertTrue(state.keywords.isEmpty)
    }
}
