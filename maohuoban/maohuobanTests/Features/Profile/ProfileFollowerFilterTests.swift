import XCTest
@testable import maohuoban

// ProfileFollowerFilterTests 我的粉丝筛选测试
// 核心职责：
// - 固化我的粉丝页面筛选规则
// - 固化搜索词对粉丝昵称、来源上下文和认证标签的匹配范围
final class ProfileFollowerFilterTests: XCTestCase {
    @MainActor
    func testUnfollowedScopeReturnsOnlyFollowersNeedingFollowBack() {
        let items = [
            ProfileFollowerItem.mockFollower(name: "夏天爱吃瓜", contextText: "关注了你的宠物 糯米", isMutual: false),
            ProfileFollowerItem.mockFollower(name: "李大锤爱柯基", contextText: "关注了你的宠物 团子小公主", isMutual: true)
        ]

        let results = ProfileFollowerFilter.filteredItems(
            items,
            scope: .unfollowed,
            query: ""
        )

        XCTAssertEqual(results.map(\.name), ["夏天爱吃瓜"])
    }

    @MainActor
    func testAllScopeSearchesNameContextAndBadge() {
        let items = [
            ProfileFollowerItem.mockFollower(name: "瑞派宠物医院", contextText: "关注了你", badgeText: "认证机构"),
            ProfileFollowerItem.mockFollower(name: "小猫咪能有什么坏心思", contextText: "通过同城动态关注了你")
        ]

        let results = ProfileFollowerFilter.filteredItems(
            items,
            scope: .all,
            query: "认证"
        )

        XCTAssertEqual(results.map(\.name), ["瑞派宠物医院"])
    }
}
