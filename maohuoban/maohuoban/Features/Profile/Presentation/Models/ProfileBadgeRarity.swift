import Foundation

// ProfileBadgeRarity 我的页勋章稀有度
// 核心职责：
// - 表达勋章在展示层的稀有程度
// - 为列表状态、详情弹窗和后续后端枚举接入提供稳定分类
enum ProfileBadgeRarity: String, Equatable, Hashable {
    case normal
    case rare
    case epic
    case legendary

    var title: String {
        switch self {
        case .normal: "普通"
        case .rare: "稀有"
        case .epic: "史诗"
        case .legendary: "传说"
        }
    }
}
