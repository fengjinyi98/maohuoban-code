import SwiftUI
import MaohuobanDesignSystem

// HomeImmersiveHeaderControls 首页沉浸式头部操作区
// 核心职责：
// - 在系统导航栏位置承载宠物切换与用户入口
// - 使用 Liquid Glass 统一管理自定义头部控件
struct HomeImmersiveHeaderControls: View {
    let selectedPet: HomeDashboardSnapshot.PetHeroSummary?
    let pets: [HomeDashboardSnapshot.PetSwitchItem]
    let avatarURL: String?
    let displayName: String
    let onOpenProfile: () -> Void
    let onSelectPet: (String) -> Void

    @Binding var isPetSwitcherPresented: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            GlassEffectContainer(spacing: MHBTheme.Spacing.s3) {
                HStack(spacing: MHBTheme.Spacing.s3) {
                    HomeImmersivePetSwitchButton(
                        pet: selectedPet,
                        isPresented: $isPetSwitcherPresented
                    )
                    .layoutPriority(1)

                    Spacer(minLength: MHBTheme.Spacing.s3)

                    HomeImmersiveUserAvatarButton(
                        avatarURL: avatarURL,
                        fallbackAssetName: "HomeUserAvatarMock",
                        displayName: displayName,
                        action: {
                            isPetSwitcherPresented = false
                            onOpenProfile()
                        }
                    )
                }
                .frame(maxWidth: .infinity)
            }

            MHBAnchoredFloatingPanel(
                isPresented: isPetSwitcherPresented,
                offset: CGSize(width: 0, height: 56),
                scaleAnchor: .topLeading
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
}

// HomeImmersivePetSwitchButton 首页沉浸式宠物切换按钮
// 核心职责：
// - 在首页固定顶层展示当前宠物头像与名称
// - 控制宠物切换菜单展开与收起
private struct HomeImmersivePetSwitchButton: View {
    let pet: HomeDashboardSnapshot.PetHeroSummary?
    @Binding var isPresented: Bool

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            HStack(spacing: MHBTheme.Spacing.s2) {
                HomeImmersivePetAvatar(
                    avatarURL: pet?.avatarURL,
                    species: pet?.species ?? .other,
                    isSelected: true,
                    size: 42
                )

                Text(pet?.name ?? "宠物")
                    .font(MHBTheme.Typography.headline)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .minimumScaleFactor(0.82)
                    .layoutPriority(1)

                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .bold))
                    .rotationEffect(.degrees(isPresented ? 180 : 0))
            }
            .foregroundStyle(.white)
            .padding(.leading, 5)
            .padding(.trailing, MHBTheme.Spacing.s4)
            .padding(.vertical, 5)
            .background {
                Color.black.opacity(0.18)
                    .clipShape(Capsule())
            }
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("切换宠物，当前宠物 \(pet?.name ?? "未知")")
        .accessibilityIdentifier("home.petHeaderSwitchButton")
    }
}
