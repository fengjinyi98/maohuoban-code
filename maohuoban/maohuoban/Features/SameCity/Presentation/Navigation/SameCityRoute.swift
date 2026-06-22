import Foundation

// SameCityRoute 同城 Tab 路由枚举
// 核心职责：
// - 定义同城 Tab 内部系统导航目标
// - 为同城发布入口提供稳定 Hashable 路由值
enum SameCityRoute: Hashable {
    case search(SearchEntryContext)
    case publishEvent(PublishEntryContext)
    case commodityDetail(postID: String)
    case topicDetail(topicID: String)
    case topicFeedDetail(postID: String)
}
