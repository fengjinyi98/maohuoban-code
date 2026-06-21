import SwiftUI
import MaohuobanDesignSystem

// ProfileBadgeDetailSheet 勋章详情弹层
// 核心职责：
// - 展示单个勋章的完整文案、获得条件和社交证明
// - 承载未点亮勋章的进度反馈与互斥勋章规则提示
struct ProfileBadgeDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    let badge: ProfileBadge

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .center, spacing: badge.isEarned ? MHBTheme.Spacing.s4 : MHBTheme.Spacing.s3) {
                ProfileBadgeDetailHero(badge: badge)

                ProfileBadgeRarityRow(badge: badge)

                ProfileBadgeQuotePanel(quote: badge.quote)

                ProfileBadgeConditionPanel(condition: badge.condition)

                if !badge.isEarned {
                    ProfileBadgeProgressSection(badge: badge)
                }

                if badge.alternateImageAssetName != nil {
                    ProfileBadgeMutualExclusiveNote()
                }

                Button {
                    dismiss()
                } label: {
                    Text("我知道了")
                        .font(MHBTheme.Typography.body.weight(.bold))
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(MHBTheme.ColorToken.separatorSoft.color, in: RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, MHBTheme.Spacing.s2)
                .accessibilityIdentifier("profile.badges.detail.close")
            }
            .padding(.horizontal, MHBTheme.Spacing.s6)
            .padding(.top, badge.isEarned ? MHBTheme.Spacing.s8 : MHBTheme.Spacing.s6)
            .padding(.bottom, MHBTheme.Spacing.s6)
        }
        .background(MHBTheme.ColorToken.cardSolid.color.ignoresSafeArea())
        .accessibilityIdentifier("profile.badges.detail")
    }
}

// ProfileBadgeDetailHero 勋章详情主视觉
// 核心职责：
// - 展示大尺寸勋章资源和标题
// - 使用点亮状态表达当前获得情况
private struct ProfileBadgeDetailHero: View {
    let badge: ProfileBadge

    var body: some View {
        VStack(alignment: .center, spacing: MHBTheme.Spacing.s3) {
            if badge.isEarned {
                ProfileBadgeCelebrationArtwork(
                    imageAssetName: badge.imageAssetName,
                    accentColor: badge.rarity.accentColor
                )
            } else {
                ProfileBadgeArtwork(
                    imageAssetName: badge.imageAssetName,
                    isEarned: false,
                    size: 116,
                    shadowRadius: 0
                )
                .frame(width: 120, height: 120)
            }

            VStack(alignment: .center, spacing: MHBTheme.Spacing.s1) {
                Text(badge.title)
                    .font(MHBTheme.Typography.title)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(badge.description)
                    .font(MHBTheme.Typography.footnote)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// ProfileBadgeCelebrationArtwork 已点亮勋章庆祝动效
// 核心职责：
// - 在详情弹层出现时呈现一次性弹出、星点和扫光动画
// - 只用于已获得勋章，避免未获得勋章产生奖励感反馈
private struct ProfileBadgeCelebrationArtwork: View {
    let imageAssetName: String
    let accentColor: Color

    @State private var isPresented = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(accentColor.opacity(0.24), lineWidth: 2)
                .frame(width: 142, height: 142)
                .scaleEffect(isPresented ? 1.18 : 0.7)
                .opacity(isPresented ? 0 : 0.9)
                .animation(.easeOut(duration: 0.72), value: isPresented)

            ProfileBadgeSparkleOrbit(
                accentColor: accentColor,
                isPresented: isPresented
            )

            ProfileBadgeArtwork(
                imageAssetName: imageAssetName,
                isEarned: true,
                size: 128,
                shadowRadius: 14
            )
            .frame(width: 132, height: 132)
            .scaleEffect(isPresented ? 1 : 0.68)
            .rotation3DEffect(
                .degrees(isPresented ? 0 : -24),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.55
            )
            .overlay {
                ProfileBadgeShineSweep(
                    imageAssetName: imageAssetName,
                    isPresented: isPresented
                )
            }
            .animation(.spring(response: 0.52, dampingFraction: 0.68), value: isPresented)
        }
        .frame(width: 156, height: 150)
        .onAppear {
            isPresented = false
            withAnimation(.spring(response: 0.52, dampingFraction: 0.68)) {
                isPresented = true
            }
        }
    }
}

// ProfileBadgeSparkleOrbit 勋章星点扩散
// 核心职责：
// - 为已点亮勋章提供轻量庆祝粒子
private struct ProfileBadgeSparkleOrbit: View {
    let accentColor: Color
    let isPresented: Bool

    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { index in
                Circle()
                    .fill(index.isMultiple(of: 2) ? accentColor : MHBTheme.ColorToken.warning.color)
                    .frame(width: index.isMultiple(of: 3) ? 4 : 6, height: index.isMultiple(of: 3) ? 4 : 6)
                    .offset(y: isPresented ? -70 : -36)
                    .rotationEffect(.degrees(Double(index) * 45 + (isPresented ? 18 : -12)))
                    .opacity(isPresented ? 0 : 0.95)
                    .scaleEffect(isPresented ? 0.4 : 1)
                    .animation(
                        .easeOut(duration: 0.62).delay(Double(index) * 0.025),
                        value: isPresented
                    )
            }
        }
    }
}

// ProfileBadgeShineSweep 勋章扫光动画
// 核心职责：
// - 在已点亮勋章弹出时添加一次性高光扫过效果
private struct ProfileBadgeShineSweep: View {
    let imageAssetName: String
    let isPresented: Bool

    var body: some View {
        GeometryReader { proxy in
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0),
                            .white.opacity(0.78),
                            .white.opacity(0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 28, height: proxy.size.height * 1.6)
                .rotationEffect(.degrees(18))
                .offset(x: isPresented ? proxy.size.width * 1.15 : -proxy.size.width * 0.85)
                .blendMode(.screen)
                .animation(.easeOut(duration: 0.72).delay(0.1), value: isPresented)
        }
        .mask {
            Image(imageAssetName)
                .resizable()
                .scaledToFit()
        }
        .allowsHitTesting(false)
    }
}

// ProfileBadgeRarityRow 勋章稀有度信息行
// 核心职责：
// - 展示稀有度标签和获得人数
private struct ProfileBadgeRarityRow: View {
    let badge: ProfileBadge

    var body: some View {
        HStack(alignment: .center, spacing: MHBTheme.Spacing.s2) {
            Text(badge.rarity.title)
                .font(MHBTheme.Typography.section.weight(.bold))
                .foregroundStyle(tagForegroundColor)
                .padding(.horizontal, MHBTheme.Spacing.s3)
                .padding(.vertical, MHBTheme.Spacing.s1)
                .background(tagBackgroundColor, in: RoundedRectangle(cornerRadius: MHBTheme.Radius.small, style: .continuous))

            Text(badge.socialProof)
                .font(MHBTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
    }

    private var tagForegroundColor: Color {
        badge.isEarned ? badge.rarity.accentColor : MHBTheme.ColorToken.labelSecondary.color
    }

    private var tagBackgroundColor: Color {
        badge.isEarned ? badge.rarity.tagBackgroundColor : MHBTheme.ColorToken.separatorSoft.color
    }
}

// ProfileBadgeQuotePanel 勋章文案面板
// 核心职责：
// - 突出展示勋章专属文案
private struct ProfileBadgeQuotePanel: View {
    let quote: String

    var body: some View {
        Text("“\(quote)”")
            .font(MHBTheme.Typography.body.weight(.bold))
            .italic()
            .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
            .multilineTextAlignment(.center)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, MHBTheme.Spacing.s2)
            .padding(.vertical, MHBTheme.Spacing.s2)
    }
}

// ProfileBadgeConditionPanel 勋章获得条件面板
// 核心职责：
// - 展示当前勋章的具体获得条件
private struct ProfileBadgeConditionPanel: View {
    let condition: String

    var body: some View {
        Text("获得条件：\(condition)")
            .font(MHBTheme.Typography.footnote)
            .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            .multilineTextAlignment(.center)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .padding(MHBTheme.Spacing.s3)
            .frame(maxWidth: .infinity)
            .background(MHBTheme.ColorToken.background.color, in: RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
    }
}

// ProfileBadgeProgressSection 勋章未点亮进度
// 核心职责：
// - 展示未获得勋章距离点亮目标的当前进度
private struct ProfileBadgeProgressSection: View {
    let badge: ProfileBadge

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
            ProfileBadgeProgressBar(fraction: badge.progressFraction)

            HStack {
                Text("当前进度")
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

                Spacer()

                Text("\(badge.progressCurrent) / \(badge.progressTarget)")
                    .font(MHBTheme.Typography.caption.weight(.bold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// ProfileBadgeProgressBar 勋章进度条
// 核心职责：
// - 绘制锁定勋章的目标完成比例
private struct ProfileBadgeProgressBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(MHBTheme.ColorToken.separator.color)

                Capsule()
                    .fill(MHBTheme.ColorToken.labelPrimary.color)
                    .frame(width: proxy.size.width * fraction)
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }
}

// ProfileBadgeMutualExclusiveNote 第一只伙伴互斥规则提示
// 核心职责：
// - 明确猫版与狗版第一只伙伴只能获得其中一个
// - 为后端按第一只宠物物种发放提供前端文案锚点
private struct ProfileBadgeMutualExclusiveNote: View {
    var body: some View {
        Text("发放规则：猫版与狗版互斥，账号只会点亮第一只宠物物种对应的一个版本。")
            .font(MHBTheme.Typography.caption)
            .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            .multilineTextAlignment(.center)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(MHBTheme.Spacing.s3)
            .frame(maxWidth: .infinity)
            .background(MHBTheme.ColorToken.primaryBackgroundSoft.color, in: RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
    }
}
