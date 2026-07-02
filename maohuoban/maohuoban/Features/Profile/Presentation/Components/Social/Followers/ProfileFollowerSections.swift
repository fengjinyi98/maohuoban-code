import SwiftUI
import MaohuobanDesignSystem

// ProfileFollowerScopePicker 我的粉丝分类切换器
// 核心职责：
// - 使用统一 Liquid Glass tabs 基础设施呈现三类粉丝关系
// - 将分类选择回写给页面状态
struct ProfileFollowerScopePicker: View {
    @Binding var selection: ProfileFollowerScope

    var body: some View {
        MHBGlassSegmentedTabsBar(
            items: ProfileFollowerScope.allCases.map { scope in
                MHBGlassSegmentedTabsBar<ProfileFollowerScope>.Item(
                    selection: scope,
                    title: scope.title
                )
            },
            selection: $selection,
            widthStrategy: .equalVisible,
            height: ProfileFollowersLayout.categoryTabsHeight,
            selectedSegmentTintColor: MHBTheme.ColorToken.primary.uiColor,
            normalTitleColor: MHBTheme.ColorToken.labelPrimary.uiColor,
            selectedTitleColor: .white,
            accessibilityIdentifier: "profile.followers.scopePicker"
        )
        .frame(height: ProfileFollowersLayout.categoryTabsHeight)
        .accessibilityIdentifier("profile.followers.scopePicker")
    }
}

// ProfileFollowerFixedTabsOverlay 我的粉丝固定分类 tabs 容器
// 核心职责：
// - 将粉丝分类 tabs 固定在滚动内容上方
// - 保持与页面水平间距一致的可视宽度
struct ProfileFollowerFixedTabsOverlay: View {
    @Binding var selection: ProfileFollowerScope

    var body: some View {
        GeometryReader { proxy in
            let visibleWidth = ProfileFollowersLayout.visibleTabsWidth(for: proxy.size.width)

            HStack {
                ProfileFollowerScopePicker(selection: $selection)
                    .frame(width: visibleWidth, height: ProfileFollowersLayout.categoryTabsHeight)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, ProfileFollowersLayout.fixedTabsTopPadding)
        }
        .frame(height: ProfileFollowersLayout.fixedTabsReservedHeight)
    }
}

// ProfileFollowerRow 我的粉丝列表行
// 核心职责：
// - 展示粉丝头像、昵称、来源上下文和关系操作
// - 为新粉丝和互关状态提供明确视觉反馈
struct ProfileFollowerRow: View {
    let item: ProfileFollowerItem

    var body: some View {
        HStack(alignment: .center, spacing: MHBTheme.Spacing.s3) {
            ProfileFollowerAvatar(
                subject: item.avatarSubject,
                isNew: item.isNew
            )

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                HStack(alignment: .center, spacing: MHBTheme.Spacing.s2) {
                    Text(item.name)
                        .font(MHBTheme.Typography.headline)
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    if let badgeText = item.badgeText {
                        ProfileFollowerBadge(text: badgeText)
                    }
                }

                ProfileFollowerContextText(
                    contextText: item.contextText,
                    highlightedPetName: item.highlightedPetName
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ProfileFollowerActionPill(isMutual: item.isMutual)
        }
        .padding(.horizontal, MHBTheme.Spacing.s3)
        .padding(.vertical, MHBTheme.Spacing.s3)
        .frame(minHeight: 82)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("profile.followers.row.\(item.id)")
    }
}

// ProfileFollowerAvatar 我的粉丝头像
// 核心职责：
// - 为粉丝列表提供统一圆形头像占位
// - 标记新粉丝提醒状态
struct ProfileFollowerAvatar: View {
    let subject: MHBAvatarSubject
    let isNew: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            MHBAvatar(
                subject: subject,
                size: .custom(54),
                shape: .circle
            )

            if isNew {
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)
                    .overlay {
                        Circle()
                            .stroke(MHBTheme.ColorToken.cardSolid.color, lineWidth: 2)
                    }
            }
        }
        .frame(width: 54, height: 54)
        .accessibilityHidden(true)
    }
}

// ProfileFollowerBadge 我的粉丝认证标签
// 核心职责：
// - 展示粉丝认证或身份标签
// - 使用低强调胶囊样式压缩横向占位
struct ProfileFollowerBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(MHBTheme.Typography.section)
            .foregroundStyle(MHBTheme.ColorToken.primary.color)
            .lineLimit(1)
            .padding(.horizontal, MHBTheme.Spacing.s2)
            .padding(.vertical, MHBTheme.Spacing.s1)
            .background(MHBTheme.ColorToken.primaryBackground.color)
            .clipShape(Capsule())
    }
}

// ProfileFollowerContextText 我的粉丝来源文本
// 核心职责：
// - 展示粉丝关注来源和关联宠物昵称
// - 对宠物昵称做轻量高亮帮助扫读
struct ProfileFollowerContextText: View {
    let contextText: String
    let highlightedPetName: String?

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s1) {
            Image(systemName: highlightedPetName == nil ? "person.badge.plus" : "pawprint.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)

            Text(prefixText)
                .font(MHBTheme.Typography.footnote)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            if let highlightedPetName {
                Text(highlightedPetName)
                    .font(MHBTheme.Typography.section.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.primary.color)
                    .lineLimit(1)
                    .padding(.horizontal, MHBTheme.Spacing.s1)
                    .padding(.vertical, 1)
                    .background(MHBTheme.ColorToken.primaryBackground.color)
                    .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.small, style: .continuous))
            }
        }
    }

    private var prefixText: String {
        guard let highlightedPetName,
              contextText.hasSuffix(highlightedPetName) else {
            return contextText
        }

        return String(contextText.dropLast(highlightedPetName.count)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// ProfileFollowerActionPill 我的粉丝关系操作
// 核心职责：
// - 展示回关或互关关系状态
// - 保持按钮宽度稳定避免列表行跳动
struct ProfileFollowerActionPill: View {
    let isMutual: Bool

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s1) {
            if isMutual {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 11, weight: .semibold))
            }

            Text(isMutual ? "互关" : "回关")
                .font(MHBTheme.Typography.caption.weight(.semibold))
        }
        .foregroundStyle(foregroundColor)
        .frame(width: 70, height: 32)
        .background(backgroundColor)
        .clipShape(Capsule())
        .accessibilityLabel(isMutual ? "互相关注" : "回关")
    }

    private var foregroundColor: Color {
        isMutual ? MHBTheme.ColorToken.labelPrimary.color : MHBTheme.ColorToken.cardSolid.color
    }

    private var backgroundColor: Color {
        isMutual ? MHBTheme.ColorToken.labelQuaternary.color.opacity(0.35) : MHBTheme.ColorToken.labelPrimary.color
    }
}

// ProfileFollowerEmptyState 我的粉丝空态
// 核心职责：
// - 在当前分类无数据或搜索无结果时给出轻量反馈
// - 保持列表区域高度稳定
struct ProfileFollowerEmptyState: View {
    let title: String

    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s3) {
            Image(systemName: "person.crop.circle.badge.xmark")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)

            Text(title)
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("profile.followers.emptyState")
    }
}
