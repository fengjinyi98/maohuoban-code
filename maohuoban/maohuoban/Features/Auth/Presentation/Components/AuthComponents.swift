import SwiftUI
import MaohuobanDesignSystem

// AuthBrandHeader 登录品牌头部
// 核心职责：
// - 展示登录页标题与副标题
// - 保持认证首页首屏层级简洁
struct AuthBrandHeader: View {
    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s2) {
            Text("欢迎来到毛伙伴")
                .font(MHBTheme.Typography.title)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            Text("让每只毛孩子被更好的记录与陪伴")
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, MHBTheme.Spacing.s4)
    }
}

// AuthPageHeading 认证页面标题
// 核心职责：
// - 统一验证码页和账号恢复页标题样式
// - 保持正文说明文本的层级一致
struct AuthPageHeading: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
            Text(title)
                .font(MHBTheme.Typography.title)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            Text(subtitle)
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
    }
}
