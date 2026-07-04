import SwiftUI
import UIKit
import MaohuobanDesignSystem

// PetPreventiveCareScreen 疫苗驱虫管理页
// 核心职责：
// - 展示疫苗/驱虫的最近到期状态和计划摘要
// - 读取真实事件列表承载历史记录浏览和后续新增入口
struct PetPreventiveCareScreen: View {
    @Environment(\.dismiss) private var dismiss

    let context: PetPreventiveCareContext
    let currentUserID: String?
    var onRecordDeleted: (String) -> Void = { _ in }
    var onMutationCompleted: () -> Void = {}

    @State private var selectedKind: PetPreventiveCareKind = .all
    @State private var selectedPet: PetRecordSwitchPet?
    @State private var formMode: PetPreventiveCareFormMode?
    @State private var detailRoute: PetRecordDetailRoute?
    @State private var windowSafeAreaInsets = UIEdgeInsets.zero
    @State private var store = PetPreventiveCareStore()

    init(
        context: PetPreventiveCareContext,
        currentUserID: String? = nil,
        onRecordDeleted: @escaping (String) -> Void = { _ in },
        onMutationCompleted: @escaping () -> Void = {}
    ) {
        self.context = context
        self.currentUserID = currentUserID
        self.onRecordDeleted = onRecordDeleted
        self.onMutationCompleted = onMutationCompleted
        self._selectedPet = State(initialValue: context.recordContext.selectedSwitchPet)
    }

    var body: some View {
        GeometryReader { proxy in
            let topInset = effectiveTopInset(geometrySafeAreaTop: proxy.safeAreaInsets.top)
            let bottomInset = proxy.safeAreaInsets.bottom

            ZStack(alignment: .topLeading) {
                MHBTheme.ColorToken.background.color
                    .ignoresSafeArea()

                MHBScreenScrollView {
                    contentView
                        .padding(.horizontal, MHBTheme.Spacing.s5)
                        .padding(.top, topContentPadding(topInset: topInset))
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .zIndex(0)

                MHBWindowSafeAreaReader { insets in
                    windowSafeAreaInsets = insets
                }
                .allowsHitTesting(false)

                MHBBottomFloatingActionCTA(
                    title: "新增记录",
                    systemImage: "plus",
                    bottomInset: bottomInset,
                    action: {
                        formMode = .create
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
                .padding(.top, topInset)
                .frame(maxWidth: .infinity, alignment: .top)
                .zIndex(3)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .ignoresSafeArea(.container, edges: [.top, .bottom])
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .navigationDestination(item: $detailRoute) { route in
            PetRecordDetailDestinationScreen(
                route: route,
                currentUserID: currentUserID,
                onRecordDeleted: { recordID in
                    store.removeRecord(id: recordID)
                    onRecordDeleted(recordID)
                    onMutationCompleted()
                }
            )
        }
        .sheet(item: $formMode) { mode in
            PetPreventiveCareAddRecordSheet(
                mode: mode,
                currentUserID: currentUserID,
                isSubmitting: store.isMutating,
                onSave: saveRecord(mode:draft:)
            )
        }
        .task(id: currentPetID) {
            await store.load(petID: currentPetID, currentUserID: currentUserID)
        }
        .accessibilityIdentifier("pet.preventiveCare")
    }

    @ViewBuilder
    private var contentView: some View {
        switch store.phase {
        case .idle, .loading:
            PetPreventiveCareLoadingState()
                .padding(.bottom, MHBTheme.Spacing.s8)
        case .failed(let message):
            PetPreventiveCareErrorState(message: message) {
                Task {
                    await store.load(petID: currentPetID, currentUserID: currentUserID)
                }
            }
            .padding(.bottom, MHBTheme.Spacing.s8)
        case .loaded:
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s5) {
                PetPreventiveCareOverviewSection(
                    nearestRecord: nearestRecord,
                    vaccineRecord: latestRecord(kind: .vaccine),
                    dewormingRecord: latestRecord(kind: .deworming)
                )

                PetPreventiveCareHistorySection(
                    selectedKind: $selectedKind,
                    groups: groupedRecords,
                    onOpenRecord: { record in
                        detailRoute = detailRoute(for: record)
                    },
                    onEditRecord: { record in
                        formMode = .edit(record)
                    }
                )
                .padding(.bottom, MHBTheme.Spacing.s8 + MHBTheme.Spacing.s8 + MHBTheme.Spacing.s6)
            }
        }
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
        selectedPet?.id ?? context.recordContext.petID
    }

    private var records: [PetPreventiveCareRecord] {
        store.records
    }

    private var availablePets: [PetRecordSwitchPet] {
        if context.recordContext.availablePets.isEmpty == false {
            return context.recordContext.availablePets
        }

        return context.recordContext.selectedSwitchPet.map { [$0] } ?? []
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

    private func detailRoute(for record: PetPreventiveCareRecord) -> PetRecordDetailRoute {
        switch record.kind {
        case .vaccine:
            .vaccine(recordID: record.id, context: currentRecordContext)
        case .deworming:
            .deworming(recordID: record.id, context: currentRecordContext)
        case .all:
            .unsupported(recordID: record.id)
        }
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
            lifeStatus: pet.lifeStatus,
            isSelected: true
        )
    }

    private var currentRecordContext: PetRecordEntryContext {
        PetRecordEntryContext(
            petID: currentPetID,
            petName: selectedPet?.name ?? context.recordContext.petName,
            petAvatarURL: selectedPet?.avatarURL ?? context.recordContext.petAvatarURL,
            petSpecies: selectedPet?.species ?? context.recordContext.petSpecies,
            petSex: selectedPet?.sex ?? context.recordContext.petSex,
            lifeStatus: selectedPet?.lifeStatus ?? context.recordContext.lifeStatus,
            availablePets: availablePets
        )
    }

    private func saveRecord(mode: PetPreventiveCareFormMode, draft: PetPreventiveCareDraft) {
        Task {
            let didSave: Bool
            switch mode {
            case .create:
                didSave = await store.create(
                    petID: currentPetID,
                    currentUserID: currentUserID,
                    draft: draft
                )
            case .edit(let record):
                didSave = await store.update(
                    eventID: record.id,
                    petID: currentPetID,
                    currentUserID: currentUserID,
                    draft: draft
                )
            }
            guard didSave else { return }
            formMode = nil
            onMutationCompleted()
        }
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

// PetPreventiveCareLoadingState 疫苗驱虫加载态
// 核心职责：
// - 展示真实记录加载反馈
// - 避免页面回落到演示数据
private struct PetPreventiveCareLoadingState: View {
    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s4) {
            ProgressView()
            Text("正在加载疫苗驱虫记录")
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, MHBTheme.Spacing.s8)
    }
}

// PetPreventiveCareErrorState 疫苗驱虫错误态
// 核心职责：
// - 展示真实记录加载失败原因
// - 提供显式重试入口
private struct PetPreventiveCareErrorState: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: MHBTheme.IconSize.large, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.warning.color)
            Text(message)
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .multilineTextAlignment(.center)
            Button("重试", action: onRetry)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, MHBTheme.Spacing.s8)
    }
}
