import Foundation

// SearchHistoryState 搜索历史本地状态
// 核心职责：
// - 承载搜索页首屏历史搜索 Mock 数据
// - 提供历史搜索清空行为
struct SearchHistoryState: Equatable {
    private(set) var keywords: [String]

    init(keywords: [String] = SearchHotKeywordProvider.historyKeywords) {
        self.keywords = keywords
    }

    mutating func clear() {
        keywords.removeAll()
    }
}
