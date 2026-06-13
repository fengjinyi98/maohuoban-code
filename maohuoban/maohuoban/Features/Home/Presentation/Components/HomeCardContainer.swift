import SwiftUI
import MaohuobanDesignSystem

// HomeCardContainer 首页卡片容器
// 核心职责：
// - 统一首页模块卡片背景、圆角和边框
// - 让业务 section 聚焦内容渲染
struct HomeCardContainer<Content: View>: View {
    let accessibilityIdentifier: String?
    @ViewBuilder let content: () -> Content

    init(
        accessibilityIdentifier: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.accessibilityIdentifier = accessibilityIdentifier
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
            content()
        }
        .padding(MHBTheme.Spacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MHBTheme.ColorToken.card.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                .stroke(MHBTheme.ColorToken.cardBorder.color, lineWidth: 1)
        }
        .homeCardAccessibilityIdentifier(accessibilityIdentifier)
    }
}

private extension View {
    @ViewBuilder
    func homeCardAccessibilityIdentifier(_ identifier: String?) -> some View {
        if let identifier {
            self
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier(identifier)
        } else {
            self
        }
    }
}
