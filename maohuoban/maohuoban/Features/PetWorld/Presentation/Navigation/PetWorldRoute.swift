import Foundation

// PetWorldRoute 宠物世界导航路由
// 核心职责：
// - 描述宠物世界 Tab 内部系统导航目标
// - 为 Feed 帖子详情跳转提供稳定 Hashable 值
enum PetWorldRoute: Hashable {
    case search(SearchEntryContext)
    case feedDetail(postID: String)
    case topicDetail(topicID: String)
    case topicFeedDetail(postID: String)
    case publishEvent(PublishEntryContext)
}
