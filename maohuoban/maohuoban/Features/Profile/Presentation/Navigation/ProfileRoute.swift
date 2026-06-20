import Foundation

// ProfileRoute 我的页导航路由
// 核心职责：
// - 描述我的 Tab 内部系统导航目标
// - 为我的动态列表和动态详情提供稳定 Hashable 值
enum ProfileRoute: Hashable {
    case posts
    case feedDetail(postID: String)
    case petAlbumList
    case petAlbumDetail(albumID: String)
    case followedTopics
    case topicDetail(topicID: String)
    case topicFeedDetail(postID: String)
    case topicComposer(seedTopicID: String?)
}
