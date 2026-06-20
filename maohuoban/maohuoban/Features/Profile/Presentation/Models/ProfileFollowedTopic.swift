import Foundation

// ProfileFollowedTopic 我关注的话题数据模型
// 核心职责：
// - 表达用户在个人中心关注的话题（如金毛寻回犬、猫咪日常等宠物话题）
// - 承载话题的展示名称、本地 Mock 图片名称和动态数统计
struct ProfileFollowedTopic: Identifiable, Equatable {
    let id: String
    let title: String
    let imageName: String
    let statsText: String

    static let mockTopics = [
        ProfileFollowedTopic(id: "golden", title: "金毛寻回犬", imageName: "HomePetAlbum1", statsText: "2.3万条动态"),
        ProfileFollowedTopic(id: "catDaily", title: "猫咪日常", imageName: "HomePetAlbum2", statsText: "5.8万条动态"),
        ProfileFollowedTopic(id: "petTips", title: "新手养宠避坑", imageName: "HomePetAlbum3", statsText: "894条动态"),
        ProfileFollowedTopic(id: "petPhoto", title: "宠物摄影", imageName: "HomePetAlbum4", statsText: "1487条动态"),
        ProfileFollowedTopic(id: "shiba", title: "柴犬俱乐部", imageName: "HomeGalleryAlbum1", statsText: "4392条动态")
    ]
}
