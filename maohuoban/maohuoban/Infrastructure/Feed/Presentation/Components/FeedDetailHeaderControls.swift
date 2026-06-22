import SwiftUI
import MaohuobanDesignSystem

// FeedDetailHeaderControls Feed 详情沉浸式头部控件
// 核心职责：
// - 在系统导航栏位置展示返回和更多入口
// - 使用 Liquid Glass 与画廊详情沉浸式头部保持一致
struct FeedDetailHeaderControls: View {
    let title: String
    let avatarAssetName: String
    let subtitle: String
    let isIdentityVisible: Bool
    let isSubtitleVisible: Bool
    let isOwnedByCurrentUser: Bool
    let onBack: () -> Void
    let onShare: () -> Void
    let onReport: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: MHBTheme.Spacing.s3) {
            ZStack {
                HStack(spacing: MHBTheme.Spacing.s3) {
                    FeedDetailHeaderButton(
                        systemImage: "chevron.left",
                        accessibilityLabel: "返回",
                        action: onBack
                    )

                    Spacer(minLength: MHBTheme.Spacing.s3)

                    FeedDetailMoreMenuButton(
                        isOwnedByCurrentUser: isOwnedByCurrentUser,
                        onShare: onShare,
                        onReport: onReport
                    )
                }

                FeedDetailNavigationIdentity(
                    title: title,
                    avatarAssetName: avatarAssetName,
                    subtitle: subtitle,
                    isVisible: isIdentityVisible,
                    isSubtitleVisible: isSubtitleVisible
                )
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// FeedDetailNavigationIdentity Feed 详情导航身份信息
// 核心职责：
// - 在内容滚动后展示当前详情对象和发布者
// - 用轻量动画让沉浸式头部过渡为详情身份栏
private struct FeedDetailNavigationIdentity: View {
    let title: String
    let avatarAssetName: String
    let subtitle: String
    let isVisible: Bool
    let isSubtitleVisible: Bool

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s2) {
            Image(avatarAssetName)
                .resizable()
                .scaledToFill()
                .frame(width: 28, height: 28)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(MHBTheme.ColorToken.cardBorder.color, lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(MHBTheme.Typography.footnote.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .lineLimit(1)

                if isSubtitleVisible {
                    Text(subtitle)
                        .font(MHBTheme.Typography.caption)
                        .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                        .lineLimit(1)
                        .transition(.offset(y: 4).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.18), value: isSubtitleVisible)
        }
        .frame(width: 176, height: 40, alignment: .center)
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 6)
        .scaleEffect(isVisible ? 1 : 0.98, anchor: .center)
        .animation(.easeInOut(duration: 0.22), value: isVisible)
        .allowsHitTesting(false)
        .accessibilityHidden(!isVisible)
    }
}

// FeedDetailHeaderButton Feed 详情头部圆形按钮
// 核心职责：
// - 承载沉浸式头部单个图标操作
// - 保持 44pt 点击热区与 Liquid Glass 反馈
private struct FeedDetailHeaderButton: View {
    let systemImage: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: MHBTheme.IconSize.small, weight: .bold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .frame(width: 44, height: 44)
                .background {
                    Color.white.opacity(0.18)
                        .clipShape(Circle())
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel(accessibilityLabel)
    }
}

// FeedDetailMoreMenuButton Feed 详情更多原生菜单
// 核心职责：
// - 使用系统 Menu 承载详情页二级操作
// - 根据内容所有权控制举报入口展示
private struct FeedDetailMoreMenuButton: View {
    let isOwnedByCurrentUser: Bool
    let onShare: () -> Void
    let onReport: () -> Void

    var body: some View {
        Menu {
            Button {
                onShare()
            } label: {
                Label("分享", systemImage: "square.and.arrow.up")
            }

            if !isOwnedByCurrentUser {
                Button(role: .destructive) {
                    onReport()
                } label: {
                    Label("举报", systemImage: "exclamationmark.triangle")
                }
                .tint(MHBTheme.ColorToken.danger.color)
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: MHBTheme.IconSize.small, weight: .bold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .frame(width: 44, height: 44)
                .background {
                    Color.white.opacity(0.18)
                        .clipShape(Circle())
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("更多")
    }
}
