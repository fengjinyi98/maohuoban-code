import SwiftUI
import MaohuobanDesignSystem

// ProfileUserHomeNavigationChrome 用户主页自绘导航栏
// 核心职责：
// - 在系统导航栏位置展示返回、分享和 AI 入口
// - 保持沉浸式头图页面的顶部 chrome 定位逻辑
struct ProfileUserHomeNavigationChrome: View {
    let title: String
    let avatarSubject: MHBAvatarSubject
    let progress: CGFloat
    let aiRoute: ProfileRoute
    let onBack: () -> Void
    let onShare: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: MHBTheme.Spacing.s3) {
            ZStack {
                HStack(spacing: MHBTheme.Spacing.s3) {
                    ProfileUserHomeChromeButton(
                        systemImage: "chevron.left",
                        accessibilityLabel: "返回",
                        progress: progress,
                        action: onBack
                    )

                    Spacer(minLength: MHBTheme.Spacing.s3)

                    ProfileUserHomeChromeButton(
                        systemImage: "square.and.arrow.up",
                        accessibilityLabel: "分享",
                        progress: progress,
                        action: onShare
                    )

                    NavigationLink(value: aiRoute) {
                        ProfileUserHomeChromeIcon(
                            systemImage: "sparkles",
                            progress: progress
                        )
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .accessibilityLabel("打开毛球")
                }

                ProfileUserHomeNavigationIdentity(
                    title: title,
                    avatarSubject: avatarSubject,
                    progress: progress
                )
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// ProfileUserHomeChromeButton 用户主页顶部图标按钮
// 核心职责：
// - 承载返回和分享等单个顶部动作
// - 维持 44pt 点击热区与 Liquid Glass 反馈
private struct ProfileUserHomeChromeButton: View {
    let systemImage: String
    let accessibilityLabel: String
    let progress: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ProfileUserHomeChromeIcon(
                systemImage: systemImage,
                progress: progress
            )
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel(accessibilityLabel)
    }
}

// ProfileUserHomeChromeIcon 用户主页顶部图标外观
// 核心职责：
// - 根据滚动进度切换图标前景和背景
// - 让白色头图态与浅色导航态都保持可读
private struct ProfileUserHomeChromeIcon: View {
    let systemImage: String
    let progress: CGFloat

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: MHBTheme.IconSize.small, weight: .bold))
            .foregroundStyle(iconColor)
            .frame(width: 44, height: 44)
            .background {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity((1 - progress) * 0.26))

                    Circle()
                        .fill(Color.white.opacity(progress * 0.20))
                }
            }
            .contentShape(Circle())
    }

    private var iconColor: Color {
        progress < 0.5
            ? .white
            : MHBTheme.ColorToken.labelPrimary.color
    }
}

// ProfileUserHomeNavigationIdentity 用户主页导航身份信息
// 核心职责：
// - 在上滑后展示当前用户身份
// - 让自绘导航栏从沉浸态过渡到详情态
private struct ProfileUserHomeNavigationIdentity: View {
    let title: String
    let avatarSubject: MHBAvatarSubject
    let progress: CGFloat

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s2) {
            MHBAvatar(
                subject: avatarSubject,
                size: .custom(28),
                shape: .circle
            )

            Text(title)
                .font(MHBTheme.Typography.footnote.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .lineLimit(1)
        }
        .frame(width: 176, height: 40, alignment: .center)
        .opacity(progress)
        .offset(y: (1 - progress) * 6)
        .scaleEffect(0.98 + progress * 0.02, anchor: .center)
        .allowsHitTesting(false)
        .accessibilityHidden(progress < 0.5)
    }
}
