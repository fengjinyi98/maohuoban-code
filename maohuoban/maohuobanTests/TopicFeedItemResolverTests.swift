import XCTest
@testable import maohuoban

// TopicFeedItemResolverTests 话题 Feed 数据映射测试
// 核心职责：
// - 固化话题详情页复用通用 FeedItem 的数据契约
// - 防止话题帖子无法进入宠物世界详情页
@MainActor
final class TopicFeedItemResolverTests: XCTestCase {
    func testTopicFeedItemsUsePetWorldDetailBackedPosts() {
        let store = TopicStore()
        let topic = store.topics[0]

        let items = store.topicFeedItems(topicID: topic.id)

        XCTAssertFalse(items.isEmpty)
        XCTAssertNotNil(PetWorldMockFeedDetail.detail(for: items[0].postID))
    }
}
