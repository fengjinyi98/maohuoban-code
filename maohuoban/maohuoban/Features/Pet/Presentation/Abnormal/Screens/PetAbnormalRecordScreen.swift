import SwiftUI
import MaohuobanDesignSystem

// PetAbnormalRecordScreen 异常记录页面
// 核心职责：
// - 收集宠物异常的症状、程度、具体表现、备注和照片线索
// - 使用自绘导航栏承载返回和宠物切换基础设施
// - 保存异常事件后回到首页并触发刷新
struct PetAbnormalRecordScreen: View {
    @Environment(\.dismiss) private var dismiss

    let context: PetRecordEntryContext
    let currentUserID: String?
    let onRecorded: () -> Void

    @State private var selectedPet: PetRecordSwitchPet?
    @State private var selectedSymptoms: Set<PetAbnormalSymptom> = []
    @State private var selectedDetails: Set<String> = []
    @State private var severity: PetAbnormalSeverity = .mild
    @State private var occurredAt = Date()
    @State private var note = ""
    @State private var attachmentStore = PetEventAttachmentUploadStore()
    @State private var isPhotoPickerPresented = false
    @State private var store = PetWriteStore()
    @State private var isSubmitting = false

    var body: some View {
        GeometryReader { proxy in
            let bottomInset = proxy.safeAreaInsets.bottom

            ZStack(alignment: .topLeading) {
                MHBTheme.ColorToken.background.color
                    .ignoresSafeArea()

                MHBScreenScrollView {
                    VStack(alignment: .leading, spacing: MHBTheme.Spacing.s5) {
                        PetAbnormalRecordSummaryCard()

                        PetAbnormalSymptomSection(
                            selectedSymptoms: $selectedSymptoms,
                            selectedDetails: $selectedDetails
                        )

                        PetAbnormalSeveritySection(severity: $severity)

                        PetAbnormalDateSection(occurredAt: $occurredAt)

                        PetAbnormalNoteSection(note: $note)

                        PetAbnormalPhotoSection(
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
                    .padding(.top, topContentPadding(geometrySafeAreaTop: proxy.safeAreaInsets.top))
                    .padding(.bottom, MHBTheme.Spacing.s8 + MHBTheme.Spacing.s8 + MHBTheme.Spacing.s6)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .zIndex(0)

                MHBBottomFloatingActionCTA(
                    title: submitButtonTitle,
                    systemImage: "checkmark",
                    bottomInset: bottomInset,
                    action: submit
                )
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
                .zIndex(2)

                PetAbnormalRecordTopChrome(
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
        .petWriteToastBridge(
            phase: store.phase,
            successMessage: store.successMessage
        )
        .onAppear {
            selectedPet = selectedPet ?? context.selectedSwitchPet
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
        .accessibilityIdentifier("pet.abnormalRecord.screen")
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
            MHBPetSwitcherItem(abnormalRecordPet: pet, isSelected: pet.id == currentPetID)
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
            isSelected: true
        )
    }

    private func submit() {
        guard isSubmitting == false,
              !attachmentStore.isUploading,
              !attachmentStore.hasFailedUploads,
              let currentPetID,
              selectedSymptoms.isEmpty == false else {
            return
        }

        isSubmitting = true
        Task {
            await store.createEvent(
                petID: currentPetID,
                draft: eventDraft(),
                currentUserID: currentUserID,
                lifeStatus: context.lifeStatus
            )
            isSubmitting = false

            if case .recordedEvent = store.phase {
                onRecorded()
                dismiss()
            }
        }
    }

    private func eventDraft() -> PetEventDraft {
        let symptomKinds = PetAbnormalSymptom.allCases
            .filter { selectedSymptoms.contains($0) }
            .map(\.rawValue)
        let symptomText = PetAbnormalSymptom.allCases
            .filter { selectedSymptoms.contains($0) }
            .map(\.title)
            .joined(separator: "、")
        let detailText = selectedDetails.sorted().joined(separator: "、")
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let detailSummary = detailText.isEmpty ? "" : "，表现：\(detailText)"
        let noteSummary = trimmedNote.isEmpty ? "" : "，备注：\(trimmedNote)"

        var payload: [String: PetEventPayloadValue] = [
            "symptom_kinds": .stringArray(symptomKinds),
            "severity": .string(severity.rawValue),
            "attachment_asset_ids": .stringArray(attachmentStore.uploadedAssetIDs)
        ]

        if !detailText.isEmpty {
            payload["symptom_details"] = .stringArray(selectedDetails.sorted())
        }

        if !trimmedNote.isEmpty {
            payload["note"] = .string(trimmedNote)
        }

        return PetEventDraft(
            kind: .health,
            subkind: "abnormal_symptom",
            title: "异常记录",
            summary: "异常：\(symptomText)，程度：\(severity.title)\(detailSummary)\(noteSummary)",
            visibility: .private,
            occurredAt: PetWriteFormatters.occurredAtString(from: occurredAt),
            eventPayload: payload
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
        return "保存异常记录"
    }
}
