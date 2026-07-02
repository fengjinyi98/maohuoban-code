import SwiftUI
import UIKit
import MaohuobanDesignSystem

// PetRecordHistoryScreen 宠物记录历史页
// 核心职责：
// - 按月份分组展示宠物完整记录列表
// - 支持通过右上角宠物切换查看不同宠物记录
struct PetRecordHistoryScreen: View {
    @Environment(\.dismiss) private var dismiss

    let context: PetRecordEntryContext

    @State private var selectedPet: PetRecordSwitchPet?
    @State private var detailRoute: PetRecordDetailRoute?
    @State private var windowSafeAreaInsets = UIEdgeInsets.zero

    private let records = PetRecordHistoryItem.mockItems

    init(context: PetRecordEntryContext) {
        self.context = context
        self._selectedPet = State(initialValue: context.selectedSwitchPet)
    }

    var body: some View {
        GeometryReader { proxy in
            let topInset = effectiveTopInset(geometrySafeAreaTop: proxy.safeAreaInsets.top)

            ZStack(alignment: .topLeading) {
                MHBTheme.ColorToken.background.color
                    .ignoresSafeArea()

                List {
                    ForEach(groupedRecords, id: \.id) { group in
                        Section {
                            ForEach(group.records) { record in
                                Button {
                                    detailRoute = record.detailRoute
                                } label: {
                                    PetRecordHistoryRow(record: record)
                                }
                                .buttonStyle(.plain)
                                .listRowInsets(
                                    EdgeInsets(
                                        top: MHBTheme.Spacing.s2,
                                        leading: MHBTheme.Spacing.s4,
                                        bottom: MHBTheme.Spacing.s2,
                                        trailing: MHBTheme.Spacing.s4
                                    )
                                )
                                .listRowSeparator(.hidden)
                                .listRowBackground(MHBTheme.ColorToken.background.color)
                            }
                        } header: {
                            PetRecordHistoryMonthHeader(
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
                .padding(.top, topContentPadding(topInset: topInset))
                .frame(width: proxy.size.width, height: proxy.size.height)
                .zIndex(0)

                MHBWindowSafeAreaReader { insets in
                    windowSafeAreaInsets = insets
                }
                .allowsHitTesting(false)

                PetRecordHistoryTopChrome(
                    selectedItem: currentPetSwitcherItem,
                    items: petSwitcherItems,
                    isDisabled: petSwitcherItems.count <= 1,
                    onBack: { dismiss() },
                    onSelect: selectPet
                )
                .padding(.horizontal, MHBTheme.Spacing.s4)
                .padding(.top, topInset)
                .frame(maxWidth: .infinity, alignment: .top)
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
        .accessibilityIdentifier("pet.recordHistory")
    }

    private var topChromeHeight: CGFloat {
        48
    }

    private func effectiveTopInset(geometrySafeAreaTop: CGFloat) -> CGFloat {
        max(geometrySafeAreaTop, windowSafeAreaInsets.top)
    }

    private func topContentPadding(topInset: CGFloat) -> CGFloat {
        topInset + topChromeHeight + MHBTheme.Spacing.s5
    }

    private var currentPetID: String? {
        selectedPet?.id ?? context.petID
    }

    private var availablePets: [PetRecordSwitchPet] {
        if context.availablePets.isEmpty == false {
            return context.availablePets
        }

        return context.selectedSwitchPet.map { [$0] } ?? []
    }

    private var currentPetSwitcherItem: MHBPetSwitcherItem? {
        petSwitcherItems.first(where: \.isSelected) ?? petSwitcherItems.first
    }

    private var petSwitcherItems: [MHBPetSwitcherItem] {
        availablePets.map { pet in
            MHBPetSwitcherItem(recordHistoryPet: pet, isSelected: pet.id == currentPetID)
        }
    }

    private var groupedRecords: [(id: String, year: String, month: String, records: [PetRecordHistoryItem])] {
        var groups: [(id: String, year: String, month: String, records: [PetRecordHistoryItem])] = []

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

// PetRecordHistoryItem 宠物记录历史展示模型
// 核心职责：
// - 承载记录历史页 mock 展示数据
// - 为列表分组和行展示提供稳定输入


// PetRecordHistoryMonthHeader 记录历史月份标题
// 核心职责：
// - 在列表分组标题中展示月份和年份
// - 保持跨年记录浏览时的时间上下文
private struct PetRecordHistoryMonthHeader: View {
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

// PetRecordHistoryRow 宠物记录历史列表行
// 核心职责：
// - 展示单条记录摘要
// - 保留右侧箭头提示后续详情入口
private struct PetRecordHistoryRow: View {
    let record: PetRecordHistoryItem

    var body: some View {
        HStack(alignment: .center, spacing: MHBTheme.Spacing.s3) {
            VStack(alignment: .trailing, spacing: MHBTheme.Spacing.s1 / 2) {
                Text(record.timeText)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                Text(record.dateText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
            }
            .frame(width: 54, alignment: .trailing)

            Image(systemName: record.systemImage)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(record.tint)
                .frame(width: 38, height: 38)
                .background(record.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                HStack(spacing: MHBTheme.Spacing.s2) {
                    Text(record.title)
                        .font(MHBTheme.Typography.callout.weight(.semibold))
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                        .lineLimit(1)

                    Text(record.kindText)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(record.tint)
                        .padding(.horizontal, MHBTheme.Spacing.s2)
                        .frame(height: 20)
                        .background(record.tint.opacity(0.10), in: Capsule())
                }

                Text(record.subtitle)
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .lineLimit(1)
            }

            Spacer(minLength: MHBTheme.Spacing.s2)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
        }
        .padding(MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
        .shadow(color: MHBTheme.ColorToken.labelPrimary.color.opacity(0.03), radius: 14, y: 3)
    }
}

// PetRecordHistoryTopChrome 全部记录顶部导航控件
// 核心职责：
// - 在系统导航栏视觉位置展示返回和宠物切换
// - 使用自绘 chrome 承载带 Liquid Glass 的宠物切换基础设施
private struct PetRecordHistoryTopChrome: View {
    let selectedItem: MHBPetSwitcherItem?
    let items: [MHBPetSwitcherItem]
    let isDisabled: Bool
    let onBack: () -> Void
    let onSelect: (String) -> Void

    var body: some View {
        GlassEffectContainer(spacing: MHBTheme.Spacing.s3) {
            ZStack {
                HStack(spacing: MHBTheme.Spacing.s3) {
                    PetRecordHistoryBackButton(onBack: onBack)

                    Spacer(minLength: MHBTheme.Spacing.s3)
                }

                HStack {
                    Spacer(minLength: MHBTheme.Spacing.s3)

                    PetRecordHistoryPetSwitcherMenu(
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

// PetRecordHistoryBackButton 全部记录返回按钮
// 核心职责：
// - 承载顶部左侧返回动作
// - 保持自绘顶部栏 Liquid Glass 圆形反馈
private struct PetRecordHistoryBackButton: View {
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
        .accessibilityIdentifier("pet.recordHistory.backButton")
    }
}

// PetRecordHistoryPetSwitcherMenu 记录历史宠物切换菜单
// 核心职责：
// - 在自绘顶部栏右侧展示当前宠物
// - 使用原生 Menu 承载宠物切换动作
private struct PetRecordHistoryPetSwitcherMenu: View {
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
        .accessibilityIdentifier("pet.recordHistory.petSwitcherButton")
    }
}

private extension MHBPetSwitcherItem {
    init(recordHistoryPet pet: PetRecordSwitchPet, isSelected: Bool) {
        self.init(
            id: pet.id,
            name: pet.name ?? "未命名宠物",
            subtitle: pet.breed,
            avatarURLString: pet.avatarURL,
            species: MHBPetSwitcherSpecies(recordHistorySpecies: pet.species),
            sex: MHBPetSwitcherSex(recordHistorySex: pet.sex),
            isSelected: isSelected
        )
    }
}

private extension MHBPetSwitcherSpecies {
    init(recordHistorySpecies species: PetRecordPetSpecies) {
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
    init(recordHistorySex sex: PetRecordPetSex) {
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
