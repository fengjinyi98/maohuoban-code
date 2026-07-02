import XCTest
@testable import maohuoban

// SearchNavigationSearchBarConfigurationTests 导航搜索栏配置测试
// 核心职责：
// - 固化 UIKit 搜索栏继承搜索入口占位文案
// - 固化不同入口的系统搜索栏文案
@MainActor
final class SearchNavigationSearchBarConfigurationTests: XCTestCase {
    func testConfigurationUsesPetWorldEntryContextPrompt() {
        let configuration = SearchNavigationSearchBarConfiguration(context: .petWorld)

        XCTAssertEqual(configuration.prompt, "搜索宠物经验、话题和动态")
    }

    func testConfigurationUsesSameCityEntryContextPrompt() {
        let configuration = SearchNavigationSearchBarConfiguration(context: .sameCity(city: "上海"))

        XCTAssertEqual(configuration.prompt, "搜索上海同城 柯基 拼单")
    }
}
