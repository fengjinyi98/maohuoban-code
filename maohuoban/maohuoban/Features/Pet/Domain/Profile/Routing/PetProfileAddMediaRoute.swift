import Foundation

// PetProfileAddMediaRoute 添加宠物媒体入口路由
// 核心职责：
// - 判断添加页媒体入口应进入选择器还是预览页
// - 保证背景图片和视频入口统一由背景预览页承载
nonisolated enum PetProfileAddMediaRoute: Equatable {
    case picker
    case preview

    static func avatar(hasLocalAvatar: Bool) -> Self {
        hasLocalAvatar ? .preview : .picker
    }

    static func background(hasLocalHeroMedia _: Bool) -> Self {
        .preview
    }
}
