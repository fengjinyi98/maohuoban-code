import SwiftUI
import UIKit
import MaohuobanDesignSystem

// PetMedicalRecordScreen 病历记录列表页
// 核心职责：
// - 展示当前宠物由医院发布回流的病历记录
// - 承载病历详情进入和宠物切换的前端状态流
struct PetMedicalRecordScreen: View {
    @Environment(\.dismiss) private var dismiss

    let context: PetRecordEntryContext

    @State private var selectedPet: PetRecordSwitchPet?
    @State private var records: [PetMedicalRecord]
    @State private var selectedRecordID: String?
    @State private var windowSafeAreaInsets = UIEdgeInsets.zero

    init(
        context: PetRecordEntryContext
    ) {
        self.context = context
        let pets = PetMedicalRecordScreen.availablePets(from: context)
        self._selectedPet = State(initialValue: context.selectedSwitchPet ?? pets.first)
        self._records = State(initialValue: [])
    }

    var body: some View {
        GeometryReader { proxy in
            let topInset = effectiveTopInset(geometrySafeAreaTop: proxy.safeAreaInsets.top)
            let bottomInset = proxy.safeAreaInsets.bottom

            ZStack(alignment: .topLeading) {
                MHBTheme.ColorToken.background.color
                    .ignoresSafeArea()

                PetMedicalRecordContent(
                    records: filteredRecords,
                    topPadding: topContentPadding(topInset: topInset),
                    bottomPadding: bottomContentPadding(bottomInset: bottomInset),
                    onOpen: { record in
                        selectedRecordID = record.id
                    }
                )
                .frame(width: proxy.size.width, height: proxy.size.height)
                .zIndex(0)

                MHBWindowSafeAreaReader { insets in
                    windowSafeAreaInsets = insets
                }
                .allowsHitTesting(false)

                PetMedicalRecordTopChrome(
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
        .navigationDestination(item: $selectedRecordID) { recordID in
            if let record = record(for: recordID) {
                PetMedicalRecordDetailScreen(record: record)
            } else {
                PetRecordDetailPlaceholderScreen(
                    systemImage: "stethoscope",
                    title: "病历不存在",
                    subtitle: "这条病历记录已不可用。",
                    accessibilityIdentifier: "pet.medicalRecord.missing"
                )
            }
        }
        .accessibilityIdentifier("pet.medicalRecord.screen")
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

    private func bottomContentPadding(bottomInset: CGFloat) -> CGFloat {
        bottomInset + MHBTheme.Spacing.s6
    }

    private var currentPetID: String? {
        selectedPet?.id ?? context.petID
    }

    private var availablePets: [PetRecordSwitchPet] {
        Self.availablePets(from: context)
    }

    private var filteredRecords: [PetMedicalRecord] {
        guard let currentPetID else { return records }
        return records.filter { $0.petID == currentPetID }
    }

    private var currentPetSwitcherItem: MHBPetSwitcherItem? {
        petSwitcherItems.first(where: \.isSelected) ?? petSwitcherItems.first
    }

    private var petSwitcherItems: [MHBPetSwitcherItem] {
        availablePets.map { pet in
            MHBPetSwitcherItem(medicalRecordPet: pet, isSelected: pet.id == currentPetID)
        }
    }

    private static func availablePets(from context: PetRecordEntryContext) -> [PetRecordSwitchPet] {
        if context.availablePets.isEmpty == false {
            return context.availablePets
        }
        return context.selectedSwitchPet.map { [$0] } ?? [
            PetRecordSwitchPet(
                id: "pet-medical-current",
                name: context.petName ?? "当前宠物",
                sex: context.petSex,
                lifeStatus: context.lifeStatus,
                isSelected: true
            )
        ]
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

    private func record(for recordID: String) -> PetMedicalRecord? {
        records.first(where: { $0.id == recordID })
    }
}

// PetMedicalRecordContent 医院病历内容区
// 核心职责：
// - 在有医院回流记录时展示概览和列表
// - 在无记录时提供居中的医院病历空状态
private struct PetMedicalRecordContent: View {
    let records: [PetMedicalRecord]
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    let onOpen: (PetMedicalRecord) -> Void

    var body: some View {
        if records.isEmpty {
            VStack {
                PetMedicalRecordEmptyState()
            }
            .padding(.horizontal, MHBTheme.Spacing.s5)
            .padding(.top, topPadding)
            .padding(.bottom, bottomPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else {
            MHBScreenScrollView {
                VStack(alignment: .leading, spacing: MHBTheme.Spacing.s5) {
                    PetMedicalRecordOverviewSection(recordCount: records.count)

                    PetMedicalRecordListSection(
                        records: records,
                        onOpen: onOpen
                    )
                }
                .padding(.horizontal, MHBTheme.Spacing.s5)
                .padding(.top, topPadding)
                .padding(.bottom, bottomPadding)
            }
        }
    }
}
