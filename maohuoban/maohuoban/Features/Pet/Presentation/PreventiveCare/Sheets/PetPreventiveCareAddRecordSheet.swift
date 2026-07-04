import SwiftUI
import UIKit
import MaohuobanDesignSystem

// PetPreventiveCareAddRecordSheet 疫苗驱虫记录表单弹层
// 核心职责：
// - 复用同一表单承载新增和编辑疫苗驱虫记录
// - 通过即时上传附件资产后提交事件写入命令
struct PetPreventiveCareAddRecordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isNameFocused: Bool

    let mode: PetPreventiveCareFormMode
    let currentUserID: String?
    let isSubmitting: Bool
    let onSave: (PetPreventiveCareFormMode, PetPreventiveCareDraft) -> Void

    @State private var selectedKind: PetPreventiveCareKind = .vaccine
    @State private var nameText = ""
    @State private var completedAt = Date()
    @State private var reminderEnabled = true
    @State private var reminderAt = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var executionMethod = PetPreventiveCareExecutionMethod.hospital
    @State private var executionName = ""
    @State private var note = ""
    @State private var attachmentStore = PetEventAttachmentUploadStore(maxAttachmentCount: 5)
    @State private var isPhotoPickerPresented = false

    init(
        mode: PetPreventiveCareFormMode = .create,
        currentUserID: String?,
        isSubmitting: Bool,
        onSave: @escaping (PetPreventiveCareFormMode, PetPreventiveCareDraft) -> Void
    ) {
        self.mode = mode
        self.currentUserID = currentUserID
        self.isSubmitting = isSubmitting
        self.onSave = onSave
        let initialDraft = mode.initialDraft
        self._selectedKind = State(initialValue: initialDraft.kind)
        self._nameText = State(initialValue: initialDraft.name)
        self._completedAt = State(initialValue: initialDraft.completedAt)
        self._reminderEnabled = State(initialValue: initialDraft.reminderEnabled)
        self._reminderAt = State(initialValue: initialDraft.reminderAt)
        self._executionMethod = State(initialValue: initialDraft.executionMethod)
        self._executionName = State(initialValue: initialDraft.executionName)
        self._note = State(initialValue: initialDraft.note)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    MHBTheme.ColorToken.background.color
                        .ignoresSafeArea()

                    ScrollView {
                        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s5) {
                            PetPreventiveCareTypeSection(selectedKind: $selectedKind)

                            PetPreventiveCareNameSection(
                                selectedKind: selectedKind,
                                nameText: $nameText,
                                isNameFocused: $isNameFocused
                            )

                            PetPreventiveCareDateSection(
                                title: "完成日期",
                                date: $completedAt
                            )

                            PetPreventiveCareExecutionSection(
                                selectedMethod: $executionMethod,
                                executionName: $executionName
                            )

                            PetPreventiveCareReminderSection(
                                isEnabled: $reminderEnabled,
                                reminderAt: $reminderAt
                            )

                            PetPreventiveCareNoteSection(note: $note)

                            PetPreventiveCarePhotoSection(
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
                        .padding(.bottom, MHBTheme.Spacing.s8)
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)

                    PetPreventiveCareAddRecordTopChrome(
                        title: mode.title,
                        isSaveDisabled: isSaveDisabled,
                        onClose: { dismiss() },
                        onSave: saveRecord
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
        .presentationCornerRadius(24)
        .onChange(of: selectedKind) { _, newKind in
            applyDefaults(for: newKind)
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
        .task {
            attachmentStore.replaceWithUploadedAssets(mode.initialDraft.attachmentAssetIDs)
        }
        .accessibilityIdentifier("pet.preventiveCare.addRecordSheet")
    }

    private var topContentPadding: CGFloat {
        MHBTheme.Spacing.s8 + MHBTheme.Spacing.s5
    }

    private func applyDefaults(for kind: PetPreventiveCareKind) {
        switch kind {
        case .vaccine:
            executionMethod = .hospital
            reminderAt = Calendar.current.date(byAdding: .year, value: 1, to: completedAt) ?? reminderAt
        case .deworming:
            executionMethod = .selfCompleted
            reminderAt = Calendar.current.date(byAdding: .month, value: 1, to: completedAt) ?? reminderAt
        case .all:
            break
        }
        executionName = ""
    }

    private func saveRecord() {
        guard !isSubmitting,
              !attachmentStore.isUploading,
              !attachmentStore.hasFailedUploads else { return }
        onSave(mode, currentDraft)
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

    private var currentDraft: PetPreventiveCareDraft {
        PetPreventiveCareDraft(
            kind: selectedKind,
            name: nameText,
            completedAt: completedAt,
            reminderEnabled: reminderEnabled,
            reminderAt: reminderAt,
            executionMethod: executionMethod,
            executionName: executionName,
            note: note,
            attachmentAssetIDs: attachmentStore.uploadedAssetIDs
        )
    }

    private var isSaveDisabled: Bool {
        isSubmitting || attachmentStore.isUploading || attachmentStore.hasFailedUploads
    }
}

// PetPreventiveCareAddRecordTopChrome 新增记录弹层顶部控件
// 核心职责：
// - 在原生 sheet 内固定标题、关闭入口和保存入口
// - 保持新增和编辑表单共用同一顶部操作模型
private struct PetPreventiveCareAddRecordTopChrome: View {
    let title: LocalizedStringResource
    let isSaveDisabled: Bool
    let onClose: () -> Void
    let onSave: () -> Void

    var body: some View {
        ZStack {
            Text(title)
                .font(MHBTheme.Typography.headline.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .frame(maxWidth: .infinity)

            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                        .frame(width: 48, height: 48)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("关闭")

                Spacer()

                Button(action: onSave) {
                    Text("保存")
                        .font(MHBTheme.Typography.callout.weight(.semibold))
                        .foregroundStyle(isSaveDisabled ? MHBTheme.ColorToken.labelTertiary.color : MHBTheme.ColorToken.primary.color)
                        .padding(.horizontal, MHBTheme.Spacing.s4)
                        .frame(height: 40)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isSaveDisabled)
                .glassEffect(.regular.interactive(), in: .capsule)
                .accessibilityLabel("保存")
            }
        }
        .frame(height: 48)
    }
}

// PetPreventiveCareFormMode 疫苗驱虫表单入口模式
// 核心职责：
// - 区分新增和编辑记录的初始草稿与提交文案
// - 保持同一表单页面复用创建和更新流程
enum PetPreventiveCareFormMode: Equatable, Identifiable {
    case create
    case edit(PetPreventiveCareRecord)

    var id: String {
        switch self {
        case .create:
            "create"
        case .edit(let record):
            "edit-\(record.id)"
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .create:
            "新增记录"
        case .edit:
            "修改记录"
        }
    }

    var initialDraft: PetPreventiveCareDraft {
        switch self {
        case .create:
            let now = Date()
            return PetPreventiveCareDraft(
                kind: .vaccine,
                name: "",
                completedAt: now,
                reminderEnabled: true,
                reminderAt: Calendar.current.date(byAdding: .year, value: 1, to: now) ?? now,
                executionMethod: .hospital,
                executionName: "",
                note: "",
                attachmentAssetIDs: []
            )
        case .edit(let record):
            return PetPreventiveCareDraft(
                kind: record.kind,
                name: record.title,
                completedAt: record.completedAt,
                reminderEnabled: record.nextDueAt != nil,
                reminderAt: record.nextDueAt ?? Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date(),
                executionMethod: PetPreventiveCareExecutionMethod(rawValue: record.executionMethodRawValue ?? "") ?? .hospital,
                executionName: record.executionName ?? "",
                note: record.note ?? "",
                attachmentAssetIDs: record.attachmentAssetIDs
            )
        }
    }
}

// PetPreventiveCareExecutionMethod 疫苗驱虫执行方式
// 核心职责：
// - 表达记录由用户、医院、商家或其他来源完成
// - 控制是否需要补充执行主体名称
enum PetPreventiveCareExecutionMethod: String, CaseIterable, Identifiable {
    case selfCompleted
    case hospital
    case merchant
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .selfCompleted: "自己完成"
        case .hospital: "医院完成"
        case .merchant: "商家完成"
        case .other: "其他"
        }
    }

    var systemImage: String {
        switch self {
        case .selfCompleted: "person.fill.checkmark"
        case .hospital: "cross.case.fill"
        case .merchant: "storefront.fill"
        case .other: "ellipsis.circle.fill"
        }
    }

    var subjectTitle: String {
        switch self {
        case .selfCompleted: "执行说明"
        case .hospital: "医院名称"
        case .merchant: "商家名称"
        case .other: "来源说明"
        }
    }

    var subjectPrompt: String {
        switch self {
        case .selfCompleted: "例如 家里口服"
        case .hospital: "例如 瑞派宠物医院"
        case .merchant: "例如 小鹿猫舍"
        case .other: "例如 原主人提供"
        }
    }

    var needsSubjectInput: Bool {
        self != .selfCompleted
    }
}
