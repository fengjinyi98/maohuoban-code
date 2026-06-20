import SwiftUI

// TopicRoute 话题功能导航路由
// 核心职责：
// - 描述我的页、宠物世界和发布原型可共享的话题导航目标
// - 通过稳定 Hashable 值进入话题列表、详情和发布话题选择页
enum TopicRoute: Hashable {
    case followedList
    case detail(topicID: String)
    case composer(seedTopicID: String?)
}

// TopicRouteDestinationScreen 话题路由目标承载页
// 核心职责：
// - 统一将 TopicRoute 映射到具体 SwiftUI 页面
// - 让多个 Tab 复用同一套话题页面实现
struct TopicRouteDestinationScreen: View {
    let route: TopicRoute
    let store: TopicStore

    var body: some View {
        switch route {
        case .followedList:
            TopicFollowedListScreen(store: store)
        case .detail(let topicID):
            TopicDetailScreen(topicID: topicID, store: store)
        case .composer(let seedTopicID):
            TopicPostComposerScreen(seedTopicID: seedTopicID, store: store)
        }
    }
}
