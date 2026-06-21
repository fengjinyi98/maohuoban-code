import Foundation

// ProfileQuickEntryRouteResolver 我的页快捷入口路由解析器
// 核心职责：
// - 将快捷入口稳定标识映射到 ProfileRoute
// - 让未接管入口保持无导航目标
enum ProfileQuickEntryRouteResolver {
    static func route(for item: ProfileQuickEntryItem) -> ProfileRoute? {
        switch item.id {
        case "myPets":
            .myPets
        case "petAlbum":
            .petAlbumList
        case "myReplies":
            .replies
        default:
            nil
        }
    }
}
