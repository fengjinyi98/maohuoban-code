import Foundation

// ProfileAccountStat 我的页账号统计展示模型
// 核心职责：
// - 表达账号概览卡片中的单个统计项
// - 为动态、关注和粉丝等指标提供稳定身份
struct ProfileAccountStat: Identifiable, Equatable {
    let id: String
    let value: String
    let title: String

    var isPostsEntry: Bool {
        id == "posts"
    }
}
