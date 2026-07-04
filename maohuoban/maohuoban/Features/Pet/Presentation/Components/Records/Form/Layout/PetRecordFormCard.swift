import SwiftUI
import MaohuobanDesignSystem

// PetRecordFormCard 记录流程通用表单卡片
// 核心职责：
// - 统一记录类表单分组标题和卡片样式
// - 支撑日常、病历等记录流程复用同一视觉基础组件
struct PetRecordFormCard<Content: View>: View {
    let title: LocalizedStringResource?
    @ViewBuilder let content: () -> Content

    init(
        title: LocalizedStringResource? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
            if let title {
                Text(title)
                    .font(MHBTheme.Typography.callout.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            }

            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(MHBTheme.Spacing.s4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MHBTheme.ColorToken.cardSolid.color)
            .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
        }
    }
}
