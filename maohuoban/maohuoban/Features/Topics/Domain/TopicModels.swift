import Foundation

// TopicIdentifier 话题身份解析器
// 核心职责：
// - 将用户输入的话题名称归一为稳定展示名称
// - 为本地快速 UI 阶段生成可复用的确定性话题 ID
enum TopicIdentifier {
    static func normalizedName(_ rawName: String) -> String {
        var name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        while name.first == "#" {
            name.removeFirst()
            name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return name
    }

    static func id(for rawName: String) -> String {
        let normalizedName = normalizedName(rawName).lowercased()
        guard !normalizedName.isEmpty else {
            return "topic-empty"
        }

        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in normalizedName.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }

        return "topic-\(String(hash, radix: 16))"
    }
}

// TopicSummary 话题摘要模型
// 核心职责：
// - 表达话题列表、详情头部和发布选择所需的稳定字段
// - 为后续服务端话题实体、RAG 标签和关注关系预留 ID 边界
struct TopicSummary: Identifiable, Hashable, Equatable {
    let id: String
    let name: String
    let description: String
    let thumbnailAssetName: String
    let followerCount: Int
    let postCount: Int
    let todayPostCount: Int
    let isUserCreated: Bool

    var displayName: String {
        "#\(name)"
    }

    var updateText: String {
        todayPostCount > 0 ? "今日更新 \(todayPostCount) 篇" : "暂无新动态"
    }
}

// TopicPostPreview 话题详情帖子预览模型
// 核心职责：
// - 为话题详情页提供轻量 UGC 卡片展示数据
// - 隔离话题 Feed 原型与后续真实帖子详情数据源
struct TopicPostPreview: Identifiable, Hashable, Equatable {
    let id: String
    let authorName: String
    let avatarAssetName: String
    let publishedText: String
    let mediaAssetName: String
    let caption: String
    let likeCountText: String
    let commentCountText: String
}
