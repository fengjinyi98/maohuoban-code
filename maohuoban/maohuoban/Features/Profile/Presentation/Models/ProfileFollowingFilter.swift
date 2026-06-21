import Foundation

// ProfileFollowingFilter 我的关注筛选器
// 核心职责：
// - 按当前关注分类裁剪列表数据
// - 按搜索词匹配昵称、品种、简介、备注和徽章文本
enum ProfileFollowingFilter {
    static func filteredItems(
        _ items: [ProfileFollowingItem],
        scope: ProfileFollowingScope,
        query: String
    ) -> [ProfileFollowingItem] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        return items.filter { item in
            guard item.scope == scope else { return false }
            guard !trimmedQuery.isEmpty else { return true }
            return item.searchableText.localizedStandardContains(trimmedQuery)
        }
    }
}
