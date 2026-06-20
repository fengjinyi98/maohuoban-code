import SwiftUI
import MaohuobanDesignSystem

// PublishPreparedBanner 发布草稿完成提示
// 核心职责：
// - 展示前端发布动作已经完成本地草稿提交
// - 让快速 UI 阶段具备明确成功反馈
struct PublishPreparedBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s2) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: MHBTheme.IconSize.small, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.success.color)

            Text(message)
                .font(MHBTheme.Typography.callout.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
        }
        .padding(MHBTheme.Spacing.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
        .accessibilityIdentifier("publish.preparedBanner")
    }
}
