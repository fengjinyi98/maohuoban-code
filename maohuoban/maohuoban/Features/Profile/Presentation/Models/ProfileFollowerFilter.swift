import Foundation

// ProfileFollowerFilter 我的粉丝筛选器
// 核心职责：
// - 按当前粉丝关系范围裁剪列表数据
// - 按搜索词匹配昵称、来源上下文、认证标签和宠物昵称
enum ProfileFollowerFilter {
    static func filteredItems(
        _ items: [ProfileFollowerItem],
        scope: ProfileFollowerScope,
        query: String
    ) -> [ProfileFollowerItem] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        return items.filter { item in
            guard matchesScope(item, scope: scope) else { return false }
            guard !trimmedQuery.isEmpty else { return true }
            return item.searchableText.localizedStandardContains(trimmedQuery)
        }
    }

    private static func matchesScope(_ item: ProfileFollowerItem, scope: ProfileFollowerScope) -> Bool {
        switch scope {
        case .all:
            true
        case .unfollowed:
            !item.isMutual
        case .mutual:
            item.isMutual
        }
    }
}
