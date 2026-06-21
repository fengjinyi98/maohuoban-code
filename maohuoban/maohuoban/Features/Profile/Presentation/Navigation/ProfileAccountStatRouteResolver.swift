import Foundation

// ProfileAccountStatRouteResolver 我的页统计项路由解析器
// 核心职责：
// - 将账号统计项稳定标识映射到 ProfileRoute
// - 隔离统计展示模型与导航目标决策
enum ProfileAccountStatRouteResolver {
    static func route(for stat: ProfileAccountStat) -> ProfileRoute? {
        switch stat.id {
        case "posts":
            .posts
        case "following":
            .following
        case "followers":
            .followers
        default:
            nil
        }
    }
}
