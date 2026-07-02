import SwiftUI
import MaohuobanDesignSystem

// PetWorldFeedDetailHeaderControls 详情页沉浸式头部控件
// 核心职责：
// - 在系统导航栏位置展示返回和更多入口
// - 使用 Liquid Glass 与首页沉浸式头部保持一致
struct PetWorldFeedDetailHeaderControls: View {
    let petName: String
    let avatarSubject: MHBAvatarSubject
    let authorName: String
    let isAuthorVisible: Bool
    let isAuthorSubtitleVisible: Bool
    let isOwnedByCurrentUser: Bool
    let onBack: () -> Void
    let onShare: () -> Void
    let onReport: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: MHBTheme.Spacing.s3) {
            ZStack {
                HStack(spacing: MHBTheme.Spacing.s3) {
                    PetWorldFeedDetailHeaderButton(
                        systemImage: "chevron.left",
                        accessibilityLabel: "返回",
                        action: onBack
                    )

                    Spacer(minLength: MHBTheme.Spacing.s3)

                    PetWorldFeedDetailMoreMenuButton(
                        isOwnedByCurrentUser: isOwnedByCurrentUser,
                        onShare: onShare,
                        onReport: onReport
                    )
                }

                PetWorldFeedDetailNavigationIdentity(
                    petName: petName,
                    avatarSubject: avatarSubject,
                    authorName: authorName,
                    isVisible: isAuthorVisible,
                    isSubtitleVisible: isAuthorSubtitleVisible
                )
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// PetWorldFeedDetailNavigationIdentity 详情页导航身份信息
// 核心职责：
// - 在内容滚动后展示当前帖子宠物和作者
// - 用轻量动画让沉浸式头部过渡为详情身份栏
private struct PetWorldFeedDetailNavigationIdentity: View {
    let petName: String
    let avatarSubject: MHBAvatarSubject
    let authorName: String
    let isVisible: Bool
    let isSubtitleVisible: Bool

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s2) {
            MHBAvatar(
                subject: avatarSubject,
                size: .custom(28),
                shape: .circle
            )

            VStack(alignment: .leading, spacing: 1) {
                Text(petName)
                    .font(MHBTheme.Typography.footnote.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .lineLimit(1)

                if isSubtitleVisible {
                    Text("by \(authorName)")
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

// PetWorldFeedDetailHeaderButton 详情页头部圆形按钮
// 核心职责：
// - 承载沉浸式头部单个图标操作
// - 保持 44pt 点击热区与 Liquid Glass 反馈
private struct PetWorldFeedDetailHeaderButton: View {
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

// PetWorldFeedDetailMoreMenuButton 详情页更多原生菜单
// 核心职责：
// - 使用系统 Menu 承载详情页二级操作
// - 根据帖子所有权控制举报入口展示
private struct PetWorldFeedDetailMoreMenuButton: View {
    let isOwnedByCurrentUser: Bool
    let onShare: () -> Void
    let onReport: () -> Void

    private var actions: [PetWorldFeedDetailMoreMenuAction] {
        PetWorldFeedDetailMoreMenuActionResolver.actions(
            isOwnedByCurrentUser: isOwnedByCurrentUser
        )
    }

    var body: some View {
        Menu {
            ForEach(actions) { action in
                switch action {
                case .share:
                    Button {
                        onShare()
                    } label: {
                        Label("分享", systemImage: "square.and.arrow.up")
                    }
                case .report:
                    Button(role: .destructive) {
                        onReport()
                    } label: {
                        PetWorldFeedDetailDestructiveMenuLabel(
                            title: "举报",
                            systemImage: "exclamationmark.triangle"
                        )
                    }
                    .tint(MHBTheme.ColorToken.danger.color)
                }
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

// PetWorldFeedDetailDestructiveMenuLabel 详情页危险菜单标签
// 核心职责：
// - 为危险菜单项提供统一危险色
// - 同时染色文本和图标以匹配破坏性操作语义
private struct PetWorldFeedDetailDestructiveMenuLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label {
            Text(title)
                .foregroundStyle(MHBTheme.ColorToken.danger.color)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(MHBTheme.ColorToken.danger.color)
        }
    }
}
