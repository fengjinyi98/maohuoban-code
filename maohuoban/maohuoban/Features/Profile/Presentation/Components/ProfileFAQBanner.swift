import SwiftUI
import MaohuobanDesignSystem

// ProfileFAQBanner 我的页常见问题疑问横幅
// 核心职责：
// - 展示引导用户阅读“毛伙伴常见问题”的通告横幅
// - 采用品牌主色半透明背景，维持视觉契合度与响应式对齐
struct ProfileFAQBanner: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: MHBTheme.Spacing.s2) {
                Image(systemName: "megaphone.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.primary.color)

                Text("有疑问请参考「毛伙伴常见问题」>>>")
                    .font(MHBTheme.Typography.footnote)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                Spacer()
            }
            .padding(.horizontal, MHBTheme.Spacing.s3)
            .frame(height: 40)
            .background(MHBTheme.ColorToken.primaryBackground.color)
            .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.small, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("常见问题：有疑问请参考毛伙伴常见问题")
    }
}
