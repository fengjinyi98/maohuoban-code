import SwiftUI
import MaohuobanDesignSystem

// PetManagementTagStrip 我的宠物列表标签组
// 核心职责：
// - 展示单个宠物的状态标签集合
// - 在窄屏中保持标签截断稳定
struct PetManagementTagStrip: View {
    let tags: [PetManagementStatusTag]

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s2) {
            ForEach(tags.prefix(2)) { tag in
                PetManagementTagChip(tag: tag)
            }
        }
    }
}
