import Foundation

// PetWorldFeedComment 宠物世界详情评论节点
// 核心职责：
// - 表达评论树中的父评论和子评论
// - 为评论树递归布局提供稳定身份和层级数据
struct PetWorldFeedComment: Identifiable, Equatable {
    let id: String
    let authorName: String
    let avatarAssetName: String
    let text: String
    let publishedAt: Date
    let isPostAuthor: Bool
    let isOwnedByCurrentUser: Bool
    let isLiked: Bool
    let likeCount: Int
    let replies: [PetWorldFeedComment]
}
