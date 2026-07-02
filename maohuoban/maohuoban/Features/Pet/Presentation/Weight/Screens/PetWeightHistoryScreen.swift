import SwiftUI
import MaohuobanDesignSystem

// PetWeightHistoryScreen 体重历史记录页
// 核心职责：
// - 使用 List 按月份展示完整体重记录
// - 通过自绘顶部导航区域承载宠物切换
struct PetWeightHistoryScreen: View {
    @Environment(\.dismiss) private var dismiss

    let context: PetRecordEntryContext
    let fallbackPetName: String
    let records: [PetWeightRecord]

    @State private var selectedPet: PetRecordSwitchPet?
    @State private var detailRoute: PetRecordDetailRoute?

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                MHBTheme.ColorToken.background.color
                    .ignoresSafeArea()

                List {
                    ForEach(groupedRecords, id: \.id) { group in
                        Section {
                            ForEach(group.records) { record in
                                Button {
                                    detailRoute = .weight(recordID: record.id)
                                } label: {
                                    PetWeightHistoryListRow(record: record)
                                }
                                .buttonStyle(.plain)
                                .listRowInsets(
                                    EdgeInsets(
                                        top: MHBTheme.Spacing.s2,
                                        leading: MHBTheme.Spacing.s5,
                                        bottom: MHBTheme.Spacing.s2,
                                        trailing: MHBTheme.Spacing.s5
                                    )
                                )
                                .listRowSeparator(.hidden)
                                .listRowBackground(MHBTheme.ColorToken.background.color)
                            }
                        } header: {
                            PetWeightHistoryMonthHeader(
                                month: group.month,
                                year: group.year
                            )
                        }
                    }
                }
                .listStyle(.plain)
                .listSectionSpacing(MHBTheme.Spacing.s1)
                .scrollContentBackground(.hidden)
                .background(MHBTheme.ColorToken.background.color)
                .padding(.top, topContentPadding(geometrySafeAreaTop: proxy.safeAreaInsets.top))
                .frame(width: proxy.size.width, height: proxy.size.height)
                .zIndex(0)

                PetWeightHistoryTopChrome(
                    selectedItem: currentPetSwitcherItem,
                    items: petSwitcherItems,
                    isDisabled: petSwitcherItems.count <= 1,
                    onBack: { dismiss() },
                    onSelect: selectPet
                )
                .padding(.horizontal, MHBTheme.Spacing.s4)
                .mhbTopChromeAligned(geometrySafeAreaTop: proxy.safeAreaInsets.top)
                .zIndex(2)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .ignoresSafeArea(.container, edges: [.top])
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .navigationDestination(item: $detailRoute) { route in
            PetRecordDetailDestinationScreen(route: route)
        }
        .onAppear {
            selectedPet = selectedPet ?? context.selectedSwitchPet
        }
        .accessibilityIdentifier("pet.weightHistory")
    }

    private var topChromeHeight: CGFloat {
        48
    }

    private func topContentPadding(geometrySafeAreaTop: CGFloat) -> CGFloat {
        MHBTopChromePositionResolver.resolvedTopInset(geometrySafeAreaTop: geometrySafeAreaTop)
            + topChromeHeight
            + MHBTheme.Spacing.s5
    }

    private var currentPetID: String? {
        selectedPet?.id ?? context.petID
    }

    private var availablePets: [PetRecordSwitchPet] {
        if context.availablePets.isEmpty == false {
            return context.availablePets
        }

        return context.selectedSwitchPet.map { [$0] } ?? [
            PetRecordSwitchPet(
                id: "pet-weight-history-current",
                name: fallbackPetName,
                isSelected: true
            )
        ]
    }

    private var currentPetSwitcherItem: MHBPetSwitcherItem? {
        petSwitcherItems.first(where: \.isSelected) ?? petSwitcherItems.first
    }

    private var petSwitcherItems: [MHBPetSwitcherItem] {
        availablePets.map { pet in
            MHBPetSwitcherItem(weightHistoryPet: pet, isSelected: pet.id == currentPetID)
        }
    }

    private var groupedRecords: [(id: String, year: String, month: String, records: [PetWeightRecord])] {
        var groups: [(id: String, year: String, month: String, records: [PetWeightRecord])] = []

        for record in records {
            let groupID = "\(record.yearText)-\(record.monthText)"
            if let index = groups.firstIndex(where: { $0.id == groupID }) {
                groups[index].records.append(record)
            } else {
                groups.append((
                    id: groupID,
                    year: record.yearText,
                    month: record.monthText,
                    records: [record]
                ))
            }
        }

        return groups
    }

    private func selectPet(_ petID: String) {
        guard let pet = availablePets.first(where: { $0.id == petID }) else { return }
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

}

// PetWeightHistoryMonthHeader 体重历史月份标题
// 核心职责：
// - 在列表分组标题中展示月份和年份
// - 保持跨年记录浏览时的时间上下文
private struct PetWeightHistoryMonthHeader: View {
    let month: String
    let year: String

    var body: some View {
        HStack(alignment: .bottom) {
            Text(month)
                .font(MHBTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

            Spacer()

            Text(year)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
        }
        .textCase(nil)
        .padding(.top, MHBTheme.Spacing.s1)
    }
}

// PetWeightHistoryListRow 体重历史列表行
// 核心职责：
// - 展示单条体重历史记录
// - 保持列表页记录信息的扫描效率
private struct PetWeightHistoryListRow: View {
    let record: PetWeightRecord

    var body: some View {
        HStack(alignment: .center, spacing: MHBTheme.Spacing.s3) {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                Text(record.dateText)
                    .font(MHBTheme.Typography.callout.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                Text(record.note)
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            }

            Spacer(minLength: MHBTheme.Spacing.s4)

            VStack(alignment: .trailing, spacing: MHBTheme.Spacing.s1 / 2) {
                Text(String(format: "%.2f kg", record.weight))
                    .font(MHBTheme.Typography.callout.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                Text(record.deltaText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(record.deltaKind.color)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
        }
        .padding(MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
        .shadow(color: MHBTheme.ColorToken.labelPrimary.color.opacity(0.03), radius: 14, y: 3)
        .contentShape(Rectangle())
    }
}

// PetWeightHistoryTopChrome 体重历史顶部导航控件
// 核心职责：
// - 在系统导航栏视觉位置展示返回和宠物切换
// - 使用自绘 chrome 承载带 Liquid Glass 的宠物切换基础设施
private struct PetWeightHistoryTopChrome: View {
    let selectedItem: MHBPetSwitcherItem?
    let items: [MHBPetSwitcherItem]
    let isDisabled: Bool
    let onBack: () -> Void
    let onSelect: (String) -> Void

    var body: some View {
        GlassEffectContainer(spacing: MHBTheme.Spacing.s3) {
            ZStack {
                HStack(spacing: MHBTheme.Spacing.s3) {
                    PetWeightHistoryBackButton(onBack: onBack)

                    Spacer(minLength: MHBTheme.Spacing.s3)
                }

                HStack {
                    Spacer(minLength: MHBTheme.Spacing.s3)

                    PetWeightHistoryPetSwitcherMenu(
                        selectedItem: selectedItem,
                        items: items,
                        isDisabled: isDisabled,
                        onSelect: onSelect
                    )
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// PetWeightHistoryBackButton 体重历史返回按钮
// 核心职责：
// - 承载顶部左侧返回动作
// - 保持自绘顶部栏 Liquid Glass 圆形反馈
private struct PetWeightHistoryBackButton: View {
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
        .accessibilityIdentifier("pet.weightHistory.backButton")
    }
}

// PetWeightHistoryPetSwitcherMenu 体重历史宠物切换菜单
// 核心职责：
// - 在自绘顶部栏右侧展示当前宠物
// - 使用原生 Menu 承载宠物切换动作
private struct PetWeightHistoryPetSwitcherMenu: View {
    let selectedItem: MHBPetSwitcherItem?
    let items: [MHBPetSwitcherItem]
    let isDisabled: Bool
    let onSelect: (String) -> Void

    var body: some View {
        Menu {
            ForEach(items) { item in
                Button {
                    onSelect(item.id)
                } label: {
                    Label(item.name, systemImage: item.isSelected ? "checkmark.circle.fill" : "circle")
                }
            }
        } label: {
            MHBPetSwitcherCapsule(
                item: selectedItem,
                isDisabled: false
            )
        }
        .disabled(items.isEmpty)
        .buttonStyle(.plain)
        .accessibilityIdentifier("pet.weightHistory.petSwitcherButton")
    }
}

private extension MHBPetSwitcherItem {
    init(weightHistoryPet pet: PetRecordSwitchPet, isSelected: Bool) {
        self.init(
            id: pet.id,
            name: pet.name ?? "未命名宠物",
            subtitle: pet.breed,
            avatarURLString: pet.avatarURL,
            species: MHBPetSwitcherSpecies(weightHistorySpecies: pet.species),
            sex: MHBPetSwitcherSex(weightHistorySex: pet.sex),
            isSelected: isSelected
        )
    }
}

private extension MHBPetSwitcherSpecies {
    init(weightHistorySpecies species: PetRecordPetSpecies) {
        switch species {
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
    init(weightHistorySex sex: PetRecordPetSex) {
        switch sex {
        case .female:
            self = .female
        case .male:
            self = .male
        case .unknown:
            self = .unknown
        }
    }
}
