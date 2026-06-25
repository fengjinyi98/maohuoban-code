import SwiftUI
import MaohuobanDesignSystem

// PetWeightHistoryScreen 体重历史记录页
// 核心职责：
// - 使用项目统一滚动容器展示完整体重记录
// - 支持通过右上角宠物切换查看不同宠物记录
struct PetWeightHistoryScreen: View {
    let context: PetRecordEntryContext
    let fallbackPetName: String
    let records: [PetWeightRecord]

    @State private var selectedPet: PetRecordSwitchPet?

    var body: some View {
        MHBScreenScrollView {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s5) {
                ForEach(groupedRecords, id: \.month) { group in
                    PetWeightHistoryMonthSection(
                        month: group.month,
                        records: group.records
                    )
                }
            }
            .padding(.horizontal, MHBTheme.Spacing.s5)
            .padding(.top, MHBTheme.Spacing.s4)
            .padding(.bottom, MHBTheme.Spacing.s8)
        }
        .background(MHBTheme.ColorToken.background.color)
        .navigationTitle("历史记录")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                PetWeightHistoryPetSwitcherMenu(
                    selectedItem: currentPetSwitcherItem,
                    items: petSwitcherItems,
                    isDisabled: petSwitcherItems.count <= 1,
                    onSelect: selectPet
                )
            }
        }
        .onAppear {
            selectedPet = selectedPet ?? context.selectedSwitchPet
        }
        .accessibilityIdentifier("pet.weightHistory")
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

    private var groupedRecords: [(month: String, records: [PetWeightRecord])] {
        var groups: [(month: String, records: [PetWeightRecord])] = []

        for record in records {
            if let index = groups.firstIndex(where: { $0.month == record.monthText }) {
                groups[index].records.append(record)
            } else {
                groups.append((month: record.monthText, records: [record]))
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

// PetWeightHistoryMonthSection 体重历史月份分组
// 核心职责：
// - 展示月份标题和该月体重记录
// - 保持滚动时月份信息清晰可见
private struct PetWeightHistoryMonthSection: View {
    let month: String
    let records: [PetWeightRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            Text(month)
                .font(MHBTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .padding(.horizontal, MHBTheme.Spacing.s1)

            VStack(spacing: MHBTheme.Spacing.s3) {
                ForEach(records) { record in
                    PetWeightHistoryListRow(record: record)
                }
            }
        }
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
        }
        .padding(MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
        .shadow(color: MHBTheme.ColorToken.labelPrimary.color.opacity(0.03), radius: 14, y: 3)
    }
}

// PetWeightHistoryPetSwitcherMenu 体重历史宠物切换菜单
// 核心职责：
// - 在系统导航栏右侧展示当前宠物
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
                isDisabled: isDisabled
            )
        }
        .disabled(isDisabled)
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
