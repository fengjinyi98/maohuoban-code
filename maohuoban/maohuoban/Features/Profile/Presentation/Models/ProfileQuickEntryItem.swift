import Foundation

// ProfileQuickEntryItem 我的页快捷入口展示模型
// 核心职责：
// - 表达快捷入口网格中的单个功能入口
// - 提供稳定标识、标题及对应的 SF Symbol 图标名称
struct ProfileQuickEntryItem: Identifiable, Equatable {
    let id: String
    let title: String
    let systemImage: String

    static let mockItems = [
        ProfileQuickEntryItem(id: "myPets", title: "我的宠物", systemImage: "pawprint.fill"),
        ProfileQuickEntryItem(id: "petAlbum", title: "宠物相册", systemImage: "photo.fill"),
        ProfileQuickEntryItem(id: "myRescues", title: "我的救助", systemImage: "cross.case.fill"),
        ProfileQuickEntryItem(id: "myFavorites", title: "我的收藏", systemImage: "star.fill"),
        ProfileQuickEntryItem(id: "myPosts", title: "我的图文", systemImage: "doc.text.fill"),
        ProfileQuickEntryItem(id: "myTrades", title: "我的交易", systemImage: "bag.fill"),
        ProfileQuickEntryItem(id: "myReplies", title: "我的回复", systemImage: "bubble.left.fill"),
        ProfileQuickEntryItem(id: "more", title: "更多", systemImage: "ellipsis")
    ]
}
