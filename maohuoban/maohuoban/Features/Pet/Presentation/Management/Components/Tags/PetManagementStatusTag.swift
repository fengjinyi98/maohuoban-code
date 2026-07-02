import Foundation

// PetManagementStatusTag 宠物管理列表状态标签
// 核心职责：
// - 表达列表行中的共管、隐私和绝育等状态
// - 为视图层提供稳定标识和视觉强调语义
struct PetManagementStatusTag: Hashable, Identifiable {
    enum Style: Hashable {
        case neutral
        case highlighted
    }

    let id: String
    let title: String
    let systemImage: String?
    let style: Style

    init(
        id: String,
        title: String,
        systemImage: String? = nil,
        style: Style = .neutral
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.style = style
    }
}
