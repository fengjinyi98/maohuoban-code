import XCTest
@testable import maohuoban

// ProfileFollowingFilterTests 我的关注筛选测试
// 核心职责：
// - 固化我的关注页面分类筛选规则
// - 固化搜索词对昵称、品种和备注的匹配范围
final class ProfileFollowingFilterTests: XCTestCase {
    @MainActor
    func testPetScopeSearchesPetNameAndBreed() {
        let items = [
            ProfileFollowingItem.mockPet(name: "糯米", breed: "金毛寻回犬"),
            ProfileFollowingItem.mockPet(name: "团子", breed: "英国短毛猫"),
            ProfileFollowingItem.mockUser(name: "糯米主人", bio: "周末遛狗")
        ]

        let results = ProfileFollowingFilter.filteredItems(
            items,
            scope: .pets,
            query: "金毛"
        )

        XCTAssertEqual(results.map(\.name), ["糯米"])
    }

    @MainActor
    func testMutualScopeSearchesMutualUsersOnly() {
        let items = [
            ProfileFollowingItem.mockUser(name: "Sarah_Chen", bio: "养了两只边牧"),
            ProfileFollowingItem.mockMutualUser(name: "李大锤爱柯基", bio: "分享柯基日常"),
            ProfileFollowingItem.mockMutualUser(name: "小透明铲屎官", bio: "刚接猫咪回家")
        ]

        let results = ProfileFollowingFilter.filteredItems(
            items,
            scope: .mutual,
            query: "柯基"
        )

        XCTAssertEqual(results.map(\.name), ["李大锤爱柯基"])
    }
}
