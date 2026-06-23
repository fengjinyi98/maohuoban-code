import SwiftUI
import MaohuobanDesignSystem

// ProfileUserHomeCoverSection 用户主页封面头图
// 核心职责：
// - 展示沉浸式背景图
// - 复用首页头图的下拉放大和滚动模糊体验
struct ProfileUserHomeCoverSection: View {
    let assetName: String
    let scrollOffset: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let blurConfiguration = ProfileUserHomeCoverBlurConfiguration.make(scrollOffset: scrollOffset)

            ZStack(alignment: .top) {
                Image(assetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: ProfileUserHomeLayout.coverHeight)
                    .clipped()

                MHBVariableBlurView(
                    maxBlurRadius: blurConfiguration.bottomBlurRadius,
                    direction: .blurredBottomClearTop,
                    startOffset: 0
                )
                .frame(width: width, height: ProfileUserHomeLayout.coverHeight * 0.24)
                .frame(width: width, height: ProfileUserHomeLayout.coverHeight, alignment: .bottom)
                .allowsHitTesting(false)

                MHBVariableBlurView(
                    maxBlurRadius: blurConfiguration.fullBlurRadius,
                    direction: .blurredAll,
                    startOffset: 0
                )
                .frame(width: width, height: ProfileUserHomeLayout.coverHeight)
                .opacity(blurConfiguration.fullBlurOpacity)
                .allowsHitTesting(false)

                LinearGradient(
                    stops: [
                        .init(color: MHBTheme.ColorToken.background.color.opacity(0), location: 0.62),
                        .init(color: MHBTheme.ColorToken.background.color.opacity(0.45), location: 0.84),
                        .init(color: MHBTheme.ColorToken.background.color, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(width: width, height: ProfileUserHomeLayout.coverHeight, alignment: .top)
            .visualEffect { content, proxy in
                let metrics = ProfileUserHomeCoverStretchMetrics.make(
                    frameMinY: proxy.frame(in: .scrollView).minY,
                    baseHeroHeight: ProfileUserHomeLayout.coverHeight
                )

                return content
                    .scaleEffect(metrics.scale, anchor: .bottom)
                    .offset(y: metrics.verticalOffset)
            }
        }
        .frame(height: ProfileUserHomeLayout.coverHeight)
        .accessibilityHidden(true)
    }
}

// ProfileUserHomeIdentitySection 用户主页资料区
// 核心职责：
// - 展示头像、昵称、ID 和个人简介
// - 保持头像与封面形成设计稿中的上浮关系
struct ProfileUserHomeIdentitySection: View {
    let displayName: String
    let petID: String
    let bio: String
    let avatarSubject: MHBAvatarSubject
    let professionalBadge: ProfileProfessionalIdentityBadge?
    let editRoute: ProfileRoute

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            HStack(alignment: .bottom) {
                ProfileUserHomeAvatar(
                    subject: avatarSubject,
                    professionalBadge: professionalBadge
                )

                Spacer(minLength: MHBTheme.Spacing.s3)

                NavigationLink(value: editRoute) {
                    ProfileUserHomeEditButtonLabel(title: "编辑资料")
                }
                .buttonStyle(.plain)
                .padding(.bottom, MHBTheme.Spacing.s3)
            }

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                Text(displayName)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text("Pet ID: \(petID)")
                    .font(MHBTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .lineLimit(1)

                Text(bio)
                    .font(MHBTheme.Typography.callout.weight(.medium))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, MHBTheme.Spacing.s1)
            }
        }
        .padding(.horizontal, MHBTheme.Spacing.s5)
        .padding(.top, -43)
        .padding(.bottom, MHBTheme.Spacing.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// ProfileUserHomeEditButtonLabel 用户主页编辑资料按钮标签
// 核心职责：
// - 对齐首页头图编辑档案按钮的胶囊样式
// - 在个人主页资料区提供进入编辑资料页的轻量操作入口
private struct ProfileUserHomeEditButtonLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                Color.black.opacity(0.18)
                    .clipShape(Capsule())
            }
            .glassEffect(.regular.interactive(), in: .capsule)
    }
}

// ProfileUserHomeStatsSection 用户主页社交统计区
// 核心职责：
// - 展示关注、粉丝和获赞收藏数据
// - 保持设计稿中的横向轻量统计排布
struct ProfileUserHomeStatsSection: View {
    let stats: [ProfileUserHomeStat]

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s6) {
            ForEach(stats) { stat in
                VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                    Text(stat.value)
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Text(stat.title)
                        .font(MHBTheme.Typography.caption)
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                        .lineLimit(1)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, MHBTheme.Spacing.s5)
        .padding(.bottom, MHBTheme.Spacing.s5)
    }
}

// ProfileUserHomeAvatar 用户主页头像
// 核心职责：
// - 展示当前用户头像和专业身份认证角标
// - 为封面下方资料区建立身份锚点
private struct ProfileUserHomeAvatar: View {
    let subject: MHBAvatarSubject
    let professionalBadge: ProfileProfessionalIdentityBadge?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            MHBAvatar(
                subject: subject,
                size: .custom(86),
                shape: .circle
            )
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)

            if let professionalBadge {
                ProfileUserHomeProfessionalBadgeIcon(badge: professionalBadge)
                    .padding(4)
            }
        }
        .accessibilityHidden(true)
    }
}

// ProfileUserHomeProfessionalBadgeIcon 用户主页专业认证角标
// 核心职责：
// - 承载专业用户身份 SVG 图标
// - 统一头像右下角角标的圆形底和描边
private struct ProfileUserHomeProfessionalBadgeIcon: View {
    let badge: ProfileProfessionalIdentityBadge

    var body: some View {
        Image(badge.assetName)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(.white)
            .frame(width: 15, height: 15)
            .frame(width: 26, height: 26)
            .background(MHBTheme.ColorToken.labelPrimary.color, in: Circle())
            .overlay {
                Circle()
                    .stroke(MHBTheme.ColorToken.background.color, lineWidth: 2)
            }
            .accessibilityLabel(Text(badge.accessibilityLabel))
    }
}

// ProfileUserHomeCoverBlurConfiguration 用户主页封面模糊配置
// 核心职责：
// - 根据滚动偏移生成底部模糊和整图模糊参数
// - 让封面滚动反馈与首页头图保持一致
private struct ProfileUserHomeCoverBlurConfiguration: Equatable {
    let bottomBlurRadius: CGFloat
    let fullBlurRadius: CGFloat
    let fullBlurOpacity: CGFloat

    nonisolated static func make(scrollOffset: CGFloat) -> ProfileUserHomeCoverBlurConfiguration {
        let transitionRange = max(
            ProfileUserHomeLayout.heroFullBlurEndOffset - ProfileUserHomeLayout.heroFullBlurStartOffset,
            1
        )
        let rawProgress = (scrollOffset - ProfileUserHomeLayout.heroFullBlurStartOffset) / transitionRange
        let transitionProgress = min(max(rawProgress, 0), 1)
        let easedProgress = transitionProgress * transitionProgress * (3 - 2 * transitionProgress)

        return ProfileUserHomeCoverBlurConfiguration(
            bottomBlurRadius: 10,
            fullBlurRadius: 10,
            fullBlurOpacity: easedProgress
        )
    }
}

// ProfileUserHomeCoverStretchMetrics 用户主页封面缩放指标
// 核心职责：
// - 计算下拉放大和上滑收敛参数
// - 让封面图片在滚动过程中只做视觉变换
private struct ProfileUserHomeCoverStretchMetrics: Equatable {
    let scale: CGFloat
    let verticalOffset: CGFloat

    nonisolated static func make(
        frameMinY: CGFloat,
        baseHeroHeight: CGFloat
    ) -> ProfileUserHomeCoverStretchMetrics {
        let stretch = max(frameMinY, 0)
        let upwardScroll = max(-frameMinY, 0)
        let defaultScale = ProfileUserHomeLayout.heroDefaultScale
        let shrinkRatio = max(defaultScale - 1, 0)
        let upwardShrinkProgress = min(
            upwardScroll / max(baseHeroHeight, 1) * ProfileUserHomeLayout.heroShrinkSpeedMultiplier,
            1
        )

        let scale: CGFloat
        if stretch > 0 {
            scale = defaultScale + stretch / max(baseHeroHeight, 1)
        } else {
            scale = defaultScale - upwardShrinkProgress * shrinkRatio
        }

        return ProfileUserHomeCoverStretchMetrics(
            scale: scale,
            verticalOffset: 0
        )
    }
}
