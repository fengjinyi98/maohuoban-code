import SwiftUI
import MaohuobanDesignSystem

// PetWorldFeedDetailHeaderControls 详情页沉浸式头部控件
// 核心职责：
// - 在系统导航栏位置展示返回和更多入口
// - 使用 Liquid Glass 与首页沉浸式头部保持一致
struct PetWorldFeedDetailHeaderControls: View {
    let showsDeleteAction: Bool
    let onBack: () -> Void
    let onShare: () -> Void
    let onReport: () -> Void
    let onDelete: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: MHBTheme.Spacing.s3) {
            HStack(spacing: MHBTheme.Spacing.s3) {
                PetWorldFeedDetailHeaderButton(
                    systemImage: "chevron.left",
                    accessibilityLabel: "返回",
                    action: onBack
                )

                Spacer(minLength: MHBTheme.Spacing.s3)

                PetWorldFeedDetailMoreMenuButton(
                    showsDeleteAction: showsDeleteAction,
                    onShare: onShare,
                    onReport: onReport,
                    onDelete: onDelete
                )
            }
            .frame(maxWidth: .infinity)
        }
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
// - 根据帖子所有权控制删除入口展示
private struct PetWorldFeedDetailMoreMenuButton: View {
    let showsDeleteAction: Bool
    let onShare: () -> Void
    let onReport: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Menu {
            Button {
                onShare()
            } label: {
                Label("分享", systemImage: "square.and.arrow.up")
            }

            Button(role: .destructive) {
                onReport()
            } label: {
                PetWorldFeedDetailDestructiveMenuLabel(
                    title: "举报",
                    systemImage: "exclamationmark.triangle"
                )
            }
            .tint(MHBTheme.ColorToken.danger.color)

            if showsDeleteAction {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    PetWorldFeedDetailDestructiveMenuLabel(
                        title: "删除",
                        systemImage: "trash"
                    )
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

// PetWorldFeedDetailDestructiveMenuLabel 详情页危险菜单标签
// 核心职责：
// - 为举报和删除菜单项提供统一危险色
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
