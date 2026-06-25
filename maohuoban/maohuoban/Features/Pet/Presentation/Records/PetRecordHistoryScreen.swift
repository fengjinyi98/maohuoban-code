import SwiftUI
import MaohuobanDesignSystem

// PetRecordHistoryScreen 宠物记录历史页
// 核心职责：
// - 按月份分组展示宠物完整记录列表
// - 支持通过右上角宠物切换查看不同宠物记录
struct PetRecordHistoryScreen: View {
    let context: PetRecordEntryContext

    @State private var selectedPet: PetRecordSwitchPet?

    private let records = PetRecordHistoryItem.mockItems

    var body: some View {
        List {
            ForEach(groupedRecords, id: \.month) { group in
                Section {
                    ForEach(group.records) { record in
                        Button {
                            // TODO: 接入记录详情页路由。
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
                    Text(group.month)
                        .font(MHBTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                        .textCase(nil)
                        .padding(.top, MHBTheme.Spacing.s2)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(MHBTheme.ColorToken.background.color)
        .navigationTitle("记录")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                PetRecordHistoryPetSwitcherMenu(
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
        .accessibilityIdentifier("pet.recordHistory")
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

    private var groupedRecords: [(month: String, records: [PetRecordHistoryItem])] {
        var groups: [(month: String, records: [PetRecordHistoryItem])] = []

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

// PetRecordHistoryItem 宠物记录历史展示模型
// 核心职责：
// - 承载记录历史页 mock 展示数据
// - 为列表分组和行展示提供稳定输入
private struct PetRecordHistoryItem: Identifiable, Hashable {
    let id: String
    let monthText: String
    let dateText: String
    let timeText: String
    let title: String
    let subtitle: String
    let kindText: String
    let systemImage: String
    let tint: Color

    static let mockItems: [PetRecordHistoryItem] = [
        PetRecordHistoryItem(
            id: "record-2026-06-breakfast",
            monthText: "6月",
            dateText: "6月24日",
            timeText: "08:30",
            title: "记录了早餐",
            subtitle: "鸡肉 + 南瓜 + 主粮",
            kindText: "日常",
            systemImage: "fork.knife",
            tint: Color(mhbHex: "E5A93C")
        ),
        PetRecordHistoryItem(
            id: "record-2026-06-weight",
            monthText: "6月",
            dateText: "6月24日",
            timeText: "09:15",
            title: "体重更新",
            subtitle: "4.20 kg，较上次 -0.15 kg",
            kindText: "体重",
            systemImage: "scalemass.fill",
            tint: Color(mhbHex: "7C3AED")
        ),
        PetRecordHistoryItem(
            id: "record-2026-06-deworming",
            monthText: "6月",
            dateText: "6月22日",
            timeText: "11:30",
            title: "完成驱虫",
            subtitle: "大宠爱体外驱虫滴剂",
            kindText: "驱虫",
            systemImage: "checkmark.seal.fill",
            tint: Color(mhbHex: "0EA5E9")
        ),
        PetRecordHistoryItem(
            id: "record-2026-05-walk",
            monthText: "5月",
            dateText: "5月20日",
            timeText: "20:20",
            title: "夜间散步",
            subtitle: "32 分钟 · 2.3 km",
            kindText: "遛弯",
            systemImage: "figure.walk",
            tint: Color(mhbHex: "F97316")
        ),
        PetRecordHistoryItem(
            id: "record-2026-05-appetite",
            monthText: "5月",
            dateText: "5月18日",
            timeText: "19:10",
            title: "食欲正常",
            subtitle: "晚餐吃完，精神状态稳定",
            kindText: "事实",
            systemImage: "heart.text.square.fill",
            tint: Color(mhbHex: "16A34A")
        ),
        PetRecordHistoryItem(
            id: "record-2026-04-hospital",
            monthText: "4月",
            dateText: "4月15日",
            timeText: "10:40",
            title: "医院体检",
            subtitle: "基础血常规与生化筛查",
            kindText: "就诊",
            systemImage: "stethoscope",
            tint: Color(mhbHex: "2563EB")
        )
    ]
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

// PetRecordHistoryPetSwitcherMenu 记录历史宠物切换菜单
// 核心职责：
// - 在系统导航栏右侧展示当前宠物
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
                isDisabled: isDisabled
            )
        }
        .disabled(isDisabled)
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
