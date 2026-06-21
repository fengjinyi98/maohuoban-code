import Foundation

// ProfileReplyFilter 我的回复筛选器
// 核心职责：
// - 按当前回复范围裁剪列表数据
// - 按搜索词匹配回复人、回复内容、引用上下文和身份标签
enum ProfileReplyFilter {
    static func filteredItems(
        _ items: [ProfileReplyItem],
        scope: ProfileReplyScope,
        query: String
    ) -> [ProfileReplyItem] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        return items.filter { item in
            guard item.scope == scope else { return false }
            guard !trimmedQuery.isEmpty else { return true }
            return item.searchableText.localizedStandardContains(trimmedQuery)
        }
    }
}
