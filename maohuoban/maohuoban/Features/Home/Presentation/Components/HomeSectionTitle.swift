import SwiftUI
import MaohuobanDesignSystem

// HomeSectionTitle 首页模块标题
// 核心职责：
// - 统一首页 section 标题排版
// - 提供可选辅助入口文案
struct HomeSectionTitle: View {
    let title: LocalizedStringResource
    let trailingTitle: LocalizedStringResource?

    init(
        _ title: LocalizedStringResource,
        trailingTitle: LocalizedStringResource? = nil
    ) {
        self.title = title
        self.trailingTitle = trailingTitle
    }

    var body: some View {
        HStack {
            Text(title)
                .font(MHBTheme.Typography.headline)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            Spacer()

            if let trailingTitle {
                Text(trailingTitle)
                    .font(MHBTheme.Typography.footnote)
                    .foregroundStyle(MHBTheme.ColorToken.primary.color)
            }
        }
    }
}

