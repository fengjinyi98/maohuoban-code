import Foundation

// SearchHotKeywordProvider 搜索热搜 Mock 数据提供器
// 核心职责：
// - 根据搜索入口上下文返回对应热搜榜单
// - 提供搜索落地页首屏历史搜索 Mock 数据
enum SearchHotKeywordProvider {
    static let historyKeywords = [
        "金渐层 拼单",
        "无偿领养",
        "猫藓怎么治",
        "瑞派宠物医院",
        "伯恩山"
    ]

    static func hotKeywords(for context: SearchEntryContext) -> [SearchHotKeyword] {
        switch context {
        case .petWorld:
            petWorldKeywords
        case .sameCity:
            sameCityKeywords
        }
    }

    private static let petWorldKeywords = [
        SearchHotKeyword(rank: 1, title: "猫藓怎么治", scoreText: "52.8w", badge: .hot),
        SearchHotKeyword(rank: 2, title: "新手养狗 必备好物", scoreText: "41.6w", badge: .new),
        SearchHotKeyword(rank: 3, title: "猫咪应激反应", scoreText: "36.4w", badge: nil),
        SearchHotKeyword(rank: 4, title: "狗狗社会化训练", scoreText: "29.7w", badge: nil),
        SearchHotKeyword(rank: 5, title: "幼猫到家第一周", scoreText: "22.5w", badge: .hot),
        SearchHotKeyword(rank: 6, title: "宠物绝育恢复记录", scoreText: "18.9w", badge: nil)
    ]

    private static let sameCityKeywords = [
        SearchHotKeyword(rank: 1, title: "金渐层 跨品种拼单", scoreText: "45.2w", badge: .hot),
        SearchHotKeyword(rank: 2, title: "流浪猫救助 领养", scoreText: "38.5w", badge: nil),
        SearchHotKeyword(rank: 3, title: "新手养狗 必备好物", scoreText: "32.1w", badge: .new),
        SearchHotKeyword(rank: 4, title: "柯基 弟弟", scoreText: "28.4w", badge: nil),
        SearchHotKeyword(rank: 5, title: "星梦名猫苑", scoreText: "19.2w", badge: .cobuy),
        SearchHotKeyword(rank: 6, title: "猫咪应激反应", scoreText: "15.8w", badge: nil)
    ]
}
