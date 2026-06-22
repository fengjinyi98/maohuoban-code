import XCTest
@testable import maohuoban

// SearchNavigationRouteTests 搜索导航路由测试
// 核心职责：
// - 固化宠物世界搜索入口路由
// - 固化同城搜索入口路由
@MainActor
final class SearchNavigationRouteTests: XCTestCase {
    func testPetWorldRouteCarriesPetWorldSearchContext() {
        let route = PetWorldRoute.search(.petWorld)

        XCTAssertEqual(route, PetWorldRoute.search(.petWorld))
    }

    func testSameCityRouteCarriesSameCitySearchContext() {
        let route = SameCityRoute.search(.sameCity(city: "上海"))

        XCTAssertEqual(route, SameCityRoute.search(.sameCity(city: "上海")))
    }

    func testSameCityRouteCarriesTopicDetailContext() {
        let route = SameCityRoute.topicDetail(topicID: "topic-cat-care")

        XCTAssertEqual(route, SameCityRoute.topicDetail(topicID: "topic-cat-care"))
    }

    func testSameCityRouteCarriesTopicFeedDetailContext() {
        let route = SameCityRoute.topicFeedDetail(postID: "same-city-commodity-001")

        XCTAssertEqual(route, SameCityRoute.topicFeedDetail(postID: "same-city-commodity-001"))
    }
}
