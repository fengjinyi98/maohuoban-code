import Foundation

// PetProfileAddMediaRoute 添加宠物媒体入口路由
// 核心职责：
// - 判断添加页媒体入口应进入选择器还是预览页
// - 保证兜底头像和兜底背景不被视为已有媒体
nonisolated enum PetProfileAddMediaRoute: Equatable {
    case picker
    case preview

    static func avatar(hasLocalAvatar: Bool) -> Self {
        hasLocalAvatar ? .preview : .picker
    }

    static func background(hasLocalHeroMedia: Bool) -> Self {
        hasLocalHeroMedia ? .preview : .picker
    }
}
