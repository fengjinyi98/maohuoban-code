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
    @State private var selectedFoodKind: HomeQuickFactFeedingFoodKind = .mainFood
    @State private var expandedFoodKind: HomeQuickFactFeedingFoodKind?
    @State private var selectedFoodItemIDs: [HomeQuickFactFeedingFoodKind: String?] = [:]
    @State private var amount: HomeQuickFactFeedingAmount = .normal
    @State private var occurredAt = Date()
    @State private var note = ""
    @State private var photoAssetNames: [String] = []

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
        self._selectedFoodItemIDs = State(initialValue: [
            .mainFood: HomeQuickFactFeedingFoodSource.defaultItemID(for: .mainFood)
        ])
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
                            HomeQuickFactFeedingFoodSection(
                                selectedKind: $selectedFoodKind,
                                expandedKind: $expandedFoodKind,
                                selectedItemIDs: $selectedFoodItemIDs
                            )

                            HomeQuickFactSingleChoiceSection(
                                title: "份量",
                                options: HomeQuickFactFeedingAmount.allCases,
                                selection: $amount
                            ) { option in
                                Text(option.title)
                                    .font(MHBTheme.Typography.callout.weight(.semibold))
                            }

                            HomeQuickFactDateSection(
                                title: "时间",
                                date: $occurredAt
                            )

                            HomeQuickFactNoteSection(
                                title: "备注",
                                prompt: "例如 换了新粮、加了罐头",
                                note: $note
                            )

                            HomeQuickFactOptionalPhotoSection(
                                title: "照片（可选）",
                                photoAssetNames: $photoAssetNames
                            )
                        }
                        .padding(.horizontal, MHBTheme.Spacing.s5)
                        .padding(.top, topContentPadding)
                        .padding(.bottom, MHBTheme.Spacing.s8 + MHBTheme.Spacing.s8 + MHBTheme.Spacing.s6)
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)

                    MHBBottomFloatingActionCTA(
                        title: isSubmitting ? "保存中" : "保存记录",
                        systemImage: "checkmark",
                        bottomInset: bottomInset,
                        action: submit
                    )
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
                    .zIndex(2)

                    HomeQuickFactFeedingTopChrome(
                        selectedItem: selectedSwitcherItem,
                        items: petSwitcherItems,
                        isDisabled: petSwitcherItems.isEmpty,
                        onSelectPet: { petID in
                            selectedPetID = petID
                        }
                    )
                    .padding(.horizontal, MHBTheme.Spacing.s4)
                    .padding(.top, MHBTheme.Spacing.s4)
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
                lifeStatus: context.selectedPetLifeStatus,
                isSelected: true
            )
        ]
    }

    private var selectedSwitcherItem: MHBPetSwitcherItem? {
        let selectedPet = pets.first { $0.id == selectedPetID } ?? pets.first
        return selectedPet.map { pet in
            MHBPetSwitcherItem(recordSwitchPet: pet, isSelected: true)
        }
    }

    private var petSwitcherItems: [MHBPetSwitcherItem] {
        pets.map { pet in
            MHBPetSwitcherItem(recordSwitchPet: pet, isSelected: pet.id == selectedPetID)
        }
    }

    private func submit() {
        guard !isSubmitting, selectedPetID != nil else { return }
        onSubmit(
            HomeQuickFactFeedingInput(
                petID: selectedPetID,
                lifeStatus: pets.first(where: { $0.id == selectedPetID })?.lifeStatus,
                foodKind: selectedFoodKind,
                foodName: HomeQuickFactFeedingFoodSource.itemName(
                    for: selectedFoodItemID(for: selectedFoodKind),
                    in: selectedFoodKind
                ),
                amount: amount,
                occurredAt: occurredAt,
                note: note,
                photoAssetNames: photoAssetNames
            )
        )
    }

    private func selectedFoodItemID(for kind: HomeQuickFactFeedingFoodKind) -> String? {
        selectedFoodItemIDs[kind] ?? HomeQuickFactFeedingFoodSource.defaultItemID(for: kind)
    }

    private var topContentPadding: CGFloat {
        MHBTheme.Spacing.s8 + MHBTheme.Spacing.s5
    }
}

// HomeQuickFactFeedingTopChrome 喂食弹层顶部控件
// 核心职责：
// - 在弹层顶部展示喂食标题
// - 将宠物切换固定在右上角而不是进入内容流
private struct HomeQuickFactFeedingTopChrome: View {
    let selectedItem: MHBPetSwitcherItem?
    let items: [MHBPetSwitcherItem]
    let isDisabled: Bool
    let onSelectPet: (String) -> Void

    var body: some View {
        ZStack {
            Text("喂食")
                .font(MHBTheme.Typography.headline.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .frame(maxWidth: .infinity)

            HStack {
                Spacer()

                HomeQuickFactPetSwitcherMenu(
                    selectedItem: selectedItem,
                    items: items,
                    isDisabled: isDisabled,
                    onSelectPet: onSelectPet
                )
            }
        }
        .frame(height: 48)
    }
}

// HomeQuickFactPetSwitcherMenu 快捷事实宠物切换菜单
// 核心职责：
// - 复用通用宠物头像胶囊展示当前宠物
// - 在多宠场景使用系统 Menu 完成宠物切换
private struct HomeQuickFactPetSwitcherMenu: View {
    let selectedItem: MHBPetSwitcherItem?
    let items: [MHBPetSwitcherItem]
    let isDisabled: Bool
    let onSelectPet: (String) -> Void

    var body: some View {
        if isDisabled {
            MHBPetSwitcherCapsule(item: selectedItem)
                .accessibilityIdentifier("home.quickFact.petSwitcherButton")
        } else {
            Menu {
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
            } label: {
                MHBPetSwitcherCapsule(item: selectedItem)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.quickFact.petSwitcherButton")
        }
    }
}

// HomeQuickFactFeedingFoodSection 喂食品类选择区
// 核心职责：
// - 以互斥展开方式组织喂食分类
// - 展示当前分类下的储物柜物品并支持切换
private struct HomeQuickFactFeedingFoodSection: View {
    @Binding var selectedKind: HomeQuickFactFeedingFoodKind
    @Binding var expandedKind: HomeQuickFactFeedingFoodKind?
    @Binding var selectedItemIDs: [HomeQuickFactFeedingFoodKind: String?]

    var body: some View {
        HomeQuickFactSheetSection(title: "喂了什么") {
            VStack(spacing: MHBTheme.Spacing.s3) {
                ForEach(HomeQuickFactFeedingFoodKind.allCases) { kind in
                    VStack(spacing: MHBTheme.Spacing.s2) {
                        HomeQuickFactFeedingCategoryRow(
                            kind: kind,
                            selectedItemName: selectedItemName(for: kind),
                            isExpanded: expandedKind == kind,
                            action: {
                                expand(kind)
                            }
                        )

                        if expandedKind == kind {
                            HomeQuickFactFeedingPantryList(
                                kind: kind,
                                selectedItemID: selectedItemID(for: kind),
                                onSelectItem: { item in
                                    setSelectedItemID(item.id, for: kind)
                                }
                            )
                            .transition(
                                .opacity.combined(with: .scale(scale: 0.98, anchor: .top))
                            )
                            .clipped()
                        }
                    }
                    .animation(.snappy(duration: 0.24), value: expandedKind)
                    .animation(.snappy(duration: 0.18), value: selectedItemID(for: kind))
                }
            }
        }
    }

    private func expand(_ kind: HomeQuickFactFeedingFoodKind) {
        let previousExpanded = expandedKind
        let nextExpanded = expandedKind == kind ? nil : kind
        selectedKind = kind
        if selectedItemID(for: kind) == nil {
            setSelectedItemID(HomeQuickFactFeedingFoodSource.defaultItemID(for: kind), for: kind)
        }

        if let previousExpanded, previousExpanded != kind {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                expandedKind = nil
            }
            DispatchQueue.main.async {
                withAnimation(.snappy(duration: 0.24)) {
                    expandedKind = kind
                }
            }
            return
        }

        withAnimation(.snappy(duration: 0.24)) {
            expandedKind = nextExpanded
        }
    }

    private func selectedItemName(for kind: HomeQuickFactFeedingFoodKind) -> String {
        HomeQuickFactFeedingFoodSource.itemName(for: selectedItemID(for: kind), in: kind)
            ?? HomeQuickFactFeedingFoodSource.defaultItemName(for: kind)
            ?? kind.emptySelectionTitle
    }

    private func selectedItemID(for kind: HomeQuickFactFeedingFoodKind) -> String? {
        selectedItemIDs[kind] ?? HomeQuickFactFeedingFoodSource.defaultItemID(for: kind)
    }

    private func setSelectedItemID(_ itemID: String?, for kind: HomeQuickFactFeedingFoodKind) {
        selectedKind = kind
        selectedItemIDs[kind] = itemID
    }
}

// HomeQuickFactFeedingCategoryRow 喂食分类展开行
// 核心职责：
// - 展示喂食分类和当前选中物品
// - 承载互斥展开入口
private struct HomeQuickFactFeedingCategoryRow: View {
    let kind: HomeQuickFactFeedingFoodKind
    let selectedItemName: String
    let isExpanded: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: MHBTheme.Spacing.s3) {
                Image(systemName: kind.systemImage)
                    .font(.system(size: MHBTheme.IconSize.medium, weight: .semibold))
                    .foregroundStyle(isExpanded ? MHBTheme.ColorToken.primary.color : MHBTheme.ColorToken.labelSecondary.color)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                    Text(kind.title)
                        .font(MHBTheme.Typography.callout.weight(.bold))
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                        .lineLimit(1)

                    Text(selectedItemName)
                        .font(MHBTheme.Typography.caption)
                        .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                        .lineLimit(1)
                }

                Spacer(minLength: MHBTheme.Spacing.s2)

                MHBAnimatedDisclosureChevron(
                    isExpanded: isExpanded,
                    size: 12,
                    weight: .bold,
                    color: MHBTheme.ColorToken.labelTertiary.color,
                    systemImage: "chevron.down",
                    expandedRotation: 180
                )
            }
            .padding(MHBTheme.Spacing.s4)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(isExpanded ? MHBTheme.ColorToken.primaryBackgroundSoft.color : MHBTheme.ColorToken.cardSolid.color)
            .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous)
                    .stroke(isExpanded ? MHBTheme.ColorToken.primary.color : MHBTheme.ColorToken.separator.color, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

// HomeQuickFactFeedingPantryList 喂食储物柜物品列表
// 核心职责：
// - 展示当前展开分类下的储物柜物品
// - 让用户在同一分类内切换具体喂食内容
private struct HomeQuickFactFeedingPantryList: View {
    let kind: HomeQuickFactFeedingFoodKind
    let selectedItemID: String?
    let onSelectItem: (PantryItem) -> Void

    private var items: [PantryItem] {
        HomeQuickFactFeedingFoodSource.items(for: kind)
    }

    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s2) {
            if items.isEmpty {
                HomeQuickFactFeedingManualItemRow(kind: kind)
            } else {
                ForEach(items) { item in
                    HomeQuickFactFeedingPantryItemRow(
                        item: item,
                        isSelected: selectedItemID == item.id,
                        action: {
                            onSelectItem(item)
                        }
                    )
                }
            }
        }
        .padding(.leading, MHBTheme.Spacing.s4)
    }
}

// HomeQuickFactFeedingPantryItemRow 喂食储物柜物品行
// 核心职责：
// - 展示储物柜物品名称、品牌和状态
// - 提供具体喂食物品选中态
private struct HomeQuickFactFeedingPantryItemRow: View {
    let item: PantryItem
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: MHBTheme.Spacing.s3) {
                HomeQuickFactFeedingPantryThumbnail(item: item)

                VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                    Text(item.name)
                        .font(MHBTheme.Typography.callout.weight(.semibold))
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                        .lineLimit(1)

                    Text("\(item.brand) · \(item.statusLabel)")
                        .font(MHBTheme.Typography.caption)
                        .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                        .lineLimit(1)
                }

                Spacer(minLength: MHBTheme.Spacing.s2)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: MHBTheme.IconSize.small, weight: .semibold))
                    .foregroundStyle(isSelected ? MHBTheme.ColorToken.primary.color : MHBTheme.ColorToken.separator.color)
            }
            .padding(MHBTheme.Spacing.s3)
            .background(isSelected ? MHBTheme.ColorToken.primaryBackgroundSoft.color : MHBTheme.ColorToken.cardSolid.color)
            .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                    .stroke(isSelected ? MHBTheme.ColorToken.primary.color : MHBTheme.ColorToken.separator.color, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

// HomeQuickFactFeedingPantryThumbnail 喂食储物柜缩略图
// 核心职责：
// - 展示储物柜物品图片
// - 在图片不可用时提供分类图标兜底
private struct HomeQuickFactFeedingPantryThumbnail: View {
    let item: PantryItem

    var body: some View {
        ZStack {
            MHBTheme.ColorToken.primaryBackgroundSoft.color

            if let imageURL = item.imageURL.flatMap(URL.init(string:)) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure, .empty:
                        fallbackIcon
                    @unknown default:
                        fallbackIcon
                    }
                }
            } else {
                fallbackIcon
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
    }

    private var fallbackIcon: some View {
        Image(systemName: item.category.feedingSystemImage)
            .font(.system(size: MHBTheme.IconSize.small, weight: .semibold))
            .foregroundStyle(MHBTheme.ColorToken.primary.color)
    }
}

// HomeQuickFactFeedingManualItemRow 手动喂食占位行
// 核心职责：
// - 为非储物柜物品保留输入位置
// - 引导用户通过备注补充具体内容
private struct HomeQuickFactFeedingManualItemRow: View {
    let kind: HomeQuickFactFeedingFoodKind

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s3) {
            Image(systemName: kind.systemImage)
                .font(.system(size: MHBTheme.IconSize.small, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

            Text(kind.emptySelectionTitle)
                .font(MHBTheme.Typography.callout.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

            Spacer()
        }
        .padding(MHBTheme.Spacing.s3)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                .stroke(MHBTheme.ColorToken.separator.color, lineWidth: 1)
        }
    }
}

// HomeQuickFactFeedingFoodSource 喂食储物柜数据源
// 核心职责：
// - 将储物柜分类映射到快捷喂食分类
// - 提供默认物品和选中物品名称解析
private enum HomeQuickFactFeedingFoodSource {
    static func items(for kind: HomeQuickFactFeedingFoodKind) -> [PantryItem] {
        PetPantryMockData.items.filter { item in
            guard let feedingKind = item.category.feedingKind else { return false }
            return feedingKind == kind
        }
    }

    static func defaultItemID(for kind: HomeQuickFactFeedingFoodKind) -> String? {
        defaultItem(for: kind)?.id
    }

    static func defaultItemName(for kind: HomeQuickFactFeedingFoodKind) -> String? {
        defaultItem(for: kind)?.name
    }

    static func itemName(for itemID: String?, in kind: HomeQuickFactFeedingFoodKind) -> String? {
        guard let itemID else { return nil }
        return items(for: kind).first { $0.id == itemID }?.name
    }

    private static func defaultItem(for kind: HomeQuickFactFeedingFoodKind) -> PantryItem? {
        let items = items(for: kind)
        return items.first { $0.status == .inUse } ?? items.first
    }
}

private extension HomeQuickFactFeedingFoodKind {
    var emptySelectionTitle: String {
        switch self {
        case .mainFood:
            "选择主粮"
        case .snack:
            "选择零食"
        case .supplement:
            "选择营养品"
        case .other:
            "在备注中补充"
        }
    }
}

private extension PantryCategory {
    var feedingKind: HomeQuickFactFeedingFoodKind? {
        switch self {
        case .mainFood, .wetFood:
            .mainFood
        case .treats:
            .snack
        case .supplements:
            .supplement
        case .all, .catLitter, .medicine:
            nil
        }
    }

    var feedingSystemImage: String {
        switch self {
        case .mainFood, .wetFood:
            HomeQuickFactFeedingFoodKind.mainFood.systemImage
        case .treats:
            HomeQuickFactFeedingFoodKind.snack.systemImage
        case .supplements:
            HomeQuickFactFeedingFoodKind.supplement.systemImage
        case .all:
            "tray.full.fill"
        case .catLitter:
            "drop.fill"
        case .medicine:
            "pills.fill"
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
                .font(MHBTheme.Typography.callout.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

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

// HomeQuickFactDateSection 快捷事实时间选择区
// 核心职责：
// - 收集快捷记录的真实发生时间
// - 统一喂食和异常 sheet 的时间输入样式
private struct HomeQuickFactDateSection: View {
    let title: LocalizedStringResource
    @Binding var date: Date

    var body: some View {
        HomeQuickFactSheetSection(title: title) {
            DatePicker(
                "发生时间",
                selection: $date,
                displayedComponents: [.date, .hourAndMinute]
            )
            .font(MHBTheme.Typography.callout)
            .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
            .padding(MHBTheme.Spacing.s4)
            .background(MHBTheme.ColorToken.cardSolid.color)
            .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous)
                    .stroke(MHBTheme.ColorToken.separator.color, lineWidth: 1)
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

// HomeQuickFactOptionalPhotoSection 快捷记录可选照片区
// 核心职责：
// - 为喂食等记录提供可选照片入口
// - 在快速 UI 阶段使用本地 mock 图片表达添加状态
private struct HomeQuickFactOptionalPhotoSection: View {
    let title: LocalizedStringResource
    @Binding var photoAssetNames: [String]

    private let mockAssetName = "HomePetFoodBowl"

    var body: some View {
        HomeQuickFactSheetSection(title: title) {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
                if photoAssetNames.isEmpty == false {
                    HStack(spacing: MHBTheme.Spacing.s2) {
                        ForEach(photoAssetNames, id: \.self) { assetName in
                            Image(assetName)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 78, height: 78)
                                .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
                        }
                    }
                }

                Button(action: toggleMockPhoto) {
                    HStack(spacing: MHBTheme.Spacing.s3) {
                        Image(systemName: photoAssetNames.isEmpty ? "camera.fill" : "xmark.circle.fill")
                            .font(.system(size: MHBTheme.IconSize.medium, weight: .semibold))

                        Text(photoAssetNames.isEmpty ? "添加照片" : "移除照片")
                            .font(MHBTheme.Typography.callout.weight(.semibold))

                        Spacer()

                        Image(systemName: photoAssetNames.isEmpty ? "plus" : "minus")
                            .font(.system(size: MHBTheme.IconSize.small, weight: .semibold))
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
            }
        }
    }

    private func toggleMockPhoto() {
        if photoAssetNames.isEmpty {
            photoAssetNames = [mockAssetName]
        } else {
            photoAssetNames = []
        }
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
        case .female:
            self = .female
        case .male:
            self = .male
        case .unknown:
            self = .unknown
        }
    }
}
