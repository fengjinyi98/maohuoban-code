import SwiftUI
import MaohuobanDesignSystem

// HomeQuickFactFeedingSheet 喂食快捷记录弹层
// 核心职责：
// - 让用户确认喂食宠物、食品类型和份量
// - 以可一键提交的默认值降低喂食记录负担
struct HomeQuickFactFeedingSheet: View {
    let context: HomeActionRoutingContext
    let isSubmitting: Bool
    let onSubmit: (HomeQuickFactFeedingInput) -> Void
    let onCancel: () -> Void

    @State private var selectedPetID: String?
    @State private var foodKind: HomeQuickFactFeedingFoodKind = .mainFood
    @State private var amount: HomeQuickFactFeedingAmount = .normal
    @State private var note = ""

    init(
        context: HomeActionRoutingContext,
        isSubmitting: Bool,
        onSubmit: @escaping (HomeQuickFactFeedingInput) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.context = context
        self.isSubmitting = isSubmitting
        self.onSubmit = onSubmit
        self.onCancel = onCancel
        self._selectedPetID = State(initialValue: context.selectedPetID ?? context.availablePets.first?.id)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: MHBTheme.Spacing.s5) {
                    HomeQuickFactPetSelectionSection(
                        context: context,
                        selectedPetID: $selectedPetID
                    )

                    HomeQuickFactSingleChoiceSection(
                        title: "喂了什么",
                        options: HomeQuickFactFeedingFoodKind.allCases,
                        selection: $foodKind
                    ) { option in
                        HomeQuickFactOptionLabel(
                            title: option.title,
                            systemImage: option.systemImage
                        )
                    }

                    HomeQuickFactSingleChoiceSection(
                        title: "份量",
                        options: HomeQuickFactFeedingAmount.allCases,
                        selection: $amount
                    ) { option in
                        Text(option.title)
                            .font(MHBTheme.Typography.callout.weight(.semibold))
                    }

                    HomeQuickFactNoteSection(
                        title: "备注",
                        prompt: "例如 换了新粮、加了罐头",
                        note: $note
                    )
                }
                .padding(.horizontal, MHBTheme.Spacing.s5)
                .padding(.top, MHBTheme.Spacing.s4)
                .padding(.bottom, MHBTheme.Spacing.s6)
            }
            .background(MHBTheme.ColorToken.background.color)
            .navigationTitle("记录喂食")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSubmitting ? "记录中" : "记录") {
                        onSubmit(
                            HomeQuickFactFeedingInput(
                                petID: selectedPetID,
                                foodKind: foodKind,
                                amount: amount,
                                note: note
                            )
                        )
                    }
                    .disabled(isSubmitting || selectedPetID == nil)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// HomeQuickFactAbnormalSheet 异常快捷记录弹层
// 核心职责：
// - 收集宠物异常的症状、多选标签和严重程度
// - 将异常入口从笼统健康记录中独立出来
struct HomeQuickFactAbnormalSheet: View {
    let context: HomeActionRoutingContext
    let isSubmitting: Bool
    let onSubmit: (HomeQuickFactAbnormalInput) -> Void
    let onCancel: () -> Void

    @State private var selectedPetID: String?
    @State private var selectedSymptoms: Set<HomeQuickFactAbnormalSymptom> = []
    @State private var severity: HomeQuickFactAbnormalSeverity = .mild
    @State private var note = ""

    init(
        context: HomeActionRoutingContext,
        isSubmitting: Bool,
        onSubmit: @escaping (HomeQuickFactAbnormalInput) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.context = context
        self.isSubmitting = isSubmitting
        self.onSubmit = onSubmit
        self.onCancel = onCancel
        self._selectedPetID = State(initialValue: context.selectedPetID ?? context.availablePets.first?.id)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: MHBTheme.Spacing.s5) {
                    HomeQuickFactPetSelectionSection(
                        context: context,
                        selectedPetID: $selectedPetID
                    )

                    HomeQuickFactMultiChoiceSection(
                        title: "哪里异常",
                        options: HomeQuickFactAbnormalSymptom.allCases,
                        selection: $selectedSymptoms
                    ) { option in
                        HomeQuickFactOptionLabel(
                            title: option.title,
                            systemImage: option.systemImage
                        )
                    }

                    HomeQuickFactSingleChoiceSection(
                        title: "程度",
                        options: HomeQuickFactAbnormalSeverity.allCases,
                        selection: $severity
                    ) { option in
                        Text(option.title)
                            .font(MHBTheme.Typography.callout.weight(.semibold))
                    }

                    HomeQuickFactNoteSection(
                        title: "备注",
                        prompt: "例如 持续多久、是否吃了新东西",
                        note: $note
                    )

                    HomeQuickFactPhotoPlaceholderSection()
                }
                .padding(.horizontal, MHBTheme.Spacing.s5)
                .padding(.top, MHBTheme.Spacing.s4)
                .padding(.bottom, MHBTheme.Spacing.s6)
            }
            .background(MHBTheme.ColorToken.background.color)
            .navigationTitle("记录异常")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSubmitting ? "记录中" : "记录") {
                        onSubmit(
                            HomeQuickFactAbnormalInput(
                                petID: selectedPetID,
                                symptoms: HomeQuickFactAbnormalSymptom.allCases.filter { selectedSymptoms.contains($0) },
                                severity: severity,
                                note: note
                            )
                        )
                    }
                    .disabled(isSubmitting || selectedPetID == nil || selectedSymptoms.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// HomeQuickFactPetSelectionSection 快捷事实宠物选择区
// 核心职责：
// - 在单宠时展示当前宠物
// - 在多宠时提供明确的宠物归属选择
private struct HomeQuickFactPetSelectionSection: View {
    let context: HomeActionRoutingContext
    @Binding var selectedPetID: String?

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

    var body: some View {
        HomeQuickFactSheetSection(title: "宠物") {
            if pets.count <= 1 {
                HomeQuickFactSelectedPetCard(
                    name: pets.first?.name ?? context.selectedPetName ?? "当前宠物"
                )
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 96), spacing: MHBTheme.Spacing.s2)],
                    alignment: .leading,
                    spacing: MHBTheme.Spacing.s2
                ) {
                    ForEach(pets) { pet in
                        HomeQuickFactSelectableChip(
                            isSelected: selectedPetID == pet.id,
                            action: {
                                selectedPetID = pet.id
                            }
                        ) {
                            Text(pet.name ?? "未命名")
                                .font(MHBTheme.Typography.callout.weight(.semibold))
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
    }
}

// HomeQuickFactSheetSection 快捷事实弹层分组
// 核心职责：
// - 统一 sheet 内标题和内容间距
// - 提供轻量表单分组结构
private struct HomeQuickFactSheetSection<Content: View>: View {
    let title: LocalizedStringResource
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            Text(title)
                .font(MHBTheme.Typography.section)
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                .textCase(.uppercase)

            content()
        }
    }
}

// HomeQuickFactSingleChoiceSection 快捷事实单选分组
// 核心职责：
// - 承载 sheet 内单选标签集合
// - 以清晰选中态表达当前输入
private struct HomeQuickFactSingleChoiceSection<Option: Identifiable & Equatable, Label: View>: View {
    let title: LocalizedStringResource
    let options: [Option]
    @Binding var selection: Option
    @ViewBuilder let label: (Option) -> Label

    var body: some View {
        HomeQuickFactSheetSection(title: title) {
            HomeQuickFactChoiceGrid(options: options) { option in
                HomeQuickFactSelectableChip(
                    isSelected: selection == option,
                    action: {
                        selection = option
                    }
                ) {
                    label(option)
                }
            }
        }
    }
}

// HomeQuickFactMultiChoiceSection 快捷事实多选分组
// 核心职责：
// - 承载 sheet 内多选标签集合
// - 支持症状等可并发事实输入
private struct HomeQuickFactMultiChoiceSection<Option: Identifiable & Hashable, Label: View>: View {
    let title: LocalizedStringResource
    let options: [Option]
    @Binding var selection: Set<Option>
    @ViewBuilder let label: (Option) -> Label

    var body: some View {
        HomeQuickFactSheetSection(title: title) {
            HomeQuickFactChoiceGrid(options: options) { option in
                HomeQuickFactSelectableChip(
                    isSelected: selection.contains(option),
                    action: {
                        if selection.contains(option) {
                            selection.remove(option)
                        } else {
                            selection.insert(option)
                        }
                    }
                ) {
                    label(option)
                }
            }
        }
    }
}

// HomeQuickFactChoiceGrid 快捷事实选项网格
// 核心职责：
// - 统一 sheet 内标签网格布局
// - 让不同选项类型复用稳定尺寸
private struct HomeQuickFactChoiceGrid<Option: Identifiable, Content: View>: View {
    let options: [Option]
    @ViewBuilder let content: (Option) -> Content

    private let columns = [
        GridItem(.adaptive(minimum: 92), spacing: MHBTheme.Spacing.s2, alignment: .leading)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: MHBTheme.Spacing.s2) {
            ForEach(options) { option in
                content(option)
            }
        }
    }
}

// HomeQuickFactSelectableChip 快捷事实可选标签
// 核心职责：
// - 统一 sheet 内单选和多选按钮视觉
// - 提供稳定的选中态与命中区域
private struct HomeQuickFactSelectableChip<Content: View>: View {
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        Button(action: action) {
            HStack(spacing: MHBTheme.Spacing.s2) {
                content()
            }
            .foregroundStyle(isSelected ? MHBTheme.ColorToken.primary.color : MHBTheme.ColorToken.labelSecondary.color)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, MHBTheme.Spacing.s3)
            .background(isSelected ? MHBTheme.ColorToken.primaryBackgroundSoft.color : MHBTheme.ColorToken.cardSolid.color)
            .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous)
                    .stroke(isSelected ? MHBTheme.ColorToken.primary.color : MHBTheme.ColorToken.separator.color, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

// HomeQuickFactOptionLabel 快捷事实图标标签
// 核心职责：
// - 统一选项内 SF Symbol 与文字组合
// - 保持 sheet 选项扫描效率
private struct HomeQuickFactOptionLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(MHBTheme.Typography.callout.weight(.semibold))
            .lineLimit(1)
    }
}

// HomeQuickFactSelectedPetCard 当前宠物展示卡片
// 核心职责：
// - 在无需切换宠物时展示事实归属
// - 避免单宠场景增加额外选择负担
private struct HomeQuickFactSelectedPetCard: View {
    let name: String

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s3) {
            Image(systemName: "pawprint.circle.fill")
                .font(.system(size: MHBTheme.IconSize.medium, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.primary.color)

            Text(name)
                .font(MHBTheme.Typography.callout.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            Spacer()
        }
        .padding(MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous)
                .stroke(MHBTheme.ColorToken.separator.color, lineWidth: 1)
        }
    }
}

// HomeQuickFactNoteSection 快捷事实备注区
// 核心职责：
// - 承载可选补充描述
// - 保持输入区域尺寸稳定
private struct HomeQuickFactNoteSection: View {
    let title: LocalizedStringResource
    let prompt: LocalizedStringResource
    @Binding var note: String

    var body: some View {
        HomeQuickFactSheetSection(title: title) {
            TextField(title, text: $note, prompt: Text(prompt), axis: .vertical)
                .lineLimit(3...5)
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .padding(MHBTheme.Spacing.s3)
                .background(MHBTheme.ColorToken.cardSolid.color)
                .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous)
                        .stroke(MHBTheme.ColorToken.separator.color, lineWidth: 1)
                }
        }
    }
}

// HomeQuickFactPhotoPlaceholderSection 异常照片占位区
// 核心职责：
// - 表达异常记录未来可附加照片的入口位置
// - 在媒体上传接入前保持禁用状态
private struct HomeQuickFactPhotoPlaceholderSection: View {
    var body: some View {
        HomeQuickFactSheetSection(title: "照片") {
            Button(action: {}) {
                HStack(spacing: MHBTheme.Spacing.s3) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: MHBTheme.IconSize.medium, weight: .semibold))
                    Text("添加照片")
                        .font(MHBTheme.Typography.callout.weight(.semibold))
                    Spacer()
                    Text("稍后接入")
                        .font(MHBTheme.Typography.caption)
                        .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                }
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .padding(MHBTheme.Spacing.s4)
                .background(MHBTheme.ColorToken.cardSolid.color)
                .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous)
                        .stroke(MHBTheme.ColorToken.separator.color, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                }
            }
            .buttonStyle(.plain)
            .disabled(true)
        }
    }
}
