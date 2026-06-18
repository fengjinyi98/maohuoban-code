import SwiftUI
import MaohuobanDesignSystem

// HomeImmersivePetHeaderLayout 首页沉浸式头图布局参数
// 核心职责：
// - 统一管理头图高度、底部过渡和滚动缩放参数
// - 为头图裁剪、融合和滚动响应保持同一套几何基准
enum HomeImmersivePetHeaderLayout {
    nonisolated static let backgroundImageHeight: CGFloat = 440
    nonisolated static let petStatsCardHeight: CGFloat = 110
    nonisolated static let imageHeight: CGFloat = backgroundImageHeight + petStatsCardHeight
    nonisolated static let backgroundDimmingReferenceHeight: CGFloat = 500
    nonisolated static let colorFogTopRatio: CGFloat = 0.82
    nonisolated static let bottomBlurHeightRatio: CGFloat = 0.24
    nonisolated static let fullBlurTransitionStartOffset: CGFloat = 40
    nonisolated static let fullBlurTransitionEndOffset: CGFloat = 160
    nonisolated static let upwardShrinkMaximumRatio: CGFloat = 0.10
    nonisolated static let upwardShrinkSpeedMultiplier: CGFloat = 8
}

// HomeImmersivePetHeaderSection 首页沉浸式宠物头图
// 核心职责：
// - 展示当前宠物的首屏大图和核心状态
// - 让首页根视图保持装载职责
struct HomeImmersivePetHeaderSection: View {
    let pet: HomeDashboardSnapshot.PetHeroSummary
    let displayName: String
    let width: CGFloat
    let fusionColor: Color
    let contentColorScheme: ColorScheme
    let scrollOffset: CGFloat
    let editProfileRoute: HomeRoute?
    var showsEditProfileButton = true

    private let imageHeight: CGFloat = HomeImmersivePetHeaderLayout.imageHeight
    private var adaptiveIconColor: Color {
        contentColorScheme == .dark ? .white.opacity(0.95) : .black.opacity(0.86)
    }

    var body: some View {
        let imageWidth = max(width, 1)
        let backgroundImageHeight = HomeImmersivePetHeaderLayout.backgroundImageHeight
        let presentation = HomeImmersivePetHeaderPresentation.make(
            pet: pet,
            displayName: displayName
        )

        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                // 背景层独立控制在内容上方，避免软色场扩散到下方业务列表
                HomeImmersivePetHeaderBackgroundLayer(
                    media: pet.heroMedia,
                    imageWidth: imageWidth,
                    baseImageHeight: backgroundImageHeight,
                    fusionColor: fusionColor,
                    scrollOffset: scrollOffset
                )

                VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
                    Spacer()

                    VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
                        HStack(spacing: 6) {
                            HomeImmersiveCalendarIcon(day: presentation.calendarDay)
                                .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 1)

                            Text(presentation.formattedDate)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .kerning(1.2)
                                .foregroundStyle(.white.opacity(0.85))
                                .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 1)
                        }

                        HStack(alignment: .bottom, spacing: 4) {
                            Text(pet.name)
                                .font(.system(size: 38, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)

                            if let genderIconSystemName = presentation.genderIconSystemName {
                                Image(systemName: genderIconSystemName)
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(presentation.genderColor)
                                    .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 1)
                                    .padding(.bottom, 6)
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image("IconWorld")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundStyle(adaptiveIconColor)
                                    .frame(width: 16, height: 16)
                                    .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 1)

                                Text(presentation.worldDaysText)
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.95))
                                    .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 1)
                            }

                            HStack(spacing: 6) {
                                Image("IconCompanion")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundStyle(adaptiveIconColor)
                                    .frame(width: 16, height: 16)
                                    .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 1)

                                Text(presentation.companionshipText)
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.95))
                                    .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 1)

                                Spacer()

                                if showsEditProfileButton {
                                    if let editProfileRoute {
                                        NavigationLink(value: editProfileRoute) {
                                            HomeImmersiveHeaderCapsuleLabel(title: "编辑档案")
                                        }
                                        .buttonStyle(.plain)
                                    } else {
                                        HomeImmersiveHeaderCapsuleLabel(
                                            title: "编辑档案",
                                            isEnabled: false
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, MHBTheme.Spacing.s4)
                .padding(.bottom, MHBTheme.Spacing.s4)
                .frame(width: imageWidth, height: backgroundImageHeight)
            }
            .frame(width: imageWidth, height: backgroundImageHeight)

            HomePetHeroSection(pet: pet)
                .padding(.horizontal, MHBTheme.Spacing.s4)
                .frame(width: imageWidth, height: HomeImmersivePetHeaderLayout.petStatsCardHeight)
        }
        .frame(width: imageWidth, height: imageHeight)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.immersivePetHeader")
    }
}
