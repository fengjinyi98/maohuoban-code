import XCTest
@testable import maohuoban

// ProfileQuickEntryRouteResolverTests 我的页快捷入口路由测试
// 核心职责：
// - 固化“我的宠物”等快捷入口到 ProfileRoute 的映射
// - 确认未接管入口不会产生导航目标
final class ProfileQuickEntryRouteResolverTests: XCTestCase {
    @MainActor
    func testMyPetsEntryRoutesToPetManagementScreen() {
        let item = ProfileQuickEntryItem(id: "myPets", title: "我的宠物", systemImage: "pawprint.fill")

        let route = ProfileQuickEntryRouteResolver.route(for: item)

        XCTAssertEqual(route, .myPets)
    }

    @MainActor
    func testUnsupportedEntryHasNoRoute() {
        let item = ProfileQuickEntryItem(id: "more", title: "更多", systemImage: "ellipsis")

        let route = ProfileQuickEntryRouteResolver.route(for: item)

        XCTAssertNil(route)
    }

    @MainActor
    func testMyRepliesEntryRoutesToProfileRepliesScreen() {
        let item = ProfileQuickEntryItem(id: "myReplies", title: "我的回复", systemImage: "bubble.left.fill")

        let route = ProfileQuickEntryRouteResolver.route(for: item)

        XCTAssertEqual(route, .replies)
    }

    @MainActor
    func testMyFavoritesEntryRoutesToProfileFavoriteFoldersScreen() {
        let item = ProfileQuickEntryItem(id: "myFavorites", title: "我的收藏", systemImage: "star.fill")

        let route = ProfileQuickEntryRouteResolver.route(for: item)

        XCTAssertEqual(route, .favoriteFolders)
    }

    @MainActor
    func testFollowingStatRoutesToProfileFollowingScreen() {
        let stat = ProfileAccountStat(id: "following", value: "41", title: "关注")

        let route = ProfileAccountStatRouteResolver.route(for: stat)

        XCTAssertEqual(route, .following)
    }

    @MainActor
    func testFollowersStatRoutesToProfileFollowersScreen() {
        let stat = ProfileAccountStat(id: "followers", value: "5", title: "粉丝")

        let route = ProfileAccountStatRouteResolver.route(for: stat)

        XCTAssertEqual(route, .followers)
    }
}
