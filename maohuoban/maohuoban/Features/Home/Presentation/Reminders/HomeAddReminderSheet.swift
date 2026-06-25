import SwiftUI
import MaohuobanDesignSystem

// HomeAddReminderSheet 首页添加提醒弹层
// 核心职责：
// - 通过原生全屏 sheet 收集通用提醒字段
// - 创建无 sourceRef 的提醒本体，业务记录关联提醒由对应业务流程生成
// - 只承载一次性提醒，疫苗驱虫和用药计划等周期规则由对应业务域生成提醒
// - 在快速 UI 阶段使用本地状态模拟表单和保存关闭
struct HomeAddReminderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTitleFocused: Bool

    let context: HomeActionRoutingContext

    @State private var selectedPetID: String?
    @State private var selectedKind: HomeReminderDraftKind = .followUp
    @State private var titleText = HomeReminderDraftKind.followUp.defaultTitle
    @State private var dueAt = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @State private var advanceNotice: HomeReminderAdvanceNotice = .oneDay
    @State private var note = ""

    init(context: HomeActionRoutingContext) {
        self.context = context
        self._selectedPetID = State(initialValue: context.selectedPetID ?? context.availablePets.first?.id)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let bottomInset = proxy.safeAreaInsets.bottom

                ZStack(alignment: .topLeading) {
                    MHBTheme.ColorToken.background.color
                        .ignoresSafeArea()

                    ScrollView {
                        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s5) {
                            HomeReminderTitleSection(
                                titleText: $titleText,
                                isTitleFocused: $isTitleFocused
                            )

                            HomeReminderKindSection(
                                selectedKind: $selectedKind,
                                onSelectKind: applyKind
                            )

                            HomeReminderDateSection(dueAt: $dueAt)

                            HomeReminderAdvanceNoticeSection(selection: $advanceNotice)

                            HomeReminderNoteSection(note: $note)
                        }
                        .padding(.horizontal, MHBTheme.Spacing.s5)
                        .padding(.top, topContentPadding)
                        .padding(.bottom, MHBTheme.Spacing.s8 + MHBTheme.Spacing.s8 + MHBTheme.Spacing.s6)
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)

                    MHBBottomFloatingActionCTA(
                        title: "保存提醒",
                        systemImage: "checkmark",
                        bottomInset: bottomInset,
                        action: saveReminder
                    )
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
                    .zIndex(2)

                    HomeAddReminderTopChrome(
                        selectedItem: selectedSwitcherItem,
                        items: petSwitcherItems,
                        isPetSwitcherDisabled: petSwitcherItems.isEmpty,
                        onClose: { dismiss() },
                        onSelectPet: { petID in
                            selectedPetID = petID
                        }
                    )
                    .padding(.horizontal, MHBTheme.Spacing.s4)
                    .padding(.top, Self.topChromeTopPadding)
                    .zIndex(3)
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            }
            .ignoresSafeArea(.container, edges: .bottom)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
        .accessibilityIdentifier("home.addReminder.sheet")
    }

    private var topContentPadding: CGFloat {
        Self.topChromeTopPadding + Self.topChromeHeight + MHBTheme.Spacing.s4
    }

    fileprivate static var topChromeTopPadding: CGFloat {
        MHBTheme.Spacing.s4
    }

    fileprivate static var topChromeHeight: CGFloat {
        48
    }

    private var pets: [PetRecordSwitchPet] {
        if !context.availablePets.isEmpty {
            return context.availablePets
        }

        guard let selectedPetID = context.selectedPetID else { return [] }
        return [
            PetRecordSwitchPet(
                id: selectedPetID,
                name: context.selectedPetName,
                species: .other,
                breed: "",
                avatarURL: context.selectedPetAvatarURL,
                sex: context.selectedPetSex,
                isSelected: true
            )
        ]
    }

    private var selectedSwitcherItem: MHBPetSwitcherItem? {
        let selectedPet = pets.first { $0.id == selectedPetID } ?? pets.first
        return selectedPet.map { pet in
            MHBPetSwitcherItem(reminderPet: pet, isSelected: true)
        }
    }

    private var petSwitcherItems: [MHBPetSwitcherItem] {
        pets.map { pet in
            MHBPetSwitcherItem(reminderPet: pet, isSelected: pet.id == selectedPetID)
        }
    }

    private func applyKind(_ kind: HomeReminderDraftKind) {
        let shouldApplyDefaultTitle = titleText.isEmpty || HomeReminderDraftKind.allCases.contains { $0.defaultTitle == titleText }
        selectedKind = kind
        if shouldApplyDefaultTitle {
            titleText = kind.defaultTitle
        }
    }

    private func saveReminder() {
        // TODO: 接入提醒系统后在这里提交 reminder，sourceRef 保持 nil。
        dismiss()
    }
}

// HomeAddReminderTopChrome 添加提醒弹层顶部控件
// 核心职责：
// - 固定展示关闭按钮、标题和宠物切换入口
// - 让宠物切换停留在顶部 chrome 而不是内容流
private struct HomeAddReminderTopChrome: View {
    let selectedItem: MHBPetSwitcherItem?
    let items: [MHBPetSwitcherItem]
    let isPetSwitcherDisabled: Bool
    let onClose: () -> Void
    let onSelectPet: (String) -> Void

    var body: some View {
        ZStack {
            Text("添加提醒")
                .font(MHBTheme.Typography.headline.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .frame(maxWidth: .infinity)

            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                        .frame(width: 48, height: 48)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("关闭")

                Spacer()

                HomeAddReminderPetSwitcherMenu(
                    selectedItem: selectedItem,
                    items: items,
                    isDisabled: isPetSwitcherDisabled,
                    onSelectPet: onSelectPet
                )
            }
        }
        .frame(height: HomeAddReminderSheet.topChromeHeight)
    }
}

// HomeAddReminderPetSwitcherMenu 添加提醒宠物切换菜单
// 核心职责：
// - 复用通用宠物头像胶囊展示提醒归属宠物
// - 单宠和多宠场景都允许点击查看当前选择
private struct HomeAddReminderPetSwitcherMenu: View {
    let selectedItem: MHBPetSwitcherItem?
    let items: [MHBPetSwitcherItem]
    let isDisabled: Bool
    let onSelectPet: (String) -> Void

    var body: some View {
        Menu {
            if items.isEmpty {
                Label("暂无可选宠物", systemImage: "pawprint")
            } else {
                ForEach(items) { item in
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
            }
        } label: {
            MHBPetSwitcherCapsule(item: selectedItem, isDisabled: isDisabled)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.addReminder.petSwitcherButton")
    }
}
