import SwiftUI
import MaohuobanDesignSystem

// PetProfileAddScreen 添加宠物档案页
// 核心职责：
// - 使用编辑档案同源的 row section 样式收集新宠物资料
// - 隐藏平台生成的宠物档案号，提交后由后端生成
struct PetProfileAddScreen: View {
    let currentUserID: String?
    let onCreated: () -> Void

    @State private var store = PetWriteStore()
    @State private var name = ""
    @State private var species = PetSpecies.dog
    @State private var chipNumber = ""
    @State private var sex = PetSex.unknown
    @State private var birthDate = Date.now
    @State private var arrivalDate = Date.now
    @State private var weight = ""
    @State private var neuterStatus = "未绝育"
    @State private var personalityTags: [String] = []
    @State private var note = ""
    @State private var nameEditorDraft = ""
    @State private var isNameEditorPresented = false
    @State private var isNameEditorChevronExpanded = false
    @State private var chipEditorDraft = ""
    @State private var isChipEditorPresented = false
    @State private var isChipEditorChevronExpanded = false
    @State private var birthDateEditorDraft = Date.now
    @State private var isBirthDateEditorPresented = false
    @State private var isBirthDateEditorChevronExpanded = false
    @State private var arrivalDateEditorDraft = Date.now
    @State private var isArrivalDateEditorPresented = false
    @State private var isArrivalDateEditorChevronExpanded = false
    @State private var weightEditorDraft = ""
    @State private var isWeightEditorPresented = false
    @State private var isWeightEditorChevronExpanded = false
    @State private var tagsEditorDraft: [String] = []
    @State private var isTagsEditorPresented = false
    @State private var isTagsEditorChevronExpanded = false
    @State private var noteEditorDraft = ""
    @State private var isNoteEditorPresented = false
    @State private var isNoteEditorChevronExpanded = false
    @State private var isSpeciesMenuPresented = false
    @State private var speciesRowFrame = CGRect.zero
    @State private var isSexMenuPresented = false
    @State private var sexRowFrame = CGRect.zero
    @State private var isNeuterStatusMenuPresented = false
    @State private var neuterStatusRowFrame = CGRect.zero

    private var canSave: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
    }

    private var isAnyMenuPresented: Bool {
        isSpeciesMenuPresented || isSexMenuPresented || isNeuterStatusMenuPresented
    }

    private var suggestedPersonalityTags: [String] {
        ["亲人", "爱撒娇", "安静", "好奇", "活跃", "胆小", "黏人", "独立", "贪吃", "爱玩", "夜间活动多", "怕生"]
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                MHBScreenScrollView {
                    VStack(spacing: MHBTheme.Spacing.s6) {
                        PetProfileAddAvatarHeader(species: species)

                        PetWriteStatusSection(
                            phase: store.phase,
                            successMessage: store.successMessage
                        )

                        VStack(spacing: MHBTheme.Spacing.s4) {
                            PetProfileAddSection {
                                PetProfileAddRow(
                                    title: "宠物名字",
                                    isAccessoryExpanded: isNameEditorChevronExpanded,
                                    action: showNameEditor
                                ) {
                                    PetProfileAddValueText(value: name.isEmpty ? "未添加" : name)
                                }

                                PetProfileAddRow(
                                    title: "宠物类型",
                                    isAccessoryExpanded: isSpeciesMenuPresented,
                                    action: toggleSpeciesMenu
                                ) {
                                    PetProfileAddValueText(value: speciesDisplayText)
                                }
                                .petProfileAddRowFrame(.species)

                                PetProfileAddRow(
                                    title: "芯片号",
                                    isAccessoryExpanded: isChipEditorChevronExpanded,
                                    action: showChipEditor
                                ) {
                                    PetProfileAddValueText(value: chipNumber.isEmpty ? "未添加" : chipNumber)
                                }

                                PetProfileAddRow(title: "背景", showsSeparator: false) {
                                    PetProfileAddValueText(value: "未设置")
                                }
                            }

                            PetProfileAddSection {
                                PetProfileAddRow(
                                    title: "性别",
                                    isAccessoryExpanded: isSexMenuPresented,
                                    action: toggleSexMenu
                                ) {
                                    PetProfileAddValueText(value: sexDisplayText)
                                }
                                .petProfileAddRowFrame(.sex)

                                PetProfileAddRow(
                                    title: "出生日期",
                                    isAccessoryExpanded: isBirthDateEditorChevronExpanded,
                                    action: showBirthDateEditor
                                ) {
                                    PetProfileAddValueText(value: formattedDate(birthDate))
                                }

                                PetProfileAddRow(
                                    title: "到家时间",
                                    isAccessoryExpanded: isArrivalDateEditorChevronExpanded,
                                    action: showArrivalDateEditor
                                ) {
                                    PetProfileAddValueText(value: formattedDate(arrivalDate))
                                }

                                PetProfileAddRow(
                                    title: "体重",
                                    isAccessoryExpanded: isWeightEditorChevronExpanded,
                                    action: showWeightEditor
                                ) {
                                    PetProfileAddValueText(value: displayWeightText)
                                }

                                PetProfileAddRow(
                                    title: "绝育状态",
                                    showsSeparator: false,
                                    isAccessoryExpanded: isNeuterStatusMenuPresented,
                                    action: toggleNeuterStatusMenu
                                ) {
                                    PetProfileAddValueText(value: neuterStatus)
                                }
                                .petProfileAddRowFrame(.neuterStatus)
                            }

                            PetProfileAddSection {
                                PetProfileAddRow(
                                    title: "性格标签",
                                    isAccessoryExpanded: isTagsEditorChevronExpanded,
                                    action: showTagsEditor
                                ) {
                                    PetProfileAddTagFlow(tags: personalityTags)
                                }

                                PetProfileAddRow(
                                    title: "备注",
                                    showsSeparator: false,
                                    isAccessoryExpanded: isNoteEditorChevronExpanded,
                                    action: showNoteEditor
                                ) {
                                    PetProfileAddValueText(value: note.isEmpty ? "暂无" : note)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, MHBTheme.Spacing.s4)
                    .padding(.top, MHBTheme.Spacing.s6)
                    .padding(.bottom, MHBTheme.Spacing.s8)
                }
                .coordinateSpace(name: PetProfileAddCoordinateSpace.name)
                .onPreferenceChange(PetProfileAddRowFramePreferenceKey.self) { frames in
                    speciesRowFrame = frames[.species] ?? .zero
                    sexRowFrame = frames[.sex] ?? .zero
                    neuterStatusRowFrame = frames[.neuterStatus] ?? .zero
                }

                if isAnyMenuPresented {
                    MHBOutsideTapDismissLayer(onDismiss: dismissSelectionMenus)
                        .zIndex(1)
                }

                PetProfileAddSelectionMenuOverlay(
                    isPresented: isSpeciesMenuPresented,
                    containerWidth: proxy.size.width,
                    rowFrame: speciesRowFrame,
                    selectedValue: speciesDisplayText,
                    options: ["狗狗", "猫咪", "其他"],
                    onSelect: updateSpecies
                )
                .zIndex(2)

                PetProfileAddSelectionMenuOverlay(
                    isPresented: isSexMenuPresented,
                    containerWidth: proxy.size.width,
                    rowFrame: sexRowFrame,
                    selectedValue: sexDisplayText,
                    options: ["公", "母", "未知"],
                    onSelect: updateSex
                )
                .zIndex(2)

                PetProfileAddSelectionMenuOverlay(
                    isPresented: isNeuterStatusMenuPresented,
                    containerWidth: proxy.size.width,
                    rowFrame: neuterStatusRowFrame,
                    selectedValue: neuterStatus,
                    options: ["已绝育", "未绝育"],
                    onSelect: updateNeuterStatus
                )
                .zIndex(2)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("添加宠物")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("保存") {
                    Task { await submit() }
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.primary.color.opacity(canSave ? 1 : 0.35))
                .disabled(!canSave || store.isSubmitting)
            }
        }
        .sheet(
            isPresented: $isNameEditorPresented,
            onDismiss: {
                isNameEditorChevronExpanded = false
            }
        ) {
            PetProfileNameEditorSheet(
                name: $nameEditorDraft,
                onWillDismiss: {
                    isNameEditorChevronExpanded = false
                },
                onSave: {
                    name = nameEditorDraft
                    isNameEditorChevronExpanded = false
                    isNameEditorPresented = false
                }
            )
        }
        .sheet(
            isPresented: $isChipEditorPresented,
            onDismiss: {
                isChipEditorChevronExpanded = false
            }
        ) {
            PetProfileChipEditorSheet(
                chipNumber: $chipEditorDraft,
                existingChipNumber: "",
                onWillDismiss: {
                    isChipEditorChevronExpanded = false
                },
                onSave: {
                    chipNumber = chipEditorDraft
                    isChipEditorChevronExpanded = false
                    isChipEditorPresented = false
                }
            )
        }
        .sheet(
            isPresented: $isBirthDateEditorPresented,
            onDismiss: {
                isBirthDateEditorChevronExpanded = false
            }
        ) {
            PetProfileDateEditorSheet(
                title: "出生日期",
                date: $birthDateEditorDraft,
                onWillDismiss: {
                    isBirthDateEditorChevronExpanded = false
                },
                onSave: {
                    birthDate = birthDateEditorDraft
                    isBirthDateEditorChevronExpanded = false
                    isBirthDateEditorPresented = false
                }
            )
        }
        .sheet(
            isPresented: $isArrivalDateEditorPresented,
            onDismiss: {
                isArrivalDateEditorChevronExpanded = false
            }
        ) {
            PetProfileDateEditorSheet(
                title: "到家时间",
                date: $arrivalDateEditorDraft,
                onWillDismiss: {
                    isArrivalDateEditorChevronExpanded = false
                },
                onSave: {
                    arrivalDate = arrivalDateEditorDraft
                    isArrivalDateEditorChevronExpanded = false
                    isArrivalDateEditorPresented = false
                }
            )
        }
        .sheet(
            isPresented: $isWeightEditorPresented,
            onDismiss: {
                isWeightEditorChevronExpanded = false
            }
        ) {
            PetProfileWeightEditorSheet(
                weight: $weightEditorDraft,
                onWillDismiss: {
                    isWeightEditorChevronExpanded = false
                },
                onSave: {
                    weight = weightEditorDraft
                    isWeightEditorChevronExpanded = false
                    isWeightEditorPresented = false
                }
            )
        }
        .sheet(
            isPresented: $isTagsEditorPresented,
            onDismiss: {
                isTagsEditorChevronExpanded = false
            }
        ) {
            PetProfileTagsEditorSheet(
                tags: $tagsEditorDraft,
                suggestions: suggestedPersonalityTags,
                onWillDismiss: {
                    isTagsEditorChevronExpanded = false
                },
                onSave: {
                    personalityTags = tagsEditorDraft
                    isTagsEditorChevronExpanded = false
                    isTagsEditorPresented = false
                }
            )
        }
        .sheet(
            isPresented: $isNoteEditorPresented,
            onDismiss: {
                isNoteEditorChevronExpanded = false
            }
        ) {
            PetProfileNoteEditorSheet(
                note: $noteEditorDraft,
                onWillDismiss: {
                    isNoteEditorChevronExpanded = false
                },
                onSave: {
                    note = noteEditorDraft
                    isNoteEditorChevronExpanded = false
                    isNoteEditorPresented = false
                }
            )
        }
        .accessibilityIdentifier("pet.profileAdd.screen")
    }

    private var speciesDisplayText: String {
        switch species {
        case .dog: "狗狗"
        case .cat: "猫咪"
        case .other: "其他"
        }
    }

    private var sexDisplayText: String {
        switch sex {
        case .male: "公"
        case .female: "母"
        case .unknown: "未知"
        }
    }

    private var displayWeightText: String {
        let trimmedWeight = weight.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedWeight.isEmpty ? "暂未记录" : "\(trimmedWeight) kg"
    }

    private func showNameEditor() {
        dismissSelectionMenus()
        nameEditorDraft = name
        isNameEditorChevronExpanded = true
        isNameEditorPresented = true
    }

    private func showChipEditor() {
        dismissSelectionMenus()
        chipEditorDraft = chipNumber
        isChipEditorChevronExpanded = true
        isChipEditorPresented = true
    }

    private func showBirthDateEditor() {
        dismissSelectionMenus()
        birthDateEditorDraft = birthDate
        isBirthDateEditorChevronExpanded = true
        isBirthDateEditorPresented = true
    }

    private func showArrivalDateEditor() {
        dismissSelectionMenus()
        arrivalDateEditorDraft = arrivalDate
        isArrivalDateEditorChevronExpanded = true
        isArrivalDateEditorPresented = true
    }

    private func showWeightEditor() {
        dismissSelectionMenus()
        weightEditorDraft = weight
        isWeightEditorChevronExpanded = true
        isWeightEditorPresented = true
    }

    private func showTagsEditor() {
        dismissSelectionMenus()
        tagsEditorDraft = personalityTags
        isTagsEditorChevronExpanded = true
        isTagsEditorPresented = true
    }

    private func showNoteEditor() {
        dismissSelectionMenus()
        noteEditorDraft = note
        isNoteEditorChevronExpanded = true
        isNoteEditorPresented = true
    }

    private func toggleSpeciesMenu() {
        let shouldOpen = !isSpeciesMenuPresented
        dismissSelectionMenus()
        isSpeciesMenuPresented = shouldOpen
    }

    private func toggleSexMenu() {
        let shouldOpen = !isSexMenuPresented
        dismissSelectionMenus()
        isSexMenuPresented = shouldOpen
    }

    private func toggleNeuterStatusMenu() {
        let shouldOpen = !isNeuterStatusMenuPresented
        dismissSelectionMenus()
        isNeuterStatusMenuPresented = shouldOpen
    }

    private func dismissSelectionMenus() {
        isSpeciesMenuPresented = false
        isSexMenuPresented = false
        isNeuterStatusMenuPresented = false
    }

    private func updateSpecies(_ value: String) {
        species = switch value {
        case "猫咪": .cat
        case "其他": .other
        default: .dog
        }
        isSpeciesMenuPresented = false
    }

    private func updateSex(_ value: String) {
        sex = switch value {
        case "公": .male
        case "母": .female
        default: .unknown
        }
        isSexMenuPresented = false
    }

    private func updateNeuterStatus(_ value: String) {
        neuterStatus = value
        isNeuterStatusMenuPresented = false
    }

    private func formattedDate(_ date: Date) -> String {
        date.formatted(
            .iso8601
                .year()
                .month()
                .day()
                .dateSeparator(.dash)
        )
    }

    private func submit() async {
        await store.createPet(
            draft: PetProfileDraft(
                name: name,
                species: species,
                breed: "",
                sex: sex,
                birthday: PetWriteFormatters.birthdayString(from: birthDate)
            ),
            currentUserID: currentUserID
        )

        if case .createdPet = store.phase {
            onCreated()
        }
    }
}

private enum PetProfileAddCoordinateSpace {
    static let name = "PetProfileAddScreen"
}

private enum PetProfileAddRowAnchor: Hashable {
    case species
    case sex
    case neuterStatus
}

private struct PetProfileAddRowFramePreferenceKey: PreferenceKey {
    static var defaultValue: [PetProfileAddRowAnchor: CGRect] = [:]

    static func reduce(
        value: inout [PetProfileAddRowAnchor: CGRect],
        nextValue: () -> [PetProfileAddRowAnchor: CGRect]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, newValue in newValue })
    }
}

private extension View {
    func petProfileAddRowFrame(_ anchor: PetProfileAddRowAnchor) -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: PetProfileAddRowFramePreferenceKey.self,
                    value: [anchor: proxy.frame(in: .named(PetProfileAddCoordinateSpace.name))]
                )
            }
        }
    }
}

// PetProfileAddAvatarHeader 添加宠物头像入口
// 核心职责：
// - 展示添加页顶部头像占位
// - 为后续接入头像上传保留入口
private struct PetProfileAddAvatarHeader: View {
    let species: PetSpecies

    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s2) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(MHBTheme.ColorToken.primaryBackground.color)
                    .frame(width: 88, height: 88)
                    .overlay {
                        Image(systemName: speciesSystemImage)
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(MHBTheme.ColorToken.primary.color)
                    }

                Image(systemName: "camera.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Color.black.opacity(0.78))
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(Color(uiColor: .systemGroupedBackground), lineWidth: 2)
                    }
            }

            Text("添加头像")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, MHBTheme.Spacing.s2)
    }

    private var speciesSystemImage: String {
        switch species {
        case .dog: "dog.fill"
        case .cat: "cat.fill"
        case .other: "pawprint.fill"
        }
    }
}

// PetProfileAddSection 添加宠物资料分组
// 核心职责：
// - 承载添加档案页面的一组 row
// - 复刻编辑档案页的卡片分组样式
private struct PetProfileAddSection<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
    }
}

// PetProfileAddRow 添加宠物资料通用行
// 核心职责：
// - 展示字段名、字段值和进入提示
// - 保持添加页与编辑页 row 高度一致
private struct PetProfileAddRow<Value: View>: View {
    let title: String
    let showsSeparator: Bool
    let isAccessoryExpanded: Bool
    let action: () -> Void
    @ViewBuilder let value: () -> Value

    init(
        title: String,
        showsSeparator: Bool = true,
        isAccessoryExpanded: Bool = false,
        action: @escaping () -> Void = {},
        @ViewBuilder value: @escaping () -> Value
    ) {
        self.title = title
        self.showsSeparator = showsSeparator
        self.isAccessoryExpanded = isAccessoryExpanded
        self.action = action
        self.value = value
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                HStack(spacing: MHBTheme.Spacing.s2) {
                    Text(title)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

                    Spacer(minLength: MHBTheme.Spacing.s3)

                    value()
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    MHBAnimatedDisclosureChevron(isExpanded: isAccessoryExpanded)
                }
                .padding(.horizontal, MHBTheme.Spacing.s4)
                .frame(minHeight: 52)
                .contentShape(Rectangle())

                if showsSeparator {
                    Rectangle()
                        .fill(MHBTheme.ColorToken.separatorSoft.color)
                        .frame(height: 0.5)
                        .padding(.horizontal, MHBTheme.Spacing.s4)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// PetProfileAddValueText 添加宠物资料行值文本
// 核心职责：
// - 统一添加页 row 右侧文本样式
// - 对占位内容应用弱化颜色
private struct PetProfileAddValueText: View {
    let value: String

    var body: some View {
        let isPlaceholder = value.isEmpty || value == "未添加" || value == "未设置" || value == "暂无" || value == "暂未记录"
        Text(value)
            .font(.system(size: 16, weight: .regular))
            .foregroundStyle(isPlaceholder ? MHBTheme.ColorToken.labelTertiary.color : MHBTheme.ColorToken.labelPrimary.color)
            .lineLimit(1)
            .truncationMode(.tail)
    }
}

// PetProfileAddTagFlow 添加宠物性格标签展示
// 核心职责：
// - 在资料 row 中展示已选性格标签
// - 复用设计系统标签组件保持视觉一致
private struct PetProfileAddTagFlow: View {
    let tags: [String]

    var body: some View {
        if tags.isEmpty {
            PetProfileAddValueText(value: "暂未设置")
        } else {
            HStack(spacing: MHBTheme.Spacing.s1) {
                ForEach(tags.prefix(3), id: \.self) { tag in
                    MHBTagView(tag, style: .neutral, size: .small)
                }
            }
        }
    }
}

// PetProfileAddSelectionMenuOverlay 添加宠物锚点选择菜单浮层
// 核心职责：
// - 将选择菜单定位在触发 row 附近
// - 使用统一锚点浮动面板承载展开转场
private struct PetProfileAddSelectionMenuOverlay: View {
    let isPresented: Bool
    let containerWidth: CGFloat
    let rowFrame: CGRect
    let selectedValue: String
    let options: [String]
    let onSelect: (String) -> Void

    private let menuWidth: CGFloat = 168

    private var offset: CGSize {
        let horizontalMargin = MHBTheme.Spacing.s4
        let x = min(
            max(rowFrame.maxX - menuWidth, horizontalMargin),
            max(horizontalMargin, containerWidth - menuWidth - horizontalMargin)
        )
        let y = rowFrame.maxY + MHBTheme.Spacing.s1

        return CGSize(width: x, height: y)
    }

    var body: some View {
        MHBAnchoredFloatingPanel(
            isPresented: isPresented && rowFrame != .zero,
            offset: offset,
            scaleAnchor: .topTrailing
        ) {
            PetProfileAddSelectionMenu(
                selectedValue: selectedValue,
                options: options,
                onSelect: onSelect
            )
        }
        .animation(.snappy(duration: 0.22), value: isPresented)
    }
}

// PetProfileAddSelectionMenu 添加宠物字段选择菜单
// 核心职责：
// - 展示字段可选项
// - 使用勾选图标表达当前值
private struct PetProfileAddSelectionMenu: View {
    let selectedValue: String
    let options: [String]
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
            ForEach(options, id: \.self) { option in
                Button {
                    onSelect(option)
                } label: {
                    PetProfileAddSelectionMenuRow(
                        title: option,
                        isSelected: option == selectedValue
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(MHBTheme.Spacing.s2)
        .frame(width: 168)
        .glassEffect(.regular, in: .rect(cornerRadius: MHBTheme.Radius.large))
        .accessibilityElement(children: .contain)
    }
}

// PetProfileAddSelectionMenuRow 添加宠物选择菜单行
// 核心职责：
// - 展示单个选择项标题
// - 为选中项显示主题化勾选标识
private struct PetProfileAddSelectionMenuRow: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s2) {
            Text(title)
                .font(MHBTheme.Typography.footnote)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .lineLimit(1)

            Spacer(minLength: MHBTheme.Spacing.s3)

            Image(systemName: "checkmark")
                .font(.system(size: MHBTheme.IconSize.small, weight: .bold))
                .foregroundStyle(MHBTheme.ColorToken.primary.color.opacity(isSelected ? 1 : 0))
        }
        .padding(.horizontal, MHBTheme.Spacing.s2)
        .padding(.vertical, MHBTheme.Spacing.s2)
        .contentShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
    }
}
