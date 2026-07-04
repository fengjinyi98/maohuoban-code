import SwiftUI
import UIKit
import MaohuobanDesignSystem

// PetMedicalRecordScreen 病历记录列表页
// 核心职责：
// - 展示当前宠物的病历记录列表
// - 承载新增病历、进入详情和宠物切换的前端 mock 状态流
struct PetMedicalRecordScreen: View {
    @Environment(\.dismiss) private var dismiss

    let context: PetRecordEntryContext
    let onRecorded: () -> Void

    @State private var selectedPet: PetRecordSwitchPet?
    @State private var records: [PetMedicalRecord]
    @State private var selectedRecordID: String?
    @State private var isCreateSheetPresented = false
    @State private var windowSafeAreaInsets = UIEdgeInsets.zero

    init(
        context: PetRecordEntryContext,
        onRecorded: @escaping () -> Void = {}
    ) {
        self.context = context
        self.onRecorded = onRecorded
        let pets = PetMedicalRecordScreen.availablePets(from: context)
        self._selectedPet = State(initialValue: context.selectedSwitchPet ?? pets.first)
        self._records = State(initialValue: PetMedicalRecordMockData.records(for: pets))
    }

    var body: some View {
        GeometryReader { proxy in
            let topInset = effectiveTopInset(geometrySafeAreaTop: proxy.safeAreaInsets.top)
            let bottomInset = proxy.safeAreaInsets.bottom

            ZStack(alignment: .topLeading) {
                MHBTheme.ColorToken.background.color
                    .ignoresSafeArea()

                MHBScreenScrollView {
                    VStack(alignment: .leading, spacing: MHBTheme.Spacing.s5) {
                        PetMedicalRecordOverviewSection(recordCount: filteredRecords.count)

                        PetMedicalRecordListSection(
                            records: filteredRecords,
                            onOpen: { record in
                                selectedRecordID = record.id
                            }
                        )
                    }
                    .padding(.horizontal, MHBTheme.Spacing.s5)
                    .padding(.top, topContentPadding(topInset: topInset))
                    .padding(.bottom, MHBTheme.Spacing.s8 + MHBTheme.Spacing.s8 + MHBTheme.Spacing.s6)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .zIndex(0)

                MHBWindowSafeAreaReader { insets in
                    windowSafeAreaInsets = insets
                }
                .allowsHitTesting(false)

                MHBBottomFloatingActionCTA(
                    title: "新增病历",
                    systemImage: "plus",
                    bottomInset: bottomInset,
                    action: {
                        isCreateSheetPresented = true
                    }
                )
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
                .zIndex(2)

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
            if let record = binding(for: recordID) {
                PetMedicalRecordDetailScreen(
                    record: record,
                    onAppendUpdate: { update in
                        append(update: update, to: recordID)
                    }
                )
            } else {
                PetRecordDetailPlaceholderScreen(
                    systemImage: "stethoscope",
                    title: "病历不存在",
                    subtitle: "这条病历记录已不可用。",
                    accessibilityIdentifier: "pet.medicalRecord.missing"
                )
            }
        }
        .sheet(isPresented: $isCreateSheetPresented) {
            PetMedicalRecordFormSheet(
                mode: .create,
                onSave: { draft in
                    createRecord(from: draft)
                }
            )
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

    private func binding(for recordID: String) -> Binding<PetMedicalRecord>? {
        guard let index = records.firstIndex(where: { $0.id == recordID }) else { return nil }
        return $records[index]
    }

    private func createRecord(from draft: PetMedicalRecordDraft) {
        let petID = currentPetID ?? "pet-medical-current"
        records.insert(draft.makeRecord(petID: petID), at: 0)
        onRecorded()
    }

    private func append(update: PetMedicalRecord.Update, to recordID: String) {
        guard let index = records.firstIndex(where: { $0.id == recordID }) else { return }
        records[index].appendUpdate(update)
        onRecorded()
    }
}
