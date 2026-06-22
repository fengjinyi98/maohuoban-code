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
    let onAddPet: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: MHBTheme.Spacing.s3) {
            HStack(spacing: MHBTheme.Spacing.s3) {
                HomeImmersiveAIAssistantButton(
                    pet: selectedPet,
                    route: aiRoute
                )
                .layoutPriority(1)

                Spacer(minLength: MHBTheme.Spacing.s3)

                Menu {
                    petMenuContent
                } label: {
                    MHBPetSwitcherCapsule(item: triggerItem)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.petHeaderSwitchButton")
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var triggerItem: MHBPetSwitcherItem? {
        if let selectedPet {
            return MHBPetSwitcherItem(homeHeroPet: selectedPet)
        }

        return pets.first(where: \.isSelected).map(MHBPetSwitcherItem.init(homeSwitchItem:))
    }

    private var aiRoute: HomeRoute {
        HomeRoute.petAssistant(
            AIAssistantEntryContext(
                selectedPetID: selectedPet?.id,
                selectedPetName: selectedPet?.name,
                selectedPetAvatarURL: selectedPet?.avatarURL,
                selectedPetSpecies: selectedPet?.species.aiAssistantSpecies ?? .other
            )
        )
    }

    @ViewBuilder
    private var petMenuContent: some View {
        ForEach(petSwitcherItems) { item in
            Button {
                guard item.isSelected == false else { return }
                onSelectPet(item.id)
            } label: {
                MHBPetSwitcherMenuItemLabel(item: item)
            }
        }

        Divider()

        Button(action: onAddPet) {
            Label("添加新宠物", systemImage: "plus")
        }
    }

    private var petSwitcherItems: [MHBPetSwitcherItem] {
        pets.map { item in
            if item.id == selectedPet?.id,
               let selectedPet {
                return MHBPetSwitcherItem(homeHeroPet: selectedPet)
            }

            return MHBPetSwitcherItem(homeSwitchItem: item)
        }
    }
}

private extension HomeDashboardSnapshot.Species {
    var aiAssistantSpecies: AIAssistantPetSpecies {
        switch self {
        case .dog: .dog
        case .cat: .cat
        case .other: .other
        }
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
        .accessibilityLabel("打开毛球，当前宠物 \(pet?.name ?? "未知")")
        .accessibilityIdentifier("home.aiAssistantButton")
    }
}

extension MHBPetSwitcherItem {
    init(homeHeroPet pet: HomeDashboardSnapshot.PetHeroSummary) {
        self.init(
            id: pet.id,
            name: pet.name,
            subtitle: [pet.breed, pet.ageText].filter { $0.isEmpty == false }.joined(separator: " · "),
            avatarURLString: pet.avatarURL,
            species: MHBPetSwitcherSpecies(homeDashboardSpecies: pet.species),
            sex: MHBPetSwitcherSex(homeDashboardSex: pet.sex),
            isSelected: true
        )
    }

    init(homeSwitchItem item: HomeDashboardSnapshot.PetSwitchItem) {
        self.init(
            id: item.id,
            name: item.name,
            subtitle: item.breed,
            avatarURLString: item.avatarURL,
            species: MHBPetSwitcherSpecies(homeDashboardSpecies: item.species),
            sex: MHBPetSwitcherSex(homeDashboardSex: item.sex),
            isSelected: item.isSelected
        )
    }
}

extension MHBPetSwitcherSpecies {
    init(homeDashboardSpecies: HomeDashboardSnapshot.Species) {
        switch homeDashboardSpecies {
        case .dog:
            self = .dog
        case .cat:
            self = .cat
        case .other:
            self = .other
        }
    }
}

extension MHBPetSwitcherSex {
    init(homeDashboardSex: HomeDashboardSnapshot.Sex?) {
        switch homeDashboardSex {
        case .female:
            self = .female
        case .male:
            self = .male
        case .unknown, nil:
            self = .unknown
        }
    }
}
