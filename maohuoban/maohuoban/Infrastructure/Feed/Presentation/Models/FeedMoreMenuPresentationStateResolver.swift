import Foundation

// FeedMoreMenuPresentationStateResolver Feed 更多菜单展示状态解析器
// 核心职责：
// - 固化更多按钮点击后的展开、收起和切换规则
// - 让不同 Feed 页面复用一致的更多菜单展示语义
enum FeedMoreMenuPresentationStateResolver {
    static func toggledPostID(
        current: String?,
        postID: String
    ) -> String? {
        current == postID ? nil : postID
    }
}
