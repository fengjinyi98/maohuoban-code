import SwiftUI
import MaohuobanDesignSystem

// PetPreventiveCareScreen 疫苗驱虫管理页
// 核心职责：
// - 展示疫苗/驱虫的最近到期状态和计划摘要
// - 用 mock 列表承载历史记录浏览和后续新增入口
struct PetPreventiveCareScreen: View {
    @Environment(\.dismiss) private var dismiss

    let context: PetPreventiveCareContext

    @State private var selectedKind: PetPreventiveCareKind = .all
    @State private var selectedPet: PetRecordSwitchPet?
    @State private var isAddRecordSheetPresented = false

    private let records = PetPreventiveCareRecord.mockRecords

    var body: some View {
        GeometryReader { proxy in
            let bottomInset = proxy.safeAreaInsets.bottom

            ZStack(alignment: .topLeading) {
                MHBTheme.ColorToken.background.color
                    .ignoresSafeArea()

                MHBScreenScrollView {
                    VStack(alignment: .leading, spacing: MHBTheme.Spacing.s5) {
                        PetPreventiveCareOverviewSection(
                            nearestRecord: nearestRecord,
                            vaccineRecord: latestRecord(kind: .vaccine),
                            dewormingRecord: latestRecord(kind: .deworming)
                        )

                        PetPreventiveCareFilterControl(selectedKind: $selectedKind)

                        PetPreventiveCareHistorySection(
                            groups: groupedRecords,
                            onOpenRecord: { _ in
                                // TODO: 疫苗/驱虫记录详情 UI 确认后接入详情路由。
                            }
                        )
                        .padding(.bottom, MHBTheme.Spacing.s8 + MHBTheme.Spacing.s8 + MHBTheme.Spacing.s6)
                    }
                    .padding(.horizontal, MHBTheme.Spacing.s5)
                    .padding(.top, topContentPadding(geometrySafeAreaTop: proxy.safeAreaInsets.top))
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .zIndex(0)

                MHBBottomFloatingActionCTA(
                    title: "新增记录",
                    systemImage: "plus",
                    bottomInset: bottomInset,
                    action: {
                        isAddRecordSheetPresented = true
                    }
                )
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
                .zIndex(2)

                PetPreventiveCareTopChrome(
                    selectedItem: currentPetSwitcherItem,
                    items: petSwitcherItems,
                    isDisabled: petSwitcherItems.isEmpty,
                    onBack: { dismiss() },
                    onSelect: selectPet
                )
                .padding(.horizontal, MHBTheme.Spacing.s4)
                .mhbTopChromeAligned(geometrySafeAreaTop: proxy.safeAreaInsets.top)
                .zIndex(3)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .ignoresSafeArea(.container, edges: [.top, .bottom])
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $isAddRecordSheetPresented) {
            PetPreventiveCareAddRecordPlaceholderSheet()
        }
        .onAppear {
            selectedPet = selectedPet ?? context.recordContext.selectedSwitchPet
        }
        .accessibilityIdentifier("pet.preventiveCare")
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
        selectedPet?.id ?? context.recordContext.petID
    }

    private var availablePets: [PetRecordSwitchPet] {
        if context.recordContext.availablePets.isEmpty == false {
            return context.recordContext.availablePets
        }

        return context.recordContext.selectedSwitchPet.map { [$0] } ?? [
            PetRecordSwitchPet(
                id: "pet-preventive-current",
                name: context.fallbackPetName,
                isSelected: true
            )
        ]
    }

    private var currentPetSwitcherItem: MHBPetSwitcherItem? {
        petSwitcherItems.first(where: \.isSelected) ?? petSwitcherItems.first
    }

    private var petSwitcherItems: [MHBPetSwitcherItem] {
        availablePets.map { pet in
            MHBPetSwitcherItem(preventiveCarePet: pet, isSelected: pet.id == currentPetID)
        }
    }

    private var filteredRecords: [PetPreventiveCareRecord] {
        switch selectedKind {
        case .all:
            records
        case .vaccine, .deworming:
            records.filter { $0.kind == selectedKind }
        }
    }

    private var nearestRecord: PetPreventiveCareRecord? {
        records
            .filter { $0.kind == .vaccine || $0.kind == .deworming }
            .sorted { lhs, rhs in
                abs(lhs.daysDelta ?? Int.max) < abs(rhs.daysDelta ?? Int.max)
            }
            .first
    }

    private var groupedRecords: [PetPreventiveCareHistoryGroup] {
        var groups: [PetPreventiveCareHistoryGroup] = []

        for record in filteredRecords {
            let groupID = "\(record.yearText)-\(record.monthText)"
            if let index = groups.firstIndex(where: { $0.id == groupID }) {
                groups[index].records.append(record)
            } else {
                groups.append(
                    PetPreventiveCareHistoryGroup(
                        id: groupID,
                        year: record.yearText,
                        month: record.monthText,
                        records: [record]
                    )
                )
            }
        }

        return groups
    }

    private func latestRecord(kind: PetPreventiveCareKind) -> PetPreventiveCareRecord? {
        records.first(where: { $0.kind == kind })
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

// PetPreventiveCareHistoryGroup 疫苗驱虫记录月份分组
// 核心职责：
// - 为历史记录 section 提供稳定分组身份
// - 保持列表渲染与分组计算解耦
struct PetPreventiveCareHistoryGroup: Identifiable, Hashable {
    let id: String
    let year: String
    let month: String
    var records: [PetPreventiveCareRecord]
}
