import SwiftUI
import MaohuobanDesignSystem

// HomeQuickFactFeedingSheet 喂食快捷记录弹层
// 核心职责：
// - 让用户确认喂食宠物、食品类型和份量
// - 以可一键提交的默认值降低喂食记录负担
struct HomeQuickFactFeedingSheet: View {
    let context: HomeActionRoutingContext
    let currentUserID: String?
    let isSubmitting: Bool
    let foodOptions: [HomeQuickFactFeedingFoodOption]
    let onPetChanged: (String?) -> Void
    let onSubmit: (HomeQuickFactFeedingInput) -> Void
    let onCancel: () -> Void

    @State private var selectedPetID: String?
    @State private var selectedFoodKind: HomeQuickFactFeedingFoodKind = .mainFood
    @State private var expandedFoodKind: HomeQuickFactFeedingFoodKind?
    @State private var selectedFoodItemIDs: [HomeQuickFactFeedingFoodKind: String?] = [:]
    @State private var automaticDefaultItemIDs: [HomeQuickFactFeedingFoodKind: String?] = [:]
    @State private var amount: HomeQuickFactFeedingAmount = .normal
    @State private var occurredAt = Date()
    @State private var note = ""
    @State private var attachmentStore = PetEventAttachmentUploadStore()
    @State private var isPhotoPickerPresented = false

    init(
        context: HomeActionRoutingContext,
        currentUserID: String? = nil,
        isSubmitting: Bool,
        foodOptions: [HomeQuickFactFeedingFoodOption] = [],
        onPetChanged: @escaping (String?) -> Void = { _ in },
        onSubmit: @escaping (HomeQuickFactFeedingInput) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.context = context
        self.currentUserID = currentUserID
        self.isSubmitting = isSubmitting
        self.foodOptions = foodOptions
        self.onPetChanged = onPetChanged
        self.onSubmit = onSubmit
        self.onCancel = onCancel
        let initialMainFoodDefaultID = HomeQuickFactFeedingFoodSource.defaultItemID(
            for: .mainFood,
            in: foodOptions
        )
        self._selectedPetID = State(initialValue: context.selectedPetID ?? context.availablePets.first?.id)
        self._selectedFoodItemIDs = State(initialValue: [
            .mainFood: initialMainFoodDefaultID
        ])
        self._automaticDefaultItemIDs = State(initialValue: [
            .mainFood: initialMainFoodDefaultID
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
                                selectedItemIDs: $selectedFoodItemIDs,
                                foodOptions: foodOptions
                            )

                            HomeQuickFactSingleChoiceSection(
                                title: "份量",
                                options: amountOptions,
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
                                attachments: attachmentStore.attachments,
                                canAddMore: attachmentStore.canAddMore,
                                onAdd: {
                                    isPhotoPickerPresented = true
                                },
                                onRemove: attachmentStore.removeAttachment(id:),
                                onRetry: { id in
                                    Task {
                                        await attachmentStore.retryAttachment(
                                            id: id,
                                            currentUserID: currentUserID
                                        )
                                    }
                                }
                            )
                        }
                        .padding(.horizontal, MHBTheme.Spacing.s5)
                        .padding(.top, topContentPadding)
                        .padding(.bottom, MHBTheme.Spacing.s8 + MHBTheme.Spacing.s8 + MHBTheme.Spacing.s6)
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)

                    MHBBottomFloatingActionCTA(
                        title: submitButtonTitle,
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
                            selectedFoodItemIDs.updateValue(nil, forKey: .mainFood)
                            automaticDefaultItemIDs.updateValue(nil, forKey: .mainFood)
                            onPetChanged(petID)
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
        .onChange(of: foodOptions) { _, newOptions in
            syncSelectedFoodItem(with: newOptions)
            normalizeAmountSelection()
        }
        .onChange(of: selectedFoodKind) { _, _ in
            normalizeAmountSelection()
        }
        .onChange(of: selectedFoodItemIDs) { _, _ in
            normalizeAmountSelection()
        }
        .fullScreenCover(isPresented: $isPhotoPickerPresented) {
            MHBMediaPickerScreen(
                title: "添加照片",
                request: MHBMediaPickerRequest(
                    maxSelectionCount: attachmentStore.remainingSelectionCount,
                    filter: .images,
                    autoConfirmSingleSelection: attachmentStore.remainingSelectionCount == 1,
                    showsCameraEntry: true
                ),
                onComplete: handlePhotoPickerResult(_:),
                onCancel: {
                    isPhotoPickerPresented = false
                }
            )
        }
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
        guard !isSubmitting,
              !attachmentStore.isUploading,
              !attachmentStore.hasFailedUploads,
              selectedPetID != nil else { return }
        let lifeStatus = pets.first(where: { $0.id == selectedPetID })?.lifeStatus
        if let option = HomeQuickFactFeedingFoodSource.item(
            for: selectedFoodItemID(for: selectedFoodKind),
            in: selectedFoodKind,
            options: foodOptions
        ) {
            onSubmit(
                option.feedingInput(
                    petID: selectedPetID,
                    lifeStatus: lifeStatus,
                    amount: amount,
                    occurredAt: occurredAt,
                    note: note,
                    attachmentAssetIDs: attachmentStore.uploadedAssetIDs
                )
            )
            return
        }

        onSubmit(
            HomeQuickFactFeedingInput(
                petID: selectedPetID,
                lifeStatus: lifeStatus,
                foodKind: selectedFoodKind,
                foodName: nil,
                foodItemID: nil,
                foodSnapshotJSON: nil,
                isDefaultFood: false,
                amount: amount,
                occurredAt: occurredAt,
                note: note,
                attachmentAssetIDs: attachmentStore.uploadedAssetIDs
            )
        )
    }

    private func handlePhotoPickerResult(_ result: MHBMediaPickerResult) {
        isPhotoPickerPresented = false
        Task {
            await attachmentStore.uploadPickedImages(
                result.images,
                localIdentifiers: result.imageLocalIdentifiers,
                currentUserID: currentUserID
            )
        }
    }

    private func selectedFoodItemID(for kind: HomeQuickFactFeedingFoodKind) -> String? {
        HomeQuickFactFeedingFoodSource.selectedItemID(
            for: kind,
            selectedItemIDs: selectedFoodItemIDs,
            options: foodOptions
        )
    }

    private var selectedFoodOption: HomeQuickFactFeedingFoodOption? {
        HomeQuickFactFeedingFoodSource.item(
            for: selectedFoodItemID(for: selectedFoodKind),
            in: selectedFoodKind,
            options: foodOptions
        )
    }

    private var amountOptions: [HomeQuickFactFeedingAmount] {
        switch selectedFoodKind {
        case .wetFood:
            HomeQuickFactFeedingAmount.packageOptions(unit: selectedFoodOption?.unit)
        case .mainFood, .snack, .supplement, .other:
            HomeQuickFactFeedingAmount.fuzzyOptions
        }
    }

    private func normalizeAmountSelection() {
        guard !amountOptions.contains(amount),
              let firstAmount = amountOptions.first
        else { return }
        amount = firstAmount
    }

    private func syncSelectedFoodItem(with options: [HomeQuickFactFeedingFoodOption]) {
        let syncedItemID = HomeQuickFactFeedingFoodSource.syncedSelectedItemID(
            for: .mainFood,
            currentSelectedItemID: selectedFoodItemIDs[.mainFood] ?? nil,
            previousDefaultItemID: automaticDefaultItemIDs[.mainFood] ?? nil,
            isManualSelection: false,
            options: options
        )
        selectedFoodItemIDs[.mainFood] = syncedItemID
        automaticDefaultItemIDs[.mainFood] = HomeQuickFactFeedingFoodSource.defaultItemID(
            for: .mainFood,
            in: options
        )
    }

    private var topContentPadding: CGFloat {
        MHBTheme.Spacing.s8 + MHBTheme.Spacing.s5
    }

    private var submitButtonTitle: String {
        if isSubmitting {
            return "保存中"
        }
        if attachmentStore.isUploading {
            return "照片上传中"
        }
        if attachmentStore.hasFailedUploads {
            return "照片需处理"
        }
        return "保存记录"
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
