import Foundation

// FeedMoreMenuContext Feed 更多菜单使用场景
// 核心职责：
// - 区分通用 Feed 与业务专用 Feed 的菜单策略
// - 为 FeedList 提供可扩展的菜单动作上下文
enum FeedMoreMenuContext: Equatable {
    case standard
    case favoriteFolder
}

// FeedMoreMenuActionResolver Feed 更多菜单动作解析器
// 核心职责：
// - 根据 Feed 使用场景生成更多菜单动作
// - 避免业务页面直接拼装菜单内容
enum FeedMoreMenuActionResolver {
    static func actions(context: FeedMoreMenuContext) -> [FeedMoreAction] {
        switch context {
        case .standard:
            [.dislike, .report]
        case .favoriteFolder:
            [.removeFromFavoriteFolder]
        }
    }
}
