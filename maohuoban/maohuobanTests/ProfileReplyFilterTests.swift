import XCTest
@testable import maohuoban

// ProfileReplyFilterTests 我的回复筛选测试
// 核心职责：
// - 固化我的回复页面收到和发出范围筛选规则
// - 固化搜索词对回复内容、引用上下文和身份标签的匹配范围
final class ProfileReplyFilterTests: XCTestCase {
    @MainActor
    func testReceivedScopeReturnsOnlyReceivedReplies() {
        let items = [
            ProfileReplyItem.mockReply(
                scope: .received,
                actorName: "李大锤爱柯基",
                timeText: "10 分钟前",
                replyText: "求一个猫舍推荐",
                contextTitle: "我的动态",
                contextText: "接糯米回家的第一天",
                contextKind: .post(symbolName: "photo.fill"),
                primaryActionTitle: "回复",
                primaryActionSymbolName: "bubble.left",
                secondaryActionTitle: "赞",
                secondaryActionSymbolName: "heart"
            ),
            ProfileReplyItem.mockReply(
                scope: .sent,
                actorName: "星梦名猫苑",
                timeText: "昨天",
                replyText: "专车大概多久能发车？",
                contextTitle: "@星梦名猫苑 的动态",
                contextText: "金渐层弟弟开放凑单中",
                contextKind: .post(symbolName: "shippingbox.fill"),
                primaryActionTitle: "删除记录",
                primaryActionSymbolName: "trash",
                secondaryActionTitle: "查看原文",
                secondaryActionSymbolName: "arrow.up.right.square"
            )
        ]

        let results = ProfileReplyFilter.filteredItems(
            items,
            scope: .received,
            query: ""
        )

        XCTAssertEqual(results.map(\.actorName), ["李大锤爱柯基"])
    }

    @MainActor
    func testSearchMatchesReplyContextAndBadge() {
        let items = [
            ProfileReplyItem.mockReply(
                scope: .received,
                actorName: "阿May的流浪小屋",
                actorBadgeText: "志愿者",
                timeText: "2 小时前",
                replyText: "感谢支持领养",
                contextTitle: "我的评论",
                contextText: "请问三花妹妹还在吗",
                contextKind: .comment,
                primaryActionTitle: "回复",
                primaryActionSymbolName: "bubble.left",
                secondaryActionTitle: "赞",
                secondaryActionSymbolName: "heart"
            ),
            ProfileReplyItem.mockReply(
                scope: .received,
                actorName: "李大锤爱柯基",
                timeText: "10 分钟前",
                replyText: "求一个猫舍推荐",
                contextTitle: "我的动态",
                contextText: "接糯米回家的第一天",
                contextKind: .post(symbolName: "photo.fill"),
                primaryActionTitle: "回复",
                primaryActionSymbolName: "bubble.left",
                secondaryActionTitle: "赞",
                secondaryActionSymbolName: "heart"
            )
        ]

        let results = ProfileReplyFilter.filteredItems(
            items,
            scope: .received,
            query: "志愿者"
        )

        XCTAssertEqual(results.map(\.actorName), ["阿May的流浪小屋"])
    }
}
