import SwiftUI
import MaohuobanDesignSystem

// ProfileAccountSummarySection 我的页个人信息区块
// 核心职责：
// - 展示账号头像、昵称、等级进度和账号入口
// - 承载动态、关注和粉丝统计卡片
struct ProfileAccountSummarySection: View {
    let profile: ProfileAccountSummary
    let onOpenPosts: (() -> Void)?

    init(
        profile: ProfileAccountSummary,
        onOpenPosts: (() -> Void)? = nil
    ) {
        self.profile = profile
        self.onOpenPosts = onOpenPosts
    }

    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s3) {
            ProfileAccountIdentityRow(profile: profile)
                .padding(.horizontal, MHBTheme.Spacing.s2)

            ProfileAccountStatsCard(
                stats: profile.stats,
                onOpenPosts: onOpenPosts
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("profile.accountSummary")
    }
}

// ProfileAccountIdentityRow 我的页账号身份行
// 核心职责：
// - 展示头像、昵称和等级进度
// - 提供后续进入账号详情或二维码入口的视觉边界
private struct ProfileAccountIdentityRow: View {
    let profile: ProfileAccountSummary

    var body: some View {
        HStack(alignment: .center, spacing: MHBTheme.Spacing.s4) {
            ProfileAccountAvatar(assetName: profile.avatarAssetName)

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
                Text(profile.displayName)
                    .font(MHBTheme.Typography.title)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                ProfileAccountLevelProgress(
                    levelText: profile.levelText,
                    experienceText: profile.experienceText,
                    progress: profile.progress
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ProfileAccountEntryIcons()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// ProfileAccountAvatar 我的页账号头像
// 核心职责：
// - 展示本地 mock 用户头像
// - 以圆形头像建立个人身份识别
private struct ProfileAccountAvatar: View {
    let assetName: String

    var body: some View {
        Image(assetName)
            .resizable()
            .scaledToFill()
            .frame(width: MHBTheme.IconSize.tabRootPlaceholder, height: MHBTheme.IconSize.tabRootPlaceholder)
            .background(MHBTheme.ColorToken.cardSolid.color)
            .clipShape(Circle())
            .overlay {
                Circle()
                    .stroke(MHBTheme.ColorToken.cardBorder.color, lineWidth: 1)
            }
            .accessibilityHidden(true)
    }
}

// ProfileAccountLevelProgress 我的页等级进度
// 核心职责：
// - 展示当前等级、经验进度和目标经验
// - 复刻酷安风格的蓝色等级进度条
private struct ProfileAccountLevelProgress: View {
    let levelText: String
    let experienceText: String
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
            HStack(alignment: .firstTextBaseline, spacing: MHBTheme.Spacing.s2) {
                Text(levelText)
                    .font(MHBTheme.Typography.caption.bold())
                    .foregroundStyle(MHBTheme.ColorToken.primaryLight.color)
                    .italic()

                Text(experienceText)
                    .font(MHBTheme.Typography.section)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            ProfileAccountProgressBar(progress: progress)
                .frame(width: 120)
        }
    }
}

// ProfileAccountProgressBar 我的页等级进度条
// 核心职责：
// - 绘制圆角轨道和当前经验进度
// - 保持进度宽度在不同屏幕下稳定裁切
private struct ProfileAccountProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(MHBTheme.ColorToken.labelQuaternary.color.opacity(0.45))

                Capsule()
                    .fill(MHBTheme.ColorToken.primaryLight.color)
                    .frame(width: max(proxy.size.width * progress, 4))
            }
        }
        .frame(height: 4)
        .accessibilityHidden(true)
    }
}

// ProfileAccountEntryIcons 我的页账号入口图标组
// 核心职责：
// - 展示二维码/账号入口和进入详情提示
// - 保持原生按钮热区与图标可访问性
private struct ProfileAccountEntryIcons: View {
    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s1) {
            Button {} label: {
                Image(systemName: "qrcode")
                    .font(.system(size: MHBTheme.IconSize.medium, weight: .medium))
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .frame(width: 32, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("账号二维码")

            Button {} label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .frame(width: 16, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("查看个人资料")
        }
    }
}

// ProfileAccountStatsCard 我的页粉丝统计卡片
// 核心职责：
// - 展示动态、关注和粉丝三项账号数据
// - 使用白色圆角卡片和竖向分隔线对齐参考布局
private struct ProfileAccountStatsCard: View {
    let stats: [ProfileAccountStat]
    let onOpenPosts: (() -> Void)?

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                ProfileAccountStatColumn(
                    stat: stat,
                    onTap: stat.isPostsEntry ? onOpenPosts : nil
                )

                if index < stats.count - 1 {
                    Rectangle()
                        .fill(MHBTheme.ColorToken.separator.color)
                        .frame(width: 1, height: 24)
                }
            }
        }
        .padding(.vertical, MHBTheme.Spacing.s3)
        .frame(maxWidth: .infinity)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.extraExtraLarge, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("profile.statsCard")
    }
}

// ProfileAccountStatColumn 我的页统计列
// 核心职责：
// - 展示单个统计数值和标题
// - 保持三列等宽排布
private struct ProfileAccountStatColumn: View {
    let stat: ProfileAccountStat
    let onTap: (() -> Void)?

    var body: some View {
        Group {
            if let onTap {
                ProfileAccountStatContent(stat: stat)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onTap()
                    }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction {
                        onTap()
                    }
                    .accessibilityLabel("\(stat.title) \(stat.value)，查看我的动态")
            } else {
                ProfileAccountStatContent(stat: stat)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("\(stat.title) \(stat.value)")
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// ProfileAccountStatContent 我的页统计内容
// 核心职责：
// - 展示统计数值和标题
// - 让可点击与不可点击状态共享同一套视觉
private struct ProfileAccountStatContent: View {
    let stat: ProfileAccountStat

    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s1) {
            Text(stat.value)
                .font(MHBTheme.Typography.headline)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(stat.title)
                .font(MHBTheme.Typography.caption)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .lineLimit(1)
        }
    }
}
