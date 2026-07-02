import SwiftUI
import MaohuobanDesignSystem

// PetRecordDetailPlaceholderScreen 宠物记录详情占位页
// 核心职责：
// - 当某个记录类型的详情页尚未实现时，展示简洁信息占位
// - 保持占位页统一复用 MHBTabPlaceholderRootScreen
struct PetRecordDetailPlaceholderScreen: View {
    let systemImage: String
    let title: LocalizedStringResource
    let subtitle: LocalizedStringResource
    let accessibilityIdentifier: String

    var body: some View {
        MHBTabPlaceholderRootScreen(
            systemImage: systemImage,
            title: title,
            subtitle: subtitle,
            accessibilityIdentifier: accessibilityIdentifier
        )
    }
}
