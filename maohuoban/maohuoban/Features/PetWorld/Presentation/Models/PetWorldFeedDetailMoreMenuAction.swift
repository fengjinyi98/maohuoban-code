import Foundation

// PetWorldFeedDetailMoreMenuAction 详情页更多菜单动作
// 核心职责：
// - 描述详情页右上角更多菜单可展示的动作
// - 支撑作者态与访客态的菜单规则解析
enum PetWorldFeedDetailMoreMenuAction: Equatable, Identifiable {
    case share
    case report

    var id: Self {
        self
    }
}

// PetWorldFeedDetailMoreMenuActionResolver 详情页更多菜单动作解析器
// 核心职责：
// - 根据当前登录用户是否为帖子作者过滤菜单入口
// - 避免作者态展示举报和删除等危险操作
enum PetWorldFeedDetailMoreMenuActionResolver {
    nonisolated static func actions(
        isOwnedByCurrentUser: Bool
    ) -> [PetWorldFeedDetailMoreMenuAction] {
        if isOwnedByCurrentUser {
            return [.share]
        }

        return [.share, .report]
    }
}
