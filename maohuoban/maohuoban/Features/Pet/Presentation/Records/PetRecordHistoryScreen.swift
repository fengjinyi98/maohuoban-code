import SwiftUI
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

    private let records = PetRecordHistoryItem.mockItems

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
                .padding(.top, topContentPadding(geometrySafeAreaTop: proxy.safeAreaInsets.top))
                .frame(width: proxy.size.width, height: proxy.size.height)
                .zIndex(0)

                PetRecordHistoryTopChrome(
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
        .accessibilityIdentifier("pet.recordHistory")
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
private struct PetRecordHistoryItem: Identifiable, Hashable {
    let id: String
    let yearText: String
    let monthText: String
    let dateText: String
    let timeText: String
    let title: String
    let subtitle: String
    let kindText: String
    let systemImage: String
    let tint: Color

    var detailRoute: PetRecordDetailRoute {
        PetRecordDetailRoute.mockRoute(for: id)
    }

    static let mockItems: [PetRecordHistoryItem] = [
        PetRecordHistoryItem(
            id: "record-2026-06-feeding",
            yearText: "2026年",
            monthText: "6月",
            dateText: "6月24日",
            timeText: "08:30",
            title: "已喂食",
            subtitle: "主粮 · 正常",
            kindText: "喂食",
            systemImage: "fork.knife",
            tint: Color(mhbHex: "0093DD")
        ),
        PetRecordHistoryItem(
            id: "record-2026-06-weight",
            yearText: "2026年",
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
            id: "record-2026-06-abnormal",
            yearText: "2026年",
            monthText: "6月",
            dateText: "6月24日",
            timeText: "20:15",
            title: "异常记录",
            subtitle: "食欲、精神 · 明显",
            kindText: "异常",
            systemImage: "cross.case.fill",
            tint: MHBTheme.ColorToken.danger.color
        ),
        PetRecordHistoryItem(
            id: "record-2026-06-deworming",
            yearText: "2026年",
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
            yearText: "2026年",
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
            yearText: "2026年",
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
            yearText: "2026年",
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
