import SwiftUI
import MaohuobanDesignSystem

// FeedMoreMenuOverlay Feed 更多菜单覆盖层
// 核心职责：
// - 使用统一锚点浮动面板展示卡片更多菜单
// - 根据按钮位置计算菜单展开方向和屏幕内偏移
struct FeedMoreMenuOverlay: View {
    let isPresented: Bool
    let containerSize: CGSize
    let buttonFrame: CGRect
    let onAction: (FeedMoreAction) -> Void

    private var isReadyToPresent: Bool {
        isPresented && buttonFrame != .zero && containerSize.width > 0
    }

    private var shouldOpenUpward: Bool {
        buttonFrame.maxY
            + FeedMoreMenuMetrics.verticalGap
            + FeedMoreMenuMetrics.estimatedHeight
            > containerSize.height - FeedMoreMenuMetrics.verticalMargin
    }

    private var offset: CGSize {
        let maxX = max(
            FeedMoreMenuMetrics.horizontalMargin,
            containerSize.width
                - FeedMoreMenuMetrics.width
                - FeedMoreMenuMetrics.horizontalMargin
        )
        let x = min(
            max(
                buttonFrame.maxX - FeedMoreMenuMetrics.width,
                FeedMoreMenuMetrics.horizontalMargin
            ),
            maxX
        )

        let downwardY = min(
            buttonFrame.maxY + FeedMoreMenuMetrics.verticalGap,
            max(
                FeedMoreMenuMetrics.verticalMargin,
                containerSize.height
                    - FeedMoreMenuMetrics.estimatedHeight
                    - FeedMoreMenuMetrics.verticalMargin
            )
        )
        let upwardY = max(
            FeedMoreMenuMetrics.verticalMargin,
            buttonFrame.minY
                - FeedMoreMenuMetrics.estimatedHeight
                - FeedMoreMenuMetrics.verticalGap
        )

        return CGSize(width: x, height: shouldOpenUpward ? upwardY : downwardY)
    }

    private var scaleAnchor: UnitPoint {
        shouldOpenUpward ? .bottomTrailing : .topTrailing
    }

    var body: some View {
        MHBAnchoredFloatingPanel(
            isPresented: isReadyToPresent,
            offset: offset,
            scaleAnchor: scaleAnchor
        ) {
            FeedMoreMenu(onAction: onAction)
        }
        .animation(.snappy(duration: 0.22), value: isPresented)
    }
}

// FeedMoreMenu Feed 卡片更多菜单
// 核心职责：
// - 展示卡片级二级操作入口
// - 使用 Liquid Glass 维持与项目浮层基础设施一致的视觉
struct FeedMoreMenu: View {
    let onAction: (FeedMoreAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
            FeedMoreMenuRow(action: .dislike, onAction: onAction)
            FeedMoreMenuRow(action: .report, onAction: onAction)
        }
        .padding(MHBTheme.Spacing.s2)
        .frame(width: FeedMoreMenuMetrics.width)
        .glassEffect(.regular, in: .rect(cornerRadius: MHBTheme.Radius.large))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("feed.moreMenu")
    }
}

// FeedMoreMenuRow Feed 更多菜单行
// 核心职责：
// - 展示单个更多操作的图标和标题
// - 根据操作语义呈现普通或危险色
private struct FeedMoreMenuRow: View {
    let action: FeedMoreAction
    let onAction: (FeedMoreAction) -> Void

    var body: some View {
        Button(role: action.buttonRole) {
            onAction(action)
        } label: {
            HStack(spacing: MHBTheme.Spacing.s2) {
                Image(systemName: action.systemImageName)
                    .font(.system(size: MHBTheme.IconSize.small, weight: .semibold))
                    .frame(width: MHBTheme.Spacing.s5)

                Text(action.title)
                    .font(MHBTheme.Typography.footnote)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .foregroundStyle(action.foregroundColor)
            .padding(.horizontal, MHBTheme.Spacing.s2)
            .padding(.vertical, MHBTheme.Spacing.s2)
            .contentShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(action.accessibilityIdentifier)
    }
}

// FeedMoreMenuMetrics Feed 更多菜单尺寸配置
// 核心职责：
// - 收敛菜单宽度、边距和定位估算值
// - 让菜单布局与列表定位逻辑共享同一套参数
private enum FeedMoreMenuMetrics {
    static let width: CGFloat = 128
    static let estimatedHeight: CGFloat = 88
    static let horizontalMargin: CGFloat = MHBTheme.Spacing.s4
    static let verticalMargin: CGFloat = MHBTheme.Spacing.s4
    static let verticalGap: CGFloat = MHBTheme.Spacing.s1
}

private extension FeedMoreAction {
    var title: String {
        switch self {
        case .dislike:
            "不喜欢"
        case .report:
            "举报"
        case .delete:
            "删除"
        }
    }

    var systemImageName: String {
        switch self {
        case .dislike:
            "hand.thumbsdown"
        case .report:
            "exclamationmark.triangle"
        case .delete:
            "trash"
        }
    }

    var foregroundColor: Color {
        switch self {
        case .dislike:
            MHBTheme.ColorToken.labelPrimary.color
        case .report:
            MHBTheme.ColorToken.danger.color
        case .delete:
            MHBTheme.ColorToken.danger.color
        }
    }

    var buttonRole: ButtonRole? {
        switch self {
        case .dislike:
            nil
        case .report:
            .destructive
        case .delete:
            .destructive
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .dislike:
            "feed.moreMenu.dislike"
        case .report:
            "feed.moreMenu.report"
        case .delete:
            "feed.moreMenu.delete"
        }
    }
}
