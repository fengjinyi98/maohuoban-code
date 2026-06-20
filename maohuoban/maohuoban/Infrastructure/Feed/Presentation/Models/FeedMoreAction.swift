import Foundation

// FeedMoreAction Feed 卡片更多操作
// 核心职责：
// - 限定卡片更多菜单当前支持的操作
// - 为 Feed 列表和后续详情页复用同一事件语义
enum FeedMoreAction: Equatable {
    case dislike
    case report
    case delete
}
