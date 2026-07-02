import Foundation

// SearchHotKeyword 搜索热搜词条
// 核心职责：
// - 承载热搜榜单展示所需排名、标题和热度
// - 为角标展示提供稳定语义
struct SearchHotKeyword: Identifiable, Hashable {
    let rank: Int
    let title: String
    let scoreText: String
    let badge: SearchHotKeywordBadge?

    var id: String {
        "\(rank)-\(title)"
    }
}

// SearchHotKeywordBadge 搜索热搜角标
// 核心职责：
// - 描述热搜词条附带的短标签语义
// - 让同城和宠物世界复用一致角标模型
enum SearchHotKeywordBadge: Hashable {
    case hot
    case new
    case cobuy
}
