import SwiftUI
import MaohuobanDesignSystem

// PetWalkHistoryScreen 宠物遛弯记录列表页
// 核心职责：
// - 展示当前宠物的月度遛弯统计和历史记录
// - 通过顶部宠物切换胶囊切换不同宠物的记录
struct PetWalkHistoryScreen: View {
    @Environment(\.dismiss) private var dismiss

    let context: PetRecordEntryContext

    @State private var selectedPet: PetRecordSwitchPet?
    @State private var month = PetWalkHistoryMonth.current()
    @State private var selectedRecord: PetWalkHistoryRecord?

    init(context: PetRecordEntryContext) {
        self.context = context
        self._selectedPet = State(initialValue: context.selectedSwitchPet)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                MHBTheme.ColorToken.background.color
                    .ignoresSafeArea()

                MHBScreenScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: MHBTheme.Spacing.s6) {
                        PetWalkHistoryDashboardSection(
                            month: month,
                            summary: displayState.summary,
                            onPreviousMonth: { month = month.previous },
                            onNextMonth: { month = month.next }
                        )

                        PetWalkHistoryContentTitle(title: historyTitle)

                        PetWalkHistoryRecordsSection(
                            sections: displayState.sections,
                            onSelectRecord: openRecordDetail
                        )
                    }
                    .padding(.horizontal, MHBTheme.Spacing.s5)
                    .padding(.top, topContentPadding(geometrySafeAreaTop: proxy.safeAreaInsets.top))
                    .padding(.bottom, MHBTheme.Spacing.s8)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .zIndex(0)

                PetWalkHistoryTopChrome(
                    petItem: currentPetSwitcherItem,
                    petItems: petSwitcherItems,
                    isPetSwitcherDisabled: petSwitcherItems.isEmpty,
                    onBack: { dismiss() },
                    onSelectPet: selectPetForHistory
                )
                .padding(.horizontal, MHBTheme.Spacing.s4)
                .mhbTopChromeAligned(geometrySafeAreaTop: proxy.safeAreaInsets.top)
                .zIndex(2)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .coordinateSpace(name: "PetWalkHistoryRoot")
        }
        .ignoresSafeArea(.container, edges: [.top, .bottom])
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .navigationDestination(item: $selectedRecord) { record in
            PetWalkHistoryDetailScreen(
                record: record,
                petName: currentPetName,
                petAvatarURL: resolvedPetAvatarURL,
                petSex: currentPetSex
            )
        }
        .onAppear {
            selectedPet = selectedPet ?? context.selectedSwitchPet
        }
        .accessibilityIdentifier("pet.walkHistory.screen")
    }

    private var topChromeHeight: CGFloat {
        48
    }

    private func topContentPadding(geometrySafeAreaTop: CGFloat) -> CGFloat {
        MHBTopChromePositionResolver.resolvedTopInset(geometrySafeAreaTop: geometrySafeAreaTop)
            + topChromeHeight
            + MHBTheme.Spacing.s5
    }

    private var displayState: PetWalkHistoryDisplayState {
        PetWalkHistoryDisplayState(
            selectedPetID: currentPetID,
            month: month,
            allRecords: PetWalkHistoryMockData.records(for: historyPets)
        )
    }

    private var currentPetID: String? {
        selectedPet?.id ?? context.petID
    }

    private var currentPetName: String {
        selectedPet?.name ?? context.petName ?? "未命名宠物"
    }

    private var currentPetAvatarURL: String? {
        selectedPet?.avatarURL ?? context.petAvatarURL
    }

    private var resolvedPetAvatarURL: URL? {
        guard let currentPetAvatarURL else { return nil }
        return MHBBackendEndpoint.resolve(currentPetAvatarURL)
    }

    private var currentPetSex: PetRecordPetSex {
        selectedPet?.sex ?? context.petSex
    }

    private var historyTitle: String {
        "\(currentPetName)的遛弯记录"
    }

    private var historyPets: [PetRecordSwitchPet] {
        if context.availablePets.isEmpty == false {
            return context.availablePets
        }

        return selectedPet.map { [$0] } ?? context.selectedSwitchPet.map { [$0] } ?? []
    }

    private var currentPetSwitcherItem: MHBPetSwitcherItem? {
        petSwitcherItems.first(where: \.isSelected)
    }

    private var petSwitcherItems: [MHBPetSwitcherItem] {
        historyPets.map { pet in
            MHBPetSwitcherItem(recordSwitchPet: pet, isSelected: pet.id == currentPetID)
        }
    }

    private func selectPetForHistory(_ petID: String) {
        guard let pet = historyPets.first(where: { $0.id == petID }) else { return }
        selectedPet = PetRecordSwitchPet(
            id: pet.id,
            name: pet.name,
            species: pet.species,
            breed: pet.breed,
            avatarURL: pet.avatarURL,
            sex: pet.sex,
            isSelected: true
        )
    }

    private func openRecordDetail(_ record: PetWalkHistoryRecord) {
        selectedRecord = record
    }
}

// PetWalkHistoryTopChrome 遛弯记录顶部导航控件
// 核心职责：
// - 在系统导航栏视觉位置展示返回和宠物切换
// - 避免标题进入自绘导航栏造成内容层级混淆
private struct PetWalkHistoryTopChrome: View {
    let petItem: MHBPetSwitcherItem?
    let petItems: [MHBPetSwitcherItem]
    let isPetSwitcherDisabled: Bool
    let onBack: () -> Void
    let onSelectPet: (String) -> Void

    var body: some View {
        GlassEffectContainer(spacing: MHBTheme.Spacing.s3) {
            ZStack {
                HStack(spacing: MHBTheme.Spacing.s3) {
                    PetWalkHistoryBackButton(onBack: onBack)

                    Spacer(minLength: MHBTheme.Spacing.s3)
                }

                HStack {
                    Spacer(minLength: MHBTheme.Spacing.s3)

                    PetWalkHistoryPetSwitcherMenu(
                        petItem: petItem,
                        petItems: petItems,
                        isPetSwitcherDisabled: isPetSwitcherDisabled,
                        onSelectPet: onSelectPet
                    )
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// PetWalkHistoryContentTitle 遛弯记录内容标题
// 核心职责：
// - 在内容流中展示当前宠物的遛弯记录标题
// - 与同城动态标题保持同一层级字号
private struct PetWalkHistoryContentTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(MHBTheme.Typography.headline.weight(.bold))
            .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("pet.walkHistory.contentTitle")
    }
}

// PetWalkHistoryPetSwitcherMenu 遛弯记录宠物切换菜单
// 核心职责：
// - 在顶部右侧展示当前宠物胶囊
// - 使用纯 SwiftUI Menu 承载宠物切换动作
private struct PetWalkHistoryPetSwitcherMenu: View {
    let petItem: MHBPetSwitcherItem?
    let petItems: [MHBPetSwitcherItem]
    let isPetSwitcherDisabled: Bool
    let onSelectPet: (String) -> Void

    var body: some View {
        Menu {
            ForEach(petItems) { item in
                Button {
                    guard item.isSelected == false else { return }
                    onSelectPet(item.id)
                } label: {
                    Label(
                        item.name,
                        systemImage: item.isSelected ? "checkmark" : item.species.fallbackSystemImage
                    )
                }
            }
        } label: {
            MHBPetSwitcherCapsule(
                item: petItem,
                isDisabled: isPetSwitcherDisabled
            )
        }
        .disabled(isPetSwitcherDisabled)
        .buttonStyle(.plain)
        .accessibilityIdentifier("pet.walkHistory.petSwitcherButton")
    }
}

// PetWalkHistoryBackButton 遛弯记录返回按钮
// 核心职责：
// - 承载顶部左侧返回动作
// - 保持与遛弯页一致的 Liquid Glass 圆形触控反馈
private struct PetWalkHistoryBackButton: View {
    let onBack: () -> Void

    var body: some View {
        Button(action: onBack) {
            Image(systemName: "chevron.left")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .frame(width: 48, height: 48)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("返回")
        .accessibilityIdentifier("pet.walkHistory.backButton")
    }
}

private extension MHBPetSwitcherItem {
    init(recordSwitchPet pet: PetRecordSwitchPet, isSelected: Bool) {
        self.init(
            id: pet.id,
            name: pet.name ?? "未命名宠物",
            subtitle: pet.breed,
            avatarURLString: pet.avatarURL,
            species: MHBPetSwitcherSpecies(recordSpecies: pet.species),
            sex: MHBPetSwitcherSex(recordSex: pet.sex),
            isSelected: isSelected
        )
    }
}

private extension MHBPetSwitcherSpecies {
    init(recordSpecies: PetRecordPetSpecies) {
        switch recordSpecies {
        case .dog:
            self = .dog
        case .cat:
            self = .cat
        case .other:
            self = .other
        }
    }
}

private extension MHBPetSwitcherSex {
    init(recordSex: PetRecordPetSex) {
        switch recordSex {
        case .male:
            self = .male
        case .female:
            self = .female
        case .unknown:
            self = .unknown
        }
    }
}
