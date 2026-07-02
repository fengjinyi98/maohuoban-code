import SwiftUI
import MaohuobanDesignSystem

// HomeQuickActionsFloatingRow 首页快捷动作浮动行
// 核心职责：
// - 展示动作图标、标题和辅助说明
// - 统一浮层内动作项的命中区域与信息层级
struct HomeQuickActionsFloatingRow: View {
    let action: HomeDashboardSnapshot.Action

    var body: some View {
        HStack(alignment: .top, spacing: MHBTheme.Spacing.s3) {
            Image(systemName: HomeQuickActionPresentation.iconName(for: action.kind))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(.white.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(action.title)
                    .font(MHBTheme.Typography.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(HomeQuickActionPresentation.subtitle(for: action))
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: MHBTheme.Spacing.s2)
        }
        .padding(.horizontal, MHBTheme.Spacing.s2)
        .padding(.vertical, MHBTheme.Spacing.s2)
        .frame(minHeight: HomeQuickActionsFloatingMetrics.rowHeight, alignment: .leading)
        .contentShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
    }
}
