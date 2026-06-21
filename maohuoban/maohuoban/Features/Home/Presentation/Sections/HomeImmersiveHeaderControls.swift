import SwiftUI
import MaohuobanDesignSystem

// HomeImmersiveHeaderControls 首页沉浸式头部操作区
// 核心职责：
// - 在系统导航栏位置承载 AI 入口与宠物切换
// - 使用 Liquid Glass 统一管理自定义头部控件
struct HomeImmersiveHeaderControls: View {
    let selectedPet: HomeDashboardSnapshot.PetHeroSummary?
    let pets: [HomeDashboardSnapshot.PetSwitchItem]
    let onSelectPet: (String) -> Void

    @Binding var isPetSwitcherPresented: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            GlassEffectContainer(spacing: MHBTheme.Spacing.s3) {
                HStack(spacing: MHBTheme.Spacing.s3) {
                    HomeImmersiveAIAssistantButton(
                        pet: selectedPet,
                        route: aiRoute
                    )
                    .layoutPriority(1)

                    Spacer(minLength: MHBTheme.Spacing.s3)

                    HomeImmersivePetSwitchAvatarButton(
                        pet: selectedPet,
                        isPresented: $isPetSwitcherPresented,
                        action: {
                            isPetSwitcherPresented.toggle()
                        }
                    )
                }
                .frame(maxWidth: .infinity)
            }

            MHBAnchoredFloatingPanel(
                isPresented: isPetSwitcherPresented,
                offset: CGSize(width: 0, height: 56),
                scaleAnchor: .topTrailing
            ) {
                HomeImmersivePetSwitchPanel(
                    pets: pets,
                    onSelectPet: { petID in
                        isPetSwitcherPresented = false
                        onSelectPet(petID)
                    },
                    onShowMore: {
                        isPetSwitcherPresented = false
                        // TODO: 接入完整宠物列表入口
                    }
                )
                .zIndex(1)
            }
        }
        .animation(.snappy(duration: 0.22), value: isPetSwitcherPresented)
    }

    private var aiRoute: HomeRoute {
        HomeRoute.petAssistant(
            AIAssistantEntryContext(
                selectedPetID: selectedPet?.id,
                selectedPetName: selectedPet?.name
            )
        )
    }
}

// HomeImmersiveAIAssistantButton 首页沉浸式 AI 入口按钮
// 核心职责：
// - 在首页固定顶层展示私域宠物 AI 入口
// - 使用系统导航值推进到 AI 助手页面
private struct HomeImmersiveAIAssistantButton: View {
    let pet: HomeDashboardSnapshot.PetHeroSummary?
    let route: HomeRoute

    var body: some View {
        NavigationLink(value: route) {
            HStack(spacing: MHBTheme.Spacing.s2) {
                Image(systemName: "sparkles")
                    .font(.system(size: MHBTheme.IconSize.small, weight: .bold))

                Text("AI")
                    .font(MHBTheme.Typography.headline)
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .frame(height: 44)
            .background {
                Color.black.opacity(0.18)
                    .clipShape(Capsule())
            }
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("打开毛伙伴 AI，当前宠物 \(pet?.name ?? "未知")")
        .accessibilityIdentifier("home.aiAssistantButton")
    }
}

// HomeImmersivePetSwitchAvatarButton 首页沉浸式宠物头像切换按钮
// 核心职责：
// - 在首页右上角展示当前宠物头像
// - 控制宠物切换菜单展开与收起
private struct HomeImmersivePetSwitchAvatarButton: View {
    let pet: HomeDashboardSnapshot.PetHeroSummary?
    @Binding var isPresented: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HomeImmersivePetAvatar(
                avatarURL: pet?.avatarURL,
                species: pet?.species ?? .other,
                isSelected: true,
                size: 44
            )
            .background {
                Circle()
                    .fill(Color.black.opacity(0.18))
            }
            .glassEffect(.regular.interactive(), in: .circle)
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 16, height: 16)
                    .background(MHBTheme.ColorToken.primary.color)
                    .clipShape(Circle())
                    .rotationEffect(.degrees(isPresented ? 180 : 0))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("切换宠物，当前宠物 \(pet?.name ?? "未知")")
        .accessibilityIdentifier("home.petHeaderSwitchButton")
    }
}
